ARG BUN_VERSION=1.3.9
ARG DOCKER_VERSION=29.3.0
ARG GO_VERSION=1.24.4
ARG HUGO_VERSION=0.156.0
ARG PLAYWRIGHT_VERSION=1.58.2

# ═════════════════════════════════════════════════════════════════════════════
# Parallel download stages — BuildKit runs these concurrently
# ═════════════════════════════════════════════════════════════════════════════

# ── Go binary ────────────────────────────────────────────────────────────────
# Pattern from: https://github.com/umputun/ralphex/blob/master/Dockerfile-go
FROM alpine:3.21 AS go-download
ARG GO_VERSION
RUN set -eux; \
    ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"; \
    wget -qO- "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" \
      | tar -xz -C /usr/local

# ── Docker CLI static binary ────────────────────────────────────────────────
# Matches ralphex base's docker-cli — only the CLI, no daemon/containerd/runc.
FROM alpine:3.21 AS docker-download
ARG DOCKER_VERSION
RUN set -eux; \
    ARCH="$(uname -m)"; \
    wget -qO- "https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VERSION}.tgz" \
      | tar -xz -C /tmp; \
    mv /tmp/docker/docker /usr/local/bin/docker

# ── Hugo Extended with checksum verification ─────────────────────────────────
FROM alpine:3.21 AS hugo-download
ARG HUGO_VERSION
ARG TARGETARCH
RUN set -eux; \
    wget -qO hugo.tar.gz \
      "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-${TARGETARCH}.tar.gz"; \
    wget -qO hugo_checksums.txt \
      "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_checksums.txt"; \
    EXPECTED=$(grep "hugo_extended_${HUGO_VERSION}_linux-${TARGETARCH}.tar.gz" hugo_checksums.txt | cut -d' ' -f1); \
    ACTUAL=$(sha256sum hugo.tar.gz | cut -d' ' -f1); \
    if [ "$EXPECTED" != "$ACTUAL" ]; then \
        echo "Hugo checksum mismatch: expected=$EXPECTED actual=$ACTUAL"; exit 1; \
    fi; \
    tar -xzf hugo.tar.gz -C /usr/local/bin/ hugo

# ── RTK (token-optimized CLI proxy for Claude Code) ─────────────────────────
# Pattern from: .devcontainer/Dockerfile
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

# ── Ralphex binary (latest from GitHub Releases) ────────────────────────────
# Pattern from: claude-code/.devcontainer/Dockerfile
FROM alpine:3.21 AS ralphex-download
RUN apk add --no-cache curl jq
RUN set -eux; \
    ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"; \
    VERSION=$(curl -fsSL https://api.github.com/repos/umputun/ralphex/releases/latest \
      | jq -r '.tag_name' | sed 's/^v//'); \
    curl -fsSL -o /tmp/ralphex.tar.gz \
      "https://github.com/umputun/ralphex/releases/download/v${VERSION}/ralphex_${VERSION}_linux_${ARCH}.tar.gz"; \
    tar -xzf /tmp/ralphex.tar.gz -C /usr/local/bin ralphex

# ═════════════════════════════════════════════════════════════════════════════
# Final image
# ═════════════════════════════════════════════════════════════════════════════
FROM node:24-trixie-slim

ARG BUN_VERSION
ARG PLAYWRIGHT_VERSION

# ── System packages ──────────────────────────────────────────────────────────
# - ca-certificates: SSL/TLS for HTTPS connections
# - curl: downloading tools and installers
# - dumb-init: PID 1 init for proper signal handling (used by /init.sh entrypoint)
# - fzf: fuzzy finder (interactive selection in Claude Code and shell)
# - git: version control
# - gosu: drop privileges to app user (Debian equivalent of Alpine's su-exec)
# - jq: JSON processing
# - python3: scripting (Claude Code uses python for ad-hoc scripts)
# - ripgrep: fast code search
# - tzdata: timezone data for container timezone configuration
# - unzip: required by Bun install script on Linux
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  dumb-init \
  fzf \
  git \
  gosu \
  jq \
  python3 \
  ripgrep \
  tzdata \
  unzip

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

# ── Copy binaries from parallel download stages ─────────────────────────────
COPY --from=go-download /usr/local/go /usr/local/go
COPY --from=docker-download /usr/local/bin/docker /usr/local/bin/docker
COPY --from=hugo-download /usr/local/bin/hugo /usr/local/bin/hugo
COPY --from=ralphex-download /usr/local/bin/ralphex /srv/ralphex
COPY --from=rtk-download /usr/local/bin/rtk /usr/local/bin/rtk

ENV GOROOT=/usr/local/go \
    GOPATH=/home/app/go
ENV PATH="${PATH}:${GOROOT}/bin:${GOPATH}/bin"

# ── Entrypoint and init scripts ──────────────────────────────────────────────
# /init.sh — entrypoint handling APP_UID remapping and privilege drop
#   Adapted from: https://github.com/umputun/baseimage/blob/master/base.alpine/files/init.sh
# /srv/init.sh — credential copier run before main command
#   Source: https://github.com/umputun/ralphex/blob/master/scripts/internal/init-docker.sh
COPY init.sh /init.sh
COPY init-docker.sh /srv/init.sh
RUN chmod +x /init.sh /srv/init.sh

WORKDIR /workspace

# ── Playwright (Chromium only — headless testing for Claude Code via ralphex) ─
# Only Chromium headless shell is needed; Firefox/WebKit skipped.
#   1. System deps (install-deps) — heavy, needs root
#   2. Browser binary (install --only-shell chromium) — Chromium headless shell only
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    npx -y playwright@${PLAYWRIGHT_VERSION} install-deps chromium
USER app
RUN npx -y playwright@${PLAYWRIGHT_VERSION} install --only-shell chromium
USER root

# ── Claude Code CLI ──────────────────────────────────────────────────────────
# npm install (not native installer) to avoid rate-limiting in parallel Docker builds.
# See: claude-code/.devcontainer/Dockerfile for rationale.
RUN --mount=type=cache,target=/root/.npm \
    npm install -g @anthropic-ai/claude-code

# ── Bun ──────────────────────────────────────────────────────────────────────
ENV BUN_INSTALL=/usr/local/bun
ENV PATH="$BUN_INSTALL/bin:$PATH"

# pipefail ensures curl failure is not masked by bash exit code
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}" && \
    bun --version
SHELL ["/bin/sh", "-c"]

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
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Ralphex-fe: Frontend development image with Bun, Hugo Extended, Playwright, and Claude Code on Debian" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="ralphex-fe" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"
