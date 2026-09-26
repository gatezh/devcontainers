# ═══════════════════════════════════════════════════════════════════════════════
# Shared devcontainer image — two build targets:
#   default — full dev environment with agent-browser and passwordless sudo
#   sandbox — network-restricted environment with firewall packages
#
# Projects consume these pre-built images and run `mise install` at container
# creation to install their specific tool versions (Bun, Hugo, etc.).
#
# Build:
#   docker build --target default -t claude-code:default .
#   docker build --target sandbox -t claude-code:sandbox .
# ═══════════════════════════════════════════════════════════════════════════════

# ═════════════════════════════════════════════════════════════════════════════
# Parallel download stages — BuildKit runs these concurrently
# ═════════════════════════════════════════════════════════════════════════════

# ── rtk (token-optimized CLI proxy) ──────────────────────────────────────
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
# ── oh-my-zsh + powerlevel10k ─────────────────────────────────
# Pinned by commit SHA: neither project tags usefully, and auto-adopting
# shell-framework changes has broken this image before. Bump deliberately.
FROM alpine:3.21 AS ohmyzsh-download
RUN apk add --no-cache curl tar
ARG OH_MY_ZSH_REF=0ee67f042872d1dfab74270c31867771ca35aef4
ARG POWERLEVEL10K_REF=d05a1b00f9a61f9578bf9dc19b8451942dde8734
RUN set -eux; \
    mkdir -p /omz/custom/themes/powerlevel10k; \
    curl -fsSL "https://github.com/ohmyzsh/ohmyzsh/archive/${OH_MY_ZSH_REF}.tar.gz" \
      | tar -xz -C /omz --strip-components=1; \
    curl -fsSL "https://github.com/romkatv/powerlevel10k/archive/${POWERLEVEL10K_REF}.tar.gz" \
      | tar -xz -C /omz/custom/themes/powerlevel10k --strip-components=1

FROM alpine:3.21 AS rtk-download
RUN apk add --no-cache curl
# renovate: datasource=github-releases depName=rtk-ai/rtk
ARG RTK_VERSION=0.49.0
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
      x86_64)  RTK_TARGET="x86_64-unknown-linux-musl" ;; \
      aarch64) RTK_TARGET="aarch64-unknown-linux-gnu" ;; \
    esac; \
    curl -fsSL -o /tmp/rtk.tar.gz \
      "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-${RTK_TARGET}.tar.gz"; \
    tar -xzf /tmp/rtk.tar.gz -C /usr/local/bin rtk

# ── ralphex (autonomous plan execution) ──────────────────────────────────
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
FROM alpine:3.21 AS ralphex-download
RUN apk add --no-cache curl
# renovate: datasource=github-releases depName=umputun/ralphex
ARG RALPHEX_VERSION=1.7.0
RUN set -eux; \
    ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"; \
    curl -fsSL -o /tmp/ralphex.tar.gz \
      "https://github.com/umputun/ralphex/releases/download/v${RALPHEX_VERSION}/ralphex_${RALPHEX_VERSION}_linux_${ARCH}.tar.gz"; \
    tar -xzf /tmp/ralphex.tar.gz -C /usr/local/bin ralphex

# ─── BASE ─────────────────────────────────────────────────────────────────────
FROM node:24-trixie-slim AS base

# renovate: datasource=github-releases depName=cli/cli
ARG GH_VERSION=2.101.0

# System packages shared by all targets
# - ca-certificates: SSL/TLS for HTTPS connections
# - curl: downloading tools and installers
# - fzf: fuzzy finder; zsh integration comes from the oh-my-zsh fzf plugin
# - git: version control
# - jq: JSON processing (firewall script, onboarding patch)
# - less: pager for git and other CLI output
# - openssh-client: ssh-keygen for SSH-format commit signing (and FIDO2 keys via
#   libfido2). git only Recommends it, so --no-install-recommends drops it. Must be
#   in base — the sandbox firewall blocks deb.debian.org at runtime. See #110.
# - sudo: privilege escalation for firewall setup
# - zsh: interactive shell; oh-my-zsh + powerlevel10k configured below
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  fzf \
  git \
  jq \
  less \
  openssh-client \
  sudo \
  zsh

# npm global directory with proper permissions for node user
# Pre-create /lib to prevent "ENOENT" errors during npx commands
RUN mkdir -p /usr/local/share/npm-global/lib \
  && chown -R node:node /usr/local/share/npm-global

ENV DEVCONTAINER=true

