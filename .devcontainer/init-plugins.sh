#!/bin/bash
# Initialize Claude Code plugins for the devcontainer-images repo
# This script is idempotent - safe to run multiple times

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

# Plugins for development workflow (code quality, web dev, analytics)
PLUGINS=(
    "code-review@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "explanatory-output-style@claude-plugins-official"
    "claude-md-management@claude-plugins-official"
    "claude-code-setup@claude-plugins-official"
    "frontend-design@claude-plugins-official"
    "typescript-lsp@claude-plugins-official"
    "playwright@claude-plugins-official"
    "posthog@claude-plugins-official"
    "ralphex@ralphex"
)

echo "Installing Claude Code plugins..."
for plugin in "${PLUGINS[@]}"; do
    echo "  Installing: $plugin"
    claude plugin install "$plugin" 2>/dev/null || {
        echo "    Note: $plugin may already be installed or unavailable"
    }
done

# Initialize rtk global hook for Claude Code (auto-rewrite mode)
echo "Initializing rtk (token optimizer)..."
rtk init -g --auto-patch || {
    echo "Note: rtk init may have already been configured or rtk not available"
}

echo "=== Plugin initialization complete ==="
