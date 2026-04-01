# Repository Naming Unification Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the repository from `devcontainer-images` to `devcontainers`, drop the `devcontainer-` prefix from image directories, and unify all image paths under `ghcr.io/gatezh/devcontainers/{name}`.

**Architecture:** All image directories drop the `devcontainer-` prefix (e.g., `devcontainer-bun/` becomes `bun/`). All published images move to the nested namespace `ghcr.io/gatezh/devcontainers/{name}`. The reusable workflow, build workflows, CI, Dockerfiles, docker-compose files, READMEs, and `.claude/` config are updated to reflect the new naming. The GitHub repository rename is a manual step done via the GitHub UI.

**Tech Stack:** GitHub Actions YAML, Dockerfiles, JSONC (devcontainer.json), Markdown

---

## File Structure

### Directories to rename (git mv)

| Old | New |
|-----|-----|
| `devcontainer-bun/` | `bun/` |
| `devcontainer-claude-bun/` | `claude-bun/` |
| `devcontainer-hugo-bun/` | `hugo-bun/` |
| `devcontainer-hugo-bun-node/` | `hugo-bun-node/` |
| `claude-code/` | `claude-code/` (no change) |
| `ralphex-fe/` | `ralphex-fe/` (no change) |

### Files to modify

| File | Change |
|------|--------|
| `.github/workflows/reusable-docker-build.yml` | image-name description update |
| `.github/workflows/build-devcontainer-bun.yml` → `build-bun.yml` | rename + update all paths |
| `.github/workflows/build-devcontainer-claude-bun.yml` → `build-claude-bun.yml` | rename + update all paths |
| `.github/workflows/build-devcontainer-hugo-bun.yml` → `build-hugo-bun.yml` | rename + update all paths |
| `.github/workflows/build-devcontainer-hugo-bun-node.yml` → `build-hugo-bun-node.yml` | rename + update all paths |
| `.github/workflows/build-claude-code.yml` | update image paths from `devcontainer-images/` to `devcontainers/` |
| `.github/workflows/build-ralphex-fe.yml` | update image path to `devcontainers/ralphex-fe` |
| `.github/workflows/update-and-build-ralphex-fe.yml` | update image-name to `devcontainers/ralphex-fe` |
| `.github/workflows/ci.yml` | update all directory paths |
| `bun/.devcontainer/Dockerfile` | update OCI labels |
| `claude-bun/.devcontainer/Dockerfile` | update OCI labels |
| `hugo-bun/.devcontainer/Dockerfile` | update OCI labels |
| `hugo-bun-node/.devcontainer/Dockerfile` | update OCI labels |
| `claude-code/.devcontainer/Dockerfile` | update OCI labels |
| `ralphex-fe/Dockerfile` | update OCI labels |
| `.devcontainer/Dockerfile` | update OCI labels and references |
| `claude-code/.devcontainer/docker-compose.yml` | update image reference |
| `claude-code/.devcontainer/claude-sandbox/docker-compose.yml` | update image reference |
| `.devcontainer/devcontainer.json` | update volume name prefixes |
| `.devcontainer/claude-sandbox/devcontainer.json` | update volume name prefixes |
| `.devcontainer/init-plugins.sh` | update comment |
| `README.md` | full rewrite of image references |
| `bun/README.md` | update image references |
| `claude-bun/README.md` | update image references |
| `hugo-bun/README.md` | update image references |
| `hugo-bun-node/README.md` | update image references |
| `claude-code/README.md` | update image references |
| `ralphex-fe/README.md` | add note about non-devcontainer-spec usage |
| `.claude/CLAUDE.md` | update naming conventions |
| `.claude/rules/dockerfile.md` | update OCI label template |
| `.claude/rules/new-image.md` | update directory conventions |
| `.claude/rules/workflows.md` | update trigger path patterns |

---

### Task 1: Rename image directories

**Files:**
- Rename: `devcontainer-bun/` → `bun/`
- Rename: `devcontainer-claude-bun/` → `claude-bun/`
- Rename: `devcontainer-hugo-bun/` → `hugo-bun/`
- Rename: `devcontainer-hugo-bun-node/` → `hugo-bun-node/`

- [ ] **Step 1: Rename directories with git mv**

```bash
git mv devcontainer-bun bun
git mv devcontainer-claude-bun claude-bun
git mv devcontainer-hugo-bun hugo-bun
git mv devcontainer-hugo-bun-node hugo-bun-node
```

- [ ] **Step 2: Verify renames**

