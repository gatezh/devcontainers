---
paths:
  - ".github/workflows/**"
---

# GitHub Actions Workflow Conventions

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

Standalone images:

```yaml
on:
  push:
    branches: [master]
    paths:
      - '{image-name}/Dockerfile'
  workflow_dispatch:
```

## Version Extraction

```yaml
- name: Extract versions from Dockerfile
  id: versions
  run: |
    DOCKERFILE="{image-name}/.devcontainer/Dockerfile"
    VERSION=$(grep '^ARG {TOOL}_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)
    echo "{tool}=$VERSION" >> $GITHUB_OUTPUT
```

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
