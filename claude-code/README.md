# claude-code

Shared devcontainer image for Claude Code development environments. Two variants from a single multi-stage Dockerfile: **default** (full dev environment) and **sandbox** (network-restricted).

Projects consume these pre-built images and control their own tool versions via `.mise.toml`.

## Image Variants

| Variant | Image | Use Case |
|---------|-------|----------|
| **default** | `ghcr.io/gatezh/devcontainers/claude-code:latest` | Full dev environment with agent-browser and passwordless sudo |
| **sandbox** | `ghcr.io/gatezh/devcontainers/claude-code-sandbox:latest` | Network-restricted environment with iptables firewall packages and agent-browser |

## What's Included

| Layer | What | Why |
|-------|------|-----|
| OS | `node:24-trixie-slim` + system packages | Node is needed during the build (Playwright, npm globals) |
| Shell | zsh, oh-my-zsh (`git`, `fzf`, `gh` plugins), powerlevel10k, `cf` completion | Completions, git aliases and prompt integration |
| Tools | gh CLI, git, curl, jq, less, fzf, procps, openssh-client, python3 (+ venv) | Standard dev utilities (`openssh-client` provides `ssh`/`ssh-keygen` — enables SSH-format commit signing; `python3` runs the `security-guidance` and `claude-security` plugins) |
| Mise | The tool manager itself (not the tools) | Projects run `mise install` at container creation for their tool versions |
| gh-stack | `gh` extension, pinned `ARG` bumped by Renovate | Native stacked PRs (`gh stack`). Baked in because `~/.local/share/gh` is not a volume, so a runtime `gh extension install` is lost on rebuild |
| cf | npm global install, pinned `ARG` bumped by Renovate | Cloudflare CLI for the whole Cloudflare API. See [Cloudflare CLI](#cloudflare-cli-cf) |
| rtk, ralphex | Pinned `ARG`s, bumped by Renovate on each GitHub release | Dev infrastructure (like Claude Code) — the image tracks the versions so projects don't have to |
| Claude Code | npm global install | npm avoids rate limiting that affects the native installer in parallel CI builds |

**Both targets:** system Chromium + `fonts-freefont-ttf` at `/usr/bin/chromium`, [agent-browser](https://github.com/vercel-labs/agent-browser) (the default browser tool for agents), and the `devcontainer-browser` skill (see [Built in: browser skill](#built-in-browser-skill)), passwordless sudo

**Sandbox-only:** iptables, ipset, iproute2, dnsutils, aggregate

### MDN MCP server

The image provides Mozilla's [MDN MCP server](https://developer.mozilla.org/en-US/mcp) (web platform docs and browser compatibility data) to every session through `managedMcpServers` in `/etc/claude-code/managed-settings.json` — no per-project setup. It sends `X-Moz-1st-Party-Data-Opt-Out: 1`, Mozilla's documented opt-out from the query logging they do while the server is experimental.

Requires Claude Code >= 2.1.259; earlier clients ignore the key. `claude mcp remove` refuses it, but each developer can turn it off for themselves in `/mcp` under **Managed MCPs**. Sandbox users must allowlist `mcp.mdn.mozilla.net` in their firewall script.

### Cloudflare CLI (`cf`)

Both targets ship Cloudflare's [`cf`](https://developers.cloudflare.com/cf/) CLI, the open-beta successor to Wrangler. It covers the whole Cloudflare API and prints JSON. The `claudeMd` key in `/etc/claude-code/managed-settings.json` tells every Claude Code session to use it, except in projects that have a Wrangler config but no `cloudflare.config.ts`: there, `cf dev`, `cf build` and `cf deploy` would rewrite project files without asking. A managed `ask` rule makes Claude Code ask before any `cf` command with `--force` or `-f`, the flag `cf` requires for deletes when there's no terminal. Bypass mode skips the prompt, as it skips every prompt. The image turns telemetry off (`CF_SEND_TELEMETRY=false`, `WRANGLER_SEND_METRICS=false`).

Sign in once per project. The template's `myproject-cloudflare-config-*` volume keeps the login (`~/.config/cloudflare`) across rebuilds, and both variants share it:

```bash
cf auth login --no-browser   # approve the printed link and code in your host browser
cf auth whoami
```

The sandbox shares that login, and Claude Code there may run with permission prompts skipped. For agents there, or in CI, prefer an [API token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) limited to what the project needs: set `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, and the token takes priority over the stored login. Sandbox users must allowlist `api.cloudflare.com` (API calls) and `dash.cloudflare.com` (sign-in).

The image deletes `cf`'s bundled `workerd` runtime (133 MB), so `cf dev` and `--local` commands work only in a project that has `cf` as a dev dependency (`cf init` and `cf migrate` add it). The global `cf` then runs the project's copy, which has its own runtime. Commands that call the Cloudflare API don't need it.

The `cloudflare` plugin (skills plus the Cloudflare MCP server) stays installed alongside `cf`: its MCP server also searches current Cloudflare docs, which `cf` doesn't.

## Multi-platform Support

Both variants are built for:
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM64/Apple Silicon)

## Image Tags

- `:latest` — most recent build
- `:<git-sha>` — pinned to a specific commit
- `:<YYYYMMDD>` — date-based tag (e.g., `20260319`)

## Automatic Rebuilds

The image rebuilds automatically whenever one of its pinned tools — Claude Code, agent-browser, cf, gh, gh-stack, rtk, or ralphex — publishes a new release: Renovate opens a version-bump PR, CI verifies it, it auto-merges, and the merge builds the image on native runners for both amd64 and arm64 (no QEMU emulation). Manual rebuilds can be triggered via the "Run workflow" button in the Actions UI.

## Quick Start

### Default variant

Copy the example files into your project's `.devcontainer/` directory and customize as needed. A host-side `initializeCommand` in `devcontainer.json` pulls the prebuilt image before the container is built, so "Rebuild Without Cache" always layers on the latest image. All other config stays in `devcontainer.json` using cross-orchestrator properties (`mounts`, `containerEnv`, `capAdd`, `init`) so you keep devcontainer variable substitution (`${localWorkspaceFolderBasename}`, `${localEnv:...}`).

**After copying:** replace `myproject` with your project name in `docker-compose.yml` (the `name:` field) and `devcontainer.json` (volume mount prefixes). This must match across both variants if using the sandbox.

Copy these to your project's `.devcontainer/`:

- [`.devcontainer/docker-compose.yml`](.devcontainer/docker-compose.yml) — image reference (kept fresh by the `initializeCommand` pull in `devcontainer.json`)
- [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) — full config with VS Code extensions, zsh shell, OXC formatter, node_modules volume isolation, and lifecycle commands

**Key settings included:** zsh + bash terminal profiles, OXC formatter (with comments for switching to Biome/Prettier), node_modules/Claude config/zsh history/gh CLI config/cf login volume mounts, env-based git config (see [Git and GitHub Authentication](#git-and-github-authentication)), and `updateContentCommand` for mise/bun setup (`bun install` is skipped until the project has a `package.json`). There is deliberately no `postCreateCommand`: see [`init-plugins.sh`](#optional-devcontainerinit-pluginssh).

### Sandbox variant

Copy these to your project's `.devcontainer/claude-sandbox/`:

- [`.devcontainer/claude-sandbox/docker-compose.yml`](.devcontainer/claude-sandbox/docker-compose.yml) — sandbox image reference
- [`.devcontainer/claude-sandbox/devcontainer.json`](.devcontainer/claude-sandbox/devcontainer.json) — full config with `NET_ADMIN`/`NET_RAW` capabilities, Claude Dark theme, `claudeCode.allowDangerouslySkipPermissions`, node_modules volume isolation, firewall script bind mount, and `CLAUDE_CODE_OAUTH_TOKEN` injection

**Sandbox differences from default:** `capAdd` for iptables, setup (including `init-plugins.sh`) runs in `postCreateCommand` before `postStartCommand` brings up the firewall, `claudeCode.allowDangerouslySkipPermissions` enabled, and an optional host-injected OAuth token for standalone use (see [Sandbox Authentication](#sandbox-authentication)).

**Shared volumes:** Both variants use `${localWorkspaceFolderBasename}` in volume names, so they share node_modules, Claude config, zsh history, gh CLI auth (`~/.config/gh`), and the `cf` login (`~/.config/cloudflare`). Install packages in one variant and both benefit. Docker named volumes support multi-container access, so both can run simultaneously — just avoid running `bun install` in both at the same time.

## Project Setup Guide

Projects consuming these images need the following files in their repository.

### Required: `.mise.toml` (project root)

Only pin tools that affect project stability — dev infrastructure (rtk, ralphex, Claude Code) is pre-installed in the image, which tracks their releases for you. See [`mise.toml`](mise.toml) for a template.

### Optional: `.devcontainer/init-plugins.sh`

Claude Code plugin initialization. `init-plugins.sh` registers marketplaces, installs plugins, updates them to the latest marketplace versions (`install` alone no-ops once the persistent `~/.claude` volume holds a plugin), and invokes the image-baked `/usr/local/bin/patch-playwright-mcp` to rewrite every cached Playwright MCP `.mcp.json` to launch the system chromium. Idempotent. See [`.devcontainer/init-plugins.sh`](.devcontainer/init-plugins.sh) for the template.

- **Sandbox variant:** its `postCreateCommand` already runs the script, if present, before `postStartCommand` brings up the firewall.
- **Default variant:** run it yourself after signing in to Claude Code, and again whenever you want plugin updates:

  ```bash
  bash .devcontainer/init-plugins.sh
  ```

  It is not wired into `postCreateCommand` on purpose. `claude` CLI calls made there race the Claude Code extension's OAuth sign-in and can corrupt auth state, even with `waitFor` set (#58).

`postStartCommand` re-runs the patch on every container start so plugin auto-updates between sessions cannot leave MCP pointing at the missing chrome channel. See the [Playwright Strategy](#playwright-strategy) section.

Mark as executable: `chmod +x init-plugins.sh`

#### Bundled plugins

`init-plugins.sh` registers six marketplaces and installs the following plugins:

| Marketplace | Plugin | Purpose |
|---|---|---|
| `anthropics/claude-plugins-official` | `frontend-design` | Production-grade UI/UX scaffolding |
| `anthropics/claude-plugins-official` | `code-review` | Multi-agent PR review |
| `anthropics/claude-plugins-official` | `code-simplifier` | Refactors for clarity and consistency |
| `anthropics/claude-plugins-official` | `playwright` | Browser MCP (system chromium via `patch-playwright-mcp`) |
| `anthropics/claude-plugins-official` | `superpowers` | Workflow skills (TDD, debugging, planning) |
| `anthropics/claude-plugins-official` | `explanatory-output-style` | Educational output mode |
| `anthropics/claude-plugins-official` | `claude-md-management` | Audits and updates CLAUDE.md |
| `anthropics/claude-plugins-official` | `claude-code-setup` | Settings, permissions, automation helpers |
| `anthropics/claude-plugins-official` | `posthog` | PostHog product-analytics & LLM-traces skills |
| `anthropics/claude-plugins-official` | `security-guidance` | Security warnings on edits, LLM diff review on Stop, agentic review on commit/push (config via env vars — see [README](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/security-guidance)) |
| `anthropics/claude-plugins-official` | `claude-security` | On-demand `/claude-security` vulnerability scans and verified patch suggestions |
| `cloudflare/skills` | `cloudflare` | Cloudflare skills and MCP server |
| `umputun/ralphex` | `ralphex` | Autonomous plan execution |
| `GoogleChrome/modern-web-guidance` | `modern-web-guidance` | Accessible, performant, secure modern web patterns ([docs](https://developer.chrome.com/docs/modern-web-guidance)) |
| `AgriciDaniel/claude-seo` | `claude-seo` | SEO analysis toolkit — technical SEO, schema, E-E-A-T, GEO/AEO, Google APIs ([repo](https://github.com/AgriciDaniel/claude-seo)) |
| `rubberduck-studio/typescript-native-lsp` | `typescript-native-lsp` | TypeScript/JavaScript LSP: TS 7's native server (`tsc --lsp`), falls back to `typescript-language-server` on TS 6 and older ([repo](https://github.com/rubberduck-studio/typescript-native-lsp)) |

> **Why not the official `typescript-lsp`:** it runs `typescript-language-server`, which wraps `tsserver`. TypeScript 7 (the native Go port) ships no `tsserver.js`, so on a TS 7 project the official plugin fails every request. `typescript-native-lsp` covers TS 7 and older versions in one plugin. The two must not be enabled together: when two plugins claim `.ts`, Claude Code starts only the first one it registers. That's why `init-plugins.sh` also disables `typescript-lsp` when a persisted `~/.claude` volume still has it (`DISABLED_PLUGINS`). TS 6 and older projects need `typescript-language-server` in the project (`bun add -d typescript-language-server`) or installed globally. The official plugin needed that too. Switch back once [anthropics/claude-plugins-official#4492](https://github.com/anthropics/claude-plugins-official/issues/4492) ships native TS 7 support (#194).

**`security-guidance` runtime download:** on first session start the plugin builds a `claude-agent-sdk` venv in `~/.claude/security/` for its agentic commit reviewer — a ~100 MB wheel from PyPI (it bundles its own Claude Code binary), stored once in the `~/.claude` volume, not the image. In the sandbox, add `pypi.org` and `files.pythonhosted.org` to your `init-firewall.sh` allowlist, or the commit reviewer falls back to the single-call diff review (edit warnings and Stop reviews still work). `SECURITY_GUIDANCE_DISABLE=1` in `containerEnv` turns the reviews off, but the venv bootstrap still runs; to skip the download, drop the plugin from your `init-plugins.sh`.

To remove a plugin in your project, delete its entry from the local `init-plugins.sh` — the script is a template, not image-baked, so each consumer controls its own list.

> **Why `init-plugins.sh` stays per-project but `patch-playwright-mcp` doesn't:** `init-plugins.sh` carries project-specific configuration (marketplace list, plugin list) — it's *meant* to be edited per project. The patch script has zero project-specific config and is identical across every consumer, so it's baked into the image and flows through the same Renovate-triggered rebuild + `initializeCommand` image-pull channel as the rest of the image. That boundary is the rule: project-specific config stays per-project; universal logic moves into the image.

### Sandbox-only: `.devcontainer/claude-sandbox/init-firewall.sh`

Default-deny iptables firewall. The image provides the packages and sudo rule; the project provides this script via bind mount. Customize the domain allowlist for your project.

See the [repo's own sandbox firewall script](../.devcontainer/claude-sandbox/init-firewall.sh) for a complete example. The script should: preserve Docker internal DNS rules, allow DNS/SSH/localhost, fetch GitHub IP ranges via `curl -s https://api.github.com/meta`, resolve additional allowed domains (npm, Anthropic API, VS Code marketplace, `mcp.mdn.mozilla.net` for the MDN MCP server, `api.cloudflare.com` and `dash.cloudflare.com` for `cf`, etc.) via `dig`, set default DROP policies, allow established connections and the ipset allowlist, then verify by confirming `example.com` is blocked and `api.github.com` is reachable.

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

### Built in: browser skill

Both image variants ship the [devcontainer-browser](.devcontainer/managed-skills/devcontainer-browser/SKILL.md) skill at `/etc/claude-code/.claude/skills/`, Claude Code's managed skills location, so every project gets it with nothing to copy. It makes **agent-browser the default** for any browser work (opening the app, UI checks, screenshots, DPR and srcset measurements, React render profiling) and keeps **Playwright as the fallback** for a project's committed `@playwright/test` suite, vitest browser mode and Storybook tests, Firefox/WebKit, or a missing agent-browser. It also carries the per-consumer `executablePath` wiring from [Playwright Strategy](#playwright-strategy) and the rule never to download a browser.

`/etc/claude-code/managed-settings.json` backs it with a short `claudeMd` routing rule loaded in every session. `permissions.deny` blocks `agent-browser install` and `agent-browser upgrade`: Chromium is preinstalled and the version is pinned.

The image doesn't pre-allow agent-browser. Some of its flags start any binary (`--executable-path`, `--args`) or load plugins (`--config`), so a blanket allow would let a page that tricks the agent run code without a prompt. The first agent-browser command in a project asks; pick "don't ask again" to keep the answer. To skip the prompts in a project you trust, add this to its `.claude/settings.local.json` (personal and uncommitted; it survives rebuilds):

```json
{ "permissions": { "allow": ["Bash(agent-browser *)"] } }
```

agent-browser reads only `/etc/agent-browser/config.json` (`AGENT_BROWSER_CONFIG`). A repo's `./agent-browser.json` can declare plugin executables and Chromium args, so it is ignored, and so is `~/.agent-browser/config.json`; pass options as CLI flags or `AGENT_BROWSER_*` env vars. The image config turns on [content boundaries](https://github.com/vercel-labs/agent-browser#security), which mark where page output starts and ends, and caps output at 50,000 characters.

**Migrating from `sandbox-playwright`:** delete `.claude/skills/sandbox-playwright/` from your project. It has a different name, so Claude Code would load both.

### Recommended: Claude Code skill for stacked PRs

Both image variants bake in the official [`github/gh-stack`](https://github.com/github/gh-stack) extension, so `gh stack` can open, link and atomically merge native [stacked PRs](https://gh.io/stacks). The [stacked-prs](.claude/skills/stacked-prs/SKILL.md) skill tells Claude Code to use it instead of hand-chaining PRs with `gh pr create --base`, and which flags keep it non-interactive.

Copy `.claude/skills/stacked-prs/` into your project's `.claude/skills/` directory so Claude Code picks it up automatically.

### Recommended: migrate Workers projects to `cloudflare.config.ts`

`cloudflare.config.ts` is `cf`'s typed replacement for `wrangler.jsonc`, so agents and the TypeScript language server can check bindings and routes. Migration is per project, so the image can't do it for you. Wrangler gets 18 months of maintenance once the `cf` beta ends, so start now:

```bash
cf migrate --dry-run   # preview
cf migrate             # writes cloudflare.config.ts, adds cf as a devDependency
```

Then resolve the `TODO(@cloudflare)` comments it leaves: Durable Object migrations, Workflows, Containers and package scripts need a manual pass, and the build fails until they're done. Keep `wrangler.jsonc` while you still need Wrangler-only commands (`wrangler tail`, setting a single secret). The two tools don't read each other's config. `cf` needs Node, so don't run it with `bun --bun`.

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

**Usual path: sign in once in the default variant.** Both variants mount the same `myproject-claude-config-*` volume at `/home/node/.claude`, so credentials created by signing in to the default variant (VS Code extension, or `claude` in a terminal) are already there when the sandbox starts. No token is needed.

**Standalone sandbox: inject a token.** If you use the sandbox without ever opening the default variant, sign-in has to happen inside the sandbox, where the firewall blocks the browser OAuth flow that `claude login` opens. Generate a token on the host and inject it via environment variable instead.

When `CLAUDE_CODE_OAUTH_TOKEN` is unset on the host, `${localEnv:CLAUDE_CODE_OAUTH_TOKEN}` resolves to an empty string, so the variable still exists in the container, but empty. That is expected: with an empty token, Claude Code authenticates from the credentials on the shared volume.

**Setup (one-time, standalone sandbox only):**

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
├── docker-compose.yml             ← default compose (image reference)
├── init-plugins.sh                ← Claude Code plugin setup (optional)
└── claude-sandbox/
    ├── devcontainer.json          ← sandbox devcontainer
    ├── docker-compose.yml         ← sandbox compose (image reference)
    ├── init-firewall.sh           ← firewall script (customize domain allowlist)
    ├── .env.example               ← template for auth token (checked in)
    └── .env.local                 ← actual auth token (gitignored)
.claude/
├── settings.json                  ← permission allowlists for common dev commands
└── skills/
    ├── sandbox-fetch-docs/
    │   └── SKILL.md               ← teaches Claude Code to fetch docs within sandbox firewall
    ├── stacked-prs/
    │   └── SKILL.md               ← teaches Claude Code to use native stacked PRs (gh stack)
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

## Git and GitHub Authentication

Both `devcontainer.json` variants set git config through `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_<n>` / `GIT_CONFIG_VALUE_<n>` in `containerEnv`. Git reads these as [command scope](https://git-scm.com/docs/git-config#SCOPES): they apply to every git process in the container (terminal, VS Code's Git extension, Claude Code) and outrank `/etc/gitconfig` and `~/.gitconfig`, which the Dev Containers extension writes to on attach.

| Key | Value | Why |
|-----|-------|-----|
| `safe.directory` | `/workspace` | Docker Desktop bind mounts can report `/workspace` as owned by another user, so git refuses it with `detected dubious ownership`. The Dev Containers extension adds this entry to `~/.gitconfig` only when its one-time check at attach detects the mismatch, so the error comes and goes. |
| `url.https://github.com/.insteadOf` | `git@github.com:` | Sends SSH-style GitHub remotes over HTTPS inside the container. The remotes themselves and the host's SSH setup don't change. |
| `credential.https://github.com.helper` | *(empty)* | Clears the helper list for github.com, including the helper VS Code injects, which answers with the host's possibly stale GitHub credential. Other hosts keep VS Code's helper. |
| `credential.https://github.com.helper` | `!gh auth git-credential` | Authenticates github.com through the container's `gh` login. The empty entry and this one are what `gh auth setup-git` writes. |

**One-time setup:** run `gh auth login` in either variant. The login lives on the shared `myproject-gh-config-*` volume, so it survives rebuilds and covers both variants. After that, fetch, pull and push work from the terminal and from VS Code for both `https://github.com/` and `git@github.com:` remotes.

To check what git sees, run `git config --show-scope --get-regexp 'safe|insteadof|credential'`. The entries above are listed with scope `command`. To add your own entries, append `GIT_CONFIG_KEY_4` / `GIT_CONFIG_VALUE_4` and so on, and raise `GIT_CONFIG_COUNT` to match.

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
AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium
AGENT_BROWSER_CONFIG=/etc/agent-browser/config.json
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
| `agent-browser` | nothing | Image sets `AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium`. Independent of the `PLAYWRIGHT_*` convention — agent-browser is a Rust CLI with its own env-var family. |

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

`init-plugins.sh` invokes the patch binary when it runs, and the
template `devcontainer.json` files run it again at `postStartCommand` so
plugin auto-updates between sessions cannot leave MCP pointing at the
missing chrome channel.

To debug, inspect the patched configs after a container start:

```bash
cat ~/.claude/plugins/cache/claude-plugins-official/playwright/*/.mcp.json
```

## Build Args

Current values live in [the Dockerfile](.devcontainer/Dockerfile) and are not repeated
here — Renovate bumps several of them weekly, so any number written below would be wrong
more often than right.

| Arg | Updated by | Description |
|-----|------------|-------------|
| `RTK_VERSION` | Renovate | rtk |
| `RALPHEX_VERSION` | Renovate | ralphex |
| `CLAUDE_CODE_VERSION` | Renovate | Claude Code CLI |
| `AGENT_BROWSER_VERSION` | Renovate | agent-browser |
| `GH_VERSION` | Renovate | GitHub CLI — from the upstream `.deb`, not apt (trixie freezes gh at 2.46.0) |
| `GH_STACK_VERSION` | Renovate | gh-stack extension (`gh stack`) |
| `CF_VERSION` | Renovate | Cloudflare CLI (`cf`), open beta; releases wait 3 days before auto-merge |
| `OH_MY_ZSH_REF` | by hand | oh-my-zsh, pinned to a commit SHA |
| `POWERLEVEL10K_REF` | by hand | powerlevel10k, pinned to a commit SHA |

The seven Renovate-managed args carry `# renovate:` annotations in the Dockerfile; edit them by
hand only for a local build. Bumps land as auto-merged PRs — see [Automatic Rebuilds](#automatic-rebuilds).

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
```

Everything else in `devcontainer.json` (mounts, containerEnv, lifecycle commands, etc.) stays the same — the local image is identical to the pre-built one. The `initializeCommand` still points at the GHCR image, but `|| exit 0` means a failed pull won't block the open; you can remove it to skip the now-unnecessary pull.

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
