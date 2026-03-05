# ralphex-fe

A standalone Docker image based on ralphex with Bun and Hugo Extended runtimes, designed for modern JavaScript/TypeScript development and static site generation.

This is a standalone Docker image, not a devcontainer configuration. It can be used directly with `docker run` or as a base for other images.

## Features

- **Ralphex Base** - Full-featured base image with common development tools
- **Node.js** - Included from ralphex base image (version provided by base)
- **Bun 1.3.9** - Fast JavaScript runtime, bundler, and package manager
- **Hugo Extended 0.155.3** - Full-featured static site generator with extended capabilities
- **Chromium** - System browser for headless end-to-end testing
- **RTK 0.26.0** - [Rust Token Killer](https://www.rtk-ai.app/) - CLI proxy to minimize LLM token consumption
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

## Building Locally

### Simple Build

```bash
docker build -t ralphex-fe ralphex-fe/
```

### Multiplatform Build with Docker Buildx

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/<USERNAME>/ralphex-fe:0.11.0 \
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
- `{ralphex-version}` - Version-specific tag (e.g., `0.11.0`)

## Version Information

The image uses specific versions defined as build arguments in the Dockerfile:

- **Bun Version**: `1.3.9` (via `BUN_VERSION` build arg)
- **Hugo Version**: `0.155.3` (via `HUGO_VERSION` build arg)
- **Base Image**: `ghcr.io/umputun/ralphex:0.11.0` (via `RALPHEX_VERSION` build arg)

## License

This image configuration is part of the devcontainer-images repository.
