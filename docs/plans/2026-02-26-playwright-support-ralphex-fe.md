# Playwright Support for ralphex-fe

## Overview
- Add Playwright/Chromium support to the ralphex-fe Docker image for end-to-end testing
- Adapt the template's proven Playwright approach for Alpine/musl (system Chromium instead of Playwright's bundled glibc binary)
- Simplify image tags to use only the ralphex version (e.g., `0.11.0`)
- Fix sed delimiter safety issue in the update workflow

## Context (from discovery)
- **Base image**: `ghcr.io/umputun/ralphex` (Alpine/musl) — cannot change
- **Template reference**: `template/master` branch uses Debian + `playwright install-deps` + `playwright install --only-shell`
- **Alpine constraint**: Playwright's bundled Chromium requires glibc, so we use Alpine's native `chromium` package instead
- **Starting point**: Reset `super-devcontainer` branch to `master`, build cleanly from there
- **Files involved**:
  - `ralphex-fe/Dockerfile` — add chromium, fonts, Playwright env vars
  - `ralphex-fe/README.md` — document Playwright usage, update tags/versions
  - `.github/workflows/build-ralphex-fe.yml` — simplify tags, add Playwright verification
  - `.github/workflows/update-and-build-ralphex-fe.yml` — simplify tags, fix sed delimiter, add verification

## Development Approach
- **Testing approach**: Regular (verify via static analysis and workflow YAML validation; no unit tests for Dockerfiles/workflows)
- Complete each task fully before moving to the next
- Make small, focused changes
- **CRITICAL: update this plan file when scope changes during implementation**
- Maintain backward compatibility with existing workflow dispatch inputs

## Progress Tracking
- Mark completed items with `[x]` immediately when done
- Add newly discovered tasks with ➕ prefix
- Document issues/blockers with ⚠️ prefix
- Update plan if implementation deviates from original scope
- Keep plan in sync with actual work done

## Implementation Steps

### Task 1: Reset branch to master
- [x] Run `git reset --hard master` to start fresh (discard existing 9 commits)
- [x] Verify branch is at master HEAD with `git log --oneline -1`

### Task 2: Update Dockerfile with Playwright support
- [x] Add `chromium` and `ttf-freefont` to the `apk add` line (with descriptive comments matching template style)
- [x] Add Playwright environment variables section after `apk add`:
  - `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` — prevent postinstall from downloading glibc binary
  - `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium-browser` — for project reference in playwright.config.ts
  - Include comment noting Playwright does NOT read this env var automatically
- [x] Update the image description label to mention Chromium
- [x] Verify Dockerfile syntax is valid (no trailing whitespace, proper line continuations)

### Task 3: Simplify image tags in build-ralphex-fe.yml
- [x] Change tag generation to use only ralphex version: `${RALPHEX_VERSION}` instead of `bun${BUN_VERSION}-hugo${HUGO_VERSION}-ralphex${RALPHEX_VERSION}`
- [x] Keep extracting all three versions (needed for logging) but tag only uses ralphex version
- [x] Add Playwright verification steps to the verify section (both amd64 and arm64):
  - Verify `chromium-browser --version`
  - Verify `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` env var is set correctly and binary is executable
  - Verify `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD` env var is `1`
  - Verify `ttf-freefont` font files exist
- [x] Validate YAML syntax

### Task 4: Update update-and-build-ralphex-fe.yml
- [x] Change tag generation to match build workflow (just ralphex version)
- [x] Fix sed delimiter from `/` to `|` for safety (prevents breakage if versions contain `/`)
- [x] Add same Playwright verification steps as build workflow
- [x] Validate YAML syntax

### Task 5: Update README.md
- [x] Update version numbers: Bun 1.3.9, Hugo 0.155.3 (matching current Dockerfile)
- [x] Add Chromium to Features list
- [x] Add "Using Playwright" section (following template's documentation style, adapted for Alpine):
  - Explain why system Chromium is used instead of Playwright's bundled binary
  - Show `playwright.config.ts` example with `executablePath` and sandbox flags
  - Show install command (`bun add -d @playwright/test`, NOT `playwright install`)
  - Show test run and verification commands
- [x] Update "Image Tags" section to show new format: `{ralphex-version}` (e.g., `0.11.0`)
- [x] Update "Building Locally" buildx example to use new tag format
- [x] Update "Version Information" section with RALPHEX_VERSION build arg

### Task 6: Verify all changes
- [x] Review all modified files for consistency
- [x] Verify Dockerfile comments match template's style (clear, explains "why")
- [x] Verify workflow YAML is valid (proper indentation, correct action versions)
- [x] Verify README examples use correct image name and tag format
- [x] Run `git diff` to review complete changeset

### Task 7: Update documentation
- [ ] Check if main README.md needs any updates for the new tag format
- [ ] Verify AGENTS.md conventions are followed (OCI labels, workflow patterns)

## Technical Details

### Alpine Playwright Adaptation (vs Template)

| Aspect | Template (Debian) | ralphex-fe (Alpine) |
|--------|-------------------|---------------------|
| Browser install | `playwright install-deps chromium` + `playwright install --only-shell` | `apk add chromium ttf-freefont` |
| libc | glibc (native) | musl (system chromium is musl-native) |
| Version tracking | From `package.json` devDependencies | System package (Alpine repo version) |
| Config needed | None (Playwright finds its own browser) | Must set `executablePath` in playwright.config.ts |
| Env vars | None needed | `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`, `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` |

### Image Tag Format Change

- **Before**: `ghcr.io/gatezh/ralphex-fe:bun1.3.9-hugo0.155.3-ralphex0.11.0`
- **After**: `ghcr.io/gatezh/ralphex-fe:0.11.0`
- Bun/Hugo versions documented in README only

### Sed Delimiter Fix

- **Before** (master): `sed -i "s/^ARG BUN_VERSION=.*/ARG BUN_VERSION=$NEW_BUN/"` — breaks if version contains `/`
- **After**: `sed -i "s|^ARG BUN_VERSION=.*|ARG BUN_VERSION=$NEW_BUN|"` — safe with any version string

## Post-Completion

**Manual verification:**
- Trigger the build workflow via workflow_dispatch after merging to verify the full pipeline
- Test pulling the image and running `chromium-browser --version` inside the container
- Test a sample Playwright project against the image
