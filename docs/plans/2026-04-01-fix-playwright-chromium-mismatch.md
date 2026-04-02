# Plan: Fix Playwright Chromium version mismatch in ralphex-fe

Replace Playwright-managed browser downloads with Debian's system Chromium package, eliminating the version coupling that causes 8+ minute browser re-downloads on every container start.

## Context

- The ralphex-fe Docker image caches Chromium at build time for `playwright@1.58.2` (revision 1208), but at runtime `@playwright/mcp@latest` depends on `playwright-core@1.60.0-alpha` which needs revision 1217
- This is structurally unfixable with version pinning because `@playwright/mcp` releases use alpha Playwright builds that change nearly every release (43 of 63 releases had different versions)
- Files involved:
  - `ralphex-fe/Dockerfile` (modify)
  - `ralphex-fe/init-docker.sh` (modify)
  - `.github/workflows/build-ralphex-fe.yml` (modify)
  - `.github/workflows/update-and-build-ralphex-fe.yml` (modify)
  - `.claude/rules/dockerfile.md` (modify)

## Implementation Approach

- Replace Playwright-managed browsers with Debian's system Chromium (`apt-get install chromium`)
- Use `@playwright/mcp`'s `--executable-path` flag to point at `/usr/bin/chromium`, bypassing Playwright's browser management entirely
- Set `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` and `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium` env vars
- Expand init-docker.sh MCP patch from ARM64-only to all architectures (AMD64 also needs `chromium` not `chrome` in Docker)
- Add `--no-sandbox` for Docker environment (matches official MCP Dockerfile)

---

## Task 1: Update Dockerfile — swap Playwright-managed browsers for system Chromium

**Files:**
- Modify: `ralphex-fe/Dockerfile`

**Changes:**
1. Remove `ARG PLAYWRIGHT_VERSION=1.58.2` (line 5) and `ARG PLAYWRIGHT_VERSION` re-declaration (line 80)
2. Add `chromium fonts-freefont-ttf` to the existing `apt-get install` block (lines 94-107)
3. Remove the entire Playwright install block (lines 153-162): `npx playwright install-deps` + `npx playwright install --only-shell`
4. Update ENV block (lines 180-183) — replace `PLAYWRIGHT_VERSION` with:
   ```
   PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
   PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium
   ```

---

## Task 2: Update init-docker.sh — expand MCP patch to all architectures

**Files:**
- Modify: `ralphex-fe/init-docker.sh`

**Changes:**
- Remove the `uname -m` architecture check — apply patch on all architectures
- Add `--executable-path /usr/bin/chromium` to MCP args
- Add `--no-sandbox` for Docker environment
- Update comment to reflect new purpose

---

## Task 3: Update CI workflows

**Files:**
- Modify: `.github/workflows/build-ralphex-fe.yml`
- Modify: `.github/workflows/update-and-build-ralphex-fe.yml`

**Changes for build-ralphex-fe.yml:**
- Update verify step: replace `test -d /home/app/.cache/ms-playwright` with `chromium --no-sandbox --version` and executable checks

**Changes for update-and-build-ralphex-fe.yml:**
- Fix binary name: `chromium-browser` → `chromium` (correct for Debian Trixie)
- Fix env var path: `/usr/bin/chromium-browser` → `/usr/bin/chromium`

---

## Task 4: Update documentation

**Files:**
- Modify: `.claude/rules/dockerfile.md`

**Changes:**
- Update the "Playwright on Debian" section to document the system Chromium approach

---

## Verification

1. `hadolint ralphex-fe/Dockerfile`
2. `shellcheck ralphex-fe/init-docker.sh`
3. YAML validation on both workflow files
4. Verify `chromium --no-sandbox --headless --version` works inside the built image
5. Confirm `--executable-path` is listed in `npx @playwright/mcp@latest --help`

## Risk: CDP protocol compatibility

System Chromium might differ from what `playwright-core` was tested against. Mitigations:
- Debian Trixie's Chromium tracks recent stable releases (close to Playwright alpha targets)
- MCP usage (browsing, clicking, extracting) doesn't need test-automation precision
- `--executable-path` is officially supported by `@playwright/mcp`
- Can pin `apt-get install chromium=VERSION` if needed
