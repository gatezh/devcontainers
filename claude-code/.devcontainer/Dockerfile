# ═══════════════════════════════════════════════════════════════════════════════
# Shared devcontainer image — two build targets:
#   default — full dev environment with agent-browser and passwordless sudo
#   sandbox — network-restricted environment: baked firewall, sudo for it only
#
# Projects consume these pre-built images and run `mise install` at container
# creation to install their specific tool versions (Bun, Hugo, etc.).
#
# Build:
#   docker build --target default -t claude-code:default .
#   docker build --target sandbox -t claude-code:sandbox .
# ═══════════════════════════════════════════════════════════════════════════════

# Global so Renovate bumps one line; re-declared in the shared stage after Chromium.
# An ARG joins the cache key of every later RUN, so declaring it earlier would
# rebuild Chromium on each Claude Code release.
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.312
# Base of the download stages only; no final image is built on it.
# renovate: datasource=docker depName=alpine
ARG ALPINE_VERSION=3.24
# Also the image tags of the actionlint and shellcheck stages. Renovate reads
# GitHub releases; the 3-day soak covers the short lag before each image tag.
# renovate: datasource=github-releases depName=rhysd/actionlint
ARG ACTIONLINT_VERSION=1.7.12
# renovate: datasource=github-releases depName=koalaman/shellcheck
ARG SHELLCHECK_VERSION=0.11.0
# Cloudflare's security-audit skill has no releases: pinned by SHA, bumped by hand
# after reading the upstream diff.
ARG SECURITY_AUDIT_SKILL_REF=c1c8a8c1471069fb0e188eeaff69b8e8db6564a8

# ═════════════════════════════════════════════════════════════════════════════
# Parallel download stages — BuildKit runs these concurrently
# ═════════════════════════════════════════════════════════════════════════════

# ── oh-my-zsh + powerlevel10k ─────────────────────────────────
# Pinned by commit SHA: neither project tags usefully, and auto-adopting
# shell-framework changes has broken this image before. Bump deliberately.
FROM alpine:${ALPINE_VERSION} AS ohmyzsh-download
RUN apk add --no-cache curl tar
ARG OH_MY_ZSH_REF=0ee67f042872d1dfab74270c31867771ca35aef4
ARG POWERLEVEL10K_REF=d05a1b00f9a61f9578bf9dc19b8451942dde8734
RUN set -eux; \
    mkdir -p /omz/custom/themes/powerlevel10k; \
    curl -fsSL "https://github.com/ohmyzsh/ohmyzsh/archive/${OH_MY_ZSH_REF}.tar.gz" \
      | tar -xz -C /omz --strip-components=1; \
    curl -fsSL "https://github.com/romkatv/powerlevel10k/archive/${POWERLEVEL10K_REF}.tar.gz" \
      | tar -xz -C /omz/custom/themes/powerlevel10k --strip-components=1

# ── security-audit skill (Cloudflare) ─────────────────────────────────────
# Wildcards, not the archive's top dir: GitHub renames it for short SHAs and tags.
# Keeps the MIT LICENSE the image must ship; drops upstream's unit tests.
FROM alpine:${ALPINE_VERSION} AS security-audit-skill-download
RUN apk add --no-cache curl tar
ARG SECURITY_AUDIT_SKILL_REF
RUN set -eux; \
    mkdir /src; \
    curl -fsSL "https://github.com/cloudflare/security-audit-skill/archive/${SECURITY_AUDIT_SKILL_REF}.tar.gz" \
      | tar -xz -C /src --strip-components=1 --wildcards --exclude='*.test.cjs' \
        '*/LICENSE' '*/skills/security-audit'; \
    mv /src/skills/security-audit /skill; \
    mv /src/LICENSE /skill/LICENSE; \
    chmod -R u=rwX,go=rX /skill

