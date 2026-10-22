---
paths:
  - "**/devcontainer.json"
  - "**/docker-compose.yml"
---

# devcontainer.json Conventions

## File Header

```jsonc
// For format details, see https://aka.ms/devcontainer.json. For config options, see the
// README at: {relevant-reference-url}
```

## Comments

Skip a comment that only repeats the line below it in other words, such as `// Show workspace folder name in window title` above `"window.title"`. Extension descriptions are not that: they say what an extension ID does.

## node_modules Mount

Always include to keep node_modules off the host:

```jsonc
"mounts": [
  "source=${localWorkspaceFolderBasename}-node_modules,target=${containerWorkspaceFolder}/node_modules,type=volume"
]
```

## Sandbox Volumes

The `claude-code` sandbox shares no volume with the default variant: not `~/.claude`, `~/.config/gh`, `~/.config/cloudflare`, shell history, or `node_modules`. A volume both mount lets the sandbox agent, which runs with prompts skipped, plant user-scope hooks or `bypassPermissions` that run in the default variant (full sudo, no firewall), and hands it the gh and cf logins. This was decided in #239; the reasons are in `claude-code/README.md` "Why the variants don't share volumes". Treat a change that shares one as a security regression, not a convenience fix.

## VS Code Extensions

Group by category with header comments:

```jsonc
"extensions": [
  // **Category Name**
  // Extension Description
  "publisher.extension-id"
]
```

Common categories: `**Claude Code**`, `**Bun**`, `**Code Quality**` (OXC), `**Git**` (GitLens), `**Tailwind**`, `**Hugo**`

## Required VS Code Settings

```jsonc
"settings": {
  "terminal.integrated.defaultProfile.linux": "zsh",
  "extensions.ignoreRecommendations": true
}
```
