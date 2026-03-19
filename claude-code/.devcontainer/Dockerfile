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

# ─── BASE ─────────────────────────────────────────────────────────────────────
FROM node:22-trixie-slim AS base

ARG GIT_DELTA_VERSION=0.18.2
ARG PLAYWRIGHT_VERSION=1.50.1
ARG AGENT_BROWSER_VERSION=0.14.0

# System packages shared by all targets
# - ca-certificates: SSL/TLS for HTTPS connections
# - curl/wget: downloading tools and installers
# - fish: interactive shell (built-in syntax highlighting, autosuggestions, completions)
# - fzf: fuzzy finder (fish integration via fzf.fish or built-in)
# - gh: GitHub CLI
# - git: version control
# - gnupg2: package signing verification
# - jq: JSON processing (firewall script, onboarding patch)
# - less: pager for git delta output
# - man-db: manual pages
# - nano/vim: editors
# - procps: ps, top (debugging)
# - sudo: privilege escalation for firewall setup
# - unzip: extracting archives
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  fish \
  fzf \
  gh \
  git \
  gnupg2 \
  jq \
  less \
  man-db \
  nano \
  procps \
  sudo \
  unzip \
  vim \
  wget \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

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
  && wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" \
  && dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" \
  && rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# ── Non-root user setup ──────────────────────────────────────────────────────
USER node

ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin
ENV SHELL=/usr/bin/fish
ENV EDITOR=nano
ENV VISUAL=nano

# ── Starship + Mise (install as root, configure as node) ───────────────────────
USER root
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes
RUN curl https://mise.run | sh \
  && cp /root/.local/bin/mise /usr/local/bin/mise

# Configure starship and fish shell.
# Mise is installed as a tool manager — projects run `mise install` at container
# creation to install their specific tool versions from .mise.toml.
# Node is NOT installed via mise — it's provided by the base image;
# mise shims would shadow the base image's npx, breaking Playwright installation.
USER node
RUN mkdir -p /home/node/.config/fish \
  && starship preset no-runtime-versions -o /home/node/.config/starship.toml \
  && printf '%s\n' 'set -g fish_greeting' 'starship init fish | source' > /home/node/.config/fish/config.fish
ENV PATH="/home/node/.local/share/mise/shims:$PATH"
ENV MISE_TRUSTED_CONFIG_PATHS="/workspace"

# ── Playwright (headless shell for browser testing) ───────────────────────────
# Browser binary baked at a pinned version (PLAYWRIGHT_VERSION build arg).
# If a project's @playwright/test version differs from PLAYWRIGHT_VERSION,
# Playwright auto-downloads the correct browser on first test run (~10s).
# This is a best-effort optimization, not a hard contract.
# Using --only-shell for smaller image (agent-browser installs full chromium separately).
USER root
RUN npx -y playwright@${PLAYWRIGHT_VERSION} install-deps chromium
USER node
RUN npx -y playwright@${PLAYWRIGHT_VERSION} install --only-shell

# ── Claude Code CLI (native installer) ───────────────────────────────────────
# Native installer replaces deprecated npm method (npm install -g @anthropic-ai/claude-code)
# See: https://code.claude.com/docs/en/getting-started
# The installer places the binary in ~/.local/bin/ (previously ~/.claude/bin/).
# Runtime volume mounts over ~/.claude/ (for config persistence) could shadow it,
# so copy to a system path to ensure the binary survives volume mounts.
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root
RUN if [ -d /home/node/.local/bin ] && ls /home/node/.local/bin/claude* >/dev/null 2>&1; then \
      cp /home/node/.local/bin/claude* /usr/local/bin/; \
    elif [ -d /home/node/.claude/bin ]; then \
      cp /home/node/.claude/bin/* /usr/local/bin/; \
    else \
      echo "ERROR: Claude Code binary not found in ~/.local/bin/ or ~/.claude/bin/" && exit 1; \
    fi
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

# agent-browser: headless browser automation for AI agents
# Installs its own bundled playwright-core + full chromium (separate from Playwright above)
# Requires root for system deps (apt-get install triggered by --with-deps)
USER root
RUN npm install -g agent-browser@${AGENT_BROWSER_VERSION} \
  && $(npm root -g)/agent-browser/node_modules/.bin/playwright-core install --with-deps chromium \
  && chown -R node:node /usr/local/share/npm-global
USER node

# ─── SANDBOX — network-restricted environment ─────────────────────────────────
FROM base AS sandbox

# Firewall packages (not needed in default target)
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Firewall sudo rule for node user.
# The init-firewall.sh script is NOT baked into the image — each project
# mounts its own script via bind mount in devcontainer.json:
#   "source=${localWorkspaceFolder}/.devcontainer/claude-sandbox/init-firewall.sh,target=/usr/local/bin/init-firewall.sh,type=bind"
# This allows different projects to define their own domain allowlists.
RUN echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall \
  && chmod 0440 /etc/sudoers.d/node-firewall
USER node
