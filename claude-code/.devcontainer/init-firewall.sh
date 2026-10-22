#!/bin/bash
# Default-deny egress firewall for the sandbox target. Baked root-owned into the
# image at /usr/local/sbin/init-firewall; node may run only this (and
# chown-volumes) through sudo, so the agent can't edit or bypass it (#208).
#
# Allows GitHub's published ranges, the domains below, and the project's
# extra domains from ALLOWLIST: one domain per line, `#` comments. The file is
# workspace data, never executed; a changed allowlist applies on the next
# container start, because a second run refuses to touch an active firewall.

set -euo pipefail
IFS=$'\n\t'

ALLOWLIST=/workspace/.devcontainer/claude-sandbox/allowed-domains.txt

BASE_DOMAINS=(
    "registry.npmjs.org"
    "api.anthropic.com"
    "sentry.io"
    "statsig.com"
    "marketplace.visualstudio.com"
    "vscode.blob.core.windows.net"
    "update.code.visualstudio.com"
    "mcp.mdn.mozilla.net"
)

# Re-running would let the agent swap in an edited allowlist mid-session.
if iptables -S OUTPUT | grep -qx -- "-P OUTPUT DROP"; then
    echo "Firewall already active; restart the container to apply allowlist changes"
    exit 0
fi

# Fail closed: whatever stops the script before the DROP policies below (a failed
# GitHub meta fetch, no default route), the network ends up shut, not wide open.
fail_closed() {
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP
    echo "ERROR: firewall setup failed; the network is closed. Restart the container to retry." >&2
}
trap fail_closed EXIT

# Project domains: read as data and validated. Bad input is skipped, not fatal, so
# a corrupted allowlist can't keep the firewall down; invalid lines aren't echoed.
# Read as node, so the kernel refuses a symlink to a file node can't read (a root-only
# file); timeout stops a FIFO from blocking start-up.
PROJECT_DOMAINS=()
allowlist=$(timeout 5 runuser -u node -- cat -- "$ALLOWLIST" 2>/dev/null || true)
line_no=0
while IFS= read -r line; do
    line_no=$((line_no + 1))
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [ -z "$line" ] && continue
    if [[ ! "$line" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]; then
        echo "WARN: $ALLOWLIST line $line_no is not a domain name — skipping"
        continue
    fi
    PROJECT_DOMAINS+=("$line")
done <<< "$allowlist"

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules and delete existing ipsets
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# 2. Selectively restore ONLY internal Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

# Allow DNS and localhost before restrictions. No blanket SSH: an open port 22 to
# any host is an exit around the allowlist (ssh -D). Allowlisted hosts, GitHub
# included, are reachable on every port by the ipset rule below.
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Create ipset with CIDR support
ipset create allowed-domains hash:net

# Fetch GitHub IP ranges
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi

echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    echo "Adding GitHub range $cidr"
    ipset add -exist allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

for domain in "${BASE_DOMAINS[@]}" "${PROJECT_DOMAINS[@]}"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "WARN: Failed to resolve $domain — skipping"
        continue
    fi

    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "ERROR: Invalid IP from DNS for $domain: $ip"
            exit 1
        fi
        echo "Adding $ip for $domain"
        ipset add -exist allowed-domains "$ip"
    done < <(echo "$ips")
done

# Allow host network
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Default DROP, allow established, allow allowlist, reject rest
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# IPv6 gets loopback only, so a Compose network with enable_ipv6 isn't an open side
# door. Skipped where the kernel has no ip6tables support.
if ip6tables -S >/dev/null 2>&1; then
    ip6tables -F
    ip6tables -X
    ip6tables -A INPUT -i lo -j ACCEPT
    ip6tables -A OUTPUT -o lo -j ACCEPT
    ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A OUTPUT -j REJECT
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT DROP
fi

echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi

# gitlab.com listens on 22 and isn't allowlisted; example.com doesn't listen there,
# so it would pass even with port 22 open.
if timeout 5 bash -c '</dev/tcp/gitlab.com/22' 2>/dev/null; then
    echo "ERROR: Firewall verification failed - was able to reach gitlab.com:22"
    exit 1
else
    echo "Firewall verification passed - unable to reach gitlab.com:22 as expected"
fi

if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi

trap - EXIT
