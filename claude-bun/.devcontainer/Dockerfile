ARG BUN_VERSION=1.3.5

# ── oh-my-zsh + powerlevel10k ─────────────────────────────────
# Pinned to commit SHAs and fetched as tarballs. Neither project tags usefully --
# oh-my-zsh has no tags at all, and powerlevel10k's last release predates its
# current master by years -- so a SHA is the only real pin. Bump deliberately:
# auto-adopting upstream shell-framework changes is what repeatedly broke this
# image, and a prompt theme does not need a 3-day release cadence.
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

# gh (GitHub CLI) — installed from the upstream .deb, not apt: Debian trixie
# freezes gh at 2.46.0 (Apr 2024). Version kept current by Renovate.
# Must stay AFTER the apt block: the .deb depends on git, and dpkg -i does not
# resolve dependencies — it fails loudly ("dependency problems") if git is absent.
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
# Only LANG, and only C.UTF-8 — what the official images do (ruby sets exactly
# this; node/debian/python set nothing). LC_ALL would override every LC_* category
# and silently defeat a consuming project's containerEnv. TERM is deliberately
# unset: no official image sets it, an image ENV beats the tty value `docker exec -t`
# supplies, and tput/clear failing without a terminal is correct behaviour.
ENV LANG=C.UTF-8

# zsh + oh-my-zsh + powerlevel10k.
#
# Written as bun: $HOME during RUN follows USER, so this must not run as root.
USER bun
# oh-my-zsh tree is COPYed from the parallel download stage above, so the final
# image needs no git or curl for it and nothing is fetched at build time here.
COPY --from=ohmyzsh-download --chown=bun:bun /omz /home/bun/.oh-my-zsh

# .zshrc is written here rather than by an installer, so nothing upstream can
# inject env overrides (locale/TERM) that then have to be patched back out.
# The wizard flag matters: without a POWERLEVEL9K_* config powerlevel10k starts
# its interactive configurator on first shell, which blocks a container.
# $HOME and $ZSH are single-quoted on purpose: they must reach .zshrc
# unexpanded so zsh resolves them at runtime, not at build time.
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
