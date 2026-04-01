# devcontainer-images Repo Devcontainer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current root `.devcontainer/` with a clean setup for developing the devcontainer-images repo itself — Node 24 LTS slim base, Claude Code, rtk + ralphex (latest at build time), two build targets (default + sandbox), built from Dockerfile.

**Architecture:** Multi-stage Dockerfile following `claude-code/.devcontainer/Dockerfile` pattern: shared `base` stage with all common tooling, then `default` (passwordless sudo) and `sandbox` (firewall packages + restricted sudo) targets. rtk and ralphex fetch latest release at build time. git-delta is pinned (v0.19.0 dropped arm64 .deb and changed naming).

**Tech Stack:** Docker multi-stage builds, Node 24 LTS (trixie-slim), Fish shell + Starship prompt, iptables (sandbox), Claude Code plugins

---

## File Structure

```
.devcontainer/
├── Dockerfile                    ← Multi-stage: base → default, base → sandbox
├── devcontainer.json             ← Default variant (builds --target default)
├── init-plugins.sh               ← Claude Code plugin + rtk hook initialization
└── claude-sandbox/
    ├── devcontainer.json         ← Sandbox variant (builds --target sandbox from ../Dockerfile)
    └── init-firewall.sh          ← Default-deny iptables firewall
```

Files removed (replaced by new structure):
- `.devcontainer/init-firewall.sh` → moves to `claude-sandbox/`
- `.devcontainer/.mise.toml` → deleted (rtk baked into image)

---

## What's Included

| Layer | What | Why |
|-------|------|-----|
| OS | `node:24-trixie-slim` | GLIBC 2.41 for rtk binary compatibility |
| Packages | ca-certificates, curl, fish, fzf, gh, git, jq, less, sudo | Minimal set — each justified (see below) |
| Shell | Fish + Starship + fzf | Built-in syntax highlighting, autosuggestions, completions |
| Tools | git-delta (pinned), rtk (latest), ralphex (latest) | GitHub releases; git-delta pinned because v0.19.0 dropped arm64 .deb |
| Claude Code | npm global install | AI assistant |

