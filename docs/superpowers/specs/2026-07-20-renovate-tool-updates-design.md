# Renovate-driven rebuilds for `claude-code` & `ralphex-fe`

- **Date:** 2026-07-20
- **Status:** Approved (design) — pending implementation plan
- **Branch:** `renovate-agent-tool-updates`

## Problem

`build-claude-code.yml` and `build-ralphex-fe.yml` rebuild their images on a daily
`schedule:` cron regardless of whether anything changed. The only reason those
crons exist is that four tools are pulled from *moving* sources at build time:

| Tool | Source | Images |
|------|--------|--------|
| `rtk` | GitHub `releases/latest` (`rtk-ai/rtk`) | `claude-code`, `ralphex-fe` |
| `ralphex` | GitHub `releases/latest` (`umputun/ralphex`) | `claude-code`, `ralphex-fe` |
| `@anthropic-ai/claude-code` | npm (unpinned `npm install -g`) | `claude-code`, `ralphex-fe` |
| `agent-browser` | npm (`ARG AGENT_BROWSER_VERSION=latest`) | `claude-code` (`default` target only) |

Everything else (`Bun`, `Hugo`, `Go`, `Docker`, `git-delta`, base images) is
already `ARG`-pinned and only changes on a Dockerfile edit, which has its own
path-filtered `push` trigger. So the scheduled build is pure waste on any day
none of the four tools published a release.

## Goal

Rebuild **only when one of the four tracked tools actually publishes a new
version** — no more time-based rebuilds.

## Non-goals

- Managing `Bun` / `Hugo` / `Go` / `Docker` / `git-delta` / base images with
  Renovate (explicitly out of scope — they stay as they are today, including the
  manual `update-and-build-ralphex-fe.yml` version-bump path).
- Adding local GitHub-Actions execution tooling (e.g. `act`). Rejected: the
  build workflows' substance is multi-arch `docker buildx` + registry push via
  the external reusable workflow `docker/github-builder/...@v1` on native ARM
  runners with OIDC — none of which `act` can faithfully emulate. The dev
  container already bakes in `hadolint` + `actionlint` for local static checks,
  and a real `docker buildx build --platform linux/amd64` reproduces CI's build
  job exactly.

## Decisions (locked with the user)

1. **Mechanism:** Renovate (the canonical "only rebuild on real dependency
   change" pattern) — pin the four tools, let Renovate open bump PRs, and let
   the *existing* `push` trigger do the rebuild on merge. The daily crons are
   deleted.
2. **Hosting:** Mend-hosted Renovate GitHub App (config in-repo; its PRs trigger
   CI, so auto-merge can be gated on green). No self-hosted workflow, no PAT.
3. **Scope:** Only the four moving tools above.
4. **Merge policy:** Auto-merge a bump when CI passes. This requires closing a
   pre-existing gap — `claude-code` is currently absent from `ci.yml`, so it has
   no PR-time verification. We add it (both targets) so auto-merge is genuinely
   gated.

## Design

### A. Pin the four tools in the Dockerfiles

Both `claude-code/.devcontainer/Dockerfile` and `ralphex-fe/Dockerfile` change
their moving downloads to pinned `ARG`s, each preceded by a `# renovate:`
annotation comment that a Renovate custom manager reads.

**`rtk-download` / `ralphex-download` stages (both files):** replace the
`curl … /releases/latest | jq -r .tag_name | sed 's/^v//'` version resolution
with a pinned ARG used directly in the download URL. `jq` is no longer needed in
these stages (`apk add --no-cache curl` only). Example (rtk):

```dockerfile
FROM alpine:3.21 AS rtk-download
RUN apk add --no-cache curl
# renovate: datasource=github-releases depName=rtk-ai/rtk
ARG RTK_VERSION=<current latest, resolved at implementation>
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

`ralphex` is analogous (`depName=umputun/ralphex`, URL keeps `v${VERSION}` in the
path and `${VERSION}` in the filename).

**`@anthropic-ai/claude-code` (both files):** add an ARG + annotation before the
install and pin the version:

```dockerfile
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=<current latest>
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}
```

(The ARG is declared inside the stage that runs the install — `base` in
`claude-code`, the final image stage in `ralphex-fe`.)

**`agent-browser` (`claude-code` `default` target only):** the existing
`ARG AGENT_BROWSER_VERSION=latest` becomes a pinned version with an annotation;
the `npm install -g agent-browser@${AGENT_BROWSER_VERSION}` line is unchanged:

```dockerfile
# renovate: datasource=npm depName=agent-browser
ARG AGENT_BROWSER_VERSION=<current latest>
```

ARG defaults are set to the **current** latest versions at implementation time
(resolved with the same API/registry calls the Dockerfiles use today), so the
first post-merge build produces an image equivalent to today's.

### B. `renovate.json5` (new, repo root)

Uses JSON5 (comments allowed, matching the repo's JSONC style). Contents:

- `extends: ["config:recommended"]`.
- One **custom manager** (regex) matching the `# renovate:` annotation + the
  `ARG …_VERSION=` line across both Dockerfiles, capturing `datasource`,
  `depName`, and `currentValue`.
- A **packageRules** entry that:
  - strips the leading `v` from the two `github-releases` deps via
    `extractVersion: "^v?(?<version>.+)$"` so the datasource tag (`v0.11.0`)
    compares against the bare ARG value (`0.11.0`);
  - **groups** all four tools into a single PR (`groupName: "devcontainer agent
    tools"`) so tools that co-release rebuild together (one PR → one rebuild),
    matching today's single daily refresh;
  - enables auto-merge (`automerge: true`, `automergeType: "pr"`,
    `platformAutomerge: true`).

