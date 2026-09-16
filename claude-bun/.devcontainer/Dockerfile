ARG BUN_VERSION=1.3.5

FROM oven/bun:${BUN_VERSION}-slim

ARG TZ=UTC
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest
# renovate: datasource=github-releases depName=deluan/zsh-in-docker
ARG ZSH_IN_DOCKER_VERSION=1.2.0
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
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# zsh + oh-my-zsh + powerlevel10k.
#
# Supply chain: ZSH_IN_DOCKER_VERSION pins only this ~190-line wrapper. The
# wrapper then curls oh-my-zsh's install.sh from master and clones powerlevel10k
# at HEAD -- both unpinned, both executed at build time, and its inner curl has
# no -f, so an upstream 5xx body would be run as shell. Accepted deliberately
# for shell tooling; pin both refs to commit SHAs if that trade stops being
# acceptable.
#
# The template opens with a preamble of env exports we don't want: en_US.UTF-8
# (which -x never generates — the slim bases carry only C/C.utf8/POSIX, so glibc
# falls back to C and mangles multibyte I/O) and a TERM that overrides whatever
# the terminal provides, cutting colour support from 256 to 8.
#
# Delete the whole preamble rather than matching individual lines. v1.2.0 wrote
# `export TERM=xterm`; v1.2.1 writes `[ -z "$TERM" ] && export TERM=xterm` inside
# an UNQUOTED heredoc, so $TERM expands at build time (unset) to `[ -z "" ] && ...`
# — always true, and invisible to a pattern anchored on the old text. Cutting to
# the `##### Zsh/Oh-my-Zsh Configuration` marker is stable across both. The grep
# guard matters: without it a marker rename would make sed delete the whole file.
# Locale now comes from ENV above, which also covers sh/bash, lifecycle commands
# and the VS Code server — not just interactive zsh.
RUN curl -fsSL -o /tmp/zsh-in-docker.sh \
      "https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh" \
  && sh /tmp/zsh-in-docker.sh \
  -p git \
  -p fzf \
  -a "export HISTFILE=/commandhistory/.bash_history" \
  -x \
  && rm /tmp/zsh-in-docker.sh \
  && grep -q '^##### Zsh/Oh-my-Zsh Configuration' "$HOME/.zshrc" \
  && sed -i '/^##### Zsh\/Oh-my-Zsh Configuration/,$!d' "$HOME/.zshrc"

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
