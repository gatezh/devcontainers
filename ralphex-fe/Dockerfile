ARG BUN_VERSION=1.3.9
ARG HUGO_VERSION=0.156.0
ARG RALPHEX_VERSION=0.20.0
ARG RTK_VERSION=0.26.0

# Cross-compile RTK on native amd64 to avoid slow QEMU-emulated Rust builds.
# --platform=linux/amd64 forces native execution; TARGETARCH selects the cross-compilation target.
# Using Debian for easy access to aarch64 cross-compilation toolchain.
FROM --platform=linux/amd64 rust:slim-bookworm AS rtk-builder
ARG RTK_VERSION
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends \
    musl-tools gcc-aarch64-linux-gnu libc6-dev-arm64-cross \
    && rm -rf /var/lib/apt/lists/*
RUN rustup target add x86_64-unknown-linux-musl aarch64-unknown-linux-musl
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=aarch64-linux-gnu-gcc && \
      export CC_aarch64_unknown_linux_musl=aarch64-linux-gnu-gcc && \
      export CFLAGS_aarch64_unknown_linux_musl="--sysroot=/usr/aarch64-linux-gnu" && \
      cargo install --git https://github.com/rtk-ai/rtk.git --tag "v${RTK_VERSION}" --locked \
        --target aarch64-unknown-linux-musl; \
    else \
      cargo install --git https://github.com/rtk-ai/rtk.git --tag "v${RTK_VERSION}" --locked \
        --target x86_64-unknown-linux-musl; \
    fi

# Extend the ralphex base image which provides the ralphex binary at /srv/ralphex
# along with Claude Code, Codex, Node.js, git, ripgrep, and other development tools
FROM ghcr.io/umputun/ralphex:${RALPHEX_VERSION}

ARG BUN_VERSION
ARG HUGO_VERSION

# Platform architecture (automatically set by Docker based on build platform)
ARG TARGETARCH

# Install dependencies:
# - ca-certificates: Required for HTTPS connections
# - chromium: System Chromium browser for Playwright tests (Alpine/musl-native, avoids Playwright's
#             bundled binary which requires glibc/Debian)
# - ttf-freefont: TrueType fonts required for Chromium text rendering in headless/screenshot mode
# - curl: Required by Bun install script
# - gcompat: glibc compatibility layer required for Hugo Extended binary (Alpine uses musl)
# - go: Required for Hugo Modules to download and manage dependencies (e.g., PaperMod theme)
# - unzip: Required by Bun install script on Linux
# - wget: Required to download Hugo Extended binary
RUN apk add --no-cache ca-certificates chromium curl gcompat go ttf-freefont unzip wget

# Playwright environment variables:
# - PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD: Prevents Playwright's postinstall from attempting to
#   download its bundled Chromium binary (which requires glibc and is incompatible with Alpine/musl).
# - PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH: Custom env var that projects can reference in
#   playwright.config.ts via executablePath. NOTE: Playwright does NOT read this automatically -
#   you must wire it up manually (e.g. executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH).
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Install Bun using official install script
# BUN_INSTALL sets the installation directory
ENV BUN_INSTALL=/usr/local/bun
ENV PATH="$BUN_INSTALL/bin:$PATH"

RUN curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}" && \
    bun --version

# Install Hugo Extended by downloading pre-built binary with checksum verification
RUN set -eux; \
    wget -O hugo.tar.gz "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-${TARGETARCH}.tar.gz"; \
    wget -O hugo_checksums.txt "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_checksums.txt"; \
    EXPECTED_CHECKSUM=$(grep "hugo_extended_${HUGO_VERSION}_linux-${TARGETARCH}.tar.gz" hugo_checksums.txt | cut -d' ' -f1); \
    if [ -z "$EXPECTED_CHECKSUM" ]; then \
        echo "Error: Could not find checksum for hugo_extended_${HUGO_VERSION}_linux-${TARGETARCH}.tar.gz"; \
        exit 1; \
    fi; \
    ACTUAL_CHECKSUM=$(sha256sum hugo.tar.gz | cut -d' ' -f1); \
    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then \
        echo "Checksum verification failed for Hugo!"; \
        echo "Expected: $EXPECTED_CHECKSUM"; \
        echo "Actual:   $ACTUAL_CHECKSUM"; \
        exit 1; \
    fi; \
    echo "Hugo checksum verified: $ACTUAL_CHECKSUM"; \
    tar -xzf hugo.tar.gz -C /usr/local/bin/ hugo; \
    rm hugo.tar.gz hugo_checksums.txt; \
    hugo version

# Copy RTK binary built from source in the builder stage
COPY --from=rtk-builder /usr/local/cargo/bin/rtk /usr/local/bin/rtk
RUN rtk --version

# OCI labels for container metadata and GitHub Package integration
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images"
LABEL org.opencontainers.image.description="Ralphex-fe: Frontend development image with Bun, Hugo Extended, Chromium, and Ralphex"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="ralphex-fe"
LABEL org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"
