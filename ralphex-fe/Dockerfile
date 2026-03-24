ARG BUN_VERSION=1.3.9
ARG HUGO_VERSION=0.156.0
ARG PLAYWRIGHT_VERSION=1.58.2

FROM node:24-trixie-slim

ARG BUN_VERSION
ARG HUGO_VERSION
ARG PLAYWRIGHT_VERSION
ARG TARGETARCH

# ── System packages ──────────────────────────────────────────────────────────
# - ca-certificates: SSL/TLS for HTTPS connections
# - curl: downloading tools and installers
# - docker.io: Docker CLI for container workflows (wrapper's --docker flag)
# - dumb-init: PID 1 init for proper signal handling (used by /init.sh entrypoint)
# - fzf: fuzzy finder (interactive selection in Claude Code and shell)
# - git: version control
# - golang-go: required for Hugo Modules to download and manage dependencies
# - gosu: drop privileges to app user (Debian equivalent of Alpine's su-exec)
# - jq: JSON processing
# - python3: scripting (Claude Code uses python for ad-hoc scripts)
# - ripgrep: fast code search
# - tzdata: timezone data for container timezone configuration
# - unzip: required by Bun install script on Linux
# - wget: required to download Hugo Extended binary
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  docker.io \
  dumb-init \
  fzf \
  git \
  golang-go \
  gosu \
  jq \
  python3 \
  ripgrep \
  tzdata \
  unzip \
  wget \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── App user (matches umputun/baseimage convention) ──────────────────────────
# The ralphex docker-wrapper (ralphex-dk.sh) expects:
#   - user "app" with home at /home/app
#   - UID 1001 (remappable at runtime via APP_UID env var)
#   - /srv owned by app
#   - docker group GID 999
# Source: https://github.com/umputun/baseimage/blob/master/base.alpine/Dockerfile
ENV APP_USER=app \
    APP_UID=1001 \
    DOCKER_GID=999 \
    TIME_ZONE=America/Chicago

# Reserve GID 998 for ping to prevent conflicts (matches umputun/baseimage convention)
RUN groupadd -g 998 ping \
  && groupadd -g ${DOCKER_GID} docker \
  && useradd --no-log-init -m -s /bin/sh -u ${APP_UID} ${APP_USER} \
  && usermod -aG docker ${APP_USER} \
  && mkdir -p /srv /workspace \
  && chown -R ${APP_USER}:${APP_USER} /srv /workspace \
  && cp /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime \
  && echo "${TIME_ZONE}" > /etc/timezone

# ── Entrypoint and init scripts ──────────────────────────────────────────────
# /init.sh — entrypoint handling APP_UID remapping and privilege drop
#   Adapted from: https://github.com/umputun/baseimage/blob/master/base.alpine/files/init.sh
# /srv/init.sh — credential copier run before main command
#   Source: https://github.com/umputun/ralphex/blob/master/scripts/internal/init-docker.sh
COPY files/init.sh /init.sh
COPY files/init-docker.sh /srv/init.sh
RUN chmod +x /init.sh /srv/init.sh

WORKDIR /workspace

# ── Ralphex binary (latest from GitHub Releases) ─────────────────────────────
# Pattern from: claude-code/.devcontainer/Dockerfile (lines 104-119)
# The wrapper script calls /srv/ralphex as the container command.
RUN set -eux; \
    ARCH="$(uname -m)"; \
    RALPHEX_ARCH=$(echo "$ARCH" | sed 's/x86_64/amd64/;s/aarch64/arm64/'); \
    RALPHEX_VERSION=$(curl -fsSL https://api.github.com/repos/umputun/ralphex/releases/latest \
      | jq -r '.tag_name' | sed 's/^v//'); \
    curl -fsSL -o /tmp/ralphex.tar.gz \
      "https://github.com/umputun/ralphex/releases/download/v${RALPHEX_VERSION}/ralphex_${RALPHEX_VERSION}_linux_${RALPHEX_ARCH}.tar.gz"; \
    tar -xzf /tmp/ralphex.tar.gz -C /srv ralphex; \
    rm /tmp/ralphex.tar.gz; \
    chmod +x /srv/ralphex

# ── Playwright (native Debian — no Alpine hacks needed) ──────────────────────
# Two-layer strategy from claude-code/.devcontainer/Dockerfile:
#   1. System deps (install-deps) — heavy, needs root
#   2. Browser binary (install --only-shell) — light, version-specific
RUN npx -y playwright@${PLAYWRIGHT_VERSION} install-deps chromium
USER app
RUN npx -y playwright@${PLAYWRIGHT_VERSION} install --only-shell
USER root

# ── Claude Code CLI ──────────────────────────────────────────────────────────
# npm install (not native installer) to avoid rate-limiting in parallel Docker builds.
# See: claude-code/.devcontainer/Dockerfile for rationale.
RUN npm install -g @anthropic-ai/claude-code

# ── Bun ──────────────────────────────────────────────────────────────────────
ENV BUN_INSTALL=/usr/local/bun
ENV PATH="$BUN_INSTALL/bin:$PATH"

# pipefail ensures curl failure is not masked by bash exit code
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}" && \
    bun --version
SHELL ["/bin/sh", "-c"]

# ── Hugo Extended (direct download with checksum verification) ───────────────
# Kept from current ralphex-fe/Dockerfile — works natively on Debian (no gcompat).
RUN set -eux; \
    wget -O hugo.tar.gz "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-${TARGETARCH}.tar.gz"; \
    wget -O hugo_checksums.txt "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_checksums.txt"; \
    EXPECTED_CHECKSUM=$(grep "hugo_extended_${HUGO_VERSION}_linux-${TARGETARCH}.tar.gz" hugo_checksums.txt | cut -d' ' -f1); \
    if [ -z "$EXPECTED_CHECKSUM" ]; then \
        echo "Error: Could not find checksum for hugo_extended_${HUGO_VERSION}_linux-${TARGETARCH}.tar.gz"; \
        exit 1; \
    fi; \
    ACTUAL_CHECKSUM=$(sha256sum hugo.tar.gz | cut -d' ' -f1); \
    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then \
        echo "Checksum verification failed for Hugo!"; \
        echo "Expected: $EXPECTED_CHECKSUM"; \
        echo "Actual:   $ACTUAL_CHECKSUM"; \
        exit 1; \
    fi; \
    echo "Hugo checksum verified: $ACTUAL_CHECKSUM"; \
    tar -xzf hugo.tar.gz -C /usr/local/bin/ hugo; \
    rm hugo.tar.gz hugo_checksums.txt; \
    hugo version

# ── Environment ──────────────────────────────────────────────────────────────
ENV RALPHEX_DOCKER=1 \
    USE_BUILTIN_RIPGREP=0 \
    PLAYWRIGHT_VERSION=${PLAYWRIGHT_VERSION}

# Ralphex web dashboard port
EXPOSE 8080

# No final USER directive — /init.sh runs as root, handles APP_UID remapping,
# then drops to app user via gosu before executing CMD.
ENTRYPOINT ["/init.sh"]
CMD ["/srv/ralphex"]

# ── OCI labels ───────────────────────────────────────────────────────────────
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images" \
      org.opencontainers.image.description="Ralphex-fe: Frontend development image with Bun, Hugo Extended, Playwright, and Claude Code on Debian" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="ralphex-fe" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"
