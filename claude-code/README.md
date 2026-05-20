# claude-code

Shared devcontainer image for Claude Code development environments. Two variants from a single multi-stage Dockerfile: **default** (full dev environment) and **sandbox** (network-restricted).

Projects consume these pre-built images and control their own tool versions via `.mise.toml`.

## Image Variants

| Variant | Image | Use Case |
|---------|-------|----------|
| **default** | `ghcr.io/gatezh/devcontainers/claude-code:latest` | Full dev environment with agent-browser and passwordless sudo |
| **sandbox** | `ghcr.io/gatezh/devcontainers/claude-code-sandbox:latest` | Network-restricted environment with iptables firewall packages |

## What's Included

| Layer | What | Why |
|-------|------|-----|
| OS | `node:24-trixie-slim` + system packages | Node is needed during the build (Playwright, npm globals) |
| Shell | Fish, Starship, fzf | Built-in syntax highlighting, autosuggestions, completions |
| Tools | git-delta, gh CLI, jq, nano, vim, wget, unzip, less, man-db, procps | Standard dev utilities |
| Mise | The tool manager itself (not the tools) | Projects run `mise install` at container creation for their tool versions |
| rtk, ralphex | Always-latest from GitHub Releases | Dev infrastructure (like Claude Code) — no version pinning needed in projects |
| Claude Code | npm global install | npm avoids rate limiting that affects the native installer in parallel CI builds |

**Both targets:** system Chromium + `fonts-freefont-ttf` (used by Playwright and the Playwright MCP plugin via `/usr/bin/chromium`)

**Default-only:** passwordless sudo, agent-browser

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
- [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) — full config with VS Code extensions, fish shell, OXC formatter, node_modules volume isolation, and lifecycle commands

**Key settings included:** fish + bash terminal profiles, OXC formatter (with comments for switching to Biome/Prettier), node_modules/Claude config/fish history volume mounts, and `updateContentCommand` for mise/bun setup.

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

Claude Code plugin initialization. `init-plugins.sh` registers marketplaces, installs plugins, and invokes the image-baked `/usr/local/bin/patch-playwright-mcp` to rewrite every cached Playwright MCP `.mcp.json` to launch the system chromium. Idempotent. See [`.devcontainer/init-plugins.sh`](.devcontainer/init-plugins.sh) for the template.

Wire into `devcontainer.json`:

```jsonc
"postCreateCommand": "bash .devcontainer/init-plugins.sh",
"postStartCommand":  "/usr/local/bin/patch-playwright-mcp"
```

