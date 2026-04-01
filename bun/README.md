# devcontainer-bun

A multiplatform development container image with Bun runtime, optimized for modern JavaScript/TypeScript development workflows.

## Features

- **Bun Runtime** - Fast JavaScript runtime, bundler, and package manager
- **Git** - Version control
- **Zsh** - Modern shell with better VS Code integration
- **Alpine Linux** - Lightweight base image

## Multiplatform Support

This image is built for multiple architectures:
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM64/Apple Silicon)

## Building the Image

To build this multiplatform image, use Docker Buildx:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/<USERNAME>/devcontainer-bun:bun<BUN_VERSION>-alpine \
  -t ghcr.io/<USERNAME>/devcontainer-bun:latest \
  --push \
  .devcontainer
```

### Example with specific versions:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/myusername/devcontainer-bun:bun1.3.5-alpine \
  -t ghcr.io/myusername/devcontainer-bun:latest \
  --push \
  .devcontainer
```

**Replace:**
- `<USERNAME>` with your GitHub username or organization
- `<BUN_VERSION>` with the Bun version (e.g., `1.3.5`)

**Note:** The `--push` flag requires you to be logged in to GitHub Container Registry:
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <USERNAME> --password-stdin
```

## Usage

### In Your Project's devcontainer.json

When using this pre-built image, replace the `dockerFile` property with the `image` property:

```json
{
  "name": "My Bun Project",
  "image": "ghcr.io/<USERNAME>/devcontainer-bun:latest"
}
```

**Note:** If you were previously using a local Dockerfile, change from:
```json
{
  "dockerFile": "Dockerfile"
}
```
to:
```json
{
  "image": "ghcr.io/<USERNAME>/devcontainer-bun:latest"
}
```

### With Specific Version Tag

```json
{
  "name": "My Bun Project",
  "image": "ghcr.io/<USERNAME>/devcontainer-bun:bun1.3.5-alpine"
}
```

## Included VS Code Extensions

The development container comes pre-configured with the following extensions:

### Core Development
- **Claude Code** (`anthropic.claude-code`) - AI-powered coding assistant
- **Bun for Visual Studio Code** (`oven.bun-vscode`) - Bun language support
- **Prettier** (`esbenp.prettier-vscode`) - Code formatter

### Tailwind CSS
- **Tailwind CSS IntelliSense** (`bradlc.vscode-tailwindcss`) - Autocomplete and syntax highlighting
- **Tailwind Fold** (`stivo.tailwind-fold`) - Fold long Tailwind class strings

## Version Information

The image uses a specific version of Bun defined as a build argument:

- **Bun Version**: Specified via `BUN_VERSION` build arg (default: `1.3.5`)
- **Base Image**: `oven/bun:${BUN_VERSION}-alpine`

### Updating Versions

To build with a different version, use build arguments:

```bash
docker buildx build \
  --build-arg BUN_VERSION=1.4.0 \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/<USERNAME>/devcontainer-bun:bun1.4.0-alpine \
  --push \
  .devcontainer
```

## Development Workflow

### Starting the Dev Container

1. Open your project in VS Code
2. Press `F1` and select "Dev Containers: Reopen in Container"
3. VS Code will pull the image and start the container

### Using Bun

```bash
# Install dependencies
bun install

# Run scripts
bun run build

# Execute files
bun run index.ts

# Start development server
bun run dev
```

## License

This image configuration is part of the devcontainer-images repository.

## Contributing

Contributions are welcome! Please ensure:
1. Version numbers are clearly documented
2. Build instructions are tested on both amd64 and arm64
3. README is updated with any new features or dependencies
