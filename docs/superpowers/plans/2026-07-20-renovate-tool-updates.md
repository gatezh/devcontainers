# Renovate-driven Image Rebuilds — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the daily rebuild crons for `claude-code` and `ralphex-fe` with pinned tool versions that Renovate bumps only when an upstream release actually happens.

**Architecture:** Pin the four moving tools (`rtk`, `ralphex`, `@anthropic-ai/claude-code`, `agent-browser`) as annotated `ARG`s in the Dockerfiles. A `.github/renovate.json5` custom manager reads those annotations, opens a grouped bump PR on any new release, CI verifies it (amd64 build + tool checks — now including `claude-code` both targets), Renovate auto-merges on green, and the existing `push` path-filter trigger performs the real multi-arch build. The `schedule:` crons are deleted.

**Tech Stack:** Docker multi-stage builds (BuildKit), GitHub Actions, Renovate (Mend-hosted app), `hadolint`, `actionlint`, `renovate-config-validator`.

## Global Constraints

- Platform for all workflow shell is Ubuntu/GNU coreutils — never BSD/macOS syntax.
- Images build multi-platform `linux/amd64,linux/arm64`; CI verifies amd64 only.
- ARG version values are **bare semver** (e.g. `0.43.0`), never `v`-prefixed — the `v` lives in the download URL / is stripped from the datasource via `extractVersion`.
- Renovate config lives at `.github/renovate.json5` (JSON5, comments allowed).
- Auto-merge is gated on CI via `platformAutomerge: false` (Renovate waits for green tests itself; no branch-protection rule required).
- Scope is exactly the four tools above — do NOT bring `Bun`/`Hugo`/`Go`/`Docker`/`git-delta`/base images under Renovate.
- Commit messages follow the repo's Conventional Commits style (`feat(...)`, `fix(...)`, `chore(...)`, `docs(...)`, `ci(...)`).
- Current pinned versions to seed the ARGs: `rtk` = `0.43.0`, `ralphex` = `1.6.0`, `@anthropic-ai/claude-code` = `2.1.216`, `agent-browser` = `0.32.3`. (Resolved 2026-07-20. If materially stale at execution, re-resolve: `curl -fsSL https://api.github.com/repos/OWNER/REPO/releases/latest | jq -r .tag_name` and `curl -fsSL https://registry.npmjs.org/PKG/latest | jq -r .version`.)

### Tooling note (validation commands)

This repo's dev container ships `hadolint` + `actionlint`. If a command below is not on `PATH` (e.g. running on the macOS host), use the Docker fallback:
- hadolint: `docker run --rm -i hadolint/hadolint < <path/to/Dockerfile>`
- actionlint: `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest -color <file>`
- renovate-config-validator: `npx --yes --package renovate -- renovate-config-validator <file>`

---

### Task 1: Pin the four tools in `claude-code/.devcontainer/Dockerfile`

**Files:**
- Modify: `claude-code/.devcontainer/Dockerfile`

**Interfaces:**
- Produces: annotated ARGs `RTK_VERSION`, `RALPHEX_VERSION`, `CLAUDE_CODE_VERSION`, `AGENT_BROWSER_VERSION` that the Renovate custom manager in Task 3 matches via the `# renovate:` comment + `ARG …_VERSION=` pattern.

- [ ] **Step 1: Pin the `rtk-download` stage**

Replace the `rtk-download` stage (the block starting `# ── rtk (token-optimized CLI proxy) ──` through the `tar -xzf /tmp/rtk.tar.gz …` line) with:

```dockerfile
# ── rtk (token-optimized CLI proxy) ──────────────────────────────────────
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
FROM alpine:3.21 AS rtk-download
RUN apk add --no-cache curl
# renovate: datasource=github-releases depName=rtk-ai/rtk
ARG RTK_VERSION=0.43.0
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
      x86_64)  RTK_TARGET="x86_64-unknown-linux-musl" ;; \
      aarch64) RTK_TARGET="aarch64-unknown-linux-gnu" ;; \
    esac; \
    curl -fsSL -o /tmp/rtk.tar.gz \
      "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-${RTK_TARGET}.tar.gz"; \
    tar -xzf /tmp/rtk.tar.gz -C /usr/local/bin rtk
```

(Removes the GitHub-API version resolution and the now-unused `jq`.)

- [ ] **Step 2: Pin the `ralphex-download` stage**

