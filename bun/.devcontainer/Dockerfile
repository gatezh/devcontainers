ARG BUN_VERSION=1.3.5

FROM oven/bun:${BUN_VERSION}-alpine

# Install dependencies:
# - ca-certificates: Required for HTTPS connections
# - git: Version control
# - zsh: Better shell for development (VS Code shell integration, modern features)
RUN apk add --no-cache \
    ca-certificates \
    git \
    zsh

# OCI labels for container metadata and GitHub Package integration
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images"
LABEL org.opencontainers.image.description="Bun development container - multiplatform image for modern JavaScript/TypeScript development"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="devcontainer-bun"
LABEL org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"
