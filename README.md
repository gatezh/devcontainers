# Devcontainers

This repository contains Dockerfiles for custom Docker images hosted on GitHub Container Registry (ghcr.io).

**New here?** The [wiki](https://github.com/gatezh/devcontainers/wiki) has a [guide to picking an image](https://github.com/gatezh/devcontainers/wiki/Choosing-an-Image) and explains [what `latest` means and when it moves](https://github.com/gatezh/devcontainers/wiki/Image-Tags-and-Rebuild-Policy).

## 📚 Image Documentation

### Devcontainer Images

- **[claude-code](./claude-code/README.md)** - Shared Claude Code devcontainer image (default + sandbox variants)
- **[bun](./bun/README.md)** - Bun development container
- **[claude-bun](./claude-bun/README.md)** - Claude Code development container with firewall sandbox
- **[hugo-bun](./hugo-bun/README.md)** - Hugo Extended + Bun development container
- **[hugo-bun-node](./hugo-bun-node/README.md)** - Hugo Extended + Bun + Node.js development container (Cloudflare Workers)

### Standalone Docker Images

- **[ralphex-fe](./ralphex-fe/README.md)** - Bun + Hugo Extended on ralphex base (standalone image)

## 📖 Guides (wiki)

Cross-image guides and host-level procedures live in the [wiki](https://github.com/gatezh/devcontainers/wiki), because they go stale when Docker or GitHub changes rather than when this repo does.

- **[Choosing an Image](https://github.com/gatezh/devcontainers/wiki/Choosing-an-Image)** - which of the six images you want
- **[Image Tags and Rebuild Policy](https://github.com/gatezh/devcontainers/wiki/Image-Tags-and-Rebuild-Policy)** - what `latest` means, which tags are immutable, when rebuilds happen
- **[Troubleshooting](https://github.com/gatezh/devcontainers/wiki/Troubleshooting)** - symptoms that span more than one image
- **[Docker Disk Maintenance](https://github.com/gatezh/devcontainers/wiki/Docker-Disk-Maintenance)** - commands for "low disk space", a hung Docker, and safe cleanup
- **[Incident: Docker Disk Exhaustion (2026-09-07)](https://github.com/gatezh/devcontainers/wiki/Incident-Docker-Disk-Exhaustion-2026-09-07)** - what actually grows, why, and the settings that prevent an outage
- **[Branch Protection and Renovate Auto-Merge](https://github.com/gatezh/devcontainers/wiki/Branch-Protection-and-Renovate-Auto-Merge)** - maintainer runbook

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

Shared devcontainer base image for Claude Code projects. Two variants from a single multi-stage Dockerfile: **default** (full dev environment with agent-browser) and **sandbox** (network-restricted with iptables firewall). Projects consume pre-built images and control tool versions via `.mise.toml`. Rebuilds when its pinned tools receive a new release (managed by Renovate), not on a schedule.

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

### Automatically, via Renovate

The agent tooling in the `claude-code` and `ralphex-fe` images — `rtk`, `ralphex`, the Claude Code
CLI, `agent-browser`, and the `gh-stack` extension — is pinned as `ARG`s carrying `# renovate:`
annotations. Renovate watches their releases and opens a single grouped bump PR when one ships; CI
verifies it, it auto-merges, and that merge rebuilds the affected images. No upstream release means no
PR and no rebuild. Scope and grouping live in [`.github/renovate.json5`](./.github/renovate.json5);
the Dependency Dashboard issue tracks what is pending. Everything else — including base images and
Bun/Hugo — stays manual.

> **Setup requirement — Mend portal toggles.** Installing the Renovate app with "All repositories"
> makes Mend default the repo to **Silent mode** (`dryRun=lookup`), where it scans and shows updates
> in the [developer portal](https://developer.mend.io/) but opens no PRs and creates no issues — not
> even the Dependency Dashboard, and not even a config-warning issue. The symptom is a correct
> config that appears to do nothing. In the portal, under *Repo Engine Settings → Dependency
> Updates*, set:
>
> | Toggle | Value |
> |--------|-------|
> | Silent mode | **off** |
> | Automated PRs | **on** |
> | Require config file | on — with an all-repositories install, this is what keeps Renovate off repos that have no config |
> | Create onboarding PRs | off — this repo already has a config, so no onboarding PR is needed |
>
> Setting `mode` in `renovate.json5` cannot substitute for the Silent-mode toggle, because `dryRun`
> takes precedence over `mode` and is admin-level.

### Manual rebuilds

Every image has a `workflow_dispatch` trigger, so a rebuild can be forced without a code change:

```bash
# Rebuild one image from current master
gh workflow run build-ralphex-fe.yml

# Check status / watch
gh run list --workflow=build-ralphex-fe.yml
gh run watch
```

To change a pinned version, edit the `ARG` in that image's Dockerfile and open a PR — the merge
triggers the build. There is no longer a workflow that rewrites Dockerfiles and pushes to `master`.

**Install GitHub CLI:**
```bash
# macOS
brew install gh

# Authenticate (one-time setup)
gh auth login
```
