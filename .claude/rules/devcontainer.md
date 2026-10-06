---
paths:
  - "**/devcontainer.json"
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
