#!/bin/bash
# Claude Code plugin initialization — runs once at container creation.
# Idempotent — safe to run multiple times.
#
# Wire into postCreateCommand in your devcontainer.json:
#   "postCreateCommand": "bash .devcontainer/init-plugins.sh"

set -euo pipefail

# Mark onboarding complete so claude CLI doesn't hang on interactive prompts
if [ -f "$HOME/.claude/.claude.json" ]; then
    jq '.hasCompletedOnboarding = true' "$HOME/.claude/.claude.json" > /tmp/.claude.json \
        && mv /tmp/.claude.json "$HOME/.claude/.claude.json"
else
    mkdir -p "$HOME/.claude"
    echo '{"hasCompletedOnboarding":true}' > "$HOME/.claude/.claude.json"
fi

# ── Claude Code plugins ─────────────────────────────────────────────────────
# Customize this list — remove plugins you don't use.
PLUGINS=(
    "frontend-design@claude-plugins-official"
    "code-review@claude-plugins-official"
    "typescript-lsp@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "playwright@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "explanatory-output-style@claude-plugins-official"
    "claude-md-management@claude-plugins-official"
    "claude-code-setup@claude-plugins-official"
    "posthog@claude-plugins-official"
    "ralphex@ralphex"
)

for plugin in "${PLUGINS[@]}"; do
    claude plugin install "$plugin" 2>/dev/null || true
done

# ── Playwright MCP: use Chromium on ARM64 (#64) ─────────────────────────────
# @playwright/mcp defaults to --browser chrome, which has no Linux ARM64 builds.
# Patch the plugin config to use chromium instead. No-op on AMD64.
PLAYWRIGHT_MCP_CONFIG="$HOME/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/playwright/.mcp.json"
if [ "$(uname -m)" = "aarch64" ] && [ -f "$PLAYWRIGHT_MCP_CONFIG" ]; then
    jq '.playwright.args = ["@playwright/mcp@latest", "--browser", "chromium"]' \
        "$PLAYWRIGHT_MCP_CONFIG" > /tmp/playwright-mcp.json \
        && mv /tmp/playwright-mcp.json "$PLAYWRIGHT_MCP_CONFIG"
fi

# ── rtk init (token-optimized CLI proxy) ────────────────────────────────────
# Global hook-first mode: installs only the PreToolUse rewrite hook to ~/.claude/,
# no workspace artifacts (CLAUDE.md, .rtk/). Safe to run multiple times.
if command -v rtk &>/dev/null; then
    rtk init -g --hook-only --auto-patch 2>/dev/null || true
fi

# ── agent-browser skill ─────────────────────────────────────────────────────
# Installs the agent-browser Claude Code skill for headless browser automation.
# agent-browser CLI is pre-installed in the default devcontainer image (not sandbox).
if command -v agent-browser &>/dev/null; then
    agent-browser install-skill 2>/dev/null || true
fi
