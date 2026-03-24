---
paths:
  - ".github/workflows/**"
---

# GitHub Actions Workflow Conventions

## Build Approach

Prefer `docker/github-builder` for build workflows — it builds platforms in parallel on native runners (no QEMU). See `build-ralphex-fe.yml` and `build-claude-code.yml` for examples.

The older `reusable-docker-build.yml` uses sequential QEMU-emulated builds and is kept for legacy images.

## Action Versions

Use latest stable major versions. Current:
- `actions/checkout@v6`
- `docker/setup-qemu-action@v4`
- `docker/setup-buildx-action@v4`
- `docker/login-action@v4`
- `docker/metadata-action@v6`
- `docker/build-push-action@v7`
- `dorny/paths-filter@v4`

## Triggers

Devcontainer images:

```yaml
on:
  push:
    branches: [master]
    paths:
      - '{image-name}/.devcontainer/Dockerfile'
      - '{image-name}/.devcontainer/*.sh'
  workflow_dispatch:
```

Standalone images (include support files):

```yaml
on:
  push:
    branches: [master]
    paths:
      - '{image-name}/Dockerfile'
      - '{image-name}/files/**'
  workflow_dispatch:
```

## CI (Pre-merge)

CI builds amd64 only (native) — no QEMU emulation. arm64 is tested on native runners at merge time.

## Multi-platform Build

Always build for both architectures:

```yaml
platforms: linux/amd64,linux/arm64
```

## Caching

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```
