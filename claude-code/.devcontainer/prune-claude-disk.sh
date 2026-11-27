#!/bin/bash
# Reclaims container disk that Claude Code sessions leave behind. Runs as an async
# managed SessionStart hook; the container's disk is the host's.
# - scratchpads of other sessions that aren't running and are idle > SCRATCH_DAYS
#   (transcript and files), except ones holding a repo with unsaved git work
# - npx installs unused for NPX_DAYS, and the npm cache once it exceeds CACHE_MAX_MB
#
# Prints only {"systemMessage": ...} JSON: plain SessionStart stdout is added to
# Claude's context.

set -uo pipefail
shopt -s nullglob
SCRATCH_DAYS=${SCRATCH_DAYS:-1}
NPX_DAYS=${NPX_DAYS:-7}
CACHE_MAX_MB=${CACHE_MAX_MB:-1024}

current=$(jq -r '.session_id // empty' 2>/dev/null || true)
tmp=${CLAUDE_CODE_TMPDIR:-${TMPDIR:-/tmp}}
root="${tmp%/}/claude-$(id -u)"
config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
uuid='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
freed=0
kept=()

git_in() { git --no-optional-locks -c safe.directory='*' -C "$1" "${@:2}" 2>/dev/null; }
repos() { find "$1" -name node_modules -prune -o -name .git "${@:2}" -print -prune 2>/dev/null; }

# True if a repo under $1 has uncommitted, stashed or unpushed work, or git fails on it.
has_unsaved_work() {
  local repo out tip
  while IFS= read -r repo; do
    repo=${repo%/.git}
    out=$(git_in "$repo" status --porcelain) && [ -z "$out" ] || return 0
    git_in "$repo" rev-parse -q --verify refs/stash >/dev/null && return 0
    tip=()
    git_in "$repo" rev-parse -q --verify HEAD >/dev/null && tip=(HEAD)
    out=$(git_in "$repo" log --branches "${tip[@]}" --not --remotes --oneline -1) &&
      [ -z "$out" ] || return 0
  done < <(repos "$1")
  return 1
}

remove() {
  local kb
  kb=$(du -sk "$1" 2>/dev/null | cut -f1)
  chmod -R u+w "$1" 2>/dev/null # read-only trees, such as Go's module cache
  rm -rf "$1" && freed=$((freed + ${kb:-0}))
}

# Deletes a session dir, then unregisters linked worktrees it held from their main repo.
remove_session() {
  local wt common commons=()
  while IFS= read -r wt; do
    common=$(git_in "${wt%/.git}" rev-parse --path-format=absolute --git-common-dir) &&
      commons+=("$common")
  done < <(repos "$1" -type f)
  remove "$1"
  for common in "${commons[@]}"; do git_in "$common" worktree prune; done
}

# Running sessions: Claude Code keeps sessions/<pid>.json while each one runs.
pidfiles=("$config"/sessions/*.json)
live=""
scan=true
if [ ${#pidfiles[@]} -gt 0 ]; then
  live=$(jq -r '.sessionId // empty' "${pidfiles[@]}" 2>/dev/null) || scan=false
fi

# Only <project>/<session-uuid>/ dirs hold a session's own scratchpad; skip the rest.
for dir in "$root"/*/*/; do
  $scan || break
  dir=${dir%/}
  sid=${dir##*/}
  [[ $sid =~ $uuid && -d $dir/scratchpad ]] || continue
  [ "$sid" = "$current" ] && continue
  grep -qxF "$sid" <<<"$live" && continue
  recent=$(find "$dir" "$config"/projects/*/"$sid".jsonl \
    -mmin -$((SCRATCH_DAYS * 1440)) -print -quit 2>/dev/null)
  [ -n "$recent" ] && continue
  if has_unsaved_work "$dir"; then kept+=("$dir"); continue; fi
  remove_session "$dir"
done

cache=$(npm config get cache --logs-max=0 2>/dev/null) || cache="$HOME/.npm"
if [ -d "$cache/_npx" ]; then
  # npx bumps an entry's mtime on each use; skip one a running `npm exec <pkg|bin>` uses.
  running=$(for f in /proc/[0-9]*/cmdline; do tr '\0' ' ' <"$f"; echo; done 2>/dev/null |
    grep '^npm exec ')
  while IFS= read -r d; do
    while IFS= read -r pkg; do
      grep -qF " $pkg" <<<"$running" && continue 2
    done < <(jq -r '.dependencies // {} | keys[]' "$d/package.json" 2>/dev/null
             find "$d/node_modules/.bin" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null)
    remove "$d"
  done < <(find "$cache/_npx" -mindepth 1 -maxdepth 1 -type d -mtime +"$NPX_DAYS")
fi

if [ -d "$cache/_cacache" ]; then
  kb=$(du -sk "$cache/_cacache" | cut -f1)
  if [ "$kb" -gt $((CACHE_MAX_MB * 1024)) ] && npm cache clean --force >/dev/null 2>&1; then
    freed=$((freed + kb))
  fi
fi

msg=""
[ "$freed" -gt 10240 ] && msg="Disk cleanup freed $((freed / 1024)) MB."
[ ${#kept[@]} -gt 0 ] && msg="$msg Kept stale scratchpads with unpushed git work: ${kept[*]}"
[ -n "$msg" ] && jq -nc --arg m "${msg# }" '{systemMessage: $m}'
exit 0
