---
paths:
  - "**/Dockerfile"
---

# Dockerfile Conventions

## Required OCI Labels

All Dockerfiles must end with these labels:

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/{owner}/devcontainer-images"
LABEL org.opencontainers.image.description="{Brief description}"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="{image-name}"
LABEL org.opencontainers.image.url="https://github.com/{owner}/devcontainer-images"
```

## Base Images

- Prefer official Docker Hub images
- Use slim/alpine variants when possible
- Bun: `oven/bun:{version}-alpine` or `oven/bun:{version}-slim`
- Node: `node:{version}` or `node:{version}-slim`

## Common Packages

Minimal images should include: `ca-certificates`, `git`, `zsh`

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
