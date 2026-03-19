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
| OS | `node:22-trixie-slim` + system packages | Node is needed during the build (Playwright, npm globals) |
| Shell | Fish, Starship, fzf | Built-in syntax highlighting, autosuggestions, completions |
| Tools | git-delta, gh CLI, jq, nano, vim, wget, unzip, less, man-db, procps | Standard dev utilities |
| Mise | The tool manager itself (not the tools) | Projects run `mise install` at container creation for their tool versions |
| Claude Code | Native CLI installer | Binary copied to `/usr/local/bin/` to survive volume mounts |
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

The image rebuilds daily at 5am MT (11:00 UTC). Cached layers (system packages, Playwright) are reused for speed, while Claude Code and agent-browser always install fresh via a cache-busting build arg. Manual rebuilds can be triggered via the "Run workflow" button in the Actions UI.

## Quick Start

### Default variant

Add to your project's `.devcontainer/devcontainer.json`:

```jsonc
{
  "name": "Local Development",
  "image": "ghcr.io/gatezh/devcontainer-images/claude-code:latest",
  "init": true,
  "remoteUser": "node",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind",
  "workspaceFolder": "/workspace",
  // Named volumes persist node_modules, Claude config, and fish history across rebuilds.
  // Dirs are pre-created in the image with node:node ownership, so fresh volumes
  // inherit correct permissions via Docker volume population.
  "mounts": [
    "source=myproject-node-modules-${devcontainerId},target=/workspace/node_modules,type=volume",
    "source=myproject-claude-config-${devcontainerId},target=/home/node/.claude,type=volume",
    "source=myproject-fish-data-${devcontainerId},target=/home/node/.local/share/fish,type=volume"
  ],
  "containerEnv": {
    "TZ": "${localEnv:TZ:America/Los_Angeles}",
    "DEVCONTAINER": "true",
    "NODE_OPTIONS": "--max-old-space-size=4096",
    "CLAUDE_CONFIG_DIR": "/home/node/.claude"
  },
  // mise install reads .mise.toml and installs project-specific tool versions.
  // sudo chown fixes volume ownership — safety net in case Docker volume population didn't apply.
  "updateContentCommand": "sudo chown node /workspace/node_modules && sudo chown -R node /home/node/.claude && mise install && bun install",
  "waitFor": "postCreateCommand"
}
```

### Sandbox variant

```jsonc
{
  "name": "Claude Sandbox",
  "image": "ghcr.io/gatezh/devcontainer-images/claude-code-sandbox:latest",
  // Capabilities required for iptables firewall setup
  "capAdd": ["NET_ADMIN", "NET_RAW"],
  "init": true,
  "remoteUser": "node",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind",
  "workspaceFolder": "/workspace",
  "mounts": [
    "source=sandbox-fish-${devcontainerId},target=/home/node/.local/share/fish,type=volume",
    "source=sandbox-config-${devcontainerId},target=/home/node/.claude,type=volume",
    // Mount project's firewall script into the expected path.
    // The image provides iptables/ipset packages and sudo rule but NOT the script itself.
    "source=${localWorkspaceFolder}/.devcontainer/claude-sandbox/init-firewall.sh,target=/usr/local/bin/init-firewall.sh,type=bind"
  ],
  "containerEnv": {
    "TZ": "${localEnv:TZ:America/Los_Angeles}",
    "DEVCONTAINER": "true",
    "NODE_OPTIONS": "--max-old-space-size=4096",
    "CLAUDE_CONFIG_DIR": "/home/node/.claude"
  },
  "postCreateCommand": "mise install",
  // Firewall init — script is bind-mounted from the project
  "postStartCommand": "sudo /usr/local/bin/init-firewall.sh",
  "waitFor": "postStartCommand"
}
```

## Project Setup Guide

Projects consuming these images need the following files in their repository.

### Required: `.mise.toml` (project root)

Each project defines its own tool versions:

```toml
[tools]
bun = "1.3.8"
# node is provided by the base image (node:22-trixie-slim).
# This entry is for CI environments where the base image isn't available.
# Inside the devcontainer, mise detects Node is already on $PATH and skips installation.
node = "22"
```

### Optional: `.devcontainer/init-plugins.sh`

Claude Code plugin initialization. Runs once at container creation. Idempotent.
Wire it into `postCreateCommand` in your `devcontainer.json`:

