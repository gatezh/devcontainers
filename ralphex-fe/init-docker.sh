#!/bin/sh
# Init script for ralphex docker container.
# The entrypoint (/init.sh) runs /srv/init.sh if it exists before the main command.
#
# Source: https://github.com/umputun/ralphex/blob/master/scripts/internal/init-docker.sh
# Copied from umputun/ralphex; local additions are marked "Local:" or cite
# an issue. Check upstream for updates.

# ── Local: ~/.claude must exist without the host mount (#128) ───────────────
# Claude Code writes into it (as app). Not recursive: only the copies below
# are chowned, never anything bind-mounted in.
mkdir -p /home/app/.claude
chown app:app /home/app/.claude

# copy only essential claude files (not the entire 2GB directory)
if [ -d /mnt/claude ]; then
    # copy config files only (not cache, history, debug, todos, etc.)
    for f in .credentials.json settings.json settings.local.json CLAUDE.md format.sh; do
        [ -e "/mnt/claude/$f" ] && cp -L "/mnt/claude/$f" "/home/app/.claude/$f" 2>/dev/null || true
    done
    # copy essential directories (symlinked in dotfiles setups)
    for d in commands skills hooks agents plugins; do
        [ -d "/mnt/claude/$d" ] && cp -rL "/mnt/claude/$d" "/home/app/.claude/" 2>/dev/null || true
    done
    # ── Local: the image has no rtk; drop a host rtk hook from this copy ────
    # Otherwise `rtk hook claude` errors on every Bash call. The host file is untouched.
    S=/home/app/.claude/settings.json
    if [ -f "$S" ] && grep -q 'rtk' "$S"; then
        jq 'if .hooks.PreToolUse then .hooks.PreToolUse |= (map(.hooks |= map(select((.command // "") | test("(^|/)rtk hook claude$|rtk-rewrite\\.sh") | not))) | map(select(.hooks | length > 0))) else . end' "$S" > /tmp/settings.json && mv /tmp/settings.json "$S"
    fi

    chown -R app:app /home/app/.claude
fi

# copy credentials extracted from macOS keychain (mounted separately)
if [ -f /mnt/claude-credentials.json ]; then
    mkdir -p /home/app/.claude
    cp /mnt/claude-credentials.json /home/app/.claude/.credentials.json
    chown -R app:app /home/app/.claude
    chmod 600 /home/app/.claude/.credentials.json
fi

# copy codex credentials if mounted
if [ -d /mnt/codex ]; then
    mkdir -p /home/app/.codex
    cp -rL /mnt/codex/* /home/app/.codex/ 2>/dev/null || true
    chown -R app:app /home/app/.codex
fi
