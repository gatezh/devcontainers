# ralphex-fe

A standalone Docker image based on ralphex with Bun and Hugo Extended runtimes, designed for modern JavaScript/TypeScript development and static site generation.

This is a standalone Docker image, not a devcontainer configuration. It can be used directly with `docker run` or as a base for other images.

## Features

- **Ralphex Base** - Full-featured base image with common development tools
- **Node.js** - Included from ralphex base image (version provided by base)
- **Bun 1.3.9** - Fast JavaScript runtime, bundler, and package manager
- **Hugo Extended 0.155.3** - Full-featured static site generator with extended capabilities
- **Chromium** - System Chromium browser for Playwright end-to-end tests (Alpine/musl-native)
- **jq** - Lightweight JSON processor for agent workflows and scripting
- **Git** - Version control (included from base)
- **Zsh** - Modern shell (included from base)

## Multiplatform Support

This image is built for multiple architectures:
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM64/Apple Silicon)

## Usage

### Pull and Run

```bash
# Pull the latest image
docker pull ghcr.io/gatezh/ralphex-fe:latest

# Run interactively
docker run -it --rm ghcr.io/gatezh/ralphex-fe:latest

# Run with a mounted project directory
docker run -it --rm -v $(pwd):/workspace -w /workspace ghcr.io/gatezh/ralphex-fe:latest
```

### Using Bun

```bash
# Check Bun version
docker run --rm ghcr.io/gatezh/ralphex-fe:latest bun --version

# Run a script
docker run --rm -v $(pwd):/workspace -w /workspace ghcr.io/gatezh/ralphex-fe:latest bun run index.ts

# Install dependencies
docker run --rm -v $(pwd):/workspace -w /workspace ghcr.io/gatezh/ralphex-fe:latest bun install
```

### Using Hugo

```bash
# Check Hugo version
docker run --rm ghcr.io/gatezh/ralphex-fe:latest hugo version

# Start Hugo development server (with port mapping)
docker run --rm -v $(pwd):/workspace -w /workspace -p 1313:1313 ghcr.io/gatezh/ralphex-fe:latest hugo server --bind 0.0.0.0

# Build a Hugo site
docker run --rm -v $(pwd):/workspace -w /workspace ghcr.io/gatezh/ralphex-fe:latest hugo
```

### Using Playwright

Playwright is configured to use the system Chromium browser via the `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` environment variable. This avoids Playwright's built-in browser download, which requires glibc/Debian and is incompatible with Alpine's musl libc.

```bash
# Run Playwright tests (Playwright uses system Chromium automatically)
docker run --rm -v $(pwd):/workspace -w /workspace ghcr.io/gatezh/ralphex-fe:latest bun run test:e2e

# Verify Chromium is available
docker run --rm ghcr.io/gatezh/ralphex-fe:latest chromium-browser --version

# Check the Playwright env var is set
docker run --rm ghcr.io/gatezh/ralphex-fe:latest sh -c 'echo $PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH'
```

In your project's Playwright config, Chromium will be resolved automatically from `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`. No extra configuration is needed beyond installing `@playwright/test` (without running `playwright install`).

### Using jq

jq is useful for JSON processing in scripts and agent workflows:

```bash
# Parse package.json
docker run --rm -v $(pwd):/workspace -w /workspace ghcr.io/gatezh/ralphex-fe:latest jq '.version' package.json

# Check jq version
docker run --rm ghcr.io/gatezh/ralphex-fe:latest jq --version
```

## Building Locally

### Simple Build

```bash
docker build -t ralphex-fe ralphex-fe/
```

### Multiplatform Build with Docker Buildx

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/<USERNAME>/ralphex-fe:bun1.3.9-hugo0.155.3-ralphex \
  -t ghcr.io/<USERNAME>/ralphex-fe:latest \
  --push \
  ralphex-fe
```

### Building with Custom Versions

```bash
docker build \
  --build-arg BUN_VERSION=1.4.0 \
  --build-arg HUGO_VERSION=0.156.0 \
  -t ralphex-fe:custom \
  ralphex-fe/
```

**Note:** The `--push` flag requires authentication to GitHub Container Registry:
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <USERNAME> --password-stdin
```

## Image Tags

- `latest` - Most recent build
- `bun{version}-hugo{version}-ralphex` - Version-specific tag (e.g., `bun1.3.9-hugo0.155.3-ralphex`)

## Version Information

The image uses specific versions defined as build arguments in the Dockerfile:

- **Bun Version**: `1.3.9` (via `BUN_VERSION` build arg)
- **Hugo Version**: `0.155.3` (via `HUGO_VERSION` build arg)
- **Base Image**: `ghcr.io/umputun/ralphex:latest`

## License

This image configuration is part of the devcontainer-images repository.
