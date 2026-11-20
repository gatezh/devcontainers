#!/bin/bash
# Reclaims container disk that Claude Code sessions leave behind. Runs as an async
# managed SessionStart hook; the container's disk is the host's.
# - scratchpads of other sessions idle > SCRATCH_DAYS (by transcript mtime), except
#   ones holding a git repo with uncommitted or unpushed work
# - npx installs older than NPX_DAYS, and the npm cache once it exceeds CACHE_MAX_MB
#
# Prints only {"systemMessage": ...} JSON: plain SessionStart stdout is added to
# Claude's context.

set -uo pipefail
SCRATCH_DAYS=${SCRATCH_DAYS:-1}
NPX_DAYS=${NPX_DAYS:-7}
CACHE_MAX_MB=${CACHE_MAX_MB:-1024}

current=$(jq -r '.session_id // empty' 2>/dev/null || true)
root="/tmp/claude-$(id -u)"
projects="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
freed=0
kept=()

git_in() { git -c safe.directory='*' -C "$1" "${@:2}" 2>/dev/null; }

has_unsaved_work() {
  local repo
  while IFS= read -r repo; do
    repo=${repo%/.git}
    [ -n "$(git_in "$repo" status --porcelain)" ] && return 0
    [ -n "$(git_in "$repo" log --branches --not --remotes --oneline -1)" ] && return 0
  done < <(find "$1" -maxdepth 4 -name .git -prune 2>/dev/null)
  return 1
}

remove() {
  local kb
  kb=$(du -sk "$1" 2>/dev/null | cut -f1)
  rm -rf "$1" && freed=$((freed + ${kb:-0}))
}

shopt -s nullglob
for dir in "$root"/*/*/; do
  sid=$(basename "$dir")
  [ "$sid" = "$current" ] && continue
  transcripts=("$projects"/*/"$sid".jsonl)
  if [ ${#transcripts[@]} -gt 0 ] &&
     [ -n "$(find "${transcripts[0]}" -mmin -$((SCRATCH_DAYS * 1440)))" ]; then
    continue
  fi
  if has_unsaved_work "$dir"; then kept+=("$dir"); continue; fi
  remove "$dir"
done

if [ -d "$HOME/.npm/_npx" ]; then
  while IFS= read -r d; do remove "$d"; done \
    < <(find "$HOME/.npm/_npx" -mindepth 1 -maxdepth 1 -type d -mtime +"$NPX_DAYS")
fi

if [ -d "$HOME/.npm/_cacache" ]; then
  kb=$(du -sk "$HOME/.npm/_cacache" | cut -f1)
  if [ "$kb" -gt $((CACHE_MAX_MB * 1024)) ] && npm cache clean --force >/dev/null 2>&1; then
    freed=$((freed + kb))
  fi
fi

msg=""
[ "$freed" -gt 10240 ] && msg="Disk cleanup freed $((freed / 1024)) MB."
[ ${#kept[@]} -gt 0 ] && msg="$msg Kept stale scratchpads with unpushed git work: ${kept[*]}"
[ -n "$msg" ] && jq -nc --arg m "${msg# }" '{systemMessage: $m}'
exit 0
