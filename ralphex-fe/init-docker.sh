#!/bin/sh
# Init script for ralphex docker container.
# The entrypoint (/init.sh) runs /srv/init.sh if it exists before the main command.
#
# Source: https://github.com/umputun/ralphex/blob/master/scripts/internal/init-docker.sh
# Copied from umputun/ralphex; local additions are marked "Local:" or cite
# an issue. Check upstream for updates.

# ── Local: ~/.claude must exist without the host mount (#128) ───────────────
# rtk init -g below writes into it and fails if it is missing.
mkdir -p /home/app/.claude

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
    # ── Playwright MCP: use system Chromium (#64, #67) ──────────────────────
    # @playwright/mcp defaults to --browser chrome, which isn't installed in Docker.
    # Point it at the system Chromium with --executable-path and --no-sandbox.
    PLAYWRIGHT_MCP_CONFIG="/home/app/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/playwright/.mcp.json"
    if [ -f "$PLAYWRIGHT_MCP_CONFIG" ]; then
        jq '.playwright.args = ["@playwright/mcp@latest", "--browser", "chromium", "--executable-path", "/usr/bin/chromium", "--no-sandbox"]' \
            "$PLAYWRIGHT_MCP_CONFIG" > /tmp/playwright-mcp.json \
            && mv /tmp/playwright-mcp.json "$PLAYWRIGHT_MCP_CONFIG"
    fi
fi

chown -R app:app /home/app/.claude

# ── Local: RTK rewrite hook, with or without the host mount (#128) ──────────
# Idempotent; --hook-only avoids workspace artifacts. Telemetry prompt:
# RTK_TELEMETRY_DISABLED=1 opts out (rtk-ai/rtk#2477), closed stdin stops it
# blocking, and timeout backstops any other hang.
if command -v rtk >/dev/null 2>&1; then
    RTK_TELEMETRY_DISABLED=1 gosu app timeout 10 rtk init -g --hook-only --auto-patch < /dev/null 2>/dev/null || true
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
