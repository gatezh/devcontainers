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
FROM alpine:3.21 AS rtk-download
RUN apk add --no-cache curl jq
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
      x86_64)  RTK_TARGET="x86_64-unknown-linux-musl" ;; \
      aarch64) RTK_TARGET="aarch64-unknown-linux-gnu" ;; \
    esac; \
    RTK_VERSION=$(curl -fsSL https://api.github.com/repos/rtk-ai/rtk/releases/latest \
      | jq -r '.tag_name' | sed 's/^v//'); \
    curl -fsSL -o /tmp/rtk.tar.gz \
      "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-${RTK_TARGET}.tar.gz"; \
    tar -xzf /tmp/rtk.tar.gz -C /usr/local/bin rtk

# ── ralphex (autonomous plan execution) ──────────────────────────────────
FROM alpine:3.21 AS ralphex-download
RUN apk add --no-cache curl jq
RUN set -eux; \
    ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"; \
    RALPHEX_VERSION=$(curl -fsSL https://api.github.com/repos/umputun/ralphex/releases/latest \
      | jq -r '.tag_name' | sed 's/^v//'); \
    curl -fsSL -o /tmp/ralphex.tar.gz \
      "https://github.com/umputun/ralphex/releases/download/v${RALPHEX_VERSION}/ralphex_${RALPHEX_VERSION}_linux_${ARCH}.tar.gz"; \
    tar -xzf /tmp/ralphex.tar.gz -C /usr/local/bin ralphex

# ─── BASE ─────────────────────────────────────────────────────────────────────
FROM node:24-trixie-slim AS base

ARG GIT_DELTA_VERSION=0.18.2

# System packages shared by all targets
# - ca-certificates: SSL/TLS for HTTPS connections
# - curl: downloading tools and installers
# - fish: interactive shell (built-in syntax highlighting, autosuggestions, completions)
# - fzf: fuzzy finder (fish integration via fzf.fish or built-in)
# - gh: GitHub CLI
# - git: version control
# - jq: JSON processing (firewall script, onboarding patch)
# - less: pager for git delta output
# - sudo: privilege escalation for firewall setup
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  fish \
  fzf \
  gh \
  git \
  jq \
  less \
  sudo

# npm global directory with proper permissions for node user
# Pre-create /lib to prevent "ENOENT" errors during npx commands
RUN mkdir -p /usr/local/share/npm-global/lib \
  && chown -R node:node /usr/local/share/npm-global

ENV DEVCONTAINER=true

# Create workspace, Claude config, and node_modules volume mount points.
# Pre-creating these dirs with node ownership ensures Docker's volume
# population seeds fresh named volumes with correct permissions.
# Standard monorepo layout shared across projects.
# See: https://docs.docker.com/engine/storage/volumes/#populate-a-volume-using-a-container
RUN mkdir -p /workspace/node_modules \
  /workspace/services/api/node_modules \
  /workspace/services/app/node_modules \
  /workspace/services/www/node_modules \
  /workspace/packages/shared/node_modules \
  /workspace/packages/database/node_modules \
  /home/node/.claude \
  /home/node/.local/share/fish \
  && chown -R node:node /workspace /home/node/.claude /home/node/.local

WORKDIR /workspace

# Install git-delta (better git diffs)
RUN ARCH=$(dpkg --print-architecture) \
  && curl -fsSL -o "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" \
    "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" \
  && dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" \
  && rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# ── Non-root user setup ──────────────────────────────────────────────────────
USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV SHELL=/usr/bin/fish
ENV EDITOR="code --wait"
ENV VISUAL="code --wait"

# ── Starship + Mise (install as root, configure as node) ───────────────────────
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes
RUN curl https://mise.run | sh \
  && cp /root/.local/bin/mise /usr/local/bin/mise \
  && rm -rf /root/.local
SHELL ["/bin/sh", "-c"]

# Configure starship and fish shell.
# Mise is installed as a tool manager — projects run `mise install` at container
# creation to install their specific tool versions from .mise.toml.
# Node is NOT installed via mise — it's provided by the base image; mise shims
# would shadow the base image's npx, breaking global npm-installed CLIs.
USER node
RUN mkdir -p /home/node/.config/fish \
  && starship preset no-runtime-versions -o /home/node/.config/starship.toml \
  && printf '%s\n' 'set -g fish_greeting' 'starship init fish | source' > /home/node/.config/fish/config.fish
ENV PATH="/home/node/.local/share/mise/shims:$PATH"
ENV MISE_TRUSTED_CONFIG_PATHS="/workspace"

# ── Dev tools (copied from parallel download stages) ─────────────────────────
# rtk (token-optimized CLI proxy) and ralphex (autonomous plan execution).
# Like Claude Code itself, these are dev infrastructure — not project dependencies.
# Downloaded from GitHub Releases; refreshed on each daily image rebuild.
COPY --from=rtk-download /usr/local/bin/rtk /usr/local/bin/rtk
COPY --from=ralphex-download /usr/local/bin/ralphex /usr/local/bin/ralphex

# ── Playwright MCP patch script ──────────────────────────────────────────────
# Universal logic with no project-specific config — bake into the image so
# consumer projects don't carry a copy. Invoked from postCreateCommand
# (init-plugins.sh), postStartCommand (devcontainer.json), and the Claude Code
# SessionStart hook (managed-settings.json below) — the hook closes the gap
# where the plugin auto-updates mid-container-run. See issues #87, #98.
COPY --chmod=0755 patch-playwright-mcp.sh /usr/local/bin/patch-playwright-mcp

# ── Claude Code managed settings ─────────────────────────────────────────────
# Image-policy settings at the Linux managed location (highest precedence,
# outside any volume mount). Wires patch-playwright-mcp as a SessionStart hook
# so cache dirs created by mid-session plugin auto-updates get patched before
# the next session reads them. See issues #98, #101.
#
# Pre-create /etc/claude-code as root: BuildKit applies COPY --chmod to any
# parent directories it auto-creates, which would leave the dir at mode 0644
# (no execute bit, not traversable). Creating it explicitly avoids that and
# makes the file readable for the node user at runtime.
USER root
RUN mkdir -p /etc/claude-code
COPY --chown=root:root --chmod=0644 managed-settings.json /etc/claude-code/managed-settings.json
USER node

# ── Claude Code CLI ───────────────────────────────────────────────────────────
# Using npm instead of the native installer (curl claude.ai/install.sh | bash).
# The native installer is recommended for interactive use, but rate-limits (429)
# when multiple parallel Docker builds hit it simultaneously.
# npm is deprecated for interactive users but still supported "for compatibility
# reasons" — Docker/CI parallel builds are exactly that reason.
# See: https://code.claude.com/docs/en/getting-started#install-with-npm
# Auto-updates don't matter here — the image rebuilds daily.
#
# Install as the node user so all files land with node ownership from the start.
# A later `chown -R` in another layer would duplicate every file (overlayfs
# treats an ownership change as a rewrite), adding hundreds of MB.
RUN npm install -g @anthropic-ai/claude-code

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
ARG AGENT_BROWSER_VERSION=latest
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