# Volume mount points, pre-created node-owned so Docker seeds fresh named volumes
# with correct ownership. The XDG dirs matter for the same reason: a volume mounted
# at a nested path (consumers still declare *-fish-data at ~/.local/share/fish)
# makes Docker invent the missing parent as root, locking mise out of its data dir.
RUN mkdir -p /workspace/node_modules \
  /workspace/services/api/node_modules \
  /workspace/services/app/node_modules \
  /workspace/services/www/node_modules \
  /workspace/packages/shared/node_modules \
  /workspace/packages/database/node_modules \
  /home/node/.claude \
  /home/node/.local/share \
  /home/node/.local/state \
  /home/node/.config/gh \
  /home/node/.cache \
  /commandhistory \
  && chown -R node:node /workspace /home/node/.claude /home/node/.local \
       /home/node/.config /home/node/.cache /commandhistory

WORKDIR /workspace

# gh from the upstream .deb: trixie freezes it at 2.46.0 (Apr 2024). Must follow
# the apt block — the .deb depends on git and dpkg -i won't resolve it.
RUN ARCH=$(dpkg --print-architecture) \
  && curl -fsSL -o "gh_${GH_VERSION}_linux_${ARCH}.deb" \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.deb" \
  && dpkg -i "gh_${GH_VERSION}_linux_${ARCH}.deb" \
  && rm "gh_${GH_VERSION}_linux_${ARCH}.deb"

# ── Non-root user setup ──────────────────────────────────────────────────────
USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV SHELL=/usr/bin/zsh
# LANG only, as the official images do. LC_ALL would outrank a consumer's
# containerEnv; TERM stays unset so the terminal's own value wins.
ENV LANG=C.UTF-8
ENV EDITOR="code --wait"
ENV VISUAL="code --wait"

# ── Mise (install as root) ────────────────────────────────────────────────────
# Tool manager only — projects run `mise install` from their own .mise.toml. Node
# is deliberately not via mise: its shims would shadow the base image's npx.
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl https://mise.run | sh \
  && cp /root/.local/bin/mise /usr/local/bin/mise \
  && rm -rf /root/.local
SHELL ["/bin/sh", "-c"]

# ── zsh + oh-my-zsh + powerlevel10k ──────────────────────────────────────────
# Written as node: $HOME during RUN follows USER, so this must not run as root.
USER node
COPY --from=ohmyzsh-download --chown=node:node /omz /home/node/.oh-my-zsh

# .zshrc written here, not by an installer, so nothing upstream injects env
# overrides. The wizard flag stops powerlevel10k prompting on first shell.
# Single-quoted so $HOME/$ZSH reach .zshrc unexpanded.
# hadolint ignore=SC2016
RUN printf '%s\n' \
      'export ZSH="$HOME/.oh-my-zsh"' \
      'ZSH_THEME="powerlevel10k/powerlevel10k"' \
      'plugins=(git fzf)' \
      "zstyle ':omz:update' mode disabled" \
      'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' \
      'export HISTFILE=/commandhistory/.zsh_history' \
      'source $ZSH/oh-my-zsh.sh' \
      'POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last' \
      'POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(user dir vcs status)' \
      'POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()' \
      'POWERLEVEL9K_STATUS_OK=false' \
      'POWERLEVEL9K_STATUS_CROSS=true' \
      > "$HOME/.zshrc"
ENV PATH="/home/node/.local/share/mise/shims:$PATH"
ENV MISE_TRUSTED_CONFIG_PATHS="/workspace"

# ── Dev tools (copied from parallel download stages) ─────────────────────────
# rtk (CLI proxy) and ralphex (plan execution) — dev infrastructure, not project
# dependencies. Renovate-pinned; see .github/renovate.json5.
COPY --from=rtk-download /usr/local/bin/rtk /usr/local/bin/rtk
COPY --from=ralphex-download /usr/local/bin/ralphex /usr/local/bin/ralphex

# ── Playwright MCP patch script ──────────────────────────────────────────────
# Baked in so consumer projects don't carry a copy. Invoked from init-plugins.sh,
# postStartCommand and a SessionStart hook — the hook covers plugin auto-updates
# mid-run. See #87, #98.
COPY --chmod=0755 patch-playwright-mcp.sh /usr/local/bin/patch-playwright-mcp