**Package justification:** ca-certificates (HTTPS), curl (downloads), fish (shell), fzf (fish fuzzy finder), gh (GitHub CLI — firewall uses it for IP ranges), git (not in slim base), jq (init-plugins.sh onboarding patch + firewall), less (git-delta's pager), sudo (firewall + volume chown).

**Default-only:** passwordless sudo

**Sandbox-only:** iptables, ipset, iproute2, dnsutils, aggregate, firewall sudo rule

---

### Task 1: Create the Multi-Stage Dockerfile

**Files:**
- Create: `.devcontainer/Dockerfile`

Reference: `claude-code/.devcontainer/Dockerfile`

Key design notes:
- git-delta pinned to 0.18.2 (v0.19.0 dropped arm64 .deb and changed asset naming)
- rtk and ralphex fetch latest via GitHub API at build time, with error handling for rate limits
- rtk amd64 uses musl binary (no gnu variant published); arm64 uses gnu. Both work on Debian.
- ralphex uses `linux_amd64` / `linux_arm64` naming convention
- ralphex tarball includes a `completions/` dir — install fish completion, clean up the rest

- [ ] **Step 1: Write the complete Dockerfile**

The full Dockerfile content (base + default + sandbox stages) is written as a single file.

```dockerfile
# ═══════════════════════════════════════════════════════════════════════════════
# Devcontainer for the devcontainer-images repo — two build targets:
#   default — full dev environment with passwordless sudo
#   sandbox — network-restricted environment with firewall packages
#
# rtk and ralphex fetch latest versions from GitHub releases at build time.
# git-delta is pinned (upstream changed release asset naming in v0.19.0).
#
# Build:
#   docker build --target default -t devcontainer-images:default .
#   docker build --target sandbox -t devcontainer-images:sandbox .
# ═══════════════════════════════════════════════════════════════════════════════

# ─── BASE ─────────────────────────────────────────────────────────────────────
FROM node:24-trixie-slim AS base

ARG GIT_DELTA_VERSION=0.18.2

# System packages (each justified — see plan doc for rationale)
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  fish \
  fzf \
  gh \
  git \
  jq \
  less \
  sudo \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV DEVCONTAINER=true

# Create workspace and config directories with proper ownership
RUN mkdir -p /workspace /home/node/.claude /home/node/.local/share/fish \
  && chown -R node:node /workspace /home/node/.claude /home/node/.local

WORKDIR /workspace

# Install git-delta (pinned — v0.19.0 dropped arm64 .deb)
RUN ARCH=$(dpkg --print-architecture) \
  && curl -fsSL -o git-delta.deb \
    "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" \
  && dpkg -i git-delta.deb \
  && rm git-delta.deb

# Install rtk (latest release — token optimizer for Claude Code)
# amd64: musl binary (no gnu variant published), arm64: gnu binary
RUN ARCH=$(dpkg --print-architecture) \
  && VERSION=$(curl -s https://api.github.com/repos/rtk-ai/rtk/releases/latest | jq -r .tag_name | sed 's/^v//') \
  && if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then echo "ERROR: Failed to fetch rtk version (GitHub API rate limit?)" && exit 1; fi \
  && case "${ARCH}" in \
       amd64) RTK_ARCH='x86_64-unknown-linux-musl' ;; \
       arm64) RTK_ARCH='aarch64-unknown-linux-gnu' ;; \
       *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
     esac \
  && curl -fsSL -o rtk.tar.gz \
    "https://github.com/rtk-ai/rtk/releases/download/v${VERSION}/rtk-${RTK_ARCH}.tar.gz" \
  && tar -xzf rtk.tar.gz \
  && install -m 755 rtk /usr/local/bin/rtk \
  && rm -rf rtk rtk.tar.gz

# Install ralphex (latest release — Claude Code skill manager)
# Tarball includes completions/ dir — install fish completion for shell integration
RUN ARCH=$(dpkg --print-architecture) \
  && VERSION=$(curl -s https://api.github.com/repos/umputun/ralphex/releases/latest | jq -r .tag_name | sed 's/^v//') \
  && if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then echo "ERROR: Failed to fetch ralphex version (GitHub API rate limit?)" && exit 1; fi \
  && curl -fsSL -o ralphex.tar.gz \
    "https://github.com/umputun/ralphex/releases/download/v${VERSION}/ralphex_${VERSION}_linux_${ARCH}.tar.gz" \
  && tar -xzf ralphex.tar.gz \
  && install -m 755 ralphex /usr/local/bin/ralphex \
  && mkdir -p /home/node/.config/fish/completions \
  && cp completions/ralphex.fish /home/node/.config/fish/completions/ 2>/dev/null || true \
  && rm -rf ralphex ralphex.tar.gz completions/

# Fix ownership of .config created by ralphex completions install above
RUN chown -R node:node /home/node/.config

# ── Non-root user setup ──────────────────────────────────────────────────────
USER node

ENV SHELL=/usr/bin/fish
ENV EDITOR="code --wait"
ENV VISUAL="code --wait"

# ── Starship prompt ──────────────────────────────────────────────────────────
USER root
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes
USER node
RUN mkdir -p /home/node/.config/fish \
  && starship preset no-runtime-versions -o /home/node/.config/starship.toml \
  && printf '%s\n' 'set -g fish_greeting' 'starship init fish | source' > /home/node/.config/fish/config.fish

# ── Claude Code CLI ──────────────────────────────────────────────────────────
USER root
RUN npm install -g @anthropic-ai/claude-code
USER node

# ─── DEFAULT — full dev environment ───────────────────────────────────────────
FROM base AS default

USER root
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node-nopasswd \
  && chmod 0440 /etc/sudoers.d/node-nopasswd
USER node

# ─── SANDBOX — network-restricted environment ─────────────────────────────────
FROM base AS sandbox

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Firewall sudo rule — the script itself is bind-mounted from claude-sandbox/
RUN echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall \
  && chmod 0440 /etc/sudoers.d/node-firewall
USER node
```

- [ ] **Step 2: Build both targets locally**

```bash
cd /Users/sergii/Code/devcontainer-images
docker build --target default -t devcontainer-images:default .devcontainer/
docker build --target sandbox -t devcontainer-images:sandbox .devcontainer/
```

- [ ] **Step 3: Verify tools in default target**

```bash
docker run --rm devcontainer-images:default bash -c \
  "node --version && claude --version && rtk --version && ralphex --version && delta --version && fish --version && starship --version && gh --version"
```

- [ ] **Step 4: Verify sandbox target tools + firewall packages**

```bash
docker run --rm devcontainer-images:sandbox bash -c \
  "claude --version && rtk --version && ralphex --version && which iptables && which ipset"
```

- [ ] **Step 5: Verify sudo scoping**

```bash
# Default — should succeed (passwordless sudo)
docker run --rm devcontainer-images:default bash -c "sudo whoami"

# Sandbox — should fail (only firewall script is allowed)
docker run --rm devcontainer-images:sandbox bash -c "sudo whoami" \
  && echo "FAIL: sandbox has full sudo" || echo "OK: sandbox restricts sudo"
```

- [ ] **Step 6: Commit**

```bash
git add .devcontainer/Dockerfile
git commit -m "feat: add multi-stage Dockerfile for repo devcontainer (default + sandbox)"
```

---

### Task 2: Create Default devcontainer.json

**Files:**
- Create: `.devcontainer/devcontainer.json`

- [ ] **Step 1: Write devcontainer.json**

```jsonc
// For format details, see https://aka.ms/devcontainer.json
{
  "name": "Default",
  "build": {
    "dockerfile": "Dockerfile",
    "target": "default"
  },
  "init": true,
  "remoteUser": "node",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=delegated",
  "workspaceFolder": "/workspace",
  "customizations": {
    "vscode": {
      "extensions": [
        // **AI Agents**
        // Claude Code - AI assistant
        "anthropic.claude-code",

        // **General**
        // YAML - YAML support (for workflows and docker-compose)
        "redhat.vscode-yaml",
        // Markdown Preview Github Styles - Markdown preview
        "bierner.markdown-preview-github-styles",
        // Docker - Dockerfile support
        "ms-azuretools.vscode-docker"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "fish",
        "terminal.integrated.profiles.linux": {
          "fish": { "path": "fish" },
          "bash": { "path": "bash", "icon": "terminal-bash" }
        },
        // Suppress extension recommendation prompts
        "extensions.ignoreRecommendations": true
      }
    }
  },
  "mounts": [
    // Persist Claude Code configuration between container rebuilds
    "source=devcontainer-images-claude-config-${devcontainerId},target=/home/node/.claude,type=volume",
    // Persist fish shell history between container rebuilds
    "source=devcontainer-images-fish-data-${devcontainerId},target=/home/node/.local/share/fish,type=volume"
  ],
  "containerEnv": {
    "TZ": "${localEnv:TZ:America/Edmonton}",
    "CLAUDE_CONFIG_DIR": "/home/node/.claude"
  },
  // Initialize Claude Code plugins (runs once when container is created)
  "postCreateCommand": "sudo chown -R node /home/node/.claude && bash /workspace/.devcontainer/init-plugins.sh",
  "waitFor": "postCreateCommand"
}
```

- [ ] **Step 2: Commit**

```bash
git add .devcontainer/devcontainer.json
git commit -m "feat: add default devcontainer.json for repo development"
```

---

### Task 3: Create Sandbox devcontainer.json + Firewall Script

**Files:**
- Create: `.devcontainer/claude-sandbox/devcontainer.json`
- Create: `.devcontainer/claude-sandbox/init-firewall.sh` (adapted from existing `.devcontainer/init-firewall.sh`)

- [ ] **Step 1: Write sandbox devcontainer.json**

```jsonc
// For format details, see https://aka.ms/devcontainer.json
{
  "name": "Sandbox",
  "build": {
    "context": "..",
    "dockerfile": "../Dockerfile",
    "target": "sandbox"
  },
  // Capabilities required for iptables firewall setup
  "capAdd": ["NET_ADMIN", "NET_RAW"],
  "init": true,
  "remoteUser": "node",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=delegated",
  "workspaceFolder": "/workspace",
  "customizations": {
    "vscode": {
      "extensions": [
        // **AI Agents**
        "anthropic.claude-code",

        // **General**
        "redhat.vscode-yaml",
        "bierner.markdown-preview-github-styles",
        "ms-azuretools.vscode-docker"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "fish",
        "terminal.integrated.profiles.linux": {
          "fish": { "path": "fish" },
          "bash": { "path": "bash", "icon": "terminal-bash" }
        },
        "extensions.ignoreRecommendations": true
      }
    }
  },
  "mounts": [
    "source=devcontainer-images-sandbox-config-${devcontainerId},target=/home/node/.claude,type=volume",
    "source=devcontainer-images-sandbox-fish-${devcontainerId},target=/home/node/.local/share/fish,type=volume",
    // Mount firewall script into the expected path
    "source=${localWorkspaceFolder}/.devcontainer/claude-sandbox/init-firewall.sh,target=/usr/local/bin/init-firewall.sh,type=bind"
  ],
  "containerEnv": {
    "TZ": "${localEnv:TZ:America/Edmonton}",
    "CLAUDE_CONFIG_DIR": "/home/node/.claude",
    // Sandbox blocks OAuth login — inject token from host
    "CLAUDE_CODE_OAUTH_TOKEN": "${localEnv:CLAUDE_CODE_OAUTH_TOKEN}"
  },
  // Plugins before firewall (network still open during postCreateCommand)
  "postCreateCommand": "sudo chown -R node /home/node/.claude && bash /workspace/.devcontainer/init-plugins.sh",
  // Firewall locks down the network
  "postStartCommand": "sudo /usr/local/bin/init-firewall.sh",
  "waitFor": "postStartCommand"
}
```

- [ ] **Step 2: Write init-firewall.sh**

Adapted from existing `.devcontainer/init-firewall.sh` — trimmed to domains this repo needs (no OpenAI/Codex):

```bash
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

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

# Allow DNS, SSH, and localhost before restrictions
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
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

# ── Allowed domains ──────────────────────────────────────────────────
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "sentry.io" \
    "statsig.anthropic.com" \
    "statsig.com" \
    "marketplace.visualstudio.com" \
    "vscode.blob.core.windows.net" \
    "update.code.visualstudio.com"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "ERROR: Failed to resolve $domain"
        exit 1
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
# ─────────────────────────────────────────────────────────────────────

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

echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi

if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi
```

- [ ] **Step 3: Make firewall script executable**

```bash
chmod +x .devcontainer/claude-sandbox/init-firewall.sh
```

- [ ] **Step 4: Commit**

```bash
git add .devcontainer/claude-sandbox/
git commit -m "feat: add sandbox devcontainer variant with firewall"
```

---

### Task 4: Create init-plugins.sh

**Files:**
- Create: `.devcontainer/init-plugins.sh`

- [ ] **Step 1: Write init-plugins.sh**

```bash
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

# Plugins relevant for a Dockerfiles/infrastructure repo
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

# Initialize rtk global hook for Claude Code (auto-rewrite mode)
echo "Initializing rtk (token optimizer)..."
rtk init -g --auto-patch || {
    echo "Note: rtk init may have already been configured or rtk not available"
}

echo "=== Plugin initialization complete ==="
```

- [ ] **Step 2: Make executable**

```bash
chmod +x .devcontainer/init-plugins.sh
```

- [ ] **Step 3: Commit**

```bash
git add .devcontainer/init-plugins.sh
git commit -m "feat: add init-plugins.sh for Claude Code plugin setup"
```

---

### Task 5: Clean Up Old Files

**Files:**
- Delete: `.devcontainer/init-firewall.sh` (replaced by `claude-sandbox/init-firewall.sh`)
- Delete: `.devcontainer/.mise.toml` (no longer needed)
- Delete: `.devcontainer/devcontainer.json` (old version — replaced in Task 2)
- Delete: `.devcontainer/Dockerfile` (old version — replaced in Task 1)
- Delete: `.devcontainer/init-plugins.sh` (old version — replaced in Task 4)

Note: Tasks 1-4 create the new files. This task removes only the files that were not overwritten (init-firewall.sh in old location, .mise.toml).

- [ ] **Step 1: Remove old files**

```bash
rm .devcontainer/init-firewall.sh
rm .devcontainer/.mise.toml
```

- [ ] **Step 2: Verify final directory structure**

```bash
find .devcontainer/ -type f | sort
```

Expected:
```
.devcontainer/Dockerfile
.devcontainer/claude-sandbox/devcontainer.json
.devcontainer/claude-sandbox/init-firewall.sh
.devcontainer/devcontainer.json
.devcontainer/init-plugins.sh
```

- [ ] **Step 3: Commit**

```bash
git add -A .devcontainer/
git commit -m "chore: remove old mise config and firewall script (replaced by new structure)"
```

---

### Task 6: End-to-End Verification

- [ ] **Step 1: Build both targets**

```bash
cd /Users/sergii/Code/devcontainer-images
docker build --target default -t devcontainer-images:default .devcontainer/
docker build --target sandbox -t devcontainer-images:sandbox .devcontainer/
```

- [ ] **Step 2: Verify default target**

```bash
docker run --rm devcontainer-images:default bash -c \
  "node --version && claude --version && rtk --version && ralphex --version && delta --version && fish --version && starship --version && gh --version"
```

- [ ] **Step 3: Verify sandbox target**

```bash
docker run --rm devcontainer-images:sandbox bash -c \
  "claude --version && rtk --version && ralphex --version && which iptables && which ipset"
```

- [ ] **Step 4: Verify sudo scoping**

```bash
docker run --rm devcontainer-images:default bash -c "sudo whoami"
docker run --rm devcontainer-images:sandbox bash -c "sudo whoami" \
  && echo "FAIL: sandbox has full sudo" || echo "OK: sandbox restricts sudo"
```

- [ ] **Step 5: Clean up test images**

```bash
docker rmi devcontainer-images:default devcontainer-images:sandbox 2>/dev/null || true
```