> **Verify during implementation** against official Renovate docs: exact
> `customManagers[].matchStrings` capture-group syntax, whether `extractVersion`
> is best placed in the custom manager vs. a `packageRules` entry, and the
> config-file discovery location. Use the `sandbox-fetch-docs` skill.

### C. `ci.yml` — add `claude-code` (both targets)

`claude-code` is currently in neither the hadolint matrix nor the
`build-and-verify` matrix, so PRs touching it get no build verification. To make
auto-merge safe:

1. **hadolint matrix:** add `claude-code/.devcontainer/Dockerfile`.
2. **`detect-changes` filters:** add `claude-code: - 'claude-code/**'` and a
   corresponding `CHANGED_CLAUDE_CODE` env var in the matrix-builder step.
3. **Matrix builder:** extend the `add_image` helper with a fifth `target`
   field (empty for existing single-target images). Emit two entries for
   `claude-code`:
   - `claude-code` → `target: default`, reusing the **exact** default verify
     string from `build-claude-code.yml`.
   - `claude-code-sandbox` → `target: sandbox`, reusing the **exact** sandbox
     verify string from `build-claude-code.yml`.
4. **`build-and-verify` job:** pass `target: ${{ matrix.target }}` to
   `docker/build-push-action`. Empty target builds the Dockerfile's final stage
   (unchanged behavior for the other images). Cache scopes stay keyed on
   `matrix.image`, so `claude-code` and `claude-code-sandbox` get distinct
   scopes.

CI remains amd64-only (native, no QEMU) — sufficient to verify a version bump;
arm64 is exercised post-merge by `build-claude-code.yml` on native runners.

### D. Remove the daily crons

- `build-claude-code.yml`: delete the `schedule:` block (cron `13 11 * * *`).
- `build-ralphex-fe.yml`: delete the `schedule:` block (cron `41 11 * * *`) and
  its explanatory comment.
- Both keep `push` (path-filtered, unchanged — this is what rebuilds on a merged
  bump) and `workflow_dispatch` (manual force build).

### E. Comment & docs cleanup (bundle-adjacent consistency)

- `claude-code/.devcontainer/Dockerfile`: update the "refreshed on each daily
  image rebuild" (near the rtk/ralphex `COPY`) and "Auto-updates don't matter
  here — the image rebuilds daily" (near the claude-code install) comments to
  describe pinned + Renovate-managed versions.
- `ralphex-fe/Dockerfile`: note the four tools are Renovate-managed where the
  existing comments describe them as "latest".
- Audit `README.md` (root), `claude-code/README.md`, `ralphex-fe/README.md` for
  "rebuilt daily" / "daily rebuild" wording and correct it.

## Runtime flow (end state)

```
Renovate scan → new version of a tracked tool detected
  → grouped PR bumps the ARG(s) in the Dockerfile(s)
  → ci.yml: hadolint + actionlint + amd64 build&verify of affected image(s)
            (now including claude-code default + sandbox)
  → CI green? → Renovate auto-merges → push to master
  → build-{image}.yml path filter fires → multi-arch build + verify + push :latest
                                           (+ date / sha tags)
```

No release → no PR → no rebuild.

## Error handling / safety

This is **safer** than the current cron:

- **Broken / yanked upstream release:** the CI amd64 build fails → PR does not
  auto-merge → `:latest` stays intact. Today's cron would build and push a
  broken `:latest`.
- **Renovate can't resolve a datasource:** no PR is opened; the image is
  unchanged.
- **`v`-prefix mismatch:** handled by `extractVersion`, so ARGs stay bare semver
  and the existing `v${VERSION}` URL construction is unchanged.
- **Shared tools (`rtk`/`ralphex`/`claude-code`) live in both Dockerfiles:** the
  custom manager matches every occurrence, so a bump updates both to the same
  version and both images rebuild — keeping them in sync.

## Verification plan

- `npx --yes renovate-config-validator` on the new config file.
- `hadolint` on both changed Dockerfiles; `actionlint` on `ci.yml` and both
  build workflows (local, pre-PR — per project convention; the dev container
  already ships both linters).
- Confirm the `ci.yml` matrix builds `claude-code` `default` + `sandbox` amd64
  and that both verify strings pass against a locally built image.
- Post-merge manual check: watch the first Renovate PR detect the four deps and
  auto-merge on green, then confirm the `push`-triggered multi-arch build runs.

## One-time manual step (user, GitHub UI — not code)

Install the **Mend Renovate app** on the repository and merge its onboarding PR.
Everything else in this design is code on this branch.

## Files touched

- `claude-code/.devcontainer/Dockerfile` (pin 4 → 3 tools + agent-browser; comments)
- `ralphex-fe/Dockerfile` (pin rtk/ralphex/claude-code; comments)
- `renovate.json5` (new)
- `.github/workflows/ci.yml` (add claude-code, both targets; `target` matrix field)
- `.github/workflows/build-claude-code.yml` (remove `schedule:`)
- `.github/workflows/build-ralphex-fe.yml` (remove `schedule:`)
- `README.md`, `claude-code/README.md`, `ralphex-fe/README.md` (wording audit)

## Unaffected

- `update-and-build-ralphex-fe.yml` (manual Bun/Hugo bump path — untouched).
- All other images and workflows.
