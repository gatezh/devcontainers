# AI Agent Instructions

This document defines patterns, conventions, and guidelines for AI agents working with this repository.

## Repository Overview

This repository contains Dockerfiles for custom devcontainer images hosted on GitHub Container Registry (ghcr.io). Each image is designed for VS Code Dev Containers with specific development environments.

## AI Agent Best Practices

### Always Verify with Official Documentation

When implementing features or making changes, **ALWAYS** check the latest official documentation:

- **GitHub Actions**: https://docs.github.com/en/actions
  - Runs on Ubuntu (GNU/Linux) - use GNU coreutils syntax, NOT macOS/BSD syntax
  - Example: `sed -i "pattern" file` (GNU) NOT `sed -i.bak "pattern" file` (BSD)
  - When substituting version strings with `sed`, use `|` as delimiter instead of `/`:
    - Correct: `sed -i "s|^ARG FOO=.*|ARG FOO=$NEW_VERSION|"` — safe with any version string
    - Incorrect: `sed -i "s/^ARG FOO=.*/ARG FOO=$NEW_VERSION/"` — breaks if version contains `/`
  - Check platform-specific tool behavior (sed, grep, awk, etc.)
  - Verify workflow syntax with official examples

- **Docker/Dockerfile**: https://docs.docker.com/reference/dockerfile/
  - Multi-platform builds use `TARGETARCH` (amd64, arm64)
  - Verify base image availability and compatibility

- **Tools and Dependencies**:
  - Bun: https://bun.sh/docs
  - Hugo: https://gohugo.io/documentation/
  - GitHub CLI: https://cli.github.com/manual/
  - Always verify command syntax from official docs, not assumptions

### Platform Awareness

- **GitHub Actions runners**: Ubuntu Linux (use GNU tools)
- **Docker builds**: Multi-platform (linux/amd64, linux/arm64)
- **Base images**: Check Alpine vs Debian (apk vs apt, musl vs glibc)
- **Scripts**: Test for portability (sh vs bash, GNU vs BSD tools)

### Validation Before Committing

- YAML syntax validation for workflows
- Dockerfile syntax validation
- Test on target platform (not just local macOS/Windows)
- Verify assumptions about available tools and their versions

## Directory Structure

```
repository-root/
├── AGENTS.md                    # AI agent instructions (this file)
├── CLAUDE.md                    # Symlink to AGENTS.md
├── README.md                    # Repository documentation
├── .github/
│   └── workflows/
│       ├── README.md            # Workflow documentation
│       └── build-*.yml          # GitHub Actions workflows
├── devcontainer-{name}/         # Devcontainer images (VS Code integration)
│   ├── README.md                # Image-specific documentation
│   └── .devcontainer/
│       ├── Dockerfile           # Image definition (source of truth)
│       ├── devcontainer.json    # VS Code devcontainer configuration
│       └── *.sh                 # Optional scripts (e.g., init-firewall.sh)
└── {standalone-name}/           # Standalone Docker images (no devcontainer)
    ├── Dockerfile               # Image definition
    └── README.md                # Image documentation
```

## Naming Conventions

### Image Names
- Devcontainer format: `devcontainer-{primary-tool}` or `devcontainer-{primary-tool}-{secondary-tool}`
- Standalone format: `{base}-{variant}` (e.g., `ralphex-fe`)
- Examples: `devcontainer-bun`, `devcontainer-hugo-bun`, `devcontainer-claude-bun`, `ralphex-fe`

### Version ARGs in Dockerfile
- Place at the top of Dockerfile
- Format: `ARG {TOOL}_VERSION={version}`
- Examples:
  ```dockerfile
  ARG BUN_VERSION=1.3.5
  ARG HUGO_VERSION=0.152.2
  ARG CLAUDE_CODE_VERSION=latest
  ```

### Image Tags
- Always include `latest` tag
- Devcontainer version-specific tag format: `{tool}{version}-{variant}`
  - Examples: `ghcr.io/owner/devcontainer-bun:bun1.3.5-alpine`, `ghcr.io/owner/devcontainer-claude-bun:bun1.3.5-slim`
- Standalone image version-specific tag format: `{primary-version}` (primary tool version only)
  - Example: `ghcr.io/owner/ralphex-fe:0.11.0` (ralphex version only; Bun/Hugo versions in README)

## Dockerfile Patterns

