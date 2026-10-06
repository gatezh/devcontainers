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

Comment only what the JSON can't say: a reason, a constraint, an issue number, or what a template adopter must change. A comment that restates the key below it (`// Show workspace folder name in window title` above `"window.title"`) is noise; leave it out.

## node_modules Mount

Always include to keep node_modules off the host:

```jsonc
"mounts": [
  "source=${localWorkspaceFolderBasename}-node_modules,target=${containerWorkspaceFolder}/node_modules,type=volume"
]
```

## VS Code Extensions

Group by category with a header comment. No per-extension description: the ID names the extension.

```jsonc
"extensions": [
  // **Category Name**
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
