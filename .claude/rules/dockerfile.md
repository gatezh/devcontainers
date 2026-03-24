---
paths:
  - "**/Dockerfile"
---

# Dockerfile Conventions

## Required OCI Labels

All Dockerfiles must end with a single combined `LABEL` instruction:

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/{owner}/devcontainer-images" \
      org.opencontainers.image.description="{Brief description}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="{image-name}" \
      org.opencontainers.image.url="https://github.com/{owner}/devcontainer-images"
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

## Playwright on Debian

Use the two-layer strategy (Chromium only for headless testing):

```dockerfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    npx -y playwright@${PLAYWRIGHT_VERSION} install-deps chromium
USER app
RUN npx -y playwright@${PLAYWRIGHT_VERSION} install --only-shell chromium
USER root
```

## Alpine Playwright Support

Do NOT use `playwright install` on Alpine — the bundled Chromium requires glibc.

Instead:
1. Install system Chromium: `apk add --no-cache chromium ttf-freefont`
2. Set env vars (single `ENV` instruction to minimize layers):
   ```dockerfile
   ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
       PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser
   ```
3. In `playwright.config.ts`, wire up `executablePath`:
   ```typescript
   launchOptions: {
     executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
     args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
   }
   ```
4. Projects install only `@playwright/test` — never run `playwright install`
5. `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` is a project convention; Playwright does NOT read it automatically
