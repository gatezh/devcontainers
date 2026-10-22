#!/bin/bash
# Patch every cached @playwright/mcp .mcp.json to launch the system chromium.
# Idempotent — safe to run on every container start.
#
# Why this exists:
#   @playwright/mcp's default --browser is the chrome channel, which looks at
#   /opt/google/chrome/chrome — we ship /usr/bin/chromium instead. The
#   PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH env var is a project convention, not
#   read by Playwright automatically, so MCP needs an explicit --executable-path.
#
# Why a loop instead of `find -print -quit`:
#   Plugin auto-updates extract into fresh cache dirs (one per version hash),
#   each with an unpatched .mcp.json. Patching only the first match (#64) left
#   newer cache dirs broken until container rebuild.
#
# Wire-up: invoke from postCreateCommand (init-plugins.sh) and postStartCommand
# (devcontainer.json) so plugin auto-updates between sessions get re-patched.

set -euo pipefail

if [ ! -x /usr/bin/chromium ]; then
    exit 0
fi

# A fresh ~/.claude volume has no plugin cache until init-plugins.sh runs; find would exit 1 (#207).
[ -d "$HOME/.claude/plugins/cache" ] || exit 0

find "$HOME/.claude/plugins/cache" -path "*/playwright*/.mcp.json" 2>/dev/null \
| while read -r MCP_CONFIG; do
    jq '.playwright.args = [
          "@playwright/mcp@latest",
          "--browser", "chromium",
          "--executable-path", "/usr/bin/chromium",
          "--no-sandbox",
          "--headless"
        ]' \
        "$MCP_CONFIG" > /tmp/playwright-mcp.json \
        && mv /tmp/playwright-mcp.json "$MCP_CONFIG" \
        && echo "✔ Playwright MCP patched: $MCP_CONFIG"
done