# ── Claude Code managed settings ─────────────────────────────────────────────
# Image-policy settings at the Linux managed location (highest precedence, outside
# any volume mount). Wires patch-playwright-mcp as a SessionStart hook (#98, #101)
# and provides the MDN MCP server. managedMcpServers needs Claude Code >= 2.1.259.
#
# /etc/claude-code is created explicitly: BuildKit applies COPY --chmod to parent
# dirs it auto-creates, leaving 0644 — not traversable.
USER root
RUN mkdir -p /etc/claude-code
COPY --chown=root:root --chmod=0644 managed-settings.json /etc/claude-code/managed-settings.json
USER node

# ── gh-stack (native stacked PRs) ────────────────────────────────────────────
# Baked as node into ~/.local/share/gh/extensions, which is on the image layer (only
# ~/.config/gh is a volume); a volume over ~/.local/share/gh would shadow it. See #160.
# renovate: datasource=github-releases depName=github/gh-stack
ARG GH_STACK_VERSION=0.1.1
RUN gh extension install github/gh-stack --pin "v${GH_STACK_VERSION}"

# ── Claude Code CLI ───────────────────────────────────────────────────────────
# npm, not the native installer: the installer rate-limits (429) under parallel
# Docker builds. npm stays supported "for compatibility reasons" — this is that
# reason. https://code.claude.com/docs/en/getting-started#install-with-npm
#
# Installed as node so files land node-owned; a later chown -R would duplicate
# every file on overlayfs, adding hundreds of MB.
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.283
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# ─── DEFAULT — full dev environment ───────────────────────────────────────────
FROM base AS default

# Passwordless sudo for node user — standard practice for devcontainer images.
# Required by the canonical "sudo chown" pattern for named volume ownership.
# See: https://code.visualstudio.com/remote/advancedcontainers/improve-performance
USER root
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node-nopasswd \
  && chmod 0440 /etc/sudoers.d/node-nopasswd
USER node

# System Chromium + fonts for headless browser testing.
# - chromium: used by Playwright and agent-browser via
#   PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH (see .claude/rules/dockerfile.md).
# - fonts-freefont-ttf: baseline fonts for headless rendering.
# Mirrored into the sandbox stage too — the firewall blocks deb.debian.org,
# so chromium cannot be added at runtime.
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      chromium \
      fonts-freefont-ttf
USER node

# Use the apt-installed chromium instead of Playwright-managed browsers.
# Avoids version coupling between @playwright/mcp (alpha playwright-core builds)
# and cached browser binaries. Projects using @playwright/test must point their
# playwright.config.ts at process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH.
# AGENT_BROWSER_EXECUTABLE_PATH points agent-browser at the same binary —
# agent-browser is a Rust CLI with its own env-var convention, NOT Playwright,
# so PLAYWRIGHT_* vars are silently ignored. Without this, agent-browser would
# auto-detect or attempt a Chrome-for-Testing download on first use.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium \
    AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium

# agent-browser: headless browser automation for AI agents.
# Uses the apt-installed chromium above (via AGENT_BROWSER_EXECUTABLE_PATH).
# Installed as the node user (see claude-code install above for rationale).
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
# renovate: datasource=npm depName=agent-browser
ARG AGENT_BROWSER_VERSION=0.38.1
RUN npm install -g agent-browser@${AGENT_BROWSER_VERSION}

LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Claude Code devcontainer — full dev environment with agent-browser, Playwright, and passwordless sudo" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="claude-code" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"

CMD ["sleep", "infinity"]

# ─── SANDBOX — network-restricted environment ─────────────────────────────────
FROM base AS sandbox

# Firewall packages (not needed in default target).
# Chromium + fonts are also baked in here — the sandbox firewall blocks
# deb.debian.org, so they cannot be added at runtime. Required for the
# Playwright MCP plugin to launch a browser.
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  chromium \
  fonts-freefont-ttf

# Use the apt-installed chromium instead of Playwright-managed browsers
# (matches the default stage; see comment above the default chromium block).
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium

# Passwordless sudo for node user — needed for:
#   - "sudo chown" on named volumes (node_modules isolation)
#   - "sudo /usr/local/bin/init-firewall.sh" (firewall setup)
# Sandbox security comes from the network firewall, not sudo restrictions.
# The firewall script is NOT baked into the image — each project mounts its
# own script via bind mount in devcontainer.json to customize the domain allowlist.
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node-nopasswd \
  && chmod 0440 /etc/sudoers.d/node-nopasswd
USER node

LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Claude Code devcontainer — network-restricted sandbox with firewall packages" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="claude-code-sandbox" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"

CMD ["sleep", "infinity"]
