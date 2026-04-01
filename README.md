# Devcontainers

This repository contains Dockerfiles for custom Docker images hosted on GitHub Container Registry (ghcr.io).

## 📚 Image Documentation

### Devcontainer Images

- **[claude-code](./claude-code/README.md)** - Shared Claude Code devcontainer image (default + sandbox variants)
- **[bun](./bun/README.md)** - Bun development container
- **[claude-bun](./claude-bun/README.md)** - Claude Code development container with firewall sandbox
- **[hugo-bun](./hugo-bun/README.md)** - Hugo Extended + Bun development container
- **[hugo-bun-node](./hugo-bun-node/README.md)** - Hugo Extended + Bun + Node.js development container (Cloudflare Workers)

### Standalone Docker Images

- **[ralphex-fe](./ralphex-fe/README.md)** - Bun + Hugo Extended on ralphex base (standalone image)

## Repository Structure

Each subdirectory represents a Docker image project. Devcontainer images use the following structure:

```
image-name/
├── .devcontainer/
│   ├── Dockerfile          # Source of truth for the image
│   └── devcontainer.json   # Dev container configuration (uses "build")
└── ...
```

Standalone Docker images (like ralphex-fe) use a flat structure:

```
image-name/
├── Dockerfile              # Image definition
└── README.md               # Image documentation
```

## Available Images

### claude-code

Shared devcontainer base image for Claude Code projects. Two variants from a single multi-stage Dockerfile: **default** (full dev environment with agent-browser) and **sandbox** (network-restricted with iptables firewall). Projects consume pre-built images and control tool versions via `.mise.toml`. Rebuilds daily to pick up latest Claude Code.

**Usage in other projects:**

```jsonc
// Default variant
{
  "image": "ghcr.io/gatezh/devcontainers/claude-code:latest"
}

// Sandbox variant
{
  "image": "ghcr.io/gatezh/devcontainers/claude-code-sandbox:latest",
  "capAdd": ["NET_ADMIN", "NET_RAW"]
}
```

See the [claude-code README](./claude-code/README.md) for full setup guide.

### bun

Bun development container for modern JavaScript/TypeScript development.

**Usage in other projects:**

```json
{
  "image": "ghcr.io/<username>/devcontainers/bun:latest"
}
```

### claude-bun

Claude Code development container with Bun runtime, Claude Code CLI, and a restrictive firewall sandbox.

**Usage in other projects:**

```json
{
  "image": "ghcr.io/<username>/devcontainers/claude-bun:latest",
  "runArgs": ["--cap-add=NET_ADMIN", "--cap-add=NET_RAW"],
  "postStartCommand": "sudo /usr/local/bin/init-firewall.sh"
}
```

### hugo-bun

Hugo development container with Bun runtime.

**Usage in other projects:**

```json
{
  "image": "ghcr.io/<username>/devcontainers/hugo-bun:latest"
}
```

### hugo-bun-node

Hugo development container with Bun runtime and Node.js LTS for Cloudflare Workers support.

**Usage in other projects:**

```json
{
  "image": "ghcr.io/<username>/devcontainers/hugo-bun-node:latest"
}
```

### ralphex-fe

Standalone Docker image based on ralphex with Bun 1.3.9, Hugo Extended 0.155.3, and Chromium for modern JavaScript/TypeScript development, static site generation, and end-to-end testing.

**Usage:**

```bash
# Pull and run interactively
docker pull ghcr.io/<username>/devcontainers/ralphex-fe:latest
docker run -it --rm -v $(pwd):/workspace -w /workspace ghcr.io/<username>/devcontainers/ralphex-fe:latest

# Run Bun commands
docker run --rm -v $(pwd):/workspace -w /workspace ghcr.io/<username>/devcontainers/ralphex-fe:latest bun run index.ts

# Run Hugo commands
docker run --rm -v $(pwd):/workspace -w /workspace -p 1313:1313 ghcr.io/<username>/devcontainers/ralphex-fe:latest hugo server --bind 0.0.0.0

```

## Adding a New Image

### Devcontainer Image

1. Create a new directory with your image name (e.g., `myimage/`)
2. Add `.devcontainer/Dockerfile` with your image definition
3. Add `.devcontainer/devcontainer.json` that references the Dockerfile
4. Create a GitHub Actions workflow for the image
5. Update this README with usage instructions

### Standalone Docker Image

1. Create a new directory with your image name (e.g., `myimage/`)
2. Add `Dockerfile` directly in the directory (no `.devcontainer/` subdirectory)
3. Add `README.md` with image documentation
4. Create a GitHub Actions workflow for the image
5. Update this README with usage instructions

## Building and Publishing

Images from this repository are built and published to GitHub Container Registry. Other projects can reference these images in their `devcontainer.json` files using the `"image"` property.

## Updating Image Versions

### Via GitHub UI

Some images have automated update workflows that allow you to update dependency versions without manually editing Dockerfiles:

1. Go to **Actions** tab → Select the update workflow (e.g., "Update and Build ralphex-fe")
2. Click **Run workflow**
3. Enter new versions (e.g., Bun 1.4.0, Hugo 0.156.0)
4. Click **Run workflow** button

The workflow will:
- Update the Dockerfile with new versions
- Commit the changes to the repository
- Build and push the updated image

### Via GitHub CLI

If you have the [GitHub CLI](https://cli.github.com/) installed, you can trigger updates from your terminal:

```bash
# Update ralphex-fe image versions
gh workflow run update-and-build-ralphex-fe.yml \
  -f bun_version=1.4.0 \
  -f hugo_version=0.156.0

# Update without building (just commit to repo)
gh workflow run update-and-build-ralphex-fe.yml \
  -f bun_version=1.4.0 \
  -f hugo_version=0.156.0 \
  -f update_only=true

# Check workflow status
gh run list --workflow=update-and-build-ralphex-fe.yml

# Watch the latest run in real-time
gh run watch
```

**Install GitHub CLI:**
```bash
# macOS
brew install gh

# Authenticate (one-time setup)
gh auth login
```