`postStartCommand` re-runs the patch on every container start so plugin auto-updates between sessions cannot leave MCP pointing at the missing chrome channel. See the [Playwright Strategy](#playwright-strategy) section.

Mark as executable: `chmod +x init-plugins.sh`

#### Bundled plugins

`init-plugins.sh` registers three marketplaces and installs the following plugins:

| Marketplace | Plugin | Purpose |
|---|---|---|
| `anthropics/claude-plugins-official` | `frontend-design` | Production-grade UI/UX scaffolding |
| `anthropics/claude-plugins-official` | `code-review` | Multi-agent PR review |
| `anthropics/claude-plugins-official` | `typescript-lsp` | TypeScript language-server tooling |
| `anthropics/claude-plugins-official` | `code-simplifier` | Refactors for clarity and consistency |
| `anthropics/claude-plugins-official` | `playwright` | Browser MCP (system chromium via `patch-playwright-mcp`) |
| `anthropics/claude-plugins-official` | `superpowers` | Workflow skills (TDD, debugging, planning) |
| `anthropics/claude-plugins-official` | `explanatory-output-style` | Educational output mode |
| `anthropics/claude-plugins-official` | `claude-md-management` | Audits and updates CLAUDE.md |
| `anthropics/claude-plugins-official` | `claude-code-setup` | Settings, permissions, automation helpers |
| `anthropics/claude-plugins-official` | `posthog` | PostHog product-analytics & LLM-traces skills |
| `umputun/ralphex` | `ralphex` | Autonomous plan execution |
| `GoogleChrome/modern-web-guidance` | `modern-web-guidance` | Accessible, performant, secure modern web patterns ([docs](https://developer.chrome.com/docs/modern-web-guidance)) |

To remove a plugin in your project, delete its entry from the local `init-plugins.sh` — the script is a template, not image-baked, so each consumer controls its own list.

> **Why `init-plugins.sh` stays per-project but `patch-playwright-mcp` doesn't:** `init-plugins.sh` carries project-specific configuration (marketplace list, plugin list) — it's *meant* to be edited per project. The patch script has zero project-specific config and is identical across every consumer, so it's baked into the image and flows through the same daily-rebuild + `pull_policy: always` channel as the rest of the image. That boundary is the rule: project-specific config stays per-project; universal logic moves into the image.

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

### Recommended: Claude Code skill for Playwright

Both image variants ship system chromium and the `/usr/local/bin/patch-playwright-mcp` binary, so Playwright MCP and `@playwright/test` (and `@vitest/browser-playwright`, and direct `playwright-core` calls) work out of the box once each project entry point wires `launchOptions.executablePath` — see [Playwright Strategy](#playwright-strategy) for the full per-consumer wiring matrix. The image includes a [sandbox-playwright](.claude/skills/sandbox-playwright/SKILL.md) skill that teaches Claude Code how to drive these paths — discovery-driven, with no hardcoded project ports, service names, or test layouts.

Copy `.claude/skills/sandbox-playwright/` into your project's `.claude/skills/` directory so Claude Code picks it up automatically.

### Recommended: Claude Code skill for upstream sync

To keep your project's `.devcontainer/` and bundled `.claude/skills/` in step with this repo, copy the [devcontainer-upstream-sync](.claude/skills/devcontainer-upstream-sync/SKILL.md) skill into your project's `.claude/skills/` directory. The skill audits drift, helps adopt missed changes, drafts upstream issues for shared bugs, and self-updates when this skill's `version:` bumps.

```bash
mkdir -p .claude/skills/devcontainer-upstream-sync
curl -sSL https://raw.githubusercontent.com/gatezh/devcontainers/master/claude-code/.claude/skills/devcontainer-upstream-sync/SKILL.md \
  > .claude/skills/devcontainer-upstream-sync/SKILL.md
git add .claude/skills/devcontainer-upstream-sync/SKILL.md
```

After the one-time copy, the skill manages its own updates.


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

The template includes extensions for Claude Code, Bun, OXC, Tailwind, YAML, Docker, Markdown Preview, spell checking, npm IntelliSense, TypeScript errors, CSS colors, Drizzle ORM, and Playwright. These are commonly added by consumer projects:

| Extension | Purpose |
|-----------|---------|
| `eamodio.gitlens` | Git blame, history, annotations |

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
    ├── sandbox-fetch-docs/
    │   └── SKILL.md               ← teaches Claude Code to fetch docs within sandbox firewall
    ├── sandbox-playwright/
    │   └── SKILL.md               ← teaches Claude Code to drive Playwright MCP + @playwright/test
    └── devcontainer-upstream-sync/
        └── SKILL.md               ← keeps project's .devcontainer/ + skills synced with this repo
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

## Playwright Strategy

Both image variants ship the system `chromium` package (apt-installed)
instead of Playwright-managed browser binaries. This avoids version coupling
between `@playwright/mcp` (alpha `playwright-core` builds) and cached
binaries, and keeps the image significantly smaller than shipping a
Playwright-managed Chromium per rebuild. Sandbox needs it baked in because
the firewall blocks `deb.debian.org` at runtime.

The Dockerfile sets:

```bash
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium
AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium   # default target only
```

`PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` is a project convention — Playwright
does **not** read it automatically. Every Playwright entry point in your
project must honor it. The image's job ends at "the env var points at the
binary"; consumer projects do the wiring.

| Consumer | Where to wire | What to add |
|---|---|---|
| `@playwright/mcp` | nothing (image-baked) | `/usr/local/bin/patch-playwright-mcp` rewrites every cached `.mcp.json` to use the system chromium. See [Playwright MCP plugin](#playwright-mcp-plugin) below. |
| `@playwright/test` | `playwright.config.ts` | `use.launchOptions.executablePath` |
| `@vitest/browser-playwright` (incl. `@storybook/addon-vitest`, `@vitest/browser`) | `vitest.config.ts` | `playwright({ launchOptions: { executablePath } })` |
| Direct `playwright-core` / `playwright` use in scripts | every `chromium.launch(...)` site | `chromium.launch({ executablePath })` |
| `agent-browser` (default target only) | nothing | Image sets `AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium`. Independent of the `PLAYWRIGHT_*` convention — agent-browser is a Rust CLI with its own env-var family. |

### `@playwright/test` — `playwright.config.ts`

```ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  use: {
    launchOptions: {
      executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
    },
  },
});
```

In a monorepo, repeat this in every `playwright.config.ts` (one per service
that has a Playwright suite). The same env-var value works for all.

### `@vitest/browser-playwright` — `vitest.config.ts`

The provider's options match the Playwright `LaunchOptions` interface
verbatim under the `launchOptions` key (see the `PlaywrightProviderOptions`
interface in `@vitest/browser-playwright`):

```ts
import { defineConfig, mergeConfig } from "vitest/config";
import { playwright } from "@vitest/browser-playwright";
import viteConfig from "./vite.config";

export default mergeConfig(
  viteConfig,
  defineConfig({
    test: {
      browser: {
        enabled: true,
        headless: true,
        provider: playwright({
          launchOptions: {
            executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
          },
        }),
        instances: [{ browser: "chromium" }],
      },
    },
  }),
);
```

For non-Vite projects, drop the `mergeConfig(viteConfig, …)` wrapper —
`defineConfig({ test: { browser: { … } } })` works directly.

**Symptom when this is missing:** `Executable doesn't exist at
/home/node/.cache/ms-playwright/chromium_headless_shell-<rev>/chrome-linux/headless_shell`
followed by a "Please run `npx playwright install`" message. **Don't follow
that hint** — wire `launchOptions.executablePath` instead. Running `npx
playwright install` would re-download the bundled binary the image
deliberately avoids.

### Direct `playwright-core` / `playwright` use

For CI scripts, custom E2E that doesn't use `@playwright/test`, or codegen
sites that import `chromium` directly:

```ts
import { chromium } from "playwright-core"; // or "playwright"

const browser = await chromium.launch({
  executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
  headless: true,
});
```

### Playwright MCP plugin

The `playwright@claude-plugins-official` plugin's `@playwright/mcp` defaults
to the `chrome` channel (`/opt/google/chrome/chrome`), which the image does
not ship. The image bakes in `/usr/local/bin/patch-playwright-mcp` (built
from [`patch-playwright-mcp.sh`](.devcontainer/patch-playwright-mcp.sh)),
which rewrites every cached `.mcp.json` under `~/.claude/plugins/cache/`
to use the system chromium:

```json
{
  "playwright": {
    "command": "npx",
    "args": [
      "@playwright/mcp@latest",
      "--browser", "chromium",
      "--executable-path", "/usr/bin/chromium",
      "--no-sandbox",
      "--headless"
    ]
  }
}
```

`init-plugins.sh` invokes the patch binary at `postCreateCommand`, and the
template `devcontainer.json` files run it again at `postStartCommand` so
plugin auto-updates between sessions cannot leave MCP pointing at the
missing chrome channel.

To debug, inspect the patched configs after a container start:

```bash
cat ~/.claude/plugins/cache/claude-plugins-official/playwright/*/.mcp.json
```

## Build Args

| Arg | Default | Description |
|-----|---------|-------------|
| `GIT_DELTA_VERSION` | `0.18.2` | git-delta version |
| `AGENT_BROWSER_VERSION` | `latest` | agent-browser version (default target only) |

## Building Locally / Local Fallback

If the pre-built image is unavailable (GHCR outage, rate limits, or you need to test image changes), build from the [devcontainers](https://github.com/gatezh/devcontainers) source:

```bash
# Clone the image source (one-time)
git clone https://github.com/gatezh/devcontainers.git
cd devcontainers/claude-code

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
    # image: ghcr.io/gatezh/devcontainers/claude-code:latest
    # With the local build:
    image: claude-code:local
    # pull_policy no longer needed for local images
```

Everything else in `devcontainer.json` (mounts, containerEnv, lifecycle commands, etc.) stays the same — the local image is identical to the pre-built one.

### Extending the image for project-specific needs

If you need to layer project-specific tools on top, create a thin Dockerfile and update your compose file to build it:

```dockerfile
# .devcontainer/Dockerfile
FROM ghcr.io/gatezh/devcontainers/claude-code:latest
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
  -t ghcr.io/gatezh/devcontainers/claude-code:latest \
  --push \
  claude-code/.devcontainer
```

## Startup Timeline

```
Pull image ──────────────────────── (cached)
mise install (bun, hugo, etc.) ──── (~15s, downloads pre-built binaries)
bun install ─────────────────────── (~15s, cached in named volume)
project setup ───────────────────── (db:migrate, init-plugins, etc.)
                                     Total: ~45s warm
```

Chromium is baked into the image via apt — no per-container browser
download step required.

## Resources

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Mise Documentation](https://mise.jdx.dev/)
- [Docker Volume Population](https://docs.docker.com/engine/storage/volumes/#populate-a-volume-using-a-container)
