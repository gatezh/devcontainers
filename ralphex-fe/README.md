# ralphex-fe

Standalone Docker image for running [ralphex](https://github.com/umputun/ralphex) via its docker-wrapper script. Bundles the full frontend development toolchain needed for ralphex-powered projects.

This is a standalone image, not a devcontainer.

## Tools

| Tool | Version |
|------|---------|
| Node.js | 24 (from base image) |
| Bun | 1.3.9 |
| Hugo Extended | 0.156.0 |
| Go | for Hugo Modules |
| Python 3 | system |
| Playwright + Chromium | native Debian |
| Claude Code CLI | latest |
| Ralphex | latest (GitHub Releases) |
| Git, ripgrep, jq, curl, wget | system |

## Usage

### Via ralphex docker-wrapper

```bash
export RALPHEX_IMAGE=ghcr.io/gatezh/ralphex-fe:latest
ralphex docs/plans/feature.md
```

### Direct docker run

```bash
docker run --rm \
  -e APP_UID=$(id -u) \
  -v ~/.claude:/mnt/claude:ro \
  -v $(pwd):/workspace \
  ghcr.io/gatezh/ralphex-fe:latest
```

## Building Locally

```bash
docker build -t ralphex-fe:test ralphex-fe/
```

## Runtime Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_UID` | `1001` | Container user UID, remapped at startup to match host user |
| `DOCKER_GID` | `999` | Docker group GID for Docker socket access |
| `TIME_ZONE` | `America/Chicago` | Container timezone |
| `SKIP_HOME_CHOWN` | unset | Set to `1` to skip chown of `/home/app` at startup |
| `INIT_QUIET` | unset | Set to `1` to suppress `init.sh` log output |

## Image Tags

- `latest` — always included
- `bun{VERSION}-hugo{VERSION}` — version-specific tag (e.g., `bun1.3.9-hugo0.156.0`)

Note: this image deviates from the standalone convention of a single primary version tag because it bundles multiple independently-versioned tools.

## Architecture / Provenance

| File / Pattern | Source |
|----------------|--------|
| `files/init.sh` | Adapted from [umputun/baseimage](https://github.com/umputun/baseimage/blob/master/base.alpine/files/init.sh) for Debian (gosu instead of su-exec, groupadd/groupdel instead of addgroup/delgroup) |
| `files/init-docker.sh` | From [umputun/ralphex](https://github.com/umputun/ralphex/blob/master/scripts/internal/init-docker.sh) (credential copying from mounted volumes) |
| Ralphex binary install | Pattern from `claude-code/.devcontainer/Dockerfile` |
| Playwright install | Pattern from `claude-code/.devcontainer/Dockerfile` |
| Hugo Extended install | Kept from previous `ralphex-fe/Dockerfile` |

## Why Debian (not Alpine)

This image migrated from Alpine to Debian because:

- Hugo Extended works natively — no `gcompat` shim needed
- Playwright's bundled Chromium works out of the box — no `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD` workaround required
- Larger package ecosystem via `apt`
