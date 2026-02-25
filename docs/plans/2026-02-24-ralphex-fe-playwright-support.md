# Add Playwright Support to ralphex-fe

## Overview
- Add Chromium and jq to the ralphex-fe container image so Claude Code (running via ralphex) can execute Playwright tests inside the container
- Chromium installed via Alpine's `apk` package manager, with `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` env var pointing Playwright to the system browser
- jq added for JSON processing (useful for agent workflows parsing configs, API responses, package.json)
- Keeps Alpine base — no base image change needed

## Context (from discovery)
- Files/components involved:
  - `ralphex-fe/Dockerfile` — main change (add packages + env var)
  - `ralphex-fe/README.md` — document new capabilities
  - `.github/workflows/build-ralphex-fe.yml` — may need verification step update
- Related patterns found:
  - Template (`remotes/template/master`) uses Playwright with `install-deps` + `--only-shell` on Debian
  - Alpine approach differs: `apk add chromium` + env var override instead
  - ralphex base image already provides Node.js, Claude Code, git, ripgrep
- Dependencies identified:
  - Alpine `chromium` package pulls in necessary dependencies (nss, freetype, harfbuzz, etc.) automatically
  - No version pinning needed — Alpine repo tracks stable Chromium releases

## Development Approach
- **Testing approach**: Regular (code first, then verify)
- Complete each task fully before moving to the next
- Make small, focused changes
- **CRITICAL: verify the image builds and tools work after each change**
- Run builds after each change
- Maintain backward compatibility (existing Bun + Hugo functionality must not break)

## Testing Strategy
- **Build verification**: Docker build must succeed for both platforms (amd64, arm64)
- **Runtime verification**: Built image must have `chromium-browser`, `jq`, and the env var set correctly
- **Backwards compatibility**: Existing tools (bun, hugo, curl, wget, go) must still work

## Progress Tracking
- Mark completed items with `[x]` immediately when done
- Add newly discovered tasks with ➕ prefix
- Document issues/blockers with ⚠️ prefix
- Update plan if implementation deviates from original scope

## Implementation Steps

### Task 1: Add Chromium and jq to ralphex-fe Dockerfile
- [x] Add `chromium` and `jq` to the existing `apk add` line in `ralphex-fe/Dockerfile`
- [x] Add `ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser` after the apk install
- [x] Add comments explaining why each new package is added (following existing comment style)
- [x] Verify Dockerfile syntax is valid (no broken lines, correct ordering)

### Task 2: Build and verify the image locally
- [x] Build the image locally for current platform: `docker build -t ralphex-fe:test ralphex-fe/`
- [x] Verify Chromium is available: `docker run --rm ralphex-fe:test chromium-browser --version`
- [x] Verify jq is available: `docker run --rm ralphex-fe:test jq --version`
- [x] Verify env var is set: `docker run --rm ralphex-fe:test sh -c 'echo $PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH'`
- [x] Verify existing tools still work: bun, hugo, curl, wget
- [x] Clean up test image

### Task 3: Update ralphex-fe README
- [x] Add Chromium/Playwright to the features list
- [x] Add jq to the features list
- [x] Add a section explaining Playwright usage (env var, how to run tests)

### Task 4: Verify acceptance criteria
- [x] Chromium is installed and accessible at `/usr/bin/chromium-browser`
- [x] `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` env var is set correctly
- [x] jq is installed and working
- [x] All existing tools (bun, hugo, go, curl, wget) still work
- [x] Dockerfile follows existing comment and formatting conventions
- [x] README accurately documents new capabilities

## Technical Details

### Dockerfile change (in `ralphex-fe/Dockerfile`)

Current apk line:
```dockerfile
RUN apk add --no-cache ca-certificates curl gcompat go unzip wget
```

New apk line:
```dockerfile
RUN apk add --no-cache ca-certificates chromium curl gcompat go jq unzip wget
```

New env var (after apk install, before Bun install):
```dockerfile
# Tell Playwright to use system Chromium instead of downloading its own binary
# (Playwright's built-in browser download doesn't work on Alpine/musl)
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

### Why system Chromium instead of Playwright's installer
- Playwright's `install-deps` and `install --only-shell` require Debian/Ubuntu (glibc)
- Alpine uses musl libc — Playwright's pre-built Chromium binaries are incompatible
- Alpine's `apk add chromium` provides a musl-native Chromium that works correctly
- `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` env var tells Playwright to skip its own download and use the system browser

## Post-Completion

**Manual verification** (if applicable):
- Test with an actual Playwright test suite in a project that uses this image
- Verify multi-platform build works in GitHub Actions (amd64 + arm64)
- Chromium on arm64 Alpine — verify the package is available and functional