```jsonc
"postCreateCommand": "bash .devcontainer/init-plugins.sh"
```

```bash
#!/bin/bash
set -euo pipefail

# Mark onboarding complete so claude CLI doesn't hang on interactive prompts
if [ -f "$HOME/.claude/.claude.json" ]; then
    jq '.hasCompletedOnboarding = true' "$HOME/.claude/.claude.json" > /tmp/.claude.json \
        && mv /tmp/.claude.json "$HOME/.claude/.claude.json"
else
    mkdir -p "$HOME/.claude"
    echo '{"hasCompletedOnboarding":true}' > "$HOME/.claude/.claude.json"
fi

# Install plugins (customize this list)
for plugin in \
    "frontend-design@claude-plugins-official" \
    "code-review@claude-plugins-official"; do
    claude plugin install "$plugin" 2>/dev/null || true
done
```

Mark as executable: `chmod +x init-plugins.sh`

### Sandbox-only: `.devcontainer/claude-sandbox/init-firewall.sh`

Default-deny iptables firewall. The image provides the packages and sudo rule; the project provides this script via bind mount. Customize the domain allowlist for your project.

See the [devcontainer-claude-bun firewall script](../devcontainer-claude-bun/.devcontainer/init-firewall.sh) for a complete example.

Mark as executable: `chmod +x init-firewall.sh`

### Sandbox-only: `.devcontainer/claude-sandbox/.env.example`

Template for sandbox authentication:

```bash
# Claude Code authentication
# Generate a token with: claude setup-token
# Copy this file to .env.local and fill in your token:
#   cp .env.example .env.local
CLAUDE_CODE_OAUTH_TOKEN=your-token-here
```

Add `.env.local` to `.gitignore`.

### Complete file structure

```
.devcontainer/
├── devcontainer.json              ← default devcontainer
├── init-plugins.sh                ← Claude Code plugin setup (optional)
└── claude-sandbox/
    ├── devcontainer.json          ← sandbox devcontainer
    ├── init-firewall.sh           ← firewall script (customize domain allowlist)
    ├── .env.example               ← template for auth token
    └── .env.local                 ← actual auth token (gitignored)
```

## Workspace Directory Layout

The image pre-creates these directories with `node:node` ownership so Docker's volume population seeds fresh named volumes with correct permissions:

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

If your project has additional services, create volume mounts in `devcontainer.json` — Docker creates directories at container start. The `sudo chown` in `updateContentCommand` fixes ownership.

## Playwright Version Strategy

The image bakes in a Playwright browser binary at a specific version (controlled by the `PLAYWRIGHT_VERSION` build arg). Daily rebuilds keep this reasonably current.

- If your project's `@playwright/test` version **matches** the image — zero startup cost, browser is ready
- If your project's version **differs** — Playwright auto-downloads the correct browser on first test run (~10s graceful fallback)
- This is a **best-effort optimization**, not a hard contract

## Build Args

| Arg | Default | Description |
|-----|---------|-------------|
| `GIT_DELTA_VERSION` | `0.18.2` | git-delta version |
| `PLAYWRIGHT_VERSION` | `1.58.2` | Playwright browser binary version |
| `AGENT_BROWSER_VERSION` | `latest` | agent-browser version (default target only) |

## Building Locally

```bash
# Default variant
docker build --target default -t claude-code:default .devcontainer

# Sandbox variant
docker build --target sandbox -t claude-code:sandbox .devcontainer

# Multi-platform
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target default \
  -t ghcr.io/gatezh/devcontainer-images/claude-code:latest \
  --push \
  .devcontainer
```

## Startup Timeline

### Warm start (Playwright version matches image)
```
Pull image ───────────────────── (cached)
mise install (bun, hugo, etc.) ─ (~15s, downloads pre-built binaries)
bun install ─────────────────── (~15s, cached in named volume)
project setup ───────────────── (db:migrate, init-plugins, etc.)
                                 Total: ~45s warm
```

### Playwright version mismatch
```
Same as above. First test run triggers browser download (~10s, one-time).
Not a blocking startup cost — tests work, just slightly slower first run.
```

## Resources

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Mise Documentation](https://mise.jdx.dev/)
- [Docker Volume Population](https://docs.docker.com/engine/storage/volumes/#populate-a-volume-using-a-container)
