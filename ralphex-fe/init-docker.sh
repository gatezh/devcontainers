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
    # ── Playwright MCP: use Chromium on ARM64 (#64) ────────────────────────
    # @playwright/mcp defaults to --browser chrome, which has no Linux ARM64 builds.
    # Patch the plugin config to use chromium instead. No-op on AMD64.
    PLAYWRIGHT_MCP_CONFIG="/home/app/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/playwright/.mcp.json"
    if [ "$(uname -m)" = "aarch64" ] && [ -f "$PLAYWRIGHT_MCP_CONFIG" ]; then
        jq '.playwright.args = ["@playwright/mcp@latest", "--browser", "chromium"]' \
            "$PLAYWRIGHT_MCP_CONFIG" > /tmp/playwright-mcp.json \
            && mv /tmp/playwright-mcp.json "$PLAYWRIGHT_MCP_CONFIG"
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