# ── ralphex (autonomous plan execution) ──────────────────────────────────
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
FROM alpine:${ALPINE_VERSION} AS ralphex-download
RUN apk add --no-cache curl
# renovate: datasource=github-releases depName=umputun/ralphex
ARG RALPHEX_VERSION=1.7.0
RUN set -eux; \
    ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"; \
    curl -fsSL -o /tmp/ralphex.tar.gz \
      "https://github.com/umputun/ralphex/releases/download/v${RALPHEX_VERSION}/ralphex_${RALPHEX_VERSION}_linux_${ARCH}.tar.gz"; \
    tar -xzf /tmp/ralphex.tar.gz -C /usr/local/bin ralphex

# ── actionlint + shellcheck (GitHub Actions workflow linting) ─────────────
# Both publish multi-arch images. actionlint hands `run:` scripts to shellcheck
# when it is on PATH, else skips them.
FROM rhysd/actionlint:${ACTIONLINT_VERSION} AS actionlint
FROM koalaman/shellcheck:v${SHELLCHECK_VERSION} AS shellcheck

# ─── BASE ─────────────────────────────────────────────────────────────────────
FROM node:24-trixie-slim AS base

# renovate: datasource=github-releases depName=cli/cli
ARG GH_VERSION=2.103.2

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
# - python3, python3-venv: runtime for the security-guidance and claude-security
#   plugin hooks/scripts (stdlib only; ~+41 MB together). python3-minimal is too
#   small (no http/urllib); python3-venv (ensurepip, +5 MB) rather than
#   python3-pip (+15 MB) lets security-guidance build its claude-agent-sdk venv
#   in ~/.claude/security. Keep the byte-compiled stdlib: without it every hook
#   call recompiles (~50 ms -> ~240 ms). In base for the same reason as
#   openssh-client: the sandbox can't apt-install.
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
  python3 \
  python3-venv \
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
  /home/node/.config/cloudflare \
  /home/node/.cache \
  /home/node/.bun/install/cache \
  /commandhistory \
  && chown -R node:node /workspace /home/node/.claude /home/node/.local \
       /home/node/.config /home/node/.cache /home/node/.bun /commandhistory

WORKDIR /workspace

# gh from the upstream .deb: trixie freezes it at 2.46.0 (Apr 2024). Must follow
# the apt block — the .deb depends on git and dpkg -i won't resolve it.
RUN ARCH=$(dpkg --print-architecture) \
  && curl -fsSL -o "gh_${GH_VERSION}_linux_${ARCH}.deb" \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.deb" \
  && dpkg -i "gh_${GH_VERSION}_linux_${ARCH}.deb" \
  && rm "gh_${GH_VERSION}_linux_${ARCH}.deb"

# Trust the bind-mounted /workspace in /etc/gitconfig, which every git process reads.
# A GIT_CONFIG_* env var is stripped by tools that filter env, e.g. Hugo, whose
# security.exec.osEnv allowlist has no GIT_* pattern (#211).
RUN git config --system --add safe.directory /workspace

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
# overrides. The wizard flag stops powerlevel10k prompting on first shell. The gh
# plugin regenerates gh's completion on each shell start, so it never goes stale.
# Single-quoted so $HOME/$ZSH reach .zshrc unexpanded.
# hadolint ignore=SC2016
RUN printf '%s\n' \
      'export ZSH="$HOME/.oh-my-zsh"' \
      'ZSH_THEME="powerlevel10k/powerlevel10k"' \
      'plugins=(git fzf gh)' \
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
# ralphex (plan execution) — dev infrastructure, not a project dependency.
# Renovate-pinned; see .github/renovate.json5.
COPY --from=ralphex-download /usr/local/bin/ralphex /usr/local/bin/ralphex

# ── gh-stack (native stacked PRs) ────────────────────────────────────────────
# Baked as node into ~/.local/share/gh/extensions, which is on the image layer (only
# ~/.config/gh is a volume); a volume over ~/.local/share/gh would shadow it. See #160.
# ~/.cache/gh is gh's HTTP cache — the install leaves a 25 MB copy of the download.
# renovate: datasource=github-releases depName=github/gh-stack
ARG GH_STACK_VERSION=0.2.1
RUN gh extension install github/gh-stack --pin "v${GH_STACK_VERSION}" \
  && rm -rf /home/node/.cache/gh

