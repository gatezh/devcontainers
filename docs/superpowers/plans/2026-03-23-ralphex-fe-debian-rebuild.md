# Ralphex-FE Debian Rebuild — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the `ralphex-fe` standalone Docker image from `node:24-trixie-slim` (Debian) instead of the Alpine-based `ghcr.io/umputun/ralphex` base image, eliminating all Alpine/musl compatibility hacks while maintaining full compatibility with the `ralphex-dk.sh` docker-wrapper script.

**Architecture:** A single-stage Dockerfile based on `node:24-trixie-slim` that creates an `app` user (matching the ralphex wrapper's expectations), installs all tools natively on Debian, and ships an init.sh entrypoint adapted from `umputun/baseimage` for APP_UID remapping. Two support scripts (`init.sh` and `init-docker.sh`) are copied into the image.

**Tech Stack:** Docker, Debian Trixie, Node.js 24, Bun, Hugo Extended, Go, Python 3, Playwright, Claude Code CLI

**Key decisions documented in this plan:**
- Why Debian over Alpine → see "Background" section
- Why `app` user, not `node` → ralphex wrapper compatibility
- Where init.sh and init-docker.sh come from → source references in each task

## Background

The previous `ralphex-fe` image extended `ghcr.io/umputun/ralphex:0.20.0` (Alpine-based). This caused friction:
- `gcompat` needed for Hugo Extended (glibc binary on musl)
- Playwright's bundled Chromium incompatible with Alpine/musl — required system Chromium + manual `executablePath` wiring
- Limited Alpine package ecosystem

The new approach uses Debian where all tools work natively. The `claude-code` devcontainer image (`claude-code/.devcontainer/Dockerfile`) in this repo served as reference for Debian-based tool installation patterns (git-delta, Playwright, Claude Code via npm, ralphex binary download).

## Source References

Scripts and patterns in this image are adapted from external sources. Document these so future maintainers know where to look for upstream changes:

| File | Source | Notes |
|---|---|---|
| `ralphex-fe/files/init.sh` | [`umputun/baseimage` — `base.alpine/files/init.sh`](https://github.com/umputun/baseimage/blob/master/base.alpine/files/init.sh) | Adapted for Debian: `gosu` replaces `su-exec`, `dumb-init` path adjusted, Alpine-specific `addgroup`/`delgroup` replaced with Debian equivalents |
| `ralphex-fe/files/init-docker.sh` | [`umputun/ralphex` — `scripts/internal/init-docker.sh`](https://github.com/umputun/ralphex/blob/master/scripts/internal/init-docker.sh) | Copied as-is; handles credential copying from mounted volumes |
| Ralphex binary install | [`claude-code/.devcontainer/Dockerfile` lines 104-119](claude-code/.devcontainer/Dockerfile) | Pattern for downloading latest ralphex from GitHub Releases |
| Playwright install | [`claude-code/.devcontainer/Dockerfile` lines 122-134](claude-code/.devcontainer/Dockerfile) | Two-layer strategy: system deps (root) + browser binary (user) |
| Hugo Extended install | [`ralphex-fe/Dockerfile` (current)](ralphex-fe/Dockerfile) | Kept from current image: direct download with checksum verification |

## File Structure

```
ralphex-fe/
├── Dockerfile                  # Complete rewrite — Debian-based
├── files/
│   ├── init.sh                 # NEW — entrypoint (adapted from umputun/baseimage for Debian)
│   └── init-docker.sh          # NEW — credential copier (from umputun/ralphex)
└── README.md                   # Update to reflect new base and usage

.github/workflows/
└── build-ralphex-fe.yml        # Update version extraction and verify commands
```

---

### Task 1: Create entrypoint script (`init.sh`)

**Files:**
- Create: `ralphex-fe/files/init.sh`

**Source:** Adapted from [`umputun/baseimage` — `base.alpine/files/init.sh`](https://github.com/umputun/baseimage/blob/master/base.alpine/files/init.sh)

**Adaptations for Debian:**
- Shebang: `#!/usr/bin/dumb-init /bin/sh` (Alpine uses `/sbin/dinit` which is a symlink)
- `su-exec` → `gosu` (Debian equivalent)
- `addgroup`/`delgroup` → `groupadd`/`groupdel`/`usermod` (Debian uses shadow utils)
- Timezone: uses same `/usr/share/zoneinfo` copy pattern (works on Debian with `tzdata`)

- [ ] **Step 1: Create the files directory**

```bash
mkdir -p ralphex-fe/files
```

- [ ] **Step 2: Write init.sh**

Write `ralphex-fe/files/init.sh` — the entrypoint script that handles:
1. Timezone configuration
2. APP_UID remapping (sed on /etc/passwd and /etc/group)
3. DOCKER_GID remapping for Docker socket access
4. Ownership of /srv and /home/app
5. Running /srv/init.sh if it exists (credential copier)
6. Dropping to `app` user via `gosu` to execute CMD

```sh
#!/usr/bin/dumb-init /bin/sh

# Entrypoint for ralphex-fe container.
# Adapted from umputun/baseimage (base.alpine/files/init.sh) for Debian.
# Changes: gosu instead of su-exec, groupadd/groupdel instead of addgroup/delgroup,
#          dumb-init path adjusted for Debian.
# Source: https://github.com/umputun/baseimage/blob/master/base.alpine/files/init.sh

uid=$(id -u)

if [ "${uid}" -eq 0 ]; then
    [ "${INIT_QUIET}" != "1" ] && echo "init container"

    # set container's time zone
    if [ -f "/usr/share/zoneinfo/${TIME_ZONE}" ]; then
        cp "/usr/share/zoneinfo/${TIME_ZONE}" /etc/localtime
        echo "${TIME_ZONE}" >/etc/timezone
        [ "${INIT_QUIET}" != "1" ] && echo "set timezone ${TIME_ZONE} ($(date))"
    fi

    # set UID for user app
    if [ "${APP_UID}" != "1001" ]; then
        [ "${INIT_QUIET}" != "1" ] && echo "set custom APP_UID=${APP_UID}"
        sed -i "s/:1001:1001:/:${APP_UID}:${APP_UID}:/g" /etc/passwd
        sed -i "s/:1001:/:${APP_UID}:/g" /etc/group
    else
        [ "${INIT_QUIET}" != "1" ] && echo "custom APP_UID not defined, using default uid=1001"
    fi

    # set GID for docker group
    if [ "${DOCKER_GID}" != "999" ]; then
        [ "${INIT_QUIET}" != "1" ] && echo "set custom DOCKER_GID=${DOCKER_GID}"
        existing_group=$(getent group "${DOCKER_GID}" | cut -d: -f1)
        if [ -n "${existing_group}" ] && [ "${existing_group}" != "docker" ]; then
            [ "${INIT_QUIET}" != "1" ] && echo "GID ${DOCKER_GID} used by '${existing_group}', adding app to it"
            usermod -aG "${existing_group}" app || { echo "error: failed to add app to group '${existing_group}'"; exit 1; }
        else
            groupdel docker 2>/dev/null || true
            groupadd -g "${DOCKER_GID}" docker || { echo "error: failed to create docker group with GID=${DOCKER_GID}"; exit 1; }
            usermod -aG docker app || { echo "error: failed to add app to docker group"; exit 1; }
        fi
    else
        [ "${INIT_QUIET}" != "1" ] && echo "custom DOCKER_GID not defined, using default gid=999"
    fi

    chown -R app:app /srv
    if [ "${SKIP_HOME_CHOWN}" != "1" ]; then
        chown -R app:app /home/app
    fi
fi

if [ -f "/srv/init.sh" ]; then
    [ "${INIT_QUIET}" != "1" ] && echo "execute /srv/init.sh"
    chmod +x /srv/init.sh
    /srv/init.sh
    if [ "$?" -ne "0" ]; then
      echo "/srv/init.sh failed"
      exit 1
    fi
fi

[ "${INIT_QUIET}" != "1" ] && echo "execute $*"
if [ "${uid}" -eq 0 ]; then
   exec gosu app "$@"
else
   exec "$@"
fi
```

- [ ] **Step 3: Make executable**

```bash
chmod +x ralphex-fe/files/init.sh
```

- [ ] **Step 4: Commit**

```bash
git add ralphex-fe/files/init.sh
git commit -m "feat(ralphex-fe): add Debian-adapted entrypoint from umputun/baseimage"
```

---

### Task 2: Create credential copier script (`init-docker.sh`)

**Files:**
- Create: `ralphex-fe/files/init-docker.sh`

**Source:** Copied from [`umputun/ralphex` — `scripts/internal/init-docker.sh`](https://github.com/umputun/ralphex/blob/master/scripts/internal/init-docker.sh)

This script is installed as `/srv/init.sh` in the image (not to be confused with the entrypoint `/init.sh`). The entrypoint calls `/srv/init.sh` before running the main command. It copies Claude and Codex credentials from read-only mounts into the app user's home directory.

- [ ] **Step 1: Write init-docker.sh**

```sh
#!/bin/sh
# Init script for ralphex docker container.
# The entrypoint (/init.sh) runs /srv/init.sh if it exists before the main command.
#
# Source: https://github.com/umputun/ralphex/blob/master/scripts/internal/init-docker.sh
# Copied as-is from umputun/ralphex. Check upstream for updates.

# copy only essential claude files (not the entire 2GB directory)
if [ -d /mnt/claude ]; then
    mkdir -p /home/app/.claude
    # copy config files only (not cache, history, debug, todos, etc.)
    for f in .credentials.json settings.json settings.local.json CLAUDE.md format.sh; do
        [ -e "/mnt/claude/$f" ] && cp -L "/mnt/claude/$f" "/home/app/.claude/$f" 2>/dev/null || true
    done
    # copy essential directories (symlinked in dotfiles setups)
    for d in commands skills hooks agents plugins; do
        [ -d "/mnt/claude/$d" ] && cp -rL "/mnt/claude/$d" "/home/app/.claude/" 2>/dev/null || true
    done
    chown -R app:app /home/app/.claude
fi

# copy credentials extracted from macOS keychain (mounted separately)
if [ -f /mnt/claude-credentials.json ]; then
    mkdir -p /home/app/.claude
    cp /mnt/claude-credentials.json /home/app/.claude/.credentials.json
    chown -R app:app /home/app/.claude
    chmod 600 /home/app/.claude/.credentials.json
fi

# copy codex credentials if mounted
if [ -d /mnt/codex ]; then
    mkdir -p /home/app/.codex
    cp -rL /mnt/codex/* /home/app/.codex/ 2>/dev/null || true
    chown -R app:app /home/app/.codex
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x ralphex-fe/files/init-docker.sh
```

- [ ] **Step 3: Commit**

```bash
git add ralphex-fe/files/init-docker.sh
git commit -m "feat(ralphex-fe): add credential copier from umputun/ralphex"
```

---

### Task 3: Rewrite the Dockerfile

**Files:**
- Rewrite: `ralphex-fe/Dockerfile`

**References:**
- `claude-code/.devcontainer/Dockerfile` — patterns for Playwright, Claude Code, ralphex binary install
- `umputun/ralphex/Dockerfile` — what the official image ships (user, env vars, CMD)
- `umputun/baseimage/base.alpine/Dockerfile` — user creation, entrypoint setup

- [ ] **Step 1: Write the new Dockerfile**

The Dockerfile should follow this structure (in order per project conventions: ARG → FROM → packages → user/permissions → tools → LABEL):

```dockerfile
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
# - dumb-init: PID 1 init for proper signal handling (used by /init.sh entrypoint)
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
  dumb-init \
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
  && useradd -m -s /bin/sh -u ${APP_UID} ${APP_USER} \
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
    curl -fsSL "https://github.com/umputun/ralphex/releases/download/v${RALPHEX_VERSION}/ralphex_${RALPHEX_VERSION}_linux_${RALPHEX_ARCH}.tar.gz" \
      | tar -xz -C /srv ralphex; \
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

RUN curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}" && \
    bun --version

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
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images"
LABEL org.opencontainers.image.description="Ralphex-fe: Frontend development image with Bun, Hugo Extended, Playwright, and Claude Code on Debian"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="ralphex-fe"
LABEL org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"
```

- [ ] **Step 2: Verify Dockerfile syntax**

```bash
docker buildx build --check ralphex-fe/
```

- [ ] **Step 3: Commit**

```bash
git add ralphex-fe/Dockerfile
git commit -m "feat(ralphex-fe): rewrite Dockerfile from Alpine to Debian (node:24-trixie-slim)"
```

---

### Task 4: Update the GitHub Actions workflow

**Files:**
- Modify: `.github/workflows/build-ralphex-fe.yml`

Changes:
- Drop `RALPHEX_VERSION` extraction (ralphex binary is now fetched as latest at build time, not pinned via base image ARG)
- Version tag becomes `bun${BUN_VERSION}-hugo${HUGO_VERSION}`
- Update verify commands: replace Alpine-specific Chromium/Playwright checks with Debian-appropriate ones

- [ ] **Step 1: Update the workflow**

```yaml
name: Build ralphex-fe

on:
  push:
    branches:
      - master
    paths:
      - 'ralphex-fe/Dockerfile'
      - 'ralphex-fe/files/**'
  workflow_dispatch:

concurrency:
  group: build-ralphex-fe-${{ github.ref }}
  cancel-in-progress: true

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      version-tag: ${{ steps.versions.outputs.version-tag }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Extract versions from Dockerfile
        id: versions
        run: |
          DOCKERFILE="ralphex-fe/Dockerfile"

          BUN_VERSION=$(grep '^ARG BUN_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)
          HUGO_VERSION=$(grep '^ARG HUGO_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)

          if [ -z "$BUN_VERSION" ] || [ -z "$HUGO_VERSION" ]; then
            echo "Error: Failed to extract version(s) from Dockerfile"
            echo "  Bun: ${BUN_VERSION:-<empty>}"
            echo "  Hugo: ${HUGO_VERSION:-<empty>}"
            exit 1
          fi

          echo "version-tag=bun${BUN_VERSION}-hugo${HUGO_VERSION}" >> "$GITHUB_OUTPUT"

          echo "Extracted versions:"
          echo "  Bun: $BUN_VERSION"
          echo "  Hugo: $HUGO_VERSION"

  build:
    needs: prepare
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/reusable-docker-build.yml
    with:
      image-name: ralphex-fe
      context: ralphex-fe
      dockerfile: ralphex-fe/Dockerfile
      version-tag: ${{ needs.prepare.outputs.version-tag }}
      verify-command: 'bun --version && hugo version && python3 --version && go version && node --version'
      extra-verify-script: |
        test -x /srv/ralphex && echo "OK: ralphex binary at /srv/ralphex" || \
          (echo "FAIL: /srv/ralphex not found or not executable" && exit 1) && \
        test -f /init.sh && echo "OK: /init.sh entrypoint exists" || \
          (echo "FAIL: /init.sh not found" && exit 1) && \
        test -f /srv/init.sh && echo "OK: /srv/init.sh credential copier exists" || \
          (echo "FAIL: /srv/init.sh not found" && exit 1) && \
        id app && echo "OK: app user exists" || \
          (echo "FAIL: app user not found" && exit 1) && \
        test -d /home/app/.cache/ms-playwright && echo "OK: Playwright browser cache exists" || \
          (echo "FAIL: Playwright browser cache missing at /home/app/.cache/ms-playwright" && exit 1)
    secrets: inherit
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/build-ralphex-fe.yml
git commit -m "fix(ralphex-fe): update workflow for Debian-based image"
```

---

### Task 5: Update README.md

**Files:**
- Rewrite: `ralphex-fe/README.md`

Update to reflect:
- New Debian base (no longer Alpine/ralphex base)
- New tool list (Python 3, Playwright native, Go)
- ralphex wrapper usage with `RALPHEX_IMAGE`
- Source references for init scripts
- Removed: Alpine-specific Chromium/Playwright notes

- [ ] **Step 1: Write updated README**

The README should cover:
1. What the image is and what it's for (standalone image for ralphex docker-wrapper)
2. Features table with all tools
3. Usage with `RALPHEX_IMAGE` env var
4. Direct `docker run` usage
5. Building locally
6. Architecture/provenance section documenting where scripts come from
7. Runtime environment variables (`APP_UID`, `DOCKER_GID`, `TIME_ZONE`, `SKIP_HOME_CHOWN`, `INIT_QUIET`)
8. Image tags
9. Note on version tag format: `bun${VERSION}-hugo${VERSION}` (deviates from standalone convention of single primary version because this image bundles multiple tools with independent versions)

- [ ] **Step 2: Commit**

```bash
git add ralphex-fe/README.md
git commit -m "docs(ralphex-fe): update README for Debian-based image"
```

---

### Task 6: Local build test

**Files:** None (verification only)

- [ ] **Step 1: Build the image locally for current platform**

```bash
docker build -t ralphex-fe:test ralphex-fe/
```

- [ ] **Step 2: Verify all tools**

```bash
docker run --rm --entrypoint sh ralphex-fe:test -c "
  echo '=== Node ===' && node --version &&
  echo '=== Bun ===' && bun --version &&
  echo '=== Hugo ===' && hugo version &&
  echo '=== Go ===' && go version &&
  echo '=== Python ===' && python3 --version &&
  echo '=== Ralphex ===' && /srv/ralphex --version &&
  echo '=== Claude ===' && claude --version &&
  echo '=== Git ===' && git --version &&
  echo '=== Playwright ===' && npx playwright --version &&
  echo '=== App user ===' && id app
"
```

- [ ] **Step 3: Verify entrypoint works with APP_UID remapping**

```bash
docker run --rm -e APP_UID=$(id -u) ralphex-fe:test whoami
# Expected: "app" (init.sh remaps UID then drops to app user via gosu)
```

- [ ] **Step 4: Verify workspace mount**

```bash
docker run --rm -v $(pwd):/workspace -w /workspace ralphex-fe:test ls -la
# Expected: files from current directory, owned by app user's UID
```