Run: `ls -d bun claude-bun hugo-bun hugo-bun-node`
Expected: all four directories listed

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: rename image directories to drop devcontainer- prefix"
```

---

### Task 2: Rename workflow files

**Files:**
- Rename: `.github/workflows/build-devcontainer-bun.yml` → `.github/workflows/build-bun.yml`
- Rename: `.github/workflows/build-devcontainer-claude-bun.yml` → `.github/workflows/build-claude-bun.yml`
- Rename: `.github/workflows/build-devcontainer-hugo-bun.yml` → `.github/workflows/build-hugo-bun.yml`
- Rename: `.github/workflows/build-devcontainer-hugo-bun-node.yml` → `.github/workflows/build-hugo-bun-node.yml`

- [ ] **Step 1: Rename workflow files with git mv**

```bash
git mv .github/workflows/build-devcontainer-bun.yml .github/workflows/build-bun.yml
git mv .github/workflows/build-devcontainer-claude-bun.yml .github/workflows/build-claude-bun.yml
git mv .github/workflows/build-devcontainer-hugo-bun.yml .github/workflows/build-hugo-bun.yml
git mv .github/workflows/build-devcontainer-hugo-bun-node.yml .github/workflows/build-hugo-bun-node.yml
```

- [ ] **Step 2: Verify renames**

Run: `ls .github/workflows/build-*.yml`
Expected:
```
.github/workflows/build-bun.yml
.github/workflows/build-claude-bun.yml
.github/workflows/build-claude-code.yml
.github/workflows/build-hugo-bun.yml
.github/workflows/build-hugo-bun-node.yml
.github/workflows/build-ralphex-fe.yml
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: rename workflow files to drop devcontainer- prefix"
```

---

### Task 3: Update reusable workflow

The reusable workflow constructs `ghcr.io/{namespace}/{image-name}`. Since callers will now pass `devcontainers/bun` as the image-name, the construction logic stays the same. Only the description needs updating.

**Files:**
- Modify: `.github/workflows/reusable-docker-build.yml`

- [ ] **Step 1: Update the image-name input description**

In `.github/workflows/reusable-docker-build.yml`, change line 7:

```yaml
# Old:
      image-name:
        description: 'Image name (e.g. devcontainer-bun)'

# New:
      image-name:
        description: 'Image name including namespace (e.g. devcontainers/bun)'
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/reusable-docker-build.yml
git commit -m "refactor: update reusable workflow description for new naming"
```

---

### Task 4: Update build-bun.yml

**Files:**
- Modify: `.github/workflows/build-bun.yml`

- [ ] **Step 1: Update workflow content**

Replace the entire content of `.github/workflows/build-bun.yml` with:

```yaml
name: Build bun

on:
  push:
    branches:
      - master
    paths:
      - 'bun/.devcontainer/Dockerfile'
  workflow_dispatch:

