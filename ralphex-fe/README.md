# ralphex-fe

Standalone Docker image for running [ralphex](https://github.com/umputun/ralphex) via its docker-wrapper script. Bundles the full frontend development toolchain needed for ralphex-powered projects.

> **Note:** This is not a devcontainer in the VS Code Dev Container spec sense (no `devcontainer.json`). It is a standalone Docker image used as a development environment for ralphex projects.

This is a standalone image, not a devcontainer.

## Tools

| Tool | Version |
|------|---------|
| Node.js | 24 (from base image) |
| Bun | 1.4.2 |
| Hugo Extended | 0.166.0 |
| Go | for Hugo Modules |
| Python 3 | system |
| Playwright + Chromium | native Debian |
| Claude Code CLI | 2.1.276 (pinned) |
| RTK | 0.49.0 (pinned) |
| Ralphex | 1.7.0 (pinned) |
| Git, ripgrep, jq, curl | system |

All pinned versions live as `ARG`s in the Dockerfile and are kept current by Renovate — see
[Automatic Rebuilds](#automatic-rebuilds). This image has no `mise`, so its Bun and Hugo are
image-level versions rather than per-project ones; Renovate tracks them like everything else.

### MDN MCP server

The image provides Mozilla's [MDN MCP server](https://developer.mozilla.org/en-US/mcp) (web platform docs and browser compatibility data) through `managedMcpServers` in `/etc/claude-code/managed-settings.json`. Ralphex drives Claude non-interactively; a local managed settings file is read at session start, so `claude -p` runs get it too — the unattended runs where a hallucinated DOM or CSS API would otherwise land in a commit unreviewed.

It sends `X-Moz-1st-Party-Data-Opt-Out: 1`, Mozilla's documented opt-out from the query logging they do while the server is experimental. Requires Claude Code >= 2.1.259; earlier clients ignore the key.

## Usage

### Via ralphex docker-wrapper

```bash
export RALPHEX_IMAGE=ghcr.io/gatezh/devcontainers/ralphex-fe:latest
ralphex docs/plans/feature.md
```

### Direct docker run

```bash
docker run --rm \
  -e APP_UID=$(id -u) \
  -v ~/.claude:/mnt/claude:ro \
  -v $(pwd):/workspace \
  ghcr.io/gatezh/devcontainers/ralphex-fe:latest
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

## Automatic Rebuilds

The image rebuilds when one of its pinned tools — Claude Code, rtk, or ralphex — publishes a
new release: Renovate opens a version-bump PR against the `ARG`s in the Dockerfile, CI verifies
it, it auto-merges, and that merge triggers the build. No upstream release means no rebuild —
there is no longer a daily cron. Manual rebuilds run from the "Run workflow" button on
**Build ralphex-fe** in the Actions tab.

Because the version tag is derived from Bun and Hugo only, an agent-tool bump refreshes
`latest` and *overwrites* the existing `bun{VERSION}-hugo{VERSION}` tag rather than creating a
new one. Pull `latest` if you want the current agent tools.

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