Replace the `ralphex-download` stage with:

```dockerfile
# ── ralphex (autonomous plan execution) ──────────────────────────────────
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
FROM alpine:3.21 AS ralphex-download
RUN apk add --no-cache curl
# renovate: datasource=github-releases depName=umputun/ralphex
ARG RALPHEX_VERSION=1.6.0
RUN set -eux; \
    ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"; \
    curl -fsSL -o /tmp/ralphex.tar.gz \
      "https://github.com/umputun/ralphex/releases/download/v${RALPHEX_VERSION}/ralphex_${RALPHEX_VERSION}_linux_${ARCH}.tar.gz"; \
    tar -xzf /tmp/ralphex.tar.gz -C /usr/local/bin ralphex
```

- [ ] **Step 3: Update the dev-tools COPY comment**

Find:

```dockerfile
# Downloaded from GitHub Releases; refreshed on each daily image rebuild.
```

Replace with:

```dockerfile
# Downloaded from GitHub Releases at Renovate-pinned versions (see .github/renovate.json5).
```

- [ ] **Step 4: Pin the Claude Code CLI install**

Find:

```dockerfile
# See: https://code.claude.com/docs/en/getting-started#install-with-npm
# Auto-updates don't matter here — the image rebuilds daily.
#
# Install as the node user so all files land with node ownership from the start.
# A later `chown -R` in another layer would duplicate every file (overlayfs
# treats an ownership change as a rewrite), adding hundreds of MB.
RUN npm install -g @anthropic-ai/claude-code
```

Replace with:

```dockerfile
# See: https://code.claude.com/docs/en/getting-started#install-with-npm
# Version pinned and kept up to date by Renovate (see .github/renovate.json5);
# a bump PR triggers a rebuild.
#
# Install as the node user so all files land with node ownership from the start.
# A later `chown -R` in another layer would duplicate every file (overlayfs
# treats an ownership change as a rewrite), adding hundreds of MB.
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.216
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}
```

- [ ] **Step 5: Pin the agent-browser install (default target)**

Find:

```dockerfile
# Installed as the node user (see claude-code install above for rationale).
ARG AGENT_BROWSER_VERSION=latest
RUN npm install -g agent-browser@${AGENT_BROWSER_VERSION}
```

Replace with:

```dockerfile
# Installed as the node user (see claude-code install above for rationale).
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
# renovate: datasource=npm depName=agent-browser
ARG AGENT_BROWSER_VERSION=0.32.3
RUN npm install -g agent-browser@${AGENT_BROWSER_VERSION}
```

- [ ] **Step 6: Lint the Dockerfile**

Run: `hadolint claude-code/.devcontainer/Dockerfile`
Expected: no output, exit 0. (Docker fallback in the tooling note above.)

- [ ] **Step 7: Commit**

```bash
git add claude-code/.devcontainer/Dockerfile
git commit -m "feat(claude-code): pin rtk/ralphex/claude-code/agent-browser for Renovate"
```

---

### Task 2: Pin the three tools in `ralphex-fe/Dockerfile`

**Files:**
- Modify: `ralphex-fe/Dockerfile`

