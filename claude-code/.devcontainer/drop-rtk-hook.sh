#!/bin/bash
# Removes the `rtk hook claude` PreToolUse entry that init-plugins.sh registered
# while the image shipped rtk. It persists on the ~/.claude volume and, without the
# binary, errors on every Bash call. Runs as a managed SessionStart hook, so every
# project is cleaned on its next session with no template change.
# Transitional: delete this script and its hook after 2027-01-31.
#
# Silent on purpose: SessionStart stdout is added to Claude's context.

set -euo pipefail

SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
grep -qs 'rtk' "$SETTINGS" || exit 0

jq 'if .hooks.PreToolUse then .hooks.PreToolUse |= (map(.hooks |= map(select((.command // "") | test("(^|/)rtk hook claude$|rtk-rewrite\\.sh") | not))) | map(select(.hooks | length > 0))) else . end' \
    "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
