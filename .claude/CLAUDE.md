# Project Overview

Dockerfiles for custom devcontainer images on GitHub Container Registry (ghcr.io). Each image provides a VS Code Dev Container for a specific development environment.

## Platform Constraints

- **GitHub Actions runners**: Ubuntu Linux — use GNU coreutils, NOT macOS/BSD syntax
  - `sed -i "pattern" file` (GNU), NOT `sed -i.bak "pattern" file` (BSD)
  - Use `|` as sed delimiter: `sed -i "s|^ARG FOO=.*|ARG FOO=$NEW_VERSION|"` — safe with version strings containing `/`
- **Docker builds**: Multi-platform (`linux/amd64`, `linux/arm64`) — use `TARGETARCH` for arch-specific logic
- **Base images**: Check Alpine vs Debian (`apk` vs `apt`, musl vs glibc)

## Naming Conventions

### Image names
- Devcontainer: `devcontainer-{tool}` or `devcontainer-{tool}-{secondary}`
- Standalone: `{base}-{variant}` (e.g., `ralphex-fe`)

### Version ARGs in Dockerfile
- Place at top of file: `ARG {TOOL}_VERSION={version}`

### Image tags
- Always include `latest`
- Devcontainer: `{tool}{version}-{variant}` (e.g., `bun1.3.5-alpine`)
- Standalone: `{primary-version}` only (e.g., `0.11.0`)

## Code Style

- 2-space indentation in JSON/YAML
- Use comments in devcontainer.json (JSONC format)
- Dockerfile instruction order: ARG → FROM → packages → user/permissions → tools → LABEL

## Validation

- **Before committing**, check which CI workflows in `.github/workflows/` will run against the changed files and run those checks locally first (e.g., Hadolint for Dockerfiles, linters for YAML/JS, etc.)
- Validate YAML and Dockerfile syntax before committing
- Verify on target platform — not just local macOS/Windows
- Check tool version availability and command syntax from official docs:
  - [GitHub Actions](https://docs.github.com/en/actions) · [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
  - [Bun](https://bun.sh/docs) · [Hugo](https://gohugo.io/documentation/) · [GitHub CLI](https://cli.github.com/manual/)