### Required OCI Labels
All Dockerfiles must include these labels at the end:

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/{owner}/devcontainer-images"
LABEL org.opencontainers.image.description="{Brief description}"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="{image-name}"
LABEL org.opencontainers.image.url="https://github.com/{owner}/devcontainer-images"
```

### Base Images
- Prefer official images from Docker Hub
- Use slim/alpine variants when possible
- Bun: `oven/bun:{version}-alpine` or `oven/bun:{version}-slim`
- Node: `node:{version}` or `node:{version}-slim`

### Common Packages
Minimal images should include:
- `ca-certificates` - HTTPS connections
- `git` - Version control
- `zsh` - Better shell for VS Code integration

### Alpine Playwright Support

When adding Playwright to an Alpine/musl-based image, do NOT use `playwright install` — the bundled Chromium binary requires glibc and is incompatible with Alpine's musl libc.

Instead:
1. Install system Chromium via apk: `apk add --no-cache chromium ttf-freefont`
2. Set env vars in the Dockerfile (combine into one `ENV` instruction to minimize layers):
   ```dockerfile
   ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
       PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser
   ```
3. In the project's `playwright.config.ts`, wire up `executablePath` manually:
   ```typescript
   launchOptions: {
     executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
     args: ['--no-sandbox', '--disable-setuid-sandbox'],
   }
   ```
4. Projects install only `@playwright/test` (e.g., `bun add -d @playwright/test`) — never `playwright install`.
5. `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` is a project-level convention; Playwright does NOT read it automatically.

## devcontainer.json Patterns

### File Header
```jsonc
// For format details, see https://aka.ms/devcontainer.json. For config options, see the
// README at: {relevant-reference-url}
```

### node_modules Mount
Always include to keep node_modules out of host machine:
```jsonc
"mounts": [
  // Keep node_modules out of a host machine
  "source=${localWorkspaceFolderBasename}-node_modules,target=${containerWorkspaceFolder}/node_modules,type=volume"
]
```

### VS Code Extensions
- Group extensions by category with header comments
- Include description comment for each extension
- Format:
```jsonc
"extensions": [
  // **Category Name**
  // Extension Description
  "publisher.extension-id",

  // **Another Category**
  // Another Extension Description
  "another.extension"
]
```

### Common Extension Categories
- `**Claude Code**` - AI assistant
- `**Bun**` - Bun runtime support
- `**Code Quality**` - Biome (formatter and linter)
- `**Git**` - GitLens
- `**Tailwind**` - Tailwind CSS tooling
- `**Hugo**` - Hugo static site generator (when applicable)

### Required VS Code Settings
```jsonc
"settings": {
  "terminal.integrated.defaultProfile.linux": "zsh",
  // Suppress extension recommendation prompts
  "extensions.ignoreRecommendations": true
}
```

## GitHub Actions Workflow Patterns

### Trigger Configuration

For devcontainer images:
```yaml
on:
  push:
    branches:
      - master
    paths:
      - '{image-name}/.devcontainer/Dockerfile'
      - '{image-name}/.devcontainer/*.sh'  # If scripts exist
  workflow_dispatch:
```

For standalone images:
```yaml
on:
  push:
    branches:
      - master
    paths:
      - '{image-name}/Dockerfile'
  workflow_dispatch:
```

### Version Extraction
Extract versions from Dockerfile ARGs:
```yaml
- name: Extract versions from Dockerfile
  id: versions
  run: |
    DOCKERFILE="{image-name}/.devcontainer/Dockerfile"
    VERSION=$(grep '^ARG {TOOL}_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)
    echo "{tool}=$VERSION" >> $GITHUB_OUTPUT
```

### Multi-platform Build
Always build for both architectures:
```yaml
platforms: linux/amd64,linux/arm64
```

### Caching
Use GitHub Actions cache:
```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

## README Patterns

### Image README Structure
1. Title and brief description
2. Features list
3. Quick Start (pre-built image usage)
4. Building locally instructions
5. Configuration details
6. Image tags
7. Customization options
8. Resources/links

### Main README Structure
1. Repository overview
2. Image documentation links
3. Repository structure
4. Available images with usage examples
5. Adding a new image guide
6. Building and publishing info

## When Adding a New Image

### Devcontainer Image
1. Create directory: `devcontainer-{name}/`
2. Add `.devcontainer/Dockerfile` following patterns above
3. Add `.devcontainer/devcontainer.json` following patterns above
4. Add `README.md` with image documentation
5. Create `.github/workflows/build-devcontainer-{name}.yml`
6. Update main `README.md` with new image entry

### Standalone Docker Image
1. Create directory: `{image-name}/`
2. Add `Dockerfile` directly in the directory (no `.devcontainer/` subdirectory)
3. Add `README.md` with image documentation
4. Create `.github/workflows/build-{image-name}.yml`
5. Update main `README.md` with new image entry

## Code Style

- Use 2-space indentation in JSON/YAML files
- Use comments liberally in devcontainer.json (JSONC)
- Keep Dockerfile instructions organized logically:
  1. ARG declarations
  2. FROM statement
  3. Package installation
  4. User/permission setup
  5. Tool installation
  6. Labels (at the end)
