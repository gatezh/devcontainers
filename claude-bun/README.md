# devcontainer-claude-bun

Claude Code development container based on the [official Anthropic devcontainer configuration](https://github.com/anthropics/claude-code/tree/main/.devcontainer), using Bun as the JavaScript runtime.

## Features

- **Bun runtime** (slim Debian-based image) for fast JavaScript/TypeScript execution
- **Claude Code CLI** pre-installed globally via `bun add -g`
- **Security by design** with custom firewall restricting network access to necessary services only
- **Developer-friendly tools**: git, ZSH with Powerline10k theme, fzf, vim, nano, git-delta
- **VS Code integration** with pre-configured extensions (Claude Code, Bun, Biome, Tailwind CSS)
- **Session persistence** for command history and Claude configuration between restarts
- **Multi-platform support** (linux/amd64, linux/arm64)

## Quick Start

### Using the pre-built image

Add to your project's `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/gatezh/devcontainer-claude-bun:latest",
  "runArgs": [
    "--cap-add=NET_ADMIN",
    "--cap-add=NET_RAW"
  ],
  "remoteUser": "bun",
  "mounts": [
    "source=claude-code-bashhistory-${devcontainerId},target=/commandhistory,type=volume",
    "source=claude-code-config-${devcontainerId},target=/home/bun/.claude,type=volume"
  ],
  "containerEnv": {
    "CLAUDE_CONFIG_DIR": "/home/bun/.claude"
  },
  "postStartCommand": "sudo /usr/local/bin/init-firewall.sh"
}
```

### Building locally

1. Copy the `.devcontainer` folder to your project
2. Open in VS Code
3. When prompted, click "Reopen in Container" (or use Command Palette: `Cmd+Shift+P` → "Dev Containers: Reopen in Container")

## Security Features

The container implements a **default-deny firewall policy** that only allows connections to:

| Service | Purpose |
|---------|---------|
| GitHub (web, API, git) | Version control, package downloads |
| npm registry | Package installation |
| Anthropic API | Claude Code functionality |
| Sentry | Error reporting |
| Statsig | Feature flags |
| VS Code services | Extension marketplace, updates |

All other outbound network connections are blocked.

### Important Security Note

When executed with `--dangerously-skip-permissions`, devcontainers do **not prevent a malicious project from exfiltrating anything accessible in the container**, including Claude Code credentials.

**Recommendation**: Only use devcontainers when developing with trusted repositories.

## Configuration Files

| File | Description |
|------|-------------|
| `Dockerfile` | Container image definition |
| `devcontainer.json` | VS Code devcontainer settings |
| `init-firewall.sh` | Firewall initialization script |

## Image Tags

- `ghcr.io/gatezh/devcontainer-claude-bun:latest` - Latest build
- `ghcr.io/gatezh/devcontainer-claude-bun:bun1.3.5-slim` - Bun version specific tag

## Customization

### Adding VS Code extensions

Edit `devcontainer.json` and add extension IDs to `customizations.vscode.extensions`.

### Modifying allowed domains

Edit `init-firewall.sh` to add domains to the allowlist in the `for domain in` loop.

### Changing Bun version

Edit the `BUN_VERSION` ARG in the Dockerfile.

## Resources

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Official devcontainer reference](https://github.com/anthropics/claude-code/tree/main/.devcontainer)
- [Bun Documentation](https://bun.sh/docs)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
