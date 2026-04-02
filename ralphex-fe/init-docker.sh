#!/bin/sh
# Init script for ralphex docker container.
# The entrypoint (/init.sh) runs /srv/init.sh if it exists before the main command.
#
# Source: https://github.com/umputun/ralphex/blob/master/scripts/internal/init-docker.sh
# Copied as-is from umputun/ralphex. Check upstream for updates.

# copy only essential claude files (not the entire 2GB directory)
if [ -d /mnt/claude ]; then
    mkdir -p /home/app/.claude
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

    chown -R app:app /home/app/.claude

    # ── RTK: ensure rewrite hook is configured ─────────────────────────────
    # Host mount usually brings the hook, but init idempotently to cover
    # standalone usage (no host mount). --hook-only avoids workspace artifacts.
    if command -v rtk >/dev/null 2>&1; then
        gosu app rtk init -g --hook-only --auto-patch 2>/dev/null || true
    fi
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