**Interfaces:**
- Produces: annotated ARGs `RTK_VERSION`, `RALPHEX_VERSION`, `CLAUDE_CODE_VERSION` matched by the same Task 3 custom manager. (No `agent-browser` here — this image doesn't install it.)

- [ ] **Step 1: Pin the `rtk-download` stage**

Replace the `rtk-download` stage (block starting `# ── RTK (token-optimized CLI proxy for Claude Code) ──`) with:

```dockerfile
# ── RTK (token-optimized CLI proxy for Claude Code) ─────────────────────────
# Pattern from: .devcontainer/Dockerfile
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
FROM alpine:3.21 AS rtk-download
RUN apk add --no-cache curl
# renovate: datasource=github-releases depName=rtk-ai/rtk
ARG RTK_VERSION=0.43.0
RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
      x86_64)  RTK_TARGET="x86_64-unknown-linux-musl" ;; \
      aarch64) RTK_TARGET="aarch64-unknown-linux-gnu" ;; \
    esac; \
    curl -fsSL -o /tmp/rtk.tar.gz \
      "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-${RTK_TARGET}.tar.gz"; \
    tar -xzf /tmp/rtk.tar.gz -C /usr/local/bin rtk
```

- [ ] **Step 2: Pin the `ralphex-download` stage**

Replace the `ralphex-download` stage (block starting `# ── Ralphex binary (latest from GitHub Releases) ──`) with:

```dockerfile
# ── Ralphex binary (pinned; Renovate-managed) ───────────────────────────────
# Pattern from: claude-code/.devcontainer/Dockerfile
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
FROM alpine:3.21 AS ralphex-download
RUN apk add --no-cache curl
# renovate: datasource=github-releases depName=umputun/ralphex
ARG RALPHEX_VERSION=1.6.0
RUN set -eux; \
    ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"; \
    curl -fsSL -o /tmp/ralphex.tar.gz \
      "https://github.com/umputun/ralphex/releases/download/v${RALPHEX_VERSION}/ralphex_${RALPHEX_VERSION}_linux_${ARCH}.tar.gz"; \
    tar -xzf /tmp/ralphex.tar.gz -C /usr/local/bin ralphex
```

- [ ] **Step 3: Pin the Claude Code CLI install**

Find:

```dockerfile
# ── Claude Code CLI ──────────────────────────────────────────────────────────
# npm install (not native installer) to avoid rate-limiting in parallel Docker builds.
# See: claude-code/.devcontainer/Dockerfile for rationale.
RUN --mount=type=cache,target=/root/.npm \
    npm install -g @anthropic-ai/claude-code
```

Replace with:

```dockerfile
# ── Claude Code CLI ──────────────────────────────────────────────────────────
# npm install (not native installer) to avoid rate-limiting in parallel Docker builds.
# See: claude-code/.devcontainer/Dockerfile for rationale.
# Version pinned and kept up to date by Renovate (see .github/renovate.json5).
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.216
RUN --mount=type=cache,target=/root/.npm \
    npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}
```

- [ ] **Step 4: Lint the Dockerfile**

Run: `hadolint ralphex-fe/Dockerfile`
Expected: no output, exit 0.

- [ ] **Step 5: Commit**

```bash
git add ralphex-fe/Dockerfile
git commit -m "feat(ralphex-fe): pin rtk/ralphex/claude-code for Renovate"
```

---

### Task 3: Add the Renovate config

**Files:**
- Create: `.github/renovate.json5`

**Interfaces:**
- Consumes: the `# renovate: datasource=… depName=…` + `ARG …_VERSION=…` annotations from Tasks 1–2.
- Produces: Renovate managed-dependency detection for the four tools; grouped auto-merging bump PRs.

- [ ] **Step 1: Create `.github/renovate.json5`**

```json5
{
  $schema: 'https://docs.renovatebot.com/renovate-schema.json',
  extends: ['config:recommended'],

  // Pin + auto-update the four dev tools these images used to pull from
  // "latest" at build time. Replaces the old daily rebuild cron: a Renovate
  // bump PR (auto-merged on green CI) triggers the existing push-based image
  // build. No upstream release -> no PR -> no rebuild.
  customManagers: [
    {
      customType: 'regex',
      managerFilePatterns: ['/(^|/)Dockerfile$/'],
      matchStrings: [
        '# renovate: datasource=(?<datasource>[a-z-]+) depName=(?<depName>\\S+)\\s+ARG [A-Z_]+_VERSION=(?<currentValue>\\S+)',
      ],
    },
  ],

  packageRules: [
    {
      // rtk / ralphex release tags look like "v0.43.0"; strip the leading "v"
      // so the datasource version matches the bare ARG value ("0.43.0").
      matchDatasources: ['github-releases'],
      extractVersion: '^v(?<version>.*)$',
    },
    {
      // Group the four tools into one PR and auto-merge once CI passes.
      // platformAutomerge:false => Renovate performs the merge itself only
      // after it observes the branch tests are green, so CI gating needs no
      // branch-protection rule. (Optional hardening: enable branch protection
      // requiring the CI checks and set platformAutomerge:true for native
      // GitHub auto-merge.)
      matchPackageNames: [
        'rtk-ai/rtk',
        'umputun/ralphex',
        '@anthropic-ai/claude-code',
        'agent-browser',
      ],
      groupName: 'devcontainer agent tools',
      automerge: true,
      platformAutomerge: false,
    },
  ],
}
```

- [ ] **Step 2: Validate the config**

Run: `npx --yes --package renovate -- renovate-config-validator .github/renovate.json5`
Expected: output includes `Config validated successfully`. If it reports the file is invalid, fix and re-run before committing.

- [ ] **Step 3: Sanity-check that the custom manager matches the annotations**

Confirm the regex matches every annotated ARG across both Dockerfiles (expect **7** matches: rtk+ralphex+claude-code in each file = 6, plus agent-browser in claude-code = 7):

Run:
```bash
grep -rEc '# renovate: datasource=[a-z-]+ depName=\S+' \
  claude-code/.devcontainer/Dockerfile ralphex-fe/Dockerfile
```
Expected: `claude-code/.devcontainer/Dockerfile:4` and `ralphex-fe/Dockerfile:3`.

- [ ] **Step 4: Commit**

```bash
git add .github/renovate.json5
git commit -m "ci(renovate): add config to pin and auto-update devcontainer agent tools"
```

---

### Task 4: Add `claude-code` (both targets) to CI

**Files:**
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: nothing from prior tasks (independent).
- Produces: PR-time hadolint + amd64 build&verify for `claude-code` `default` and `sandbox` — the gate that makes Task 3's auto-merge safe. Adds a `target` field to the build matrix.

- [ ] **Step 1: Add claude-code to the hadolint matrix**

Find:

```yaml
        dockerfile:
          - bun/.devcontainer/Dockerfile
          - claude-bun/.devcontainer/Dockerfile
          - hugo-bun/.devcontainer/Dockerfile
```

Replace with:

```yaml
        dockerfile:
          - bun/.devcontainer/Dockerfile
          - claude-bun/.devcontainer/Dockerfile
          - claude-code/.devcontainer/Dockerfile
          - hugo-bun/.devcontainer/Dockerfile
```

- [ ] **Step 2: Add the claude-code paths filter**

Find:

```yaml
            claude-bun:
              - 'claude-bun/**'
            hugo-bun:
              - 'hugo-bun/**'
```

Replace with:

```yaml
            claude-bun:
              - 'claude-bun/**'
            claude-code:
              - 'claude-code/**'
            hugo-bun:
              - 'hugo-bun/**'
```

- [ ] **Step 3: Add the CHANGED_CLAUDE_CODE env var**

Find:

```yaml
          CHANGED_CLAUDE_BUN: ${{ steps.filter.outputs.claude-bun }}
          CHANGED_HUGO_BUN: ${{ steps.filter.outputs.hugo-bun }}
```

Replace with:

```yaml
          CHANGED_CLAUDE_BUN: ${{ steps.filter.outputs.claude-bun }}
          CHANGED_CLAUDE_CODE: ${{ steps.filter.outputs.claude-code }}
          CHANGED_HUGO_BUN: ${{ steps.filter.outputs.hugo-bun }}
```

- [ ] **Step 4: Extend `add_image` with an optional `target` field**

Find:

```bash
          add_image() {
            local image="$1" context="$2" dockerfile="$3" verify="$4"
            INCLUDES=$(echo "$INCLUDES" | jq -c \
              --arg img "$image" \
              --arg ctx "$context" \
              --arg df "$dockerfile" \
              --arg v "$verify" \
              '. + [{"image":$img,"context":$ctx,"dockerfile":$df,"verify":$v}]')
          }
```

Replace with:

```bash
          add_image() {
            local image="$1" context="$2" dockerfile="$3" verify="$4" target="${5:-}"
            INCLUDES=$(echo "$INCLUDES" | jq -c \
              --arg img "$image" \
              --arg ctx "$context" \
              --arg df "$dockerfile" \
              --arg v "$verify" \
              --arg tgt "$target" \
              '. + [{"image":$img,"context":$ctx,"dockerfile":$df,"verify":$v,"target":$tgt}]')
          }
```

(Existing 4-argument calls keep working — `target` defaults to `""`, which `docker/build-push-action` treats as "build the final stage".)

- [ ] **Step 5: Add the claude-code build entries (both targets)**

Find:

```bash
          if [ "$CHANGED_CLAUDE_BUN" = "true" ]; then
            add_image "claude-bun" \
              "claude-bun/.devcontainer" \
              "claude-bun/.devcontainer/Dockerfile" \
              "bun --version"
          fi
```

Insert immediately **after** that `fi` (before the `CHANGED_HUGO_BUN` block):

```bash
          if [ "$CHANGED_CLAUDE_CODE" = "true" ]; then
            add_image "claude-code" \
              "claude-code/.devcontainer" \
              "claude-code/.devcontainer/Dockerfile" \
              "bun --version || true && claude --version && mise --version && fish --version && rtk --version && ralphex --version && test -x /usr/local/bin/patch-playwright-mcp && test -r /etc/claude-code/managed-settings.json && jq -r '.hooks.SessionStart[0].hooks[0].command' /etc/claude-code/managed-settings.json | grep -qx /usr/local/bin/patch-playwright-mcp && printenv AGENT_BROWSER_EXECUTABLE_PATH | grep -qx /usr/bin/chromium" \
              "default"
            add_image "claude-code-sandbox" \
              "claude-code/.devcontainer" \
              "claude-code/.devcontainer/Dockerfile" \
              "claude --version && mise --version && fish --version && which iptables && rtk --version && ralphex --version && test -x /usr/local/bin/patch-playwright-mcp && test -r /etc/claude-code/managed-settings.json && jq -r '.hooks.SessionStart[0].hooks[0].command' /etc/claude-code/managed-settings.json | grep -qx /usr/local/bin/patch-playwright-mcp" \
              "sandbox"
          fi
```

(Verify strings copied verbatim from `build-claude-code.yml`.)

- [ ] **Step 6: Pass the target to the build step**

Find:

```yaml
        with:
          context: ${{ matrix.context }}
          file: ${{ matrix.dockerfile }}
          platforms: linux/amd64
```

Replace with:

```yaml
        with:
          context: ${{ matrix.context }}
          file: ${{ matrix.dockerfile }}
          target: ${{ matrix.target }}
          platforms: linux/amd64
```

- [ ] **Step 7: Lint the workflow**

Run: `actionlint .github/workflows/ci.yml`
Expected: no output, exit 0.

- [ ] **Step 8: Dry-run the matrix builder locally**

Run (reproduces the `add_image` logic with only claude-code changed):

```bash
INCLUDES="[]"
add_image() { local image="$1" context="$2" dockerfile="$3" verify="$4" target="${5:-}"
  INCLUDES=$(echo "$INCLUDES" | jq -c --arg img "$image" --arg ctx "$context" --arg df "$dockerfile" --arg v "$verify" --arg tgt "$target" \
    '. + [{"image":$img,"context":$ctx,"dockerfile":$df,"verify":$v,"target":$tgt}]'); }
add_image "claude-code" "claude-code/.devcontainer" "claude-code/.devcontainer/Dockerfile" "claude --version" "default"
add_image "claude-code-sandbox" "claude-code/.devcontainer" "claude-code/.devcontainer/Dockerfile" "claude --version" "sandbox"
add_image "ralphex-fe" "ralphex-fe" "ralphex-fe/Dockerfile" "bun --version"
echo "$INCLUDES" | jq '{include:.}'
```
Expected: valid JSON; the two `claude-code*` entries have `"target":"default"` / `"target":"sandbox"`, and `ralphex-fe` has `"target":""`.

- [ ] **Step 9: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: build and verify claude-code (default + sandbox) on PRs"
```

---

### Task 5: Remove the daily rebuild crons

**Files:**
- Modify: `.github/workflows/build-claude-code.yml`
- Modify: `.github/workflows/build-ralphex-fe.yml`

**Interfaces:**
- Consumes: nothing.
- Produces: build workflows triggered only by `push` (path-filtered) and `workflow_dispatch`.

- [ ] **Step 1: Drop the cron from `build-claude-code.yml`**

Find:

```yaml
      - "claude-code/.devcontainer/managed-settings.json"
  schedule:
    - cron: '13 11 * * *'
  workflow_dispatch:
```

Replace with:

```yaml
      - "claude-code/.devcontainer/managed-settings.json"
  workflow_dispatch:
```

- [ ] **Step 2: Drop the cron from `build-ralphex-fe.yml`**

Find:

```yaml
      - 'ralphex-fe/Dockerfile'
      - 'ralphex-fe/*.sh'
  schedule:
    # Daily rebuild to bake in the latest ralphex and rtk releases, which the
    # Dockerfile pulls from GitHub "latest" at build time. Offset from
    # build-claude-code.yml's 11:13 to avoid hitting the GitHub API at the same minute.
    - cron: '41 11 * * *'
  workflow_dispatch:
```

Replace with:

```yaml
      - 'ralphex-fe/Dockerfile'
      - 'ralphex-fe/*.sh'
  workflow_dispatch:
```

- [ ] **Step 3: Lint both workflows**

Run: `actionlint .github/workflows/build-claude-code.yml .github/workflows/build-ralphex-fe.yml`
Expected: no output, exit 0.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/build-claude-code.yml .github/workflows/build-ralphex-fe.yml
git commit -m "ci: drop daily rebuild crons (Renovate triggers rebuilds now)"
```

---

### Task 6: Correct the "rebuilds daily" documentation

**Files:**
- Modify: `README.md`
- Modify: `claude-code/README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: docs consistent with the Renovate-driven rebuild model.

- [ ] **Step 1: Root README**

Find:

```
Projects consume pre-built images and control tool versions via `.mise.toml`. Rebuilds daily to pick up latest Claude Code.
```

Replace with:

```
Projects consume pre-built images and control tool versions via `.mise.toml`. Rebuilds when its pinned tools receive a new release (managed by Renovate), not on a schedule.
```

- [ ] **Step 2: claude-code README — rebuild description**

Find:

```
The image rebuilds daily at 5am MT (11:00 UTC) using native runners for both amd64 and arm64 (no QEMU emulation). Each rebuild picks up the latest Claude Code and agent-browser. Manual rebuilds can be triggered via the "Run workflow" button in the Actions UI.
```

Replace with:

```
The image rebuilds automatically whenever one of its pinned tools — Claude Code, agent-browser, rtk, or ralphex — publishes a new release: Renovate opens a version-bump PR, CI verifies it, it auto-merges, and the merge builds the image on native runners for both amd64 and arm64 (no QEMU emulation). Manual rebuilds can be triggered via the "Run workflow" button in the Actions UI.
```

- [ ] **Step 3: claude-code README — patch-script channel note**

Find:

```
so it's baked into the image and flows through the same daily-rebuild + `initializeCommand` image-pull channel as the rest of the image.
```

Replace with:

```
so it's baked into the image and flows through the same Renovate-triggered rebuild + `initializeCommand` image-pull channel as the rest of the image.
```

- [ ] **Step 4: Correct the stale comment in `.hadolint.yaml`**

The `DL3016` ignore block still asserts the old daily-rebuild rationale. The ignore rule stays (other images may still install npm tools unpinned), but the comment is now inaccurate.

Find:

```yaml
  # Dev tools (Claude Code) intentionally unpinned — images rebuild daily
  # to always get latest. Pinning would defeat the purpose.
  - DL3016 # pin versions in npm install
```

Replace with:

```yaml
  # Dev tools (e.g. Claude Code) are installed via npm; some images pin the
  # version via a Renovate-managed ARG, others intentionally don't.
  - DL3016 # pin versions in npm install
```

- [ ] **Step 5: Confirm no stale wording remains**

Run:
```bash
grep -rniE 'rebuilds? daily|daily (image )?rebuild' \
  README.md claude-code/README.md ralphex-fe/README.md \
  claude-code/.devcontainer/Dockerfile ralphex-fe/Dockerfile .hadolint.yaml
```
Expected: no matches (exit 1).

- [ ] **Step 6: Commit**

```bash
git add README.md claude-code/README.md .hadolint.yaml
git commit -m "docs: describe Renovate-driven rebuilds instead of daily cron"
```

---

## Post-implementation manual steps (user, GitHub UI — not code)

1. **Install the Mend Renovate GitHub App** on the `gatezh/devcontainers` repo (https://github.com/apps/renovate → Configure). Merge the onboarding PR Renovate opens.
2. After onboarding, confirm Renovate's **Dependency Dashboard** issue lists all four tools (`rtk-ai/rtk`, `umputun/ralphex`, `@anthropic-ai/claude-code`, `agent-browser`). If any is missing, the custom-manager regex didn't match — recheck the annotations (Tasks 1–2).
3. *(Optional hardening)* Enable a branch-protection rule on `master` requiring the CI checks, then flip `platformAutomerge` to `true` in the config for faster native GitHub auto-merge.

## Verification of the end-to-end result (after first real bump)

- A bump PR appears, groups the changed tool(s), and CI runs hadolint + amd64 build&verify (including `claude-code` default + sandbox).
- On green CI the PR auto-merges; the merge to `master` triggers `build-claude-code.yml` / `build-ralphex-fe.yml`, which build multi-arch and push `:latest`.
- On a day with no upstream release, no PR is opened and no build runs.
