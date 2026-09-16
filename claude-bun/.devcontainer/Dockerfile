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

# Persist bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
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

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Default powerline10k theme
RUN curl -fsSL -o /tmp/zsh-in-docker.sh \
      "https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh" \
  && sh /tmp/zsh-in-docker.sh \
  -p git \
  -p fzf \
  -a "export HISTFILE=/commandhistory/.bash_history" \
  -x \
  && rm /tmp/zsh-in-docker.sh

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