# ─── SHARED — Chromium, Claude Code and agent-browser, common to both targets ─
# Everything heavy lives here so default and sandbox share these layers: pulling
# both images downloads Chromium and Claude Code once. Each target adds only a
# small layer on top (firewall packages in the sandbox).
FROM base AS shared

# System Chromium + fonts for headless browser testing.
# - chromium: launched by agent-browser and Playwright (env vars below).
# - fonts-freefont-ttf: baseline fonts for headless rendering.
# Baked in for both targets — the sandbox firewall blocks deb.debian.org, so
# chromium cannot be added at runtime.
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
# agent-browser is a Rust CLI that ignores PLAYWRIGHT_* vars; without its own var
# it would attempt a Chrome-for-Testing download on first use. AGENT_BROWSER_CONFIG
# pins its config to the image's file, so a repo's ./agent-browser.json (which can
# declare plugin executables and Chromium args) is never loaded.
# PLAYWRIGHT_MCP_* configure the Playwright MCP plugin, which Claude Code starts with
# this environment: its default chrome channel isn't installed. The chromium channel
# already runs without Chromium's sandbox on Linux.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_MCP_BROWSER=chromium \
    PLAYWRIGHT_MCP_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_MCP_HEADLESS=true \
    AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium \
    AGENT_BROWSER_CONFIG=/etc/agent-browser/config.json

# ── actionlint + shellcheck — after Chromium, so their bumps don't rebuild it ─
COPY --from=actionlint /usr/local/bin/actionlint /usr/local/bin/actionlint
COPY --from=shellcheck /bin/shellcheck /usr/local/bin/shellcheck

# ── cf (Cloudflare CLI) — before Claude Code so its bumps don't reinstall cf ──
# Needs Node >= 22.18 (Bun can't load cloudflare.config.ts). No install scripts, and the
# bundled workerd (133 MB) goes: `cf dev`/--local run the project's own cf copy.
# Completion is installed the documented way; it queries cf, so upgrades don't stale it.
# renovate: datasource=npm depName=cf
ARG CF_VERSION=1.0.0-beta.21
RUN --mount=type=cache,target=/tmp/npm-cache,uid=1000,gid=1000 \
    npm install -g --cache /tmp/npm-cache --ignore-scripts cf@${CF_VERSION} \
  && rm -rf /usr/local/share/npm-global/lib/node_modules/cf/node_modules/@cloudflare/workerd-linux-* \
  && cf complete zsh >> "$HOME/.zshrc"
# No telemetry from cf, nor from the Wrangler it delegates esbuild builds to, and
# no npm dependency metadata in Worker deploys (cf >= 1.0.0-beta.15).
ENV CF_SEND_TELEMETRY=false \
    WRANGLER_SEND_METRICS=false \
    CLOUDFLARE_DEPENDENCIES_INSTRUMENTATION=false

# ── Claude Code CLI — after Chromium: it changes most often (see global ARG) ─
# npm, not the native installer: the installer rate-limits (429) under parallel
# Docker builds. npm stays supported "for compatibility reasons" — this is that
# reason. https://code.claude.com/docs/en/getting-started#install-with-npm
#
# Installed as node so files land node-owned; a later chown -R would duplicate
# every file on overlayfs, adding hundreds of MB.
#
# The npm cache goes to a BuildKit cache mount, not ~/.npm: left in the image it
# keeps a second, compressed copy of every package (~160 MB across both installs).
ARG CLAUDE_CODE_VERSION
RUN --mount=type=cache,target=/tmp/npm-cache,uid=1000,gid=1000 \
    npm install -g --cache /tmp/npm-cache @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# ── agent-browser — the default browser tool (devcontainer-browser skill) ────
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
# The package ships prebuilt binaries for 7 platforms (~113 MB); the global
# `agent-browser` link targets agent-browser-linux-<arch> directly, so the other
# six are deleted. Rebuilt on each Claude Code bump (ARG above) — a small layer.
# renovate: datasource=npm depName=agent-browser
ARG AGENT_BROWSER_VERSION=0.39.2
RUN --mount=type=cache,target=/tmp/npm-cache,uid=1000,gid=1000 \
    npm install -g --cache /tmp/npm-cache agent-browser@${AGENT_BROWSER_VERSION} \
  && find /usr/local/share/npm-global/lib/node_modules/agent-browser/bin \
       -name 'agent-browser-*' ! -name "agent-browser-linux-$(node -p process.arch)" -delete

