# ═══════════════════════════════════════════════════════════════════════════════
# Devcontainer for the devcontainers repo — two build targets:
#   default — full dev environment with passwordless sudo
#   sandbox — network-restricted environment with firewall packages
#
# Mirrors claude-code/.devcontainer/Dockerfile patterns:
#   - Parallel download stages for binary tools
#   - apt/npm cache mounts for faster rebuilds
#   - npm-global directory with proper permissions
#
# Build:
#   docker build --target default -t devcontainers:default .
#   docker build --target sandbox -t devcontainers:sandbox .
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

# ── hadolint (Dockerfile linter) ────────────────────────────────────────
FROM alpine:3.21 AS hadolint-download
RUN apk add --no-cache curl jq
RUN set -eux; \
    ARCH="$(uname -m | sed 's/x86_64/x86_64/;s/aarch64/arm64/')"; \
    HADOLINT_VERSION=$(curl -fsSL https://api.github.com/repos/hadolint/hadolint/releases/latest \
      | jq -r '.tag_name'); \
    curl -fsSL -o /usr/local/bin/hadolint \
      "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-linux-${ARCH}"; \
    chmod +x /usr/local/bin/hadolint

# ── actionlint (GitHub Actions workflow linter) ────────────────────────
FROM alpine:3.21 AS actionlint-download
RUN apk add --no-cache curl jq
RUN set -eux; \
    ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"; \
    ACTIONLINT_VERSION=$(curl -fsSL https://api.github.com/repos/rhysd/actionlint/releases/latest \
      | jq -r '.tag_name' | sed 's/^v//'); \
    curl -fsSL -o /tmp/actionlint.tar.gz \
      "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_${ARCH}.tar.gz"; \
    tar -xzf /tmp/actionlint.tar.gz -C /usr/local/bin actionlint

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

# System packages (each justified — see claude-code Dockerfile for rationale)
# - ca-certificates: SSL/TLS for HTTPS connections
# - curl: downloading tools and installers
# - fish: interactive shell (built-in syntax highlighting, autosuggestions, completions)
# - fzf: fuzzy finder (fish integration)
# - gh: GitHub CLI
# - git: version control
# - jq: JSON processing (onboarding patch, firewall script)
# - less: pager for git delta output
# - sudo: privilege escalation (chown for named volumes, firewall setup)
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

# Create workspace and config directories with proper ownership
RUN mkdir -p /workspace /home/node/.claude /home/node/.local/share/fish \
  && chown -R node:node /workspace /home/node/.claude /home/node/.local

WORKDIR /workspace

# Install git-delta (pinned — v0.19.0 dropped arm64 .deb)
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

# ── Starship prompt ──────────────────────────────────────────────────────────
USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes
SHELL ["/bin/sh", "-c"]

USER node
RUN mkdir -p /home/node/.config/fish \
  && starship preset no-runtime-versions -o /home/node/.config/starship.toml \
  && printf '%s\n' 'set -g fish_greeting' 'starship init fish | source' > /home/node/.config/fish/config.fish

# ── Dev tools (copied from parallel download stages) ─────────────────────────
# rtk (token-optimized CLI proxy) and ralphex (autonomous plan execution).
# Downloaded from GitHub Releases; refreshed on each image rebuild.
COPY --from=rtk-download /usr/local/bin/rtk /usr/local/bin/rtk
COPY --from=ralphex-download /usr/local/bin/ralphex /usr/local/bin/ralphex

# ── CI linting tools ────────────────────────────────────────────────────────
# hadolint (Dockerfile linter) and actionlint (GitHub Actions workflow linter).
# Enables running the same checks locally that CI runs on PRs.
COPY --from=hadolint-download /usr/local/bin/hadolint /usr/local/bin/hadolint
COPY --from=actionlint-download /usr/local/bin/actionlint /usr/local/bin/actionlint

# ── Claude Code CLI ──────────────────────────────────────────────────────────
# npm install (not native installer) to avoid rate-limiting in parallel builds.
# See: claude-code/.devcontainer/Dockerfile for rationale.
USER root
RUN --mount=type=cache,target=/root/.npm \
    npm install -g @anthropic-ai/claude-code
USER node

# ─── DEFAULT — full dev environment ───────────────────────────────────────────
FROM base AS default

# Passwordless sudo for node user — standard practice for devcontainer images.
# Required by the canonical "sudo chown" pattern for named volume ownership.
# See: https://code.visualstudio.com/remote/advancedcontainers/improve-performance
USER root
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node-nopasswd \
  && chmod 0440 /etc/sudoers.d/node-nopasswd
USER node

LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Devcontainer for the devcontainers repo — full dev environment" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="devcontainers" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"

CMD ["sleep", "infinity"]

# ─── SANDBOX — network-restricted environment ─────────────────────────────────
FROM base AS sandbox

# Firewall packages (not needed in default target)
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate

# Passwordless sudo — needed for "sudo chown" on named volumes (postCreateCommand)
# and for running the firewall script (postStartCommand).
# Sandbox security comes from the network firewall, not sudo restrictions.
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node-nopasswd \
  && chmod 0440 /etc/sudoers.d/node-nopasswd
USER node

LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Devcontainer for the devcontainers repo — network-restricted sandbox" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="devcontainers-sandbox" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"

CMD ["sleep", "infinity"]
