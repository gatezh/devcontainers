# claude-code

Shared devcontainer image for Claude Code development environments. Two variants from a single multi-stage Dockerfile: **default** (full dev environment) and **sandbox** (network-restricted).

Projects consume these pre-built images and control their own tool versions via `.mise.toml`.

## Image Variants

| Variant | Image | Use Case |
|---------|-------|----------|
| **default** | `ghcr.io/gatezh/devcontainers/claude-code:latest` | Full dev environment with agent-browser and passwordless sudo |
| **sandbox** | `ghcr.io/gatezh/devcontainers/claude-code-sandbox:latest` | Network-restricted environment with a baked-in firewall and agent-browser; sudo runs only the firewall |

## What's Included

| Layer | What | Why |
|-------|------|-----|
| OS | `node:24-trixie-slim` + system packages | Node is needed during the build (Playwright, npm globals) |
| Shell | zsh, oh-my-zsh (`git`, `fzf`, `gh` plugins), powerlevel10k, `cf` completion | Completions, git aliases and prompt integration |
| Tools | gh CLI, git, curl, jq, less, fzf, procps, openssh-client, python3 (+ venv) | Standard dev utilities (`openssh-client` provides `ssh`/`ssh-keygen` — enables SSH-format commit signing; `python3` runs the `security-guidance` and `claude-security` plugins) |
| Mise | The tool manager itself (not the tools) | Projects run `mise install` at container creation for their tool versions |
| gh-stack | `gh` extension, pinned `ARG` bumped by Renovate | Native stacked PRs (`gh stack`). Baked in because `~/.local/share/gh` is not a volume, so a runtime `gh extension install` is lost on rebuild |
| cf | npm global install, pinned `ARG` bumped by Renovate | Cloudflare CLI for the whole Cloudflare API. See [Cloudflare CLI](#cloudflare-cli-cf) |
| ralphex | Pinned `ARG`, bumped by Renovate on each GitHub release | Dev infrastructure (like Claude Code) — the image tracks the version so projects don't have to |
| actionlint, shellcheck | Pinned `ARG`s, bumped by Renovate on each GitHub release | GitHub Actions workflow linting; actionlint checks `run:` scripts only when shellcheck is on `PATH` |
| Claude Code | npm global install | npm avoids rate limiting that affects the native installer in parallel CI builds |

**Both targets:** system Chromium + `fonts-freefont-ttf` at `/usr/bin/chromium`, [agent-browser](https://github.com/vercel-labs/agent-browser) (the default browser tool for agents), the `devcontainer-browser` skill (see [Built in: browser skill](#built-in-browser-skill)), and `/usr/local/sbin/chown-volumes`, the volume-ownership safety net both templates run

**Default-only:** passwordless sudo

**Sandbox-only:** iptables, ipset, iproute2, dnsutils, aggregate; the firewall (`/usr/local/sbin/init-firewall`). It and `chown-volumes` are the only commands `node` can run with sudo

### MDN MCP server

The image provides Mozilla's [MDN MCP server](https://developer.mozilla.org/en-US/mcp) (web platform docs and browser compatibility data) to every session through `managedMcpServers` in `/etc/claude-code/managed-settings.json` — no per-project setup. It sends `X-Moz-1st-Party-Data-Opt-Out: 1`, Mozilla's documented opt-out from the query logging they do while the server is experimental.

Requires Claude Code >= 2.1.259; earlier clients ignore the key. `claude mcp remove` refuses it, but each developer can turn it off for themselves in `/mcp` under **Managed MCPs**. The sandbox firewall allows `mcp.mdn.mozilla.net` by default.

### Cloudflare CLI (`cf`)

Both targets ship Cloudflare's [`cf`](https://developers.cloudflare.com/cf/) CLI, the open-beta successor to Wrangler. It covers the whole Cloudflare API and prints JSON. The `claudeMd` key in `/etc/claude-code/managed-settings.json` tells every Claude Code session to use it, except in projects that have a Wrangler config but no `cloudflare.config.ts`: there, `cf dev`, `cf build` and `cf deploy` would rewrite project files without asking. A managed `ask` rule makes Claude Code ask before any `cf` command with `--force` or `-f`, the flag `cf` requires for deletes when there's no terminal. Bypass mode skips the prompt, as it skips every prompt. The image turns telemetry off (`CF_SEND_TELEMETRY=false`, `WRANGLER_SEND_METRICS=false`) and leaves npm dependency metadata out of Worker deploys (`CLOUDFLARE_DEPENDENCIES_INSTRUMENTATION=false`).

Sign in once per project. The template's `myproject-cloudflare-config-*` volume keeps the login (`~/.config/cloudflare`) across rebuilds:

```bash
cf auth login --no-browser   # approve the printed link and code in your host browser
cf auth whoami
```

The sandbox doesn't get that login: it has its own volumes (see [Why the variants don't share volumes](#why-the-variants-dont-share-volumes)), and Claude Code there may run with permission prompts skipped. For agents there, or in CI, use an [API token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) limited to what the project needs: set `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`, and the token takes priority over the stored login. Sandbox users must add `api.cloudflare.com` (API calls) and `dash.cloudflare.com` (sign-in) to `allowed-domains.txt`.

The image deletes `cf`'s bundled `workerd` runtime (133 MB), so `cf dev` and `--local` commands work only in a project that has `cf` as a dev dependency (`cf init` and `cf migrate` add it). The global `cf` then runs the project's copy, which has its own runtime. Most commands that call the Cloudflare API don't need it, but `cf workers …` does, even for API reads like `cf workers scripts list` ([#212](https://github.com/gatezh/devcontainers/issues/212)). For Workers reads outside such a project, use `bunx wrangler` or the Cloudflare MCP server.

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

The image rebuilds automatically whenever one of its pinned tools — Claude Code, agent-browser, cf, gh, gh-stack, ralphex, actionlint, or shellcheck — publishes a new release: Renovate opens a version-bump PR, CI verifies it, it auto-merges (a new major version waits for review instead), and the merge builds the image on native runners for both amd64 and arm64 (no QEMU emulation). Manual rebuilds can be triggered via the "Run workflow" button in the Actions UI.

## Quick Start

### Default variant

Copy the example files into your project's `.devcontainer/` directory and customize as needed. A host-side `initializeCommand` in `devcontainer.json` pulls the prebuilt image before the container is built, so "Rebuild Without Cache" always layers on the latest image. Apart from the shared Bun store (see [Volumes](#volumes)), config stays in `devcontainer.json` using cross-orchestrator properties (`mounts`, `containerEnv`, `capAdd`, `init`) so you keep devcontainer variable substitution (`${localWorkspaceFolderBasename}`, `${localEnv:...}`).

**After copying:** replace `myproject` with your project name in `docker-compose.yml` (the `name:` field) and `devcontainer.json` (volume mount prefixes), in both variants if you use the sandbox. Leave `bun-global-store` as it is: every project shares it.

Copy these to your project's `.devcontainer/`:

- [`.devcontainer/docker-compose.yml`](.devcontainer/docker-compose.yml) — image reference (kept fresh by the `initializeCommand` pull in `devcontainer.json`)
- [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) — full config with VS Code extensions, zsh shell, OXC formatter, node_modules volume isolation, and lifecycle commands

**Key settings included:** zsh + bash terminal profiles, OXC formatter (with comments for switching to Biome/Prettier), named volumes for node_modules, Claude config, zsh history, gh CLI config, the cf login and the shared Bun store (see [Volumes](#volumes)), env-based git config (see [Git and GitHub Authentication](#git-and-github-authentication)), and `updateContentCommand` for mise/bun setup (`bun install` is skipped until the project has a `package.json`). There is deliberately no `postCreateCommand`: see [`init-plugins.sh`](#optional-devcontainerinit-pluginssh).

### Sandbox variant

Copy these to your project's `.devcontainer/claude-sandbox/`:

- [`.devcontainer/claude-sandbox/docker-compose.yml`](.devcontainer/claude-sandbox/docker-compose.yml) — sandbox image reference
- [`.devcontainer/claude-sandbox/devcontainer.json`](.devcontainer/claude-sandbox/devcontainer.json) — full config with `NET_ADMIN`/`NET_RAW` capabilities, Claude Dark theme, `claudeCode.allowDangerouslySkipPermissions`, node_modules volume isolation, and `CLAUDE_CODE_OAUTH_TOKEN` injection
- [`.devcontainer/claude-sandbox/allowed-domains.txt`](.devcontainer/claude-sandbox/allowed-domains.txt) — extra domains for the firewall (optional)

**Sandbox differences from default:** `capAdd` for iptables, setup (including `init-plugins.sh`) runs in `postCreateCommand` before `postStartCommand` brings up the firewall, `claudeCode.allowDangerouslySkipPermissions` enabled, and a host-injected OAuth token for sign-in (see [Sandbox Authentication](#sandbox-authentication)).

**Separate volumes:** the sandbox shares no volumes with the default variant. It has its own Claude config, zsh history, gh CLI auth (`~/.config/gh`), `cf` login (`~/.config/cloudflare`) and `node_modules`, so you sign in to it separately. This is deliberate: see [Why the variants don't share volumes](#why-the-variants-dont-share-volumes).

## Project Setup Guide

Projects consuming these images need the following files in their repository.

### Required: `.mise.toml` (project root)

Only pin tools that affect project stability — dev infrastructure (ralphex, Claude Code, actionlint, shellcheck) is pre-installed in the image, which tracks their releases for you. A project whose CI must match exact linter versions pins them in a CI-only `.mise.ci.toml` (`MISE_ENV=ci`), so container creation doesn't download them. See [`mise.toml`](mise.toml) for a template.

### Optional: `.devcontainer/init-plugins.sh`

Claude Code plugin initialization. `init-plugins.sh` registers marketplaces, installs plugins, updates them to the latest marketplace versions (`install` alone no-ops once the persistent `~/.claude` volume holds a plugin). Idempotent. See [`.devcontainer/init-plugins.sh`](.devcontainer/init-plugins.sh) for the template.

- **Sandbox variant:** its `postCreateCommand` already runs the script, if present, before `postStartCommand` brings up the firewall.
- **Default variant:** run it yourself after signing in to Claude Code, and again whenever you want plugin updates:

  ```bash
  bash .devcontainer/init-plugins.sh
  ```

  It is not wired into `postCreateCommand` on purpose. `claude` CLI calls made there race the Claude Code extension's OAuth sign-in and can corrupt auth state, even with `waitFor` set (#58).

`postStartCommand` re-runs the patch on every container start so plugin auto-updates between sessions cannot leave MCP pointing at the missing chrome channel. See the [Playwright Strategy](#playwright-strategy) section.

Mark as executable: `chmod +x init-plugins.sh`

**Upgrading from an image with rtk:** the images no longer ship rtk, but earlier versions of this script registered its `rtk hook claude` hook in `~/.claude/settings.json`, which persists on the volume. The image removes that entry at the start of each Claude Code session (a managed `SessionStart` hook) and leaves your other hooks alone, so there's nothing to do. Until the first session after you pull the new image, Bash calls log a non-blocking hook error.

#### Bundled plugins

`init-plugins.sh` registers six marketplaces and installs the following plugins:

| Marketplace | Plugin | Purpose |
|---|---|---|
| `anthropics/claude-plugins-official` | `frontend-design` | Production-grade UI/UX scaffolding |
| `anthropics/claude-plugins-official` | `code-review` | Multi-agent PR review |
| `anthropics/claude-plugins-official` | `code-simplifier` | Refactors for clarity and consistency |
| `anthropics/claude-plugins-official` | `playwright` | Browser MCP (system chromium via the image's `PLAYWRIGHT_MCP_*` env vars) |
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

**`security-guidance` runtime download:** on first session start the plugin builds a `claude-agent-sdk` venv in `~/.claude/security/` for its agentic commit reviewer — a ~100 MB wheel from PyPI (it bundles its own Claude Code binary), stored once in the `~/.claude` volume, not the image. In the sandbox, add `pypi.org` and `files.pythonhosted.org` to `allowed-domains.txt`, or the commit reviewer falls back to the single-call diff review (edit warnings and Stop reviews still work). `SECURITY_GUIDANCE_DISABLE=1` in `containerEnv` turns the reviews off, but the venv bootstrap still runs; to skip the download, drop the plugin from your `init-plugins.sh`.

To remove a plugin in your project, delete its entry from the local `init-plugins.sh` — the script is a template, not image-baked, so each consumer controls its own list.

> **Why `init-plugins.sh` stays per-project:** it carries project-specific configuration (marketplace list, plugin list) and is *meant* to be edited per project. Anything identical across every consumer, such as the Playwright MCP browser settings or the managed settings file, lives in the image instead and flows through the same Renovate-triggered rebuild + `initializeCommand` image-pull channel. That boundary is the rule: project-specific config stays per-project; universal logic moves into the image.

### Sandbox-only: `.devcontainer/claude-sandbox/allowed-domains.txt`

The sandbox image ships a default-deny iptables firewall at `/usr/local/sbin/init-firewall`, and `postStartCommand` runs it. It allows GitHub's published IP ranges, the npm registry, the Anthropic API, the VS Code marketplace and `mcp.mdn.mozilla.net`, then checks that `example.com` is blocked and `api.github.com` is reachable.

To allow more, list one domain per line in `allowed-domains.txt`. Lines starting with `#` are comments. The firewall resolves each domain with `dig` when it starts. The file is read as data, never run, and the firewall skips, with a warning, any line that isn't a plain domain name. A broken allowlist never keeps the firewall down, and if setup itself fails partway (say, GitHub's IP list can't be fetched), the firewall closes the network rather than leaving it open: restart the container to retry. Allowlisted hosts are reachable on every port, SSH included; nothing else is, and IPv6 gets loopback only.

```
# cf
api.cloudflare.com
dash.cloudflare.com
```

**Why the script is in the image:** Claude Code in the sandbox runs with permission prompts skipped, so the agent mustn't be able to turn the firewall off. In the sandbox, `node` can run only `init-firewall` and `chown-volumes` with sudo, both root-owned and without arguments. A second run of `init-firewall` refuses to touch an active firewall, so allowlist edits apply on the next container start, and you'll see them in `git diff` first. The default variant keeps passwordless sudo ([#208](https://github.com/gatezh/devcontainers/issues/208)).

**Upgrading from a project `init-firewall.sh`:** the image no longer runs a bind-mounted script, and sudo refuses `/usr/local/bin/init-firewall.sh`. Copy the domains your script adds beyond the defaults into `allowed-domains.txt`. Then delete the script and its bind mount, and update `postCreateCommand` and `postStartCommand` from the template's [`devcontainer.json`](.devcontainer/claude-sandbox/devcontainer.json).

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

**Sign in with a token.** The sandbox has its own `~/.claude` volume, so signing in to the default variant doesn't sign it in ([why](#why-the-variants-dont-share-volumes)). Signing in inside the sandbox doesn't work either: the firewall blocks the browser OAuth flow that `claude login` opens. Generate a token on the host and inject it through an environment variable instead.

When `CLAUDE_CODE_OAUTH_TOKEN` is unset on the host, `${localEnv:CLAUDE_CODE_OAUTH_TOKEN}` resolves to an empty string, so the variable still exists in the container, but empty. Claude Code then falls back to any credentials already on the sandbox's own `~/.claude` volume.

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
├── docker-compose.yml             ← default compose (image reference)
├── init-plugins.sh                ← Claude Code plugin setup (optional)
└── claude-sandbox/
    ├── devcontainer.json          ← sandbox devcontainer
    ├── docker-compose.yml         ← sandbox compose (image reference)
    ├── allowed-domains.txt        ← extra firewall domains (optional)
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

## Volumes

| Volume (as named in the template) | Mounted at | Shared by |
|---|---|---|
| `myproject-claude-config-*` | `~/.claude` | nothing: one per variant and worktree |
| `myproject-zsh-history-*` | `/commandhistory` | nothing: one per variant and worktree |
| `myproject-gh-config-*` | `~/.config/gh` | nothing: one per variant and worktree |
| `myproject-cloudflare-config-*` | `~/.config/cloudflare` | nothing: one per variant and worktree |
| `myproject-node-modules-*` | `/workspace/**/node_modules` | nothing: one per variant and worktree |
| `bun-global-store` | `~/.bun/install/cache` | every project's default variant |

The devcontainer CLI passes `devcontainer.json` `mounts` to Compose, which prefixes each volume with its project name (`myproject` or `myproject-sandbox`). On disk the default's Claude config is `myproject_myproject-claude-config-<folder>` and the sandbox's is `myproject-sandbox_myproject-claude-config-<folder>`. `bun-global-store` is declared in `docker-compose.yml` with a fixed `name:` instead, because a fixed name is the only way a volume is shared across Compose projects.

### Why the variants don't share volumes

The sandbox exists to contain Claude Code running with permission prompts skipped. Any volume the sandbox can write and the default variant reads would carry the sandbox agent's writes past the firewall into a container with passwordless sudo and open network. So the sandbox gets none of the default variant's volumes, and you sign in to it separately ([Sandbox Authentication](#sandbox-authentication)). Older templates said the variants shared these volumes, but Compose's prefixing meant they never did ([#209](https://github.com/gatezh/devcontainers/issues/209)). [#239](https://github.com/gatezh/devcontainers/pull/239) considered making them share and kept them separate for the reasons below, so don't add sharing back.

- **`~/.claude` is user scope, which is stronger than the workspace both variants already share.** Claude Code honors `permissions.defaultMode: "bypassPermissions"` only from user or managed settings, never from a project's `.claude/settings.json`. User `allow` rules don't wait for workspace trust, settings and hooks hot-reload, and `~/.claude` edits don't show in `git diff`. A sandbox agent that wrote a hook or bypass mode there would run it in the default variant. See [settings precedence](https://code.claude.com/docs/en/settings#a-value-you-set-is-ignored).
- **`~/.config/gh` holds your `gh auth login` token**, whose default scopes are `repo`, `read:org` and `gist`. GitHub is on the sandbox allowlist, so a shared token would let the agent push to your repos or post data to a gist.
- **`~/.config/cloudflare` holds your Cloudflare account login.** Give the sandbox a scoped API token instead (see [Cloudflare CLI](#cloudflare-cli-cf)).
- **Shell history** holds whatever you typed in the default variant, including tokens pasted on a command line.
- **`node_modules`** in the default variant can be symlinks into `bun-global-store`, which the sandbox doesn't mount.

`/workspace` is still shared, but edits there show in `git diff`, and a project's settings can't turn on bypass mode.

### Shared Bun store

The default variant mounts `bun-global-store` at Bun's cache directory, and every project's default variant mounts the same volume. A package one project downloaded is already there for the next. The image pre-creates the mount point `node`-owned, so a new volume needs no chown.

To also link packages instead of copying them into `node_modules`, enable Bun's [global store](https://bun.com/docs/pm/global-store) in the project's `bunfig.toml`. It works only with the isolated linker:

```toml
[install]
linker = "isolated"
globalStore = true
```

Bun then keeps each package once in the volume's `links/`, and `node_modules` holds symlinks. In a downstream pilot this took `node_modules` from about 720 MB to 80–300 MB, and a second project with the same packages installed in under a second. The setting goes in `bunfig.toml`, not the devcontainer, so CI installs the same layout and catches a package that breaks under the store.

- **Needs Bun 1.4.4 or later.** Earlier versions can drop a package's `@types/*` peer types with no error ([oven-sh/bun#36795](https://github.com/oven-sh/bun/issues/36795)). Bun keeps such packages, and packages with install scripts, project-local.
- **If a package breaks under the store**, add its missing dependency with `packageExtensions` in `package.json`, or set `globalStore = false`.
- **CI cache:** if CI caches `~/.bun/install/cache`, exclude `!~/.bun/install/cache/links`. `bun install` rebuilds it from the downloads, and caching it about doubles what every job restores.
- **Trust model:** every devcontainer that mounts the store can change packages the others run. A malicious install script in one project could edit a package another project loads. That's the trust model of a laptop where all projects share `~/.bun`. The sandbox doesn't mount it and keeps its own cache.
- **To reset it**, run `bun pm cache rm` in any default-variant container: it clears the cache, global store included ([Bun docs](https://bun.com/docs/pm/global-store)). Then run `bun install` in each project; until then, their `node_modules` symlinks point at nothing. To delete the volume itself, stop every devcontainer first, then `docker volume rm bun-global-store`.

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

The image itself trusts `/workspace` in `/etc/gitconfig` (`safe.directory`). Docker Desktop bind mounts can report `/workspace` as owned by another user, so git refuses it with `detected dubious ownership`. The Dev Containers extension adds this entry to `~/.gitconfig` only when its one-time check at attach detects the mismatch, so the error comes and goes. It's system config rather than a `GIT_CONFIG_*` entry because tools that filter their child's env strip those. Hugo, for example, passes git only the variables its `security.exec.osEnv` allowlist matches, and that has no `GIT_*` pattern ([#211](https://github.com/gatezh/devcontainers/issues/211)).

| Key | Value | Why |
|-----|-------|-----|
| `url.https://github.com/.insteadOf` | `git@github.com:` | Sends SSH-style GitHub remotes over HTTPS inside the container. The remotes themselves and the host's SSH setup don't change. |
| `credential.https://github.com.helper` | *(empty)* | Clears the helper list for github.com, including the helper VS Code injects, which answers with the host's possibly stale GitHub credential. Other hosts keep VS Code's helper. |
| `credential.https://github.com.helper` | `!gh auth git-credential` | Authenticates github.com through the container's `gh` login. The empty entry and this one are what `gh auth setup-git` writes. |

**One-time setup:** run `gh auth login` in the default variant. The login lives on its `myproject-gh-config-*` volume, so it survives rebuilds. The sandbox has its own volume ([why](#why-the-variants-dont-share-volumes)): there, sign in with a [fine-grained token](https://github.com/settings/personal-access-tokens) limited to the project's repository (run `gh auth login --with-token`, paste the token, and press Ctrl-D; don't save it to a file under `/workspace`, which is your host repo). After that, fetch, pull and push work from the terminal and from VS Code for both `https://github.com/` and `git@github.com:` remotes.

To check what git sees, run `git config --show-scope --get-regexp 'safe|insteadof|credential'`. The table's entries are listed with scope `command` and `safe.directory` with scope `system`. To add your own entries, append `GIT_CONFIG_KEY_3` / `GIT_CONFIG_VALUE_3` and so on, and raise `GIT_CONFIG_COUNT` to match.

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
| `@playwright/mcp` | nothing (image env) | Image sets `PLAYWRIGHT_MCP_BROWSER`, `PLAYWRIGHT_MCP_EXECUTABLE_PATH` and `PLAYWRIGHT_MCP_HEADLESS`. See [Playwright MCP plugin](#playwright-mcp-plugin) below. |
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

The `playwright@claude-plugins-official` plugin starts `npx @playwright/mcp@latest`
with no arguments, and `@playwright/mcp` defaults to the `chrome` channel
(`/opt/google/chrome/chrome`), which the image does not ship. Every
`@playwright/mcp` command-line option also has an environment variable, and
Claude Code starts stdio MCP servers with its own environment, so the image sets:

| Variable | Value | Replaces |
|---|---|---|
| `PLAYWRIGHT_MCP_BROWSER` | `chromium` | `--browser chromium` |
| `PLAYWRIGHT_MCP_EXECUTABLE_PATH` | `/usr/bin/chromium` | `--executable-path /usr/bin/chromium` |
| `PLAYWRIGHT_MCP_HEADLESS` | `true` | `--headless` |

The `chromium` channel already runs without Chromium's sandbox on Linux, so there's
no `--no-sandbox` equivalent to set. The plugin's `.mcp.json` stays exactly as
upstream ships it, so plugin auto-updates can't undo the configuration.

**Upgrading from an image with `patch-playwright-mcp`:** earlier images rewrote
each cached `.mcp.json` with a `patch-playwright-mcp` script, run from
`postStartCommand`, `init-plugins.sh` and a SessionStart hook. Remove the calls
from your `devcontainer.json` and `init-plugins.sh`. Until 2027-01-31 the image
keeps a no-op at `/usr/local/bin/patch-playwright-mcp`, so old calls still succeed.
A `.mcp.json` the script already rewrote passes the same settings as flags, which
take precedence over the env vars, and the next plugin update restores the original.

## Build Args

Current values live in [the Dockerfile](.devcontainer/Dockerfile) and are not repeated
here — Renovate bumps several of them weekly, so any number written below would be wrong
more often than right.

| Arg | Updated by | Description |
|-----|------------|-------------|
| `RALPHEX_VERSION` | Renovate | ralphex |
| `ACTIONLINT_VERSION` | Renovate | actionlint |
| `SHELLCHECK_VERSION` | Renovate | shellcheck |
| `CLAUDE_CODE_VERSION` | Renovate | Claude Code CLI |
| `AGENT_BROWSER_VERSION` | Renovate | agent-browser |
| `GH_VERSION` | Renovate | GitHub CLI — from the upstream `.deb`, not apt (trixie freezes gh at 2.46.0) |
| `GH_STACK_VERSION` | Renovate | gh-stack extension (`gh stack`) |
| `CF_VERSION` | Renovate | Cloudflare CLI (`cf`), open beta; releases wait 3 days before auto-merge |
| `ALPINE_VERSION` | Renovate | Alpine base of the download stages; no final image is built on it |
| `OH_MY_ZSH_REF` | by hand | oh-my-zsh, pinned to a commit SHA |
| `POWERLEVEL10K_REF` | by hand | powerlevel10k, pinned to a commit SHA |

The Renovate-managed args carry `# renovate:` annotations in the Dockerfile; edit them by
hand only for a local build. Minor and patch bumps land as auto-merged PRs, majors wait for review —
see [Automatic Rebuilds](#automatic-rebuilds).

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

# Run the checks CI runs (use "sandbox" for the sandbox image)
docker run --rm -v "$PWD/verify-image.sh:/verify-image.sh:ro" claude-code:local bash /verify-image.sh default
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
