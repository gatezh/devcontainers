#!/bin/bash
# Smoke-tests a built claude-code image. CI and local runs use the same command:
#   docker run --rm -v "$PWD/claude-code/verify-image.sh:/verify-image.sh:ro" <image> bash /verify-image.sh default|sandbox
#
# No pipefail: `… | grep -q` exits early, and a SIGPIPE'd writer must not fail the check.
set -eux

case "${1:?usage: verify-image.sh default|sandbox}" in
    default) ;;
    sandbox) command -v iptables ;;
    *) echo "unknown target: $1" >&2; exit 2 ;;
esac

SETTINGS=/etc/claude-code/managed-settings.json

# ── Tools ───────────────────────────────────────────────────────────────────
claude --version
mise --version
zsh --version
gh --version
gh stack --version
ralphex --version
cf --version
cf cli search 'list zones' | jq -e '.[0].command' >/dev/null
python3 -c 'import ensurepip'
agent-browser --version

# ── Managed settings ────────────────────────────────────────────────────────
test -r "$SETTINGS"
test -x /usr/local/bin/patch-playwright-mcp
jq -r '.hooks.SessionStart[0].hooks[0].command' "$SETTINGS" | grep -qx /usr/local/bin/patch-playwright-mcp
/usr/local/bin/patch-playwright-mcp
test -x /usr/local/bin/drop-rtk-hook
jq -r '.hooks.SessionStart[].hooks[].command' "$SETTINGS" | grep -qx /usr/local/bin/drop-rtk-hook
jq -r '.managedMcpServers.mdn.url' "$SETTINGS" | grep -qx https://mcp.mdn.mozilla.net/
jq -e '.permissions.deny | index("Bash(agent-browser install *)")' "$SETTINGS" >/dev/null
jq -r '.permissions.ask[]' "$SETTINGS" | grep -qxF 'Bash(cf * --force*)'
jq -r '.claudeMd' "$SETTINGS" | grep -q devcontainer-browser
jq -r '.claudeMd' "$SETTINGS" | grep -q cloudflare.config.ts

# ── Browser ─────────────────────────────────────────────────────────────────
printenv AGENT_BROWSER_EXECUTABLE_PATH | grep -qx /usr/bin/chromium
printenv AGENT_BROWSER_CONFIG | grep -qx /etc/agent-browser/config.json
jq -e .contentBoundaries /etc/agent-browser/config.json >/dev/null
test -r /etc/claude-code/.claude/skills/devcontainer-browser/SKILL.md

# ── Environment ─────────────────────────────────────────────────────────────
printenv CF_SEND_TELEMETRY | grep -qx false
printenv WRANGLER_SEND_METRICS | grep -qx false

# ── Git ─────────────────────────────────────────────────────────────────────
git config --system --get-all safe.directory | grep -qx /workspace

# ── Shell ───────────────────────────────────────────────────────────────────
zsh -ic 'typeset -p ZSH_THEME' | grep -q powerlevel10k/powerlevel10k
zsh -ic '(( $+_comps[gh] && $+_comps[cf] ))'

# ── Volume mount points owned by node ───────────────────────────────────────
for dir in /home/node/.local/share /home/node/.config/gh /home/node/.config/cloudflare; do
    stat -c %U "$dir" | grep -qx node
done

echo "verify-image: $1 OK"
