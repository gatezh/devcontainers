# claude-code

Shared devcontainer image for Claude Code development environments. Two variants from a single multi-stage Dockerfile: **default** (full dev environment) and **sandbox** (network-restricted).

Projects consume these pre-built images and control their own tool versions via `.mise.toml`.

## Image Variants

| Variant | Image | Use Case |
|---------|-------|----------|
| **default** | `ghcr.io/gatezh/devcontainer-images/claude-code:latest` | Full dev environment with agent-browser and passwordless sudo |
| **sandbox** | `ghcr.io/gatezh/devcontainer-images/claude-code-sandbox:latest` | Network-restricted environment with iptables firewall packages |

## What's Included

| Layer | What | Why |
|-------|------|-----|
| OS | `node:24-trixie-slim` + system packages | Node is needed during the build (Playwright, npm globals) |
| Shell | Fish, Starship, fzf | Built-in syntax highlighting, autosuggestions, completions |
| Tools | git-delta, gh CLI, jq, nano, vim, wget, unzip, less, man-db, procps | Standard dev utilities |
| Mise | The tool manager itself (not the tools) | Projects run `mise install` at container creation for their tool versions |
| rtk, ralphex | Always-latest from GitHub Releases | Dev infrastructure (like Claude Code) — no version pinning needed in projects |
| Claude Code | npm global install | npm avoids rate limiting that affects the native installer in parallel CI builds |
| Playwright | System deps + browser binary at a pinned version | See [Playwright version strategy](#playwright-version-strategy) |

**Default-only:** passwordless sudo, agent-browser + full Chromium

**Sandbox-only:** iptables, ipset, iproute2, dnsutils, aggregate, firewall sudo rule

## Multi-platform Support

Both variants are built for:
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM64/Apple Silicon)

## Image Tags

- `:latest` — most recent build
- `:<git-sha>` — pinned to a specific commit
- `:<YYYYMMDD>` — date-based tag (e.g., `20260319`)

## Automatic Rebuilds

The image rebuilds daily at 5am MT (11:00 UTC) using native runners for both amd64 and arm64 (no QEMU emulation). Each rebuild picks up the latest Claude Code and agent-browser. Manual rebuilds can be triggered via the "Run workflow" button in the Actions UI.

## Quick Start

### Default variant

Copy the example files into your project's `.devcontainer/` directory and customize as needed. Docker Compose with `pull_policy: always` ensures "Rebuild Without Cache" always pulls the latest image. All other config stays in `devcontainer.json` using cross-orchestrator properties (`mounts`, `containerEnv`, `capAdd`, `init`) so you keep devcontainer variable substitution (`${localWorkspaceFolderBasename}`, `${localEnv:...}`).

**After copying:** replace `myproject` with your project name in `docker-compose.yml` (the `name:` field) and `devcontainer.json` (volume mount prefixes). This must match across both variants if using the sandbox.

Copy these to your project's `.devcontainer/`:

- [`.devcontainer/docker-compose.yml`](.devcontainer/docker-compose.yml) — image reference with `pull_policy: always`
- [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) — full config with VS Code extensions, Claude Dark theme, fish shell, OXC formatter, node_modules volume isolation, and lifecycle commands

**Key settings included:** Claude Dark theme with coral remote indicator, fish + bash terminal profiles, OXC formatter (with comments for switching to Biome/Prettier), node_modules/Claude config/fish history volume mounts, and `updateContentCommand` for mise/bun/Playwright setup.

### Sandbox variant

Copy these to your project's `.devcontainer/claude-sandbox/`:

- [`.devcontainer/claude-sandbox/docker-compose.yml`](.devcontainer/claude-sandbox/docker-compose.yml) — sandbox image reference
- [`.devcontainer/claude-sandbox/devcontainer.json`](.devcontainer/claude-sandbox/devcontainer.json) — full config with `NET_ADMIN`/`NET_RAW` capabilities, Claude Dark theme, `claudeCode.allowDangerouslySkipPermissions`, node_modules volume isolation, firewall script bind mount, and `CLAUDE_CODE_OAUTH_TOKEN` injection