# ── Claude Code managed settings and skills, agent-browser config ────────────
# Image-policy settings at the Linux managed location (highest precedence, outside
# any volume mount). Wires drop-rtk-hook as a SessionStart hook,
# provides the MDN MCP server (managedMcpServers needs Claude Code >= 2.1.259), and
# routes browser work to the devcontainer-browser skill and Cloudflare work to cf
# (claudeMd), denies agent-browser install/upgrade, asks before `cf ... --force`, and
# installs the auto-updating dev plugin from gatezh/claude-skills at session start.
#
# The skills ship at the managed skills location, so every project gets them without a
# copy in its own .claude/skills/, and they win a name clash with a project skill.
#
# Last in shared so editing these files doesn't rebuild Chromium or Claude Code.
#
# The directories are created explicitly: BuildKit applies COPY --chmod to parent
# dirs it auto-creates, leaving 0644 — not traversable.
USER root
RUN mkdir -p /etc/claude-code/.claude/skills/devcontainer-browser /etc/agent-browser
COPY --chown=root:root --chmod=0644 managed-settings.json /etc/claude-code/managed-settings.json
COPY --chown=root:root --chmod=0644 managed-skills/devcontainer-browser/SKILL.md /etc/claude-code/.claude/skills/devcontainer-browser/SKILL.md
# No --chmod: modes come from the download stage's chmod; verify-image.sh checks them.
COPY --from=security-audit-skill-download --chown=root:root /skill /etc/claude-code/.claude/skills/security-audit
COPY --chown=root:root --chmod=0644 agent-browser.json /etc/agent-browser/config.json
# Transitional: a hook that removes the rtk hook older images registered, and a
# no-op where the Playwright MCP patcher was, for projects that still call it.
COPY --chmod=0755 drop-rtk-hook.sh /usr/local/bin/drop-rtk-hook
COPY --chmod=0755 patch-playwright-mcp.sh /usr/local/bin/patch-playwright-mcp
# Volume-ownership safety net both templates run through sudo; in the sandbox it's
# one of the only two commands sudo allows (#208).
COPY --chown=root:root --chmod=0755 chown-volumes.sh /usr/local/sbin/chown-volumes
USER node

# ─── DEFAULT — full dev environment ───────────────────────────────────────────
FROM shared AS default

# Passwordless sudo for node user — standard practice for devcontainer images,
# needed for the canonical "sudo chown" pattern for named volume ownership.
# See: https://code.visualstudio.com/remote/advancedcontainers/improve-performance
USER root
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node-nopasswd \
  && chmod 0440 /etc/sudoers.d/node-nopasswd
USER node

LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Claude Code devcontainer — full dev environment with agent-browser, Playwright, and passwordless sudo" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="claude-code" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"

CMD ["sleep", "infinity"]

# ─── SANDBOX — network-restricted environment ─────────────────────────────────
FROM shared AS sandbox

# Firewall packages (not needed in default target).
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate

# The agent runs with permission prompts skipped, so sudo reaches only these two
# root-owned scripts, with no arguments: a firewall the agent can't edit or flush,
# and the volume chown. Projects list extra domains in a file, read as data (#208).
COPY --chown=root:root --chmod=0755 init-firewall.sh /usr/local/sbin/init-firewall
RUN printf '%s\n' 'node ALL=(root) NOPASSWD: /usr/local/sbin/init-firewall "", /usr/local/sbin/chown-volumes ""' \
    > /etc/sudoers.d/node-sandbox \
  && chmod 0440 /etc/sudoers.d/node-sandbox \
  && visudo -cf /etc/sudoers.d/node-sandbox
USER node

LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Claude Code devcontainer — network-restricted sandbox with a baked firewall and agent-browser" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="claude-code-sandbox" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"

CMD ["sleep", "infinity"]
