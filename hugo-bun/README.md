# devcontainer-hugo-bun

A multiplatform development container image combining Hugo Extended and Bun runtime, optimized for modern static site development workflows.

## 🌟 Features

- **Hugo Extended** - Full-featured static site generator with extended capabilities
- **Bun Runtime** - Fast JavaScript runtime, bundler, and package manager
- **Go** - Required for Hugo Modules dependency management
- **Git** - Version control
- **Zsh** - Modern shell with better VS Code integration
- **Alpine Linux** - Lightweight base image with glibc compatibility (gcompat)

## 🏗️ Multiplatform Support

This image is built for multiple architectures:
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM64/Apple Silicon)

## 📦 Building the Image

To build this multiplatform image, use Docker Buildx:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/<USERNAME>/devcontainer-hugo-bun:hugo<HUGO_VERSION>-bun<BUN_VERSION>-alpine \
  -t ghcr.io/<USERNAME>/devcontainer-hugo-bun:latest \
  --push \
  .devcontainer
```

### Example with specific versions:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/myusername/devcontainer-hugo-bun:hugo0.152.2-bun1.3.2-alpine \
  -t ghcr.io/myusername/devcontainer-hugo-bun:latest \
  --push \
  .devcontainer
```

**Replace:**
- `<USERNAME>` with your GitHub username or organization
- `<HUGO_VERSION>` with the Hugo version (e.g., `0.152.2`)
- `<BUN_VERSION>` with the Bun version (e.g., `1.3.2`)

**Note:** The `--push` flag requires you to be logged in to GitHub Container Registry:
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <USERNAME> --password-stdin
```

## 🚀 Usage

### In Your Project's devcontainer.json

When using this pre-built image, replace the `dockerFile` property with the `image` property:

```json
{
  "name": "My Hugo Project",
  "image": "ghcr.io/<USERNAME>/devcontainer-hugo-bun:latest"
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
  "image": "ghcr.io/<USERNAME>/devcontainer-hugo-bun:latest"
}
```

### With Specific Version Tag

```json
{
  "name": "My Hugo Project",
  "image": "ghcr.io/<USERNAME>/devcontainer-hugo-bun:hugo0.152.2-bun1.3.2-alpine"
}
```

## 🔧 Included VS Code Extensions

The development container comes pre-configured with the following extensions:

### Core Development
- **Claude Code** (`anthropic.claude-code`) - AI-powered coding assistant
- **Bun for Visual Studio Code** (`oven.bun-vscode`) - Bun language support
- **Prettier** (`esbenp.prettier-vscode`) - Code formatter

### Tailwind CSS
- **Tailwind CSS IntelliSense** (`bradlc.vscode-tailwindcss`) - Autocomplete and syntax highlighting
- **Tailwind Fold** (`stivo.tailwind-fold`) - Fold long Tailwind class strings

### Hugo
- **Hugofy** (`akmittal.hugofy`) - Hugo-related utilities
- **Language Hugo VSCode** (`budparr.language-hugo-vscode`) - Hugo language support
- **Hugo Shortcode Syntax** (`kaellarkin.hugo-shortcode-syntax`) - Syntax highlighting for Hugo shortcodes

## 📋 Version Information

The image uses specific versions of Hugo and Bun defined as build arguments:

- **Hugo Version**: Specified via `HUGO_VERSION` build arg (default: `0.152.2`)
- **Bun Version**: Specified via `BUN_VERSION` build arg (default: `1.3.2`)
- **Base Image**: `oven/bun:${BUN_VERSION}-alpine`

### Updating Versions

To build with different versions, use build arguments:

```bash
docker buildx build \
  --build-arg HUGO_VERSION=0.153.0 \
  --build-arg BUN_VERSION=1.4.0 \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/<USERNAME>/devcontainer-hugo-bun:hugo0.153.0-bun1.4.0-alpine \
  --push \
  .devcontainer
```

## ⚠️ Important Notes

### GitHub Actions Integration

If you use this image with GitHub Actions for deployment, ensure version consistency:

1. The Hugo and Bun versions in the Dockerfile are documented with comments
2. Update your GitHub Actions workflow (`.github/workflows/deploy.yml`) when changing versions
3. Both environments should use the same versions to avoid inconsistencies

Example comment in Dockerfile:
```dockerfile
# ℹ️ Same version is used in GitHub Actions deployment (.github/workflows/deploy.yml)
# ⚠️ Remember to update GitHub Actions workflow if changing it here
ARG HUGO_VERSION=0.152.2
```

### gcompat Requirement

Hugo Extended binary requires glibc, but Alpine Linux uses musl. The `gcompat` package provides compatibility:
```dockerfile
RUN apk add --no-cache gcompat
```

## 🛠️ Development Workflow

### Starting the Dev Container

1. Open your project in VS Code
2. Press `F1` and select "Dev Containers: Reopen in Container"
3. VS Code will pull the image and start the container

### Running Hugo

```bash
# Start Hugo development server
hugo server

# Build site
hugo build

# Create new content
hugo new posts/my-post.md
```

### Using Bun

```bash
# Install dependencies
bun install

# Run scripts
bun run build

# Execute files
bun run index.ts
```

## 📄 License

This image configuration is part of the devcontainer-images repository.

## 🤝 Contributing

Contributions are welcome! Please ensure:
1. Version numbers are clearly documented
2. Build instructions are tested on both amd64 and arm64
3. README is updated with any new features or dependencies
