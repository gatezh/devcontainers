---
paths:
  - "**/Dockerfile"
---

# Dockerfile Conventions

## Required OCI Labels

All Dockerfiles must end with a single combined `LABEL` instruction:

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/{owner}/devcontainers" \
      org.opencontainers.image.description="{Brief description}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="{image-name}" \
      org.opencontainers.image.url="https://github.com/{owner}/devcontainers"
```

## Base Images

- Prefer official Docker Hub images
- Use slim/alpine variants when possible
- Bun: `oven/bun:{version}-alpine` or `oven/bun:{version}-slim`
- Node: `node:{version}` or `node:{version}-slim`

## Common Packages

Minimal images should include: `ca-certificates`, `git`

## Docker Best Practices

- **Cache mounts**: Use `--mount=type=cache` for apt and npm to persist download caches between builds:
  ```dockerfile
  RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
      --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
      apt-get update && apt-get install -y --no-install-recommends ...
  ```
- **Pipefail**: Set `SHELL ["/bin/bash", "-o", "pipefail", "-c"]` before any `curl | bash` pipes, reset with `SHELL ["/bin/sh", "-c"]` after
- **useradd**: Always use `--no-log-init` to avoid large sparse log files
- **Downloads**: Use download-then-extract (two commands) instead of `curl | tar` pipes — prevents masked failures under `/bin/sh`
- **Parallel downloads**: For images with multiple binary tool downloads, use multi-stage builds — BuildKit runs independent stages concurrently. See `ralphex-fe/Dockerfile` for the pattern.

## Playwright / Chromium in Docker

Use system Chromium instead of Playwright-managed browsers. This avoids version coupling
between `@playwright/mcp` (which uses alpha `playwright-core` builds) and cached browser binaries.

**Debian (Trixie):**
```dockerfile
# Install in the apt-get block:
chromium fonts-freefont-ttf

# Set env vars:
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium
```

**Alpine:**
```dockerfile
RUN apk add --no-cache chromium ttf-freefont

ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

Note: Binary is `chromium` on Debian Trixie, `chromium-browser` on Alpine and older Debian.

**For `@playwright/mcp`**, use `--executable-path` and `--no-sandbox` in the MCP config args.

**`PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`** is a project convention; Playwright does NOT read it automatically.
Use it in `playwright.config.ts` via `process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` if needed.
