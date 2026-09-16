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

# zsh + oh-my-zsh + powerlevel10k.
#
# Supply chain: ZSH_IN_DOCKER_VERSION pins only this ~190-line wrapper. The
# wrapper then curls oh-my-zsh's install.sh from master and clones powerlevel10k
# at HEAD -- both unpinned, both executed at build time, and its inner curl has
# no -f, so an upstream 5xx body would be run as shell. Accepted deliberately
# for shell tooling; pin both refs to commit SHAs if that trade stops being
# acceptable.
#
# The installer's .zshrc template hardcodes en_US.UTF-8 and TERM=xterm. With -x
# we skip its locale-gen, and the slim base ships only C/C.utf8/POSIX — so the
# en_US export leaves glibc in the C locale and mangles multibyte I/O. TERM=xterm
# likewise clobbers the xterm-256color the terminal provides, dropping colour
# support to 8. Rewrite both: C.UTF-8 is a real UTF-8 locale needing no extra
# package, and dropping the TERM line lets the terminal decide.
RUN curl -fsSL -o /tmp/zsh-in-docker.sh \
      "https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh" \
  && sh /tmp/zsh-in-docker.sh \
  -p git \
  -p fzf \
  -a "export HISTFILE=/commandhistory/.bash_history" \
  -x \
  && rm /tmp/zsh-in-docker.sh \
  && sed -i \
       -e "s|^export LANG=.*|export LANG='C.UTF-8'|" \
       -e "s|^export LC_ALL=.*|export LC_ALL='C.UTF-8'|" \
       -e "/^export LANGUAGE=/d" \
       -e "/^export TERM=xterm$/d" \
       "$HOME/.zshrc"

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
