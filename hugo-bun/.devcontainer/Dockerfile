ARG BUN_VERSION=1.3.8

FROM oven/bun:${BUN_VERSION}-alpine

ARG HUGO_VERSION=0.155.1

# Platform architecture (automatically set by Docker based on build platform)
ARG TARGETARCH

# Install dependencies:
# - ca-certificates: Required for HTTPS connections
# - gcompat: glibc compatibility layer required for Hugo Extended binary (Alpine uses musl)
# - git: Version control
# - go: Required for Hugo Modules to download and manage dependencies (e.g., PaperMod theme)
# - wget: Required to download Hugo Extended binary
# - zsh: Better shell for development (VS Code shell integration, modern features)
RUN apk add --no-cache \
    ca-certificates \
    git \
    gcompat \
    go \
    wget \
    zsh

# Install Hugo Extended
RUN set -eux; \
    wget -O hugo.tar.gz "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-${TARGETARCH}.tar.gz"; \
    tar -xzf hugo.tar.gz -C /usr/local/bin/ hugo; \
    rm hugo.tar.gz; \
    hugo version

# OCI labels for container metadata and GitHub Package integration
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images"
LABEL org.opencontainers.image.description="Hugo Extended + Bun development container - multiplatform image for modern static site development"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="devcontainer-hugo-bun"
LABEL org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"