concurrency:
  group: build-bun-${{ github.ref }}
  cancel-in-progress: true

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      version-tag: ${{ steps.versions.outputs.version-tag }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Extract versions from Dockerfile
        id: versions
        run: |
          DOCKERFILE="bun/.devcontainer/Dockerfile"
          BUN_VERSION=$(grep '^ARG BUN_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)
          echo "version-tag=bun${BUN_VERSION}-alpine" >> "$GITHUB_OUTPUT"
          echo "Bun: $BUN_VERSION"

  build:
    needs: prepare
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/reusable-docker-build.yml
    with:
      image-name: devcontainers/bun
      context: bun/.devcontainer
      dockerfile: bun/.devcontainer/Dockerfile
      version-tag: ${{ needs.prepare.outputs.version-tag }}
      verify-command: 'bun --version'
    secrets: inherit
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/build-bun.yml
git commit -m "refactor: update build-bun workflow for new paths and naming"
```

---

### Task 5: Update build-claude-bun.yml

**Files:**
- Modify: `.github/workflows/build-claude-bun.yml`

- [ ] **Step 1: Update workflow content**

Replace the entire content of `.github/workflows/build-claude-bun.yml` with:

```yaml
name: Build claude-bun

on:
  push:
    branches:
      - master
    paths:
      - 'claude-bun/.devcontainer/Dockerfile'
      - 'claude-bun/.devcontainer/init-firewall.sh'
  workflow_dispatch:

concurrency:
  group: build-claude-bun-${{ github.ref }}
  cancel-in-progress: true

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      version-tag: ${{ steps.versions.outputs.version-tag }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Extract versions from Dockerfile
        id: versions
        run: |
          DOCKERFILE="claude-bun/.devcontainer/Dockerfile"
          BUN_VERSION=$(grep '^ARG BUN_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)
          echo "version-tag=bun${BUN_VERSION}-slim" >> "$GITHUB_OUTPUT"
          echo "Bun: $BUN_VERSION"

  build:
    needs: prepare
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/reusable-docker-build.yml
    with:
      image-name: devcontainers/claude-bun
      context: claude-bun/.devcontainer
      dockerfile: claude-bun/.devcontainer/Dockerfile
      version-tag: ${{ needs.prepare.outputs.version-tag }}
      verify-command: 'bun --version'
    secrets: inherit
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/build-claude-bun.yml
git commit -m "refactor: update build-claude-bun workflow for new paths and naming"
```

---

### Task 6: Update build-hugo-bun.yml

**Files:**
- Modify: `.github/workflows/build-hugo-bun.yml`

- [ ] **Step 1: Update workflow content**

Replace the entire content of `.github/workflows/build-hugo-bun.yml` with:

```yaml
name: Build hugo-bun

on:
  push:
    branches:
      - master
    paths:
      - 'hugo-bun/.devcontainer/Dockerfile'
  workflow_dispatch:

concurrency:
  group: build-hugo-bun-${{ github.ref }}
  cancel-in-progress: true

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      version-tag: ${{ steps.versions.outputs.version-tag }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Extract versions from Dockerfile
        id: versions
        run: |
          DOCKERFILE="hugo-bun/.devcontainer/Dockerfile"
          HUGO_VERSION=$(grep '^ARG HUGO_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)
          BUN_VERSION=$(grep '^ARG BUN_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)
          echo "version-tag=hugo${HUGO_VERSION}-bun${BUN_VERSION}-alpine" >> "$GITHUB_OUTPUT"
          echo "Hugo: $HUGO_VERSION, Bun: $BUN_VERSION"

  build:
    needs: prepare
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/reusable-docker-build.yml
    with:
      image-name: devcontainers/hugo-bun
      context: hugo-bun/.devcontainer
      dockerfile: hugo-bun/.devcontainer/Dockerfile
      version-tag: ${{ needs.prepare.outputs.version-tag }}
      verify-command: 'bun --version && hugo version'
    secrets: inherit
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/build-hugo-bun.yml
git commit -m "refactor: update build-hugo-bun workflow for new paths and naming"
```

---

### Task 7: Update build-hugo-bun-node.yml

**Files:**
- Modify: `.github/workflows/build-hugo-bun-node.yml`

- [ ] **Step 1: Update workflow content**

Replace the entire content of `.github/workflows/build-hugo-bun-node.yml` with:

```yaml
name: Build hugo-bun-node

on:
  push:
    branches:
      - master
    paths:
      - 'hugo-bun-node/.devcontainer/Dockerfile'
  workflow_dispatch:

concurrency:
  group: build-hugo-bun-node-${{ github.ref }}
  cancel-in-progress: true

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      version-tag: ${{ steps.versions.outputs.version-tag }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Extract versions from Dockerfile
        id: versions
        run: |
          DOCKERFILE="hugo-bun-node/.devcontainer/Dockerfile"
          HUGO_VERSION=$(grep '^ARG HUGO_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)
          BUN_VERSION=$(grep '^ARG BUN_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)
          NODE_VERSION=$(grep '^ARG NODE_VERSION=' "$DOCKERFILE" | cut -d'=' -f2)
          echo "version-tag=hugo${HUGO_VERSION}-bun${BUN_VERSION}-node${NODE_VERSION}-alpine" >> "$GITHUB_OUTPUT"
          echo "Hugo: $HUGO_VERSION, Bun: $BUN_VERSION, Node: $NODE_VERSION"

  build:
    needs: prepare
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/reusable-docker-build.yml
    with:
      image-name: devcontainers/hugo-bun-node
      context: hugo-bun-node/.devcontainer
      dockerfile: hugo-bun-node/.devcontainer/Dockerfile
      version-tag: ${{ needs.prepare.outputs.version-tag }}
      verify-command: 'bun --version && hugo version && node --version'
    secrets: inherit
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/build-hugo-bun-node.yml
git commit -m "refactor: update build-hugo-bun-node workflow for new paths and naming"
```

---

### Task 8: Update build-claude-code.yml

**Files:**
- Modify: `.github/workflows/build-claude-code.yml`

- [ ] **Step 1: Update all references**

In `.github/workflows/build-claude-code.yml`, make these replacements:

1. Line 7: `'claude-code/.devcontainer/Dockerfile'` — no change needed (directory not renamed)
2. Line 35: `ghcr.io/gatezh/devcontainer-images/claude-code` → `ghcr.io/gatezh/devcontainers/claude-code`
3. Line 59: `ghcr.io/gatezh/devcontainer-images/claude-code-sandbox` → `ghcr.io/gatezh/devcontainers/claude-code-sandbox`
4. Line 104: `ghcr.io/gatezh/devcontainer-images/${{ matrix.image-suffix }}:latest` → `ghcr.io/gatezh/devcontainers/${{ matrix.image-suffix }}:latest`
5. Line 105: `ghcr.io/gatezh/devcontainer-images/${{ matrix.image-suffix }}:latest` → `ghcr.io/gatezh/devcontainers/${{ matrix.image-suffix }}:latest`

All occurrences: replace `devcontainer-images` with `devcontainers` in the image paths.

- [ ] **Step 2: Verify the changes**

Run: `grep 'devcontainer-images' .github/workflows/build-claude-code.yml`
Expected: no output (all replaced)

Run: `grep 'devcontainers/' .github/workflows/build-claude-code.yml`
Expected: 4 lines with `ghcr.io/gatezh/devcontainers/claude-code` references

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/build-claude-code.yml
git commit -m "refactor: update build-claude-code workflow image paths"
```

---

### Task 9: Update build-ralphex-fe.yml

**Files:**
- Modify: `.github/workflows/build-ralphex-fe.yml`

- [ ] **Step 1: Update image references**

In `.github/workflows/build-ralphex-fe.yml`, make these replacements:

1. Line 63: `meta-images: ghcr.io/gatezh/ralphex-fe` → `meta-images: ghcr.io/gatezh/devcontainers/ralphex-fe`
2. Line 95: `docker pull ghcr.io/gatezh/ralphex-fe:latest` → `docker pull ghcr.io/gatezh/devcontainers/ralphex-fe:latest`
3. Line 96: `docker run --rm --entrypoint sh ghcr.io/gatezh/ralphex-fe:latest` → `docker run --rm --entrypoint sh ghcr.io/gatezh/devcontainers/ralphex-fe:latest`

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/build-ralphex-fe.yml
git commit -m "refactor: update build-ralphex-fe workflow to devcontainers namespace"
```

---

### Task 10: Update update-and-build-ralphex-fe.yml

**Files:**
- Modify: `.github/workflows/update-and-build-ralphex-fe.yml`

- [ ] **Step 1: Update image-name in the reusable workflow call**

In `.github/workflows/update-and-build-ralphex-fe.yml`, line 152:

```yaml
# Old:
      image-name: ralphex-fe

# New:
      image-name: devcontainers/ralphex-fe
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/update-and-build-ralphex-fe.yml
git commit -m "refactor: update update-and-build-ralphex-fe image name"
```

---

### Task 11: Update CI workflow

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Update hadolint matrix paths**

In `.github/workflows/ci.yml`, replace the hadolint matrix (lines 24-29):

```yaml
# Old:
        dockerfile:
          - devcontainer-bun/.devcontainer/Dockerfile
          - devcontainer-claude-bun/.devcontainer/Dockerfile
          - devcontainer-hugo-bun/.devcontainer/Dockerfile
          - devcontainer-hugo-bun-node/.devcontainer/Dockerfile
          - ralphex-fe/Dockerfile

# New:
        dockerfile:
          - bun/.devcontainer/Dockerfile
          - claude-bun/.devcontainer/Dockerfile
          - hugo-bun/.devcontainer/Dockerfile
          - hugo-bun-node/.devcontainer/Dockerfile
          - ralphex-fe/Dockerfile
```

- [ ] **Step 2: Update path filters**

In `.github/workflows/ci.yml`, replace the path filter section (lines 66-75):

```yaml
# Old:
            devcontainer-bun:
              - 'devcontainer-bun/**'
            devcontainer-claude-bun:
              - 'devcontainer-claude-bun/**'
            devcontainer-hugo-bun:
              - 'devcontainer-hugo-bun/**'
            devcontainer-hugo-bun-node:
              - 'devcontainer-hugo-bun-node/**'
            ralphex-fe:
              - 'ralphex-fe/**'

# New:
            bun:
              - 'bun/**'
            claude-bun:
              - 'claude-bun/**'
            hugo-bun:
              - 'hugo-bun/**'
            hugo-bun-node:
              - 'hugo-bun-node/**'
            ralphex-fe:
              - 'ralphex-fe/**'
```

- [ ] **Step 3: Update environment variable names and add_image calls**

In `.github/workflows/ci.yml`, replace the set-matrix step's env block and conditionals (lines 80-131):

```yaml
        env:
          CHANGED_BUN: ${{ steps.filter.outputs.bun }}
          CHANGED_CLAUDE_BUN: ${{ steps.filter.outputs.claude-bun }}
          CHANGED_HUGO_BUN: ${{ steps.filter.outputs.hugo-bun }}
          CHANGED_HUGO_BUN_NODE: ${{ steps.filter.outputs.hugo-bun-node }}
          CHANGED_RALPHEX: ${{ steps.filter.outputs.ralphex-fe }}
        run: |
          INCLUDES="[]"

          add_image() {
            local image="$1" context="$2" dockerfile="$3" verify="$4"
            INCLUDES=$(echo "$INCLUDES" | jq -c \
              --arg img "$image" \
              --arg ctx "$context" \
              --arg df "$dockerfile" \
              --arg v "$verify" \
              '. + [{"image":$img,"context":$ctx,"dockerfile":$df,"verify":$v}]')
          }

          if [ "$CHANGED_BUN" = "true" ]; then
            add_image "bun" \
              "bun/.devcontainer" \
              "bun/.devcontainer/Dockerfile" \
              "bun --version"
          fi

          if [ "$CHANGED_CLAUDE_BUN" = "true" ]; then
            add_image "claude-bun" \
              "claude-bun/.devcontainer" \
              "claude-bun/.devcontainer/Dockerfile" \
              "bun --version"
          fi

          if [ "$CHANGED_HUGO_BUN" = "true" ]; then
            add_image "hugo-bun" \
              "hugo-bun/.devcontainer" \
              "hugo-bun/.devcontainer/Dockerfile" \
              "bun --version && hugo version"
          fi

          if [ "$CHANGED_HUGO_BUN_NODE" = "true" ]; then
            add_image "hugo-bun-node" \
              "hugo-bun-node/.devcontainer" \
              "hugo-bun-node/.devcontainer/Dockerfile" \
              "bun --version && hugo version && node --version"
          fi

          if [ "$CHANGED_RALPHEX" = "true" ]; then
            add_image "ralphex-fe" \
              "ralphex-fe" \
              "ralphex-fe/Dockerfile" \
              "bun --version && hugo version && /srv/ralphex --version"
          fi

          if [ "$INCLUDES" = "[]" ]; then
            {
              echo "has-changes=false"
              echo "matrix={\"include\":[]}"
            } >> "$GITHUB_OUTPUT"
          else
            {
              echo "has-changes=true"
              echo "matrix=$(echo "$INCLUDES" | jq -c '{include:.}')"
            } >> "$GITHUB_OUTPUT"
          fi
```

- [ ] **Step 4: Verify no old references remain**

Run: `grep 'devcontainer-bun\|devcontainer-claude-bun\|devcontainer-hugo-bun' .github/workflows/ci.yml`
Expected: no output

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "refactor: update CI workflow for renamed directories"
```

---

### Task 12: Update OCI labels in all Dockerfiles

All Dockerfiles need `org.opencontainers.image.source` and `org.opencontainers.image.url` changed from `devcontainer-images` to `devcontainers`, and `org.opencontainers.image.title` updated to drop the `devcontainer-` prefix.

**Files:**
- Modify: `bun/.devcontainer/Dockerfile` (lines 15-19)
- Modify: `claude-bun/.devcontainer/Dockerfile` (lines 92-96)
- Modify: `hugo-bun/.devcontainer/Dockerfile` (lines 33-37)
- Modify: `hugo-bun-node/.devcontainer/Dockerfile` (lines 49-53)
- Modify: `claude-code/.devcontainer/Dockerfile` (lines 198-202, 230-234)
- Modify: `ralphex-fe/Dockerfile` (lines 177-181)
- Modify: `.devcontainer/Dockerfile` (lines 139-143, 168-172)

- [ ] **Step 1: Update bun/.devcontainer/Dockerfile**

Replace the OCI labels (lines 15-19):

```dockerfile
# Old:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images"
LABEL org.opencontainers.image.description="Bun development container - multiplatform image for modern JavaScript/TypeScript development"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="devcontainer-bun"
LABEL org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"

# New:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers"
LABEL org.opencontainers.image.description="Bun development container - multiplatform image for modern JavaScript/TypeScript development"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="bun"
LABEL org.opencontainers.image.url="https://github.com/gatezh/devcontainers"
```

- [ ] **Step 2: Update claude-bun/.devcontainer/Dockerfile**

Replace the OCI labels (lines 92-96):

```dockerfile
# Old:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images" \
      org.opencontainers.image.description="Claude Code development container — Bun environment with Claude Code CLI, firewall sandbox, and zsh" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="devcontainer-claude-bun" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"

# New:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Claude Code development container — Bun environment with Claude Code CLI, firewall sandbox, and zsh" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="claude-bun" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"
```

- [ ] **Step 3: Update hugo-bun/.devcontainer/Dockerfile**

Replace the OCI labels (lines 33-37):

```dockerfile
# Old:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images"
LABEL org.opencontainers.image.description="Hugo Extended + Bun development container - multiplatform image for modern static site development"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="devcontainer-hugo-bun"
LABEL org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"

# New:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers"
LABEL org.opencontainers.image.description="Hugo Extended + Bun development container - multiplatform image for modern static site development"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="hugo-bun"
LABEL org.opencontainers.image.url="https://github.com/gatezh/devcontainers"
```

- [ ] **Step 4: Update hugo-bun-node/.devcontainer/Dockerfile**

Replace the OCI labels (lines 49-53):

```dockerfile
# Old:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images"
LABEL org.opencontainers.image.description="Hugo Extended + Bun + Node.js development container - multiplatform image for modern static site development with Cloudflare Workers support"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="devcontainer-hugo-bun-node"
LABEL org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"

# New:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers"
LABEL org.opencontainers.image.description="Hugo Extended + Bun + Node.js development container - multiplatform image for modern static site development with Cloudflare Workers support"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="hugo-bun-node"
LABEL org.opencontainers.image.url="https://github.com/gatezh/devcontainers"
```

- [ ] **Step 5: Update claude-code/.devcontainer/Dockerfile (default target)**

Replace the OCI labels at lines 198-202:

```dockerfile
# Old:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images" \
      org.opencontainers.image.description="Claude Code devcontainer — full dev environment with agent-browser, Playwright, and passwordless sudo" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="claude-code" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"

# New:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Claude Code devcontainer — full dev environment with agent-browser, Playwright, and passwordless sudo" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="claude-code" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"
```

- [ ] **Step 6: Update claude-code/.devcontainer/Dockerfile (sandbox target)**

Replace the OCI labels at lines 230-234:

```dockerfile
# Old:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images" \
      org.opencontainers.image.description="Claude Code devcontainer — network-restricted sandbox with firewall packages" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="claude-code-sandbox" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"

# New:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Claude Code devcontainer — network-restricted sandbox with firewall packages" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="claude-code-sandbox" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"
```

- [ ] **Step 7: Update ralphex-fe/Dockerfile**

Replace the OCI labels at lines 177-181:

```dockerfile
# Old:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainer-images" \
      org.opencontainers.image.description="Ralphex-fe: Frontend development image with Bun, Hugo Extended, Playwright, and Claude Code on Debian" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="ralphex-fe" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainer-images"

# New:
LABEL org.opencontainers.image.source="https://github.com/gatezh/devcontainers" \
      org.opencontainers.image.description="Ralphex-fe: Frontend development image with Bun, Hugo Extended, Playwright, and Claude Code on Debian" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="ralphex-fe" \
      org.opencontainers.image.url="https://github.com/gatezh/devcontainers"
```

- [ ] **Step 8: Update .devcontainer/Dockerfile (repo's own devcontainer)**

Replace `devcontainer-images` with `devcontainers` in all references. This file has:
- Line 2 comment: `devcontainer-images repo` → `devcontainers repo`
- Lines 12-13: build tag examples: `devcontainer-images:default` → `devcontainers:default`
- Lines 139-143: default target OCI labels
- Lines 168-172: sandbox target OCI labels

Replace all occurrences of `devcontainer-images` with `devcontainers` in this file.

- [ ] **Step 9: Verify no old references remain in Dockerfiles**

Run: `grep -r 'devcontainer-images' bun/ claude-bun/ hugo-bun/ hugo-bun-node/ claude-code/ ralphex-fe/ .devcontainer/Dockerfile`
Expected: no output

Run: `grep -r 'title="devcontainer-' bun/ claude-bun/ hugo-bun/ hugo-bun-node/`
Expected: no output

- [ ] **Step 10: Commit**

```bash
git add bun/.devcontainer/Dockerfile claude-bun/.devcontainer/Dockerfile hugo-bun/.devcontainer/Dockerfile hugo-bun-node/.devcontainer/Dockerfile claude-code/.devcontainer/Dockerfile ralphex-fe/Dockerfile .devcontainer/Dockerfile
git commit -m "refactor: update OCI labels in all Dockerfiles for new repo name"
```

---

### Task 13: Update docker-compose files

**Files:**
- Modify: `claude-code/.devcontainer/docker-compose.yml`
- Modify: `claude-code/.devcontainer/claude-sandbox/docker-compose.yml`

- [ ] **Step 1: Update default docker-compose.yml**

In `claude-code/.devcontainer/docker-compose.yml`, line 5:

```yaml
# Old:
    image: ghcr.io/gatezh/devcontainer-images/claude-code:latest

# New:
    image: ghcr.io/gatezh/devcontainers/claude-code:latest
```

- [ ] **Step 2: Update sandbox docker-compose.yml**

In `claude-code/.devcontainer/claude-sandbox/docker-compose.yml`, line 5:

```yaml
# Old:
    image: ghcr.io/gatezh/devcontainer-images/claude-code-sandbox:latest

# New:
    image: ghcr.io/gatezh/devcontainers/claude-code-sandbox:latest
```

- [ ] **Step 3: Commit**

```bash
git add claude-code/.devcontainer/docker-compose.yml claude-code/.devcontainer/claude-sandbox/docker-compose.yml
git commit -m "refactor: update docker-compose image references"
```

---

### Task 14: Update repo's own .devcontainer config

**Files:**
- Modify: `.devcontainer/devcontainer.json` (volume name prefixes)
- Modify: `.devcontainer/claude-sandbox/devcontainer.json` (volume name prefixes)
- Modify: `.devcontainer/init-plugins.sh` (comment)

- [ ] **Step 1: Update .devcontainer/devcontainer.json volume names**

Replace `devcontainer-images` with `devcontainers` in volume source names:

```jsonc
// Old:
"source=devcontainer-images-claude-config-${devcontainerId},target=/home/node/.claude,type=volume",
...
"source=devcontainer-images-fish-data-${devcontainerId},target=/home/node/.local/share/fish,type=volume"

// New:
"source=devcontainers-claude-config-${devcontainerId},target=/home/node/.claude,type=volume",
...
"source=devcontainers-fish-data-${devcontainerId},target=/home/node/.local/share/fish,type=volume"
```

- [ ] **Step 2: Update .devcontainer/claude-sandbox/devcontainer.json volume names**

Replace `devcontainer-images` with `devcontainers` in volume source names:

```jsonc
// Old:
"source=devcontainer-images-sandbox-config-${devcontainerId},target=/home/node/.claude,type=volume",
"source=devcontainer-images-sandbox-fish-${devcontainerId},target=/home/node/.local/share/fish,type=volume",

// New:
"source=devcontainers-sandbox-config-${devcontainerId},target=/home/node/.claude,type=volume",
"source=devcontainers-sandbox-fish-${devcontainerId},target=/home/node/.local/share/fish,type=volume",
```

- [ ] **Step 3: Update .devcontainer/init-plugins.sh comment**

```bash
# Old:
# Initialize Claude Code plugins for the devcontainer-images repo

# New:
# Initialize Claude Code plugins for the devcontainers repo
```

- [ ] **Step 4: Commit**

```bash
git add .devcontainer/devcontainer.json .devcontainer/claude-sandbox/devcontainer.json .devcontainer/init-plugins.sh
git commit -m "refactor: update repo devcontainer config for new repo name"
```

---

### Task 15: Update all README files

**Files:**
- Modify: `README.md`
- Modify: `bun/README.md`
- Modify: `claude-bun/README.md`
- Modify: `hugo-bun/README.md`
- Modify: `hugo-bun-node/README.md`
- Modify: `claude-code/README.md`
- Modify: `ralphex-fe/README.md`

- [ ] **Step 1: Update root README.md**

Replace all occurrences using these rules:
- `devcontainer-images` (repo name) → `devcontainers`
- `./devcontainer-bun/` → `./bun/`
- `./devcontainer-claude-bun/` → `./claude-bun/`
- `./devcontainer-hugo-bun/` → `./hugo-bun/`
- `./devcontainer-hugo-bun-node/` → `./hugo-bun-node/`
- `devcontainer-name/` → `image-name/` (in the structure example)
- `ghcr.io/gatezh/devcontainer-images/claude-code` → `ghcr.io/gatezh/devcontainers/claude-code`
- `ghcr.io/gatezh/devcontainer-images/claude-code-sandbox` → `ghcr.io/gatezh/devcontainers/claude-code-sandbox`
- `ghcr.io/<username>/devcontainer-bun` → `ghcr.io/<username>/devcontainers/bun`
- `ghcr.io/<username>/devcontainer-claude-bun` → `ghcr.io/<username>/devcontainers/claude-bun`
- `ghcr.io/<username>/devcontainer-hugo-bun` → `ghcr.io/<username>/devcontainers/hugo-bun`
- `ghcr.io/<username>/ralphex-fe` → `ghcr.io/<username>/devcontainers/ralphex-fe`
- Section headers: `### devcontainer-bun` → `### bun`, etc.
- Title: `# Devcontainer Images` → `# Devcontainers`
- Directory structure example: update `devcontainer-name/` → `image-name/`
- Adding new image instructions: `devcontainer-myimage/` → `myimage/`
- `build-devcontainer-{name}.yml` → `build-{name}.yml` (in "Adding a New Image")

- [ ] **Step 2: Update bun/README.md**

Replace all occurrences:
- `# devcontainer-bun` → `# bun`
- `devcontainer-bun:` → `devcontainers/bun:` (in image references like `ghcr.io/<USERNAME>/devcontainer-bun:`)
- `ghcr.io/myusername/devcontainer-bun:` → `ghcr.io/myusername/devcontainers/bun:`
- `devcontainer-images repository` → `devcontainers repository` (in License section)

- [ ] **Step 3: Update claude-bun/README.md**

Replace all occurrences:
- `# devcontainer-claude-bun` → `# claude-bun`
- `ghcr.io/gatezh/devcontainer-claude-bun:` → `ghcr.io/gatezh/devcontainers/claude-bun:`
- `devcontainer-images repository` → `devcontainers repository` (if present)

- [ ] **Step 4: Update hugo-bun/README.md**

Replace all occurrences:
- `# devcontainer-hugo-bun` → `# hugo-bun`
- `devcontainer-hugo-bun:` → `devcontainers/hugo-bun:` (in image references)
- `ghcr.io/myusername/devcontainer-hugo-bun:` → `ghcr.io/myusername/devcontainers/hugo-bun:`
- `devcontainer-images repository` → `devcontainers repository`

- [ ] **Step 5: Update hugo-bun-node/README.md**

Replace all occurrences:
- `# devcontainer-hugo-bun-node` → `# hugo-bun-node`
- `devcontainer-hugo-bun-node:` → `devcontainers/hugo-bun-node:` (in image references)
- `ghcr.io/myusername/devcontainer-hugo-bun-node:` → `ghcr.io/myusername/devcontainers/hugo-bun-node:`
- `devcontainer-images repository` → `devcontainers repository`

- [ ] **Step 6: Update claude-code/README.md**

Replace all occurrences:
- `ghcr.io/gatezh/devcontainer-images/claude-code` → `ghcr.io/gatezh/devcontainers/claude-code`
- `ghcr.io/gatezh/devcontainer-images/claude-code-sandbox` → `ghcr.io/gatezh/devcontainers/claude-code-sandbox`
- `devcontainer-images` (repo name references) → `devcontainers`
- `git clone https://github.com/gatezh/devcontainer-images.git` → `git clone https://github.com/gatezh/devcontainers.git`
- `cd devcontainer-images/claude-code` → `cd devcontainers/claude-code`

- [ ] **Step 7: Update ralphex-fe/README.md**

Replace:
- `ghcr.io/gatezh/ralphex-fe:` → `ghcr.io/gatezh/devcontainers/ralphex-fe:`

Add a note near the top (after the first paragraph):

```markdown
> **Note:** This is not a devcontainer in the VS Code Dev Container spec sense (no `devcontainer.json`). It is a standalone Docker image used as a development environment for ralphex projects.
```

- [ ] **Step 8: Verify no old references remain**

Run: `grep -r 'devcontainer-images' README.md bun/README.md claude-bun/README.md hugo-bun/README.md hugo-bun-node/README.md claude-code/README.md ralphex-fe/README.md`
Expected: no output (except possibly the old plan file in docs/)

Run: `grep -r 'ghcr.io/gatezh/devcontainer-bun\|ghcr.io/gatezh/devcontainer-claude-bun\|ghcr.io/gatezh/devcontainer-hugo-bun\|ghcr.io/gatezh/ralphex-fe' README.md bun/ claude-bun/ hugo-bun/ hugo-bun-node/ claude-code/ ralphex-fe/`
Expected: no output

- [ ] **Step 9: Commit**

```bash
git add README.md bun/README.md claude-bun/README.md hugo-bun/README.md hugo-bun-node/README.md claude-code/README.md ralphex-fe/README.md
git commit -m "docs: update all READMEs for new repo name and image paths"
```

---

### Task 16: Update .claude/ configuration files

**Files:**
- Modify: `.claude/CLAUDE.md`
- Modify: `.claude/rules/dockerfile.md`
- Modify: `.claude/rules/new-image.md`
- Modify: `.claude/rules/workflows.md`

- [ ] **Step 1: Update .claude/CLAUDE.md**

Replace the naming conventions section:

```markdown
# Old:
## Naming Conventions

### Image names
- Devcontainer: `devcontainer-{tool}` or `devcontainer-{tool}-{secondary}`
- Standalone: `{base}-{variant}` (e.g., `ralphex-fe`)

# New:
## Naming Conventions

### Directory names
- Named after the primary tool(s): `{tool}` or `{tool}-{secondary}` (e.g., `bun`, `hugo-bun`, `claude-code`)
- No `devcontainer-` prefix — the repo name `devcontainers` provides that context

### Image paths
- All images: `ghcr.io/gatezh/devcontainers/{directory-name}` (e.g., `ghcr.io/gatezh/devcontainers/bun`)
```

Also update the Project Overview line:
```markdown
# Old:
Dockerfiles for custom devcontainer images on GitHub Container Registry (ghcr.io). Each image provides a VS Code Dev Container for a specific development environment.

# New:
Dockerfiles for custom devcontainer images on GitHub Container Registry (ghcr.io). Each image provides a development container for a specific environment. Published under `ghcr.io/gatezh/devcontainers/`.
```

- [ ] **Step 2: Update .claude/rules/dockerfile.md**

Replace the OCI label template:

```markdown
# Old:
LABEL org.opencontainers.image.source="https://github.com/{owner}/devcontainer-images" \
      org.opencontainers.image.description="{Brief description}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="{image-name}" \
      org.opencontainers.image.url="https://github.com/{owner}/devcontainer-images"

# New:
LABEL org.opencontainers.image.source="https://github.com/{owner}/devcontainers" \
      org.opencontainers.image.description="{Brief description}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="{image-name}" \
      org.opencontainers.image.url="https://github.com/{owner}/devcontainers"
```

- [ ] **Step 3: Update .claude/rules/new-image.md**

Replace entire content:

```markdown
# Adding a New Image

## Devcontainer Image

1. Create `{name}/.devcontainer/Dockerfile`
2. Create `{name}/.devcontainer/devcontainer.json`
3. Create `{name}/README.md`
4. Create `.github/workflows/build-{name}.yml`
5. Update root `README.md` with new image entry

## Standalone Docker Image

1. Create `{name}/Dockerfile` (no `.devcontainer/` subdirectory)
2. Create `{name}/README.md`
3. Create `.github/workflows/build-{name}.yml`
4. Update root `README.md` with new image entry
```

- [ ] **Step 4: Update .claude/rules/workflows.md**

Update the trigger path patterns:

```markdown
# Old:
      - '{image-name}/.devcontainer/Dockerfile'
      - '{image-name}/.devcontainer/*.sh'
...
      - '{image-name}/Dockerfile'
      - '{image-name}/files/**'

# New:
      - '{name}/.devcontainer/Dockerfile'
      - '{name}/.devcontainer/*.sh'
...
      - '{name}/Dockerfile'
      - '{name}/files/**'
```

- [ ] **Step 5: Commit**

```bash
git add .claude/CLAUDE.md .claude/rules/dockerfile.md .claude/rules/new-image.md .claude/rules/workflows.md
git commit -m "docs: update .claude/ config for new naming conventions"
```

---

### Task 17: Lint verification

- [ ] **Step 1: Run hadolint on all Dockerfiles**

```bash
hadolint bun/.devcontainer/Dockerfile
hadolint claude-bun/.devcontainer/Dockerfile
hadolint hugo-bun/.devcontainer/Dockerfile
hadolint hugo-bun-node/.devcontainer/Dockerfile
hadolint claude-code/.devcontainer/Dockerfile
hadolint ralphex-fe/Dockerfile
hadolint .devcontainer/Dockerfile
```

Expected: all pass (OCI labels don't affect lint)

- [ ] **Step 2: Run actionlint on workflows**

```bash
actionlint .github/workflows/build-bun.yml
actionlint .github/workflows/build-claude-bun.yml
actionlint .github/workflows/build-hugo-bun.yml
actionlint .github/workflows/build-hugo-bun-node.yml
actionlint .github/workflows/build-claude-code.yml
actionlint .github/workflows/build-ralphex-fe.yml
actionlint .github/workflows/update-and-build-ralphex-fe.yml
actionlint .github/workflows/ci.yml
actionlint .github/workflows/reusable-docker-build.yml
```

Expected: all pass

- [ ] **Step 3: Final grep for any missed old references**

```bash
grep -r 'devcontainer-images' --include='*.yml' --include='*.yaml' --include='*.md' --include='*.json' --include='*.jsonc' --include='Dockerfile' --include='*.sh' . | grep -v 'docs/superpowers/plans/' | grep -v '.git/'
```

Expected: no output (the old plan file in docs/ is excluded)

```bash
grep -r 'ghcr.io/gatezh/devcontainer-' --include='*.yml' --include='*.yaml' --include='*.md' --include='*.json' --include='*.jsonc' --include='Dockerfile' --include='*.sh' . | grep -v 'docs/superpowers/plans/' | grep -v '.git/'
```

Expected: no output

---

### Task 18: GitHub repository rename (manual)

This task is done by the user via the GitHub UI, NOT via code.

- [ ] **Step 1: Rename repository on GitHub**

Go to `https://github.com/gatezh/devcontainer-images/settings` → Repository name → change to `devcontainers` → click "Rename".

GitHub will automatically set up a redirect from the old URL. All existing git remotes using the old URL will continue to work, but should be updated.

- [ ] **Step 2: Update local git remote**

```bash
git remote set-url github git@github.com:gatezh/devcontainers.git
```

- [ ] **Step 3: Delete old GHCR packages (optional)**

Old packages at `ghcr.io/gatezh/devcontainer-bun`, `ghcr.io/gatezh/devcontainer-claude-bun`, etc. can be deleted from the GitHub Packages settings page once all consumers have migrated to the new paths.