**Sandbox differences from default:** `capAdd` for iptables, `postStartCommand` runs the firewall script, `claudeCode.allowDangerouslySkipPermissions` enabled, and OAuth token must be injected from the host (see [Sandbox Authentication](#sandbox-authentication)).

**Shared volumes:** Both variants use `${localWorkspaceFolderBasename}` in volume names, so they share node_modules, Claude config, and fish history. Install packages in one variant and both benefit. Docker named volumes support multi-container access, so both can run simultaneously — just avoid running `bun install` in both at the same time.

## Project Setup Guide

Projects consuming these images need the following files in their repository.

### Required: `.mise.toml` (project root)

Only pin tools that affect project stability — dev infrastructure (rtk, ralphex, Claude Code) is pre-installed in the image at latest. See [`mise.toml`](mise.toml) for a template.

### Optional: `.devcontainer/init-plugins.sh`

Claude Code plugin initialization. Runs once at container creation. Idempotent. See [`.devcontainer/init-plugins.sh`](.devcontainer/init-plugins.sh) for a template.

Wire it into `postCreateCommand` in your `devcontainer.json`:

```jsonc
"postCreateCommand": "bash .devcontainer/init-plugins.sh"
```

Mark as executable: `chmod +x init-plugins.sh`

### Sandbox-only: `.devcontainer/claude-sandbox/init-firewall.sh`

Default-deny iptables firewall. The image provides the packages and sudo rule; the project provides this script via bind mount. Customize the domain allowlist for your project.

See the [repo's own sandbox firewall script](../.devcontainer/claude-sandbox/init-firewall.sh) for a complete example. The script should: preserve Docker internal DNS rules, allow DNS/SSH/localhost, fetch GitHub IP ranges via `curl -s https://api.github.com/meta`, resolve additional allowed domains (npm, Anthropic API, VS Code marketplace, etc.) via `dig`, set default DROP policies, allow established connections and the ipset allowlist, then verify by confirming `example.com` is blocked and `api.github.com` is reachable.

Mark as executable and ensure git tracks the executable bit:

```bash
chmod +x .devcontainer/claude-sandbox/init-firewall.sh
git add .devcontainer/claude-sandbox/init-firewall.sh   # ensures git tracks +x (100755)
```

> **Troubleshooting (macOS):** If the firewall script fails with "command not found" despite correct permissions (`stat` shows `rwxr-xr-x`, git shows `100755`), stale Docker Desktop metadata may be overriding the file mode. Fix by removing the cached extended attribute:
>
> ```bash
> xattr -d com.docker.grpcfuse.ownership .devcontainer/claude-sandbox/init-firewall.sh
> ```

### Sandbox-only: Claude Code skill for fetching docs

The sandbox firewall blocks vendor doc sites, so Claude Code can't `WebFetch` or `WebSearch` as it normally would. The image includes a [sandbox-fetch-docs](.claude/skills/sandbox-fetch-docs/SKILL.md) skill that teaches Claude Code how to look up library documentation using only allowed network paths (node_modules, raw.githubusercontent.com, GitHub Contents API, npm registry).

Copy `.claude/skills/sandbox-fetch-docs/` into your project's `.claude/skills/` directory so Claude Code picks it up automatically.

### Sandbox Authentication

The sandbox firewall blocks outbound traffic, so `claude login` (which opens a browser OAuth flow) won't work inside the container. Instead, generate a token on the host and inject it via environment variable.

**Setup (one-time):**

1. Generate a setup token on your host machine:
   ```bash
   claude setup-token
   ```
   This outputs a token string.

2. Set it as a host environment variable (add to `~/.zshrc`, `~/.bashrc`, or equivalent):
   ```bash
   export CLAUDE_CODE_OAUTH_TOKEN="your-token-here"
   ```

3. Restart VS Code (or reload window) so it picks up the new env var.

The sandbox `devcontainer.json` already injects this via `${localEnv:CLAUDE_CODE_OAUTH_TOKEN}`. Claude Code reads the env var automatically — no additional configuration inside the container.

**Alternative — per-project `.env.local` file:**

If you prefer file-based configuration over host env vars, add `env_file` to the sandbox `docker-compose.yml` and remove `CLAUDE_CODE_OAUTH_TOKEN` from `containerEnv` in `devcontainer.json`:

```yaml
services:
  devcontainer:
    env_file:
      - .env.local
```

Create `.env.local` from the template (git-ignored):
```bash
cp .devcontainer/claude-sandbox/.env.example .devcontainer/claude-sandbox/.env.local
# Edit .env.local with your actual token
```

The `.env.example` template to check into your project:
```bash
# .devcontainer/claude-sandbox/.env.example
# Claude Code authentication for sandbox containers.
# Copy to .env.local and fill in your token:
#   cp .env.example .env.local
# Generate a token with: claude setup-token
CLAUDE_CODE_OAUTH_TOKEN=your-token-here
```

Add `.env.local` to `.gitignore`. Note: Docker Compose fails to start if `.env.local` doesn't exist when using `env_file` (set `required: false` in compose to make it optional).

### Recommended additional extensions

The template includes core extensions (Claude Code, Bun, OXC, Tailwind, YAML, Docker, Markdown Preview). These are commonly added by consumer projects:

| Extension | Purpose |
|-----------|---------|
| `streetsidesoftware.code-spell-checker` | Catch typos |
| `christian-kohler.npm-intellisense` | Autocomplete npm imports |
| `mattpocock.ts-error-translator` | Human-readable TS errors |
| `eamodio.gitlens` | Git blame, history, annotations |
| `ms-playwright.playwright` | Playwright test runner |

### Complete file structure

```
.devcontainer/
├── devcontainer.json              ← default devcontainer
├── docker-compose.yml             ← default compose (image + pull_policy)
├── init-plugins.sh                ← Claude Code plugin setup (optional)
└── claude-sandbox/
    ├── devcontainer.json          ← sandbox devcontainer
    ├── docker-compose.yml         ← sandbox compose (image + pull_policy)
    ├── init-firewall.sh           ← firewall script (customize domain allowlist)
    ├── .env.example               ← template for auth token (checked in)
    └── .env.local                 ← actual auth token (gitignored)
.claude/
├── settings.json                  ← permission allowlists for common dev commands
└── skills/
    └── sandbox-fetch-docs/
        └── SKILL.md               ← teaches Claude Code to fetch docs within sandbox firewall
```

## Workspace Directory Layout

The image pre-creates a common monorepo directory structure with `node:node` ownership so Docker's volume population seeds fresh named volumes with correct permissions:

```
/workspace/
├── node_modules/
├── services/
│   ├── api/node_modules/
│   ├── app/node_modules/
│   └── www/node_modules/
└── packages/
    ├── shared/node_modules/
    └── database/node_modules/
```

The template only mounts root `node_modules` by default. For monorepo projects, uncomment and customize the additional volume mounts in `devcontainer.json` to match your structure. The pre-created directories ensure correct ownership when you add mounts.

The `sudo find` in `updateContentCommand` chowns all `node_modules` directories in one pass, so additional mounts are handled automatically.

## Playwright Version Strategy

The image uses a two-layer strategy so that any project can use any `@playwright/test` version:

| Layer | What | Baked in image? | Version-sensitive? |
|-------|------|-----------------|--------------------|
| System deps (`install-deps`) | OS libraries (libgbm, libnss3, …) | Yes (needs root) | Stable across nearby versions |
| Browser binary (`install --only-shell`) | Headless Chromium shell | Yes, as cache | Exact match required |

**Prerequisite:** Your project must have `@playwright/test` in `devDependencies`. Without it, `npx` will prompt interactively to download the `playwright` package, which hangs container creation (no TTY). Pin it to the image's baked version (check `$PLAYWRIGHT_VERSION`) or your preferred version:

```bash
bun add -d @playwright/test    # or: npm install -D @playwright/test
```

**One-time project setup** — add this to your container creation command (`updateContentCommand` or `postCreateCommand`, as shown in [Quick Start](#quick-start)):

```bash
npx playwright install --only-shell
```

This is **idempotent** — if the cached binary already matches, it's a no-op (~0s). If the project's `@playwright/test` version differs from the image, it downloads the correct binary (~10s, once at container creation).

The baked version is available at runtime via the `PLAYWRIGHT_VERSION` environment variable.

## Build Args

| Arg | Default | Description |
|-----|---------|-------------|
| `GIT_DELTA_VERSION` | `0.18.2` | git-delta version |
| `PLAYWRIGHT_VERSION` | `1.58.2` | Playwright browser binary version |
| `AGENT_BROWSER_VERSION` | `latest` | agent-browser version (default target only) |

## Building Locally / Local Fallback

If the pre-built image is unavailable (GHCR outage, rate limits, or you need to test image changes), build from the [devcontainer-images](https://github.com/gatezh/devcontainer-images) source:

```bash
# Clone the image source (one-time)
git clone https://github.com/gatezh/devcontainer-images.git
cd devcontainer-images/claude-code

# Default variant
docker build --target default -t claude-code:local .devcontainer

# Sandbox variant
docker build --target sandbox -t claude-code-sandbox:local .devcontainer
```

Then update your project's `docker-compose.yml` to use the local tag:

```yaml
services:
  devcontainer:
    # Replace the GHCR reference:
    # image: ghcr.io/gatezh/devcontainer-images/claude-code:latest
    # With the local build:
    image: claude-code:local
    # pull_policy no longer needed for local images
```

Everything else in `devcontainer.json` (mounts, containerEnv, lifecycle commands, etc.) stays the same — the local image is identical to the pre-built one.

### Extending the image for project-specific needs

If you need to layer project-specific tools on top, create a thin Dockerfile and update your compose file to build it:

```dockerfile
# .devcontainer/Dockerfile
FROM ghcr.io/gatezh/devcontainer-images/claude-code:latest
# Project-specific additions
RUN npm install -g your-tool
```

```yaml
# .devcontainer/docker-compose.yml — replace `image` with `build`
services:
  devcontainer:
    build:
      context: .
      dockerfile: Dockerfile
    # ... rest stays the same (workspace volume, etc.)
```

This pulls the pre-built image as a base layer (cached after first pull) and adds your customizations on top.

### Multi-platform build (maintainers)

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target default \
  -t ghcr.io/gatezh/devcontainer-images/claude-code:latest \
  --push \
  claude-code/.devcontainer
```

## Startup Timeline

### Warm start (Playwright version matches image)
```
Pull image ──────────────────────── (cached)
mise install (bun, hugo, etc.) ──── (~15s, downloads pre-built binaries)
bun install ─────────────────────── (~15s, cached in named volume)
playwright install --only-shell ─── (~0s, binary already cached — no-op)
project setup ───────────────────── (db:migrate, init-plugins, etc.)
                                     Total: ~45s warm
```

### Playwright version mismatch
```
Pull image ──────────────────────── (cached)
mise install (bun, hugo, etc.) ──── (~15s)
bun install ─────────────────────── (~15s)
playwright install --only-shell ─── (~10s, downloads correct browser binary)
project setup ───────────────────── (db:migrate, init-plugins, etc.)
                                     Total: ~55s warm
```

## Resources

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Mise Documentation](https://mise.jdx.dev/)
- [Docker Volume Population](https://docs.docker.com/engine/storage/volumes/#populate-a-volume-using-a-container)
