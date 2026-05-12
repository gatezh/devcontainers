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

# ── Claude Code marketplaces ────────────────────────────────────────────────
# The official marketplace is auto-configured on first interactive launch, but
# postCreateCommand runs before that — register explicitly so plugin install works.
MARKETPLACES=(
    "anthropics/claude-plugins-official"
    "umputun/ralphex"
)

for marketplace in "${MARKETPLACES[@]}"; do
    if claude plugin marketplace add "$marketplace" 2>&1; then
        echo "✔ Marketplace added: $marketplace"
    else
        echo "⚠ Failed to add marketplace: $marketplace" >&2
    fi
done

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
    if claude plugin install "$plugin" 2>&1; then
        echo "✔ Installed: $plugin"
    else
        echo "⚠ Failed to install: $plugin" >&2
    fi
done

# ── Playwright MCP: route every cached .mcp.json to system chromium ─────────
# Universal across arches (no Chrome stable binary in either default or sandbox).
# The patch binary is baked into the image (see Dockerfile #87) and also runs
# from postStartCommand (#85) and a Claude Code SessionStart hook (#98) — the
# hook is what closes the gap when the plugin auto-updates mid-container-run.
/usr/local/bin/patch-playwright-mcp

# ── rtk init (token-optimized CLI proxy) ────────────────────────────────────
# Global hook-first mode: installs only the PreToolUse rewrite hook to ~/.claude/,
# no workspace artifacts (CLAUDE.md, .rtk/). Safe to run multiple times.
# WORKAROUND: RTK ≥0.36.0 added a GDPR telemetry consent prompt that hangs in
# non-interactive environments. timeout + RTK_TELEMETRY_DISABLED work around it.
# Remove when upstream fixes it: https://github.com/rtk-ai/rtk/issues/1307
if command -v rtk &>/dev/null; then
    RTK_TELEMETRY_DISABLED=1 timeout 10 rtk init -g --hook-only --auto-patch 2>/dev/null || true
fi

# ── agent-browser skill ─────────────────────────────────────────────────────
# Installs the agent-browser Claude Code skill for headless browser automation.
# agent-browser CLI is pre-installed in the default devcontainer image (not sandbox).
if command -v agent-browser &>/dev/null; then
    agent-browser install-skill 2>/dev/null || true
fi
