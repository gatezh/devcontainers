#!/bin/bash
# Smoke-tests a built claude-code image. CI and local runs use the same command:
#   docker run --rm -v "$PWD/claude-code/verify-image.sh:/verify-image.sh:ro" <image> bash /verify-image.sh default|sandbox
# Add `--cap-add NET_ADMIN --cap-add NET_RAW` to also bring up the sandbox firewall.
#
# No pipefail: `… | grep -q` exits early, and a SIGPIPE'd writer must not fail the check.
set -eux

case "${1:?usage: verify-image.sh default|sandbox}" in
    default)
        sudo -n true
        test -x /usr/local/sbin/chown-volumes
        ;;
    sandbox)
        command -v iptables
        test -x /usr/local/sbin/init-firewall
        # sudo reaches the two baked scripts and nothing else (#208). Not `! sudo …`:
        # set -e ignores a negated command, so that line could never fail.
        sudo -n -l /usr/local/sbin/init-firewall >/dev/null
        sudo -n -l /usr/local/sbin/chown-volumes >/dev/null
        if sudo -n true 2>/dev/null; then echo "sandbox: sudo is unrestricted" >&2; exit 1; fi
        ;;
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
actionlint --version
shellcheck --version
cf --version
cf cli search 'list zones' | jq -e '.[0].command' >/dev/null
python3 -c 'import ensurepip'
agent-browser --version

# ── Managed settings ────────────────────────────────────────────────────────
test -r "$SETTINGS"
jq -r '.managedMcpServers.mdn.url' "$SETTINGS" | grep -qx https://mcp.mdn.mozilla.net/
jq -e '.permissions.deny | index("Bash(agent-browser install *)")' "$SETTINGS" >/dev/null
jq -r '.permissions.ask[]' "$SETTINGS" | grep -qxF 'Bash(cf * --force*)'
jq -r '.claudeMd' "$SETTINGS" | grep -q devcontainer-browser
jq -r '.claudeMd' "$SETTINGS" | grep -q cloudflare.config.ts

# ── Managed skills ──────────────────────────────────────────────────────────
grep -qx 'name: security-audit' /etc/claude-code/.claude/skills/security-audit/SKILL.md
test -r /etc/claude-code/.claude/skills/security-audit/validate-findings.cjs

# ── Transitional (until 2027-01-31) ─────────────────────────────────────────
test -x /usr/local/bin/drop-rtk-hook
jq -r '.hooks.SessionStart[].hooks[].command' "$SETTINGS" | grep -qx /usr/local/bin/drop-rtk-hook
/usr/local/bin/patch-playwright-mcp

# ── Browser ─────────────────────────────────────────────────────────────────
printenv AGENT_BROWSER_EXECUTABLE_PATH | grep -qx /usr/bin/chromium
printenv PLAYWRIGHT_MCP_BROWSER | grep -qx chromium
printenv PLAYWRIGHT_MCP_EXECUTABLE_PATH | grep -qx /usr/bin/chromium
printenv PLAYWRIGHT_MCP_HEADLESS | grep -qx true
printenv AGENT_BROWSER_CONFIG | grep -qx /etc/agent-browser/config.json
jq -e .contentBoundaries /etc/agent-browser/config.json >/dev/null
test -r /etc/claude-code/.claude/skills/devcontainer-browser/SKILL.md

# ── Environment ─────────────────────────────────────────────────────────────
printenv CF_SEND_TELEMETRY | grep -qx false
printenv WRANGLER_SEND_METRICS | grep -qx false
printenv CLOUDFLARE_DEPENDENCIES_INSTRUMENTATION | grep -qx false

# ── Git ─────────────────────────────────────────────────────────────────────
git config --system --get-all safe.directory | grep -qx /workspace

# ── Shell ───────────────────────────────────────────────────────────────────
zsh -ic 'typeset -p ZSH_THEME' | grep -q powerlevel10k/powerlevel10k
zsh -ic '(( $+_comps[gh] && $+_comps[cf] ))'

# ── Volume mount points owned by node ───────────────────────────────────────
for dir in /home/node/.local/share /home/node/.config/gh /home/node/.config/cloudflare /home/node/.bun/install/cache; do
    stat -c %U "$dir" | grep -qx node
done

# ── Firewall: sandbox only, and only when run with NET_ADMIN (CI adds it) ───
# init-firewall checks itself: example.com:443 and gitlab.com:22 refused, GitHub reachable.
# Last, because nothing can reach the network after it.
cap_bnd=$(awk '/^CapBnd:/ {print $2}' /proc/self/status)
if [ "$1" = sandbox ] && (( (0x$cap_bnd >> 12) & 1 )); then
    sudo -n /usr/local/sbin/init-firewall
fi

echo "verify-image: $1 OK"
