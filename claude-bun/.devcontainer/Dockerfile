ARG BUN_VERSION=1.3.5

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

FROM oven/bun:${BUN_VERSION}-slim

ARG TZ=UTC
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest
# renovate: datasource=github-releases depName=cli/cli
ARG GH_VERSION=2.100.0

# Install basic development tools and iptables/ipset
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  less \
  git \
  sudo \
  fzf \
  zsh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq

# Ensure default bun user has access to /usr/local/share
RUN mkdir -p /usr/local/share/bun-global && \
  chown -R bun:bun /usr/local/share

ARG USERNAME=bun

# Shared history volume mount point. Despite the .bash_history name — kept so
# existing /commandhistory volumes don't lose their history — zsh is what writes
# here, via HISTFILE below. bash history is not persisted in this image.
RUN mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/bun/.claude /home/bun/.bun && \
  chown -R bun:bun /workspace /home/bun/.claude /home/bun/.bun

WORKDIR /workspace

# gh from the upstream .deb: trixie freezes it at 2.46.0 (Apr 2024). Must follow
# the apt block — the .deb depends on git and dpkg -i won't resolve it.
RUN ARCH=$(dpkg --print-architecture) && \
  curl -fsSL -o "gh_${GH_VERSION}_linux_${ARCH}.deb" \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.deb" && \
  dpkg -i "gh_${GH_VERSION}_linux_${ARCH}.deb" && \
  rm "gh_${GH_VERSION}_linux_${ARCH}.deb"

# Set up non-root user
USER bun

# Ensure bun uses the correct home and global install path
ENV HOME=/home/bun
ENV BUN_INSTALL=/home/bun/.bun
ENV PATH="$BUN_INSTALL/bin:$PATH"

# Set the default shell to zsh rather than sh (/usr/bin/zsh, matching the other
# images; /bin/zsh is the same binary via usrmerge)
ENV SHELL=/usr/bin/zsh
# LANG only, as the official images do. LC_ALL would outrank a consumer's
# containerEnv; TERM stays unset so the terminal's own value wins.
ENV LANG=C.UTF-8

# zsh + oh-my-zsh + powerlevel10k.
#
# Written as bun: $HOME during RUN follows USER, so this must not run as root.
USER bun
COPY --from=ohmyzsh-download --chown=bun:bun /omz /home/bun/.oh-my-zsh

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
      'export HISTFILE=/commandhistory/.bash_history' \
      'source $ZSH/oh-my-zsh.sh' \
      'POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last' \
      'POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(user dir vcs status)' \
      'POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()' \
      'POWERLEVEL9K_STATUS_OK=false' \
      'POWERLEVEL9K_STATUS_CROSS=true' \
      > "$HOME/.zshrc"

# Install Claude Code globally using bun (run as root to avoid EACCES linking)
USER root
RUN BUN_INSTALL=/home/bun/.bun HOME=/home/bun bun add -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} && \
  chown -R bun:bun /home/bun/.bun
USER bun

# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "bun ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/bun-firewall && \
  chmod 0440 /etc/sudoers.d/bun-firewall
USER bun

LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Claude Code development container — Bun environment with Claude Code CLI, firewall sandbox, and zsh" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="claude-bun" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"
