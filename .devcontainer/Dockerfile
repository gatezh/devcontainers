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
