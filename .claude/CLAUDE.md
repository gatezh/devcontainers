# Project Overview

Dockerfiles for custom devcontainer images on GitHub Container Registry (ghcr.io). Each image provides a development container for a specific environment. Published under `ghcr.io/gatezh/devcontainers/`.

## Platform Constraints

- **GitHub Actions runners**: Ubuntu Linux — use GNU coreutils, NOT macOS/BSD syntax
  - `sed -i "pattern" file` (GNU), NOT `sed -i.bak "pattern" file` (BSD)
  - Use `|` as sed delimiter: `sed -i "s|^ARG FOO=.*|ARG FOO=$NEW_VERSION|"` — safe with version strings containing `/`
- **Docker builds**: Multi-platform (`linux/amd64`, `linux/arm64`) — use `TARGETARCH` for arch-specific logic
- **Base images**: Check Alpine vs Debian (`apk` vs `apt`, musl vs glibc)

## Naming Conventions

### Directory names
- Named after the primary tool(s): `{tool}` or `{tool}-{secondary}` (e.g., `bun`, `hugo-bun`, `claude-code`)
- No `devcontainer-` prefix — the repo name `devcontainers` provides that context

### Image paths
- All images: `ghcr.io/gatezh/devcontainers/{directory-name}` (e.g., `ghcr.io/gatezh/devcontainers/bun`)

### Version ARGs in Dockerfile
- Place at top of file: `ARG {TOOL}_VERSION={version}`

### Image tags
- Always include `latest`
- Devcontainer: `{tool}{version}-{variant}` (e.g., `bun1.3.5-alpine`)
- Standalone: `{primary-version}` only (e.g., `0.11.0`)
- Multi-tool images: `{tool1}{version}-{tool2}{version}` (e.g., `bun1.3.9-hugo0.156.0`)

## Where Documentation Goes

**If a document goes stale when this repo's code changes, it belongs in the repo. If it goes stale when an external system changes — Docker Desktop, GitHub settings, an upstream tool — or it spans several images, it belongs in the [wiki](https://github.com/gatezh/devcontainers/wiki).**

| In the repo | |
|---|---|
| Per-image `README.md` | A tag list or tool table must change in the same commit as its Dockerfile |
| `.claude/CLAUDE.md`, `.claude/rules/*` | Conventions enforced in review |
| `.github/workflows/README.md` | Describes the workflows beside it |
| `docs/plans/`, `docs/superpowers/` | Planning and design artifacts |

| In the wiki | |
|---|---|
| Cross-image guides | Belong to no single image |
| Host / Docker Desktop procedures | Track Docker, not this repo |
| GitHub settings runbooks | Configuration that can't be reviewed in a PR |
| Incident writeups | Operational history, not code |

Never duplicate: wiki pages link to READMEs, READMEs link back. Every wiki page ends with a `## Sources` section citing the PRs/issues it came from and a `*Last verified:*` date.

## Code Style

- 2-space indentation in JSON/YAML
- Use comments in devcontainer.json (JSONC format)
- Dockerfile instruction order: ARG → FROM → packages → user/permissions → tools → LABEL
- For images with multiple binary downloads, use multi-stage parallel builds (see `ralphex-fe/Dockerfile`)
- Commit every `.sh` file as `100755` (they all have a shebang); check with `git ls-files -s '*.sh'`
- README headings are plain text, no emoji. Per-image READMEs use these shared section names, in this order, wherever the section exists: `Features` → `Multi-platform Support` → `Image Tags` → `Usage` → image-specific sections → `Build Args` → `Building the Image` → `Resources` → `License` → `Contributing`. Shared boilerplate (platform list, buildx block) is worded identically; only each image's tag scheme and paths differ.

## Validation

- **Before committing**, check which CI workflows in `.github/workflows/` will run against the changed files and run those checks locally first (e.g., Hadolint for Dockerfiles, linters for YAML/JS, etc.)
- Validate YAML and Dockerfile syntax before committing
- Verify on target platform — not just local macOS/Windows
- Check tool version availability and command syntax from official docs:
  - [GitHub Actions](https://docs.github.com/en/actions) · [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
  - [Bun](https://bun.sh/docs) · [Hugo](https://gohugo.io/documentation/) · [GitHub CLI](https://cli.github.com/manual/)
