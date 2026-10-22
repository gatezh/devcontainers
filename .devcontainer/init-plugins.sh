#!/bin/bash
# Initialize Claude Code plugins for the devcontainers repo
# This script is idempotent - safe to run multiple times; each run also updates plugins

set -euo pipefail

echo "=== Claude Code Plugin Initialization ==="

# Mark onboarding complete so claude CLI doesn't hang on interactive prompts
echo "Ensuring Claude Code onboarding is complete..."
if [ -f "$HOME/.claude/.claude.json" ]; then
    jq '.hasCompletedOnboarding = true' "$HOME/.claude/.claude.json" > /tmp/.claude.json \
        && mv /tmp/.claude.json "$HOME/.claude/.claude.json"
else
    mkdir -p "$HOME/.claude"
    echo '{"hasCompletedOnboarding":true}' > "$HOME/.claude/.claude.json"
fi

# Add plugin marketplaces
echo "Adding plugin marketplaces..."
claude plugin marketplace add anthropics/claude-plugins-official || {
    echo "Note: Marketplace may already be added or claude not available yet"
}
claude plugin marketplace add umputun/ralphex || {
    echo "Note: ralphex marketplace may already be added or unavailable"
}

# Plugins for development workflow (this repo is Dockerfiles/YAML, not frontend)
PLUGINS=(
    "code-review@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "explanatory-output-style@claude-plugins-official"
    "claude-md-management@claude-plugins-official"
    "claude-code-setup@claude-plugins-official"
    "ralphex@ralphex"
)

echo "Installing Claude Code plugins..."
for plugin in "${PLUGINS[@]}"; do
    echo "  Installing: $plugin"
    claude plugin install "$plugin" 2>/dev/null || {
        echo "    Note: $plugin may already be installed or unavailable"
    }
done

# ~/.claude is a persistent volume, so `install` no-ops after the first run.
# Refresh marketplace indexes first — `plugin update` resolves against the cache.
echo "Updating Claude Code plugins..."
claude plugin marketplace update || {
    echo "Note: marketplace refresh failed; updates use cached indexes"
}
for plugin in "${PLUGINS[@]}"; do
    echo "  Updating: $plugin"
    claude plugin update "$plugin" 2>/dev/null || {
        echo "    Note: $plugin update failed or unavailable"
    }
done

# ── rtk removed: drop the hook earlier versions of this script registered ───
# Without the binary, a leftover `rtk hook claude` PreToolUse entry errors on
# every Bash call. Transitional: delete this block after 2027-01-31.
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
if [ -f "$SETTINGS" ] && grep -q 'rtk' "$SETTINGS"; then
    jq 'if .hooks.PreToolUse then .hooks.PreToolUse |= (map(.hooks |= map(select((.command // "") | test("(^|/)rtk hook claude$|rtk-rewrite\\.sh") | not))) | map(select(.hooks | length > 0))) else . end' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
fi

echo "=== Plugin initialization complete ==="
