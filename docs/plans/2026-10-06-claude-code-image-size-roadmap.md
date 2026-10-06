# claude-code Image Size — Roadmap

> Living roadmap. Pick up the next unchecked tier; update the status and the
> measurements table as each one lands. Move to `completed/` when Tier 3 ships
> or the remaining tiers are explicitly dropped.

**Goal:** Shrink `ghcr.io/gatezh/devcontainers/claude-code` (and `-sandbox`) back
toward the lean image this repo started with, without losing tools that are
actually used.

**Status:**

- [x] Analysis: baseline measured (2026-10-06)
- [x] **Tier 1:** remove waste and share layers (branch `perf/claude-code-image-size`, 2026-10-06)
- [ ] **Tier 2:** strip the Mesa/LLVM graphics stack from Chromium (optional, hacky)
- [ ] **Tier 3:** take the browser out of the core image (the architectural change)

---

## Baseline (2026-10-06, `latest`, linux/amd64, Claude Code 2.1.291)

| Image | On disk | Download (compressed) |
|---|---|---|
| `claude-code` (default) | 2.82 GB | 812 MB |
| `claude-code-sandbox` | ~2.6 GB | 715 MB |

### Where the bytes go (default target, on disk)

| Component | Size | Notes |
|---|---|---|
| Chromium + deps | 731 MB | `chromium` 320 MB, `chromium-common` 66 MB, `libllvm19` 127 MB, `mesa-libgallium` 42 MB, `libz3-4` 27 MB, GTK/icons. LLVM/Mesa/z3 come in via `chromium → libgbm1 → mesa-libgallium`. |
| Claude Code (npm) | 366 MB | 239 MB native binary (`claude.exe`) **+ 107 MB npm cache** (`~/.npm/_cacache`) left in the layer |
| node:24-trixie-slim | 244 MB | Debian 88 MB + Node 156 MB |
| agent-browser (npm) | 174 MB | ships **7 prebuilt binaries** (darwin×2, win32, linux-musl×2, linux×2) — only `linux-<arch>` (18 MB) is used **+ 51 MB npm cache** |
| mise | 153 MB | the upstream binary really is this size now (stripping saves only 15 MB); installed unpinned via `curl mise.run` |
| apt base | 147 MB | git (+ ~50 MB perl), openssh-client, zsh, curl, jq, sudo, fzf |
| gh (.deb) + gh-stack | 94 MB | gh 43 MB; gh-stack 26 MB **+ 25 MB `~/.cache/gh`** (gh's HTTP cache of the download) |
| oh-my-zsh + p10k, rtk, ralphex | 45 MB | |

### Structural problems

1. **The daily-churn layer is bloated.** Claude Code is bumped by Renovate
   almost daily, and its layer was 214 MB compressed — half of it the npm cache.
   Every consumer re-pulls it on every bump.
2. **default and sandbox share nothing heavy.** Each target installed Chromium
   and Claude Code in its own layers, so anyone using both images (and the
   registry) carried ~490 MB compressed twice.

### How to re-measure

```bash
IMG=ghcr.io/gatezh/devcontainers/claude-code:latest
docker history --format '{{.Size}}\t{{printf "%.100s" .CreatedBy}}' "$IMG" | grep -v '^0B'
docker run --rm --entrypoint sh -u root "$IMG" -c \
  'du -xsh /usr/lib/chromium /usr/local/share/npm-global/lib/node_modules/* /home/node/.[a-z]* /usr/local/bin/*' 
docker run --rm --entrypoint sh -u root "$IMG" -c \
  "dpkg-query -Wf '\${Installed-Size}\t\${Package}\n' | sort -rn | head -20"
# compressed (download) size per layer — note: in zsh write "${R}:latest", "$R:latest" triggers the :l modifier
R=ghcr.io/gatezh/devcontainers/claude-code
DG=$(docker buildx imagetools inspect --raw "${R}:latest" | jq -r '.manifests[] | select(.platform.architecture=="amd64") | .digest')
docker buildx imagetools inspect --raw "${R}@${DG}" | jq '[.layers[].size] | add / 1048576'
```

---

## Tier 1 — Remove waste, share layers (safe)

No behavior change; every tool stays. Changes in `claude-code/.devcontainer/Dockerfile`:

- [x] `npm install -g` uses `--cache /tmp/npm-cache` on a BuildKit cache mount, so
  no npm cache lands in the image (−158 MB, already-compressed data, so the
  download shrinks by nearly the same amount).
- [x] Delete agent-browser's six non-matching platform binaries in the install
  step (−95 MB). Safe: npm's global `agent-browser` link points straight at
  `bin/agent-browser-linux-<arch>`.
- [x] `rm -rf ~/.cache/gh` in the gh-stack install step (−25 MB).
- [x] New `shared` stage (sudoers, Chromium, Claude Code) that both targets build
  `FROM`; each target adds only a small layer (agent-browser / firewall packages).
  Trade-off: those small layers now rebuild on each Claude Code bump.

**Expected:** default download ~812 → ~610 MB; the Claude Code layer halves
(~214 → ~107 MB compressed per bump); default + sandbox share all heavy layers.

**Result (local amd64 build, 2026-10-06):** 2.82 → 2.32 GB on disk; download
852 → 633 MB (−26%, measured as Docker "content size" for both, which reads
~40 MB higher than the registry's 812 MB). Claude Code layer 214 → 108 MB
compressed; agent-browser layer 174 → 19 MB; default and sandbox share 22 of
23 layers (sandbox adds only a 17.6 MB firewall layer). CI verify commands pass
for both targets; also checked: headless Chromium renders, `agent-browser`
opens and snapshots a page, runtime `npx` works and creates a node-owned `~/.npm`.

---

## Tier 2 — Strip the graphics stack from Chromium (optional)

Headless Chromium renders in software through its bundled SwiftShader
(`/usr/lib/chromium/libvk_swiftshader.so`), so these are dead weight at runtime:

- `libllvm19` (127 MB), `mesa-libgallium` (42 MB), `libz3-4` (27 MB)
- `/usr/lib/chromium/libVkLayer_khronos_validation.so` (23 MB, a Vulkan debug layer)

**Catch:** `libgbm1` hard-depends on `mesa-libgallium`, so removing them with
`dpkg --force-depends` / `rm` leaves apt with broken dependencies. Users have
sudo; a later `apt-get install` will try to "fix" it. Options to evaluate:

- `dpkg --path-exclude` rules (in `/etc/dpkg/dpkg.cfg.d/`) for the library
  files before installing Chromium: packages stay "installed", files never land.
- An equivs dummy package instead of the real one.

**Gate:** only ship with a CI smoke test that actually launches the browser
(`chromium --headless --no-sandbox --dump-dom about:blank`, plus an
`agent-browser` open/snapshot) on **both** amd64 and arm64.

**Expected:** −~220 MB on disk, ~−60 MB compressed.

---

## Tier 3 — Take the browser out of the core image (architecture)

Chromium + agent-browser are ~0.9 GB of the image, and many projects never
drive a browser. A core image without them is roughly:

| Core content | Size |
|---|---|
| node:24-trixie-slim | 244 MB |
| apt base (git, zsh, ssh, …) | 147 MB |
| mise | 153 MB |
| Claude Code | 239 MB |
| gh + gh-stack, oh-my-zsh, rtk, ralphex | ~115 MB |
| **Total** | **~0.9 GB on disk, ~330 MB download** |

### Option 3a — layered `browser` variant (recommended first)

- `claude-code` = core (no Chromium, no agent-browser)
- `claude-code-browser` = `FROM` core + Chromium + agent-browser
- sandbox: same split (`claude-code-sandbox` / `claude-code-sandbox-browser`),
  or sandbox always gets the browser (firewall blocks runtime apt installs).

Simple, no runtime changes; projects pick the variant in their compose file.
The browser variant shares every core layer.

**Open questions:**
- Which consumer projects actually use the Playwright MCP plugin / agent-browser?
  (They switch image tag; the others get the slim one for free.)
- Is the Playwright plugin wired by `init-plugins.sh` unconditionally? Then it
  needs to skip it (and `patch-playwright-mcp`) when `/usr/bin/chromium` is absent.
- CI verify commands and image tags per variant; README + template updates.
- Tag naming per `.claude/CLAUDE.md` conventions.

### Option 3b — browser as a sidecar container (experiment later)

Run Chromium (or Microsoft's Playwright MCP image, serving MCP over HTTP) as a
second Compose service next to the dev container:

- `network_mode: "service:<dev>"` puts it in the dev container's network
  namespace: `localhost` dev servers keep working, and in the sandbox the
  iptables firewall should apply to the browser too. **Unverified, must test.**
- Playwright MCP / agent-browser connect over CDP (`--cdp-endpoint` /
  `--cdp`), or Claude connects to the MCP server's HTTP endpoint directly.
- Could retire `patch-playwright-mcp` and its SessionStart hook (#87, #98).
- Sidecar image changes rarely, so it's pulled once — not on every Claude bump.

Costs: more moving parts in every consumer's compose file; needs a design pass
on the sandbox network model before adopting.

---

## Considered and not recommended (for now)

- **Back to Alpine.** Saves maybe ~150 MB (perl, glibc userland). The heavy
  items — Claude Code, mise, Chromium — are the same size on any distro, and
  rtk's arm64 build is glibc-only. Not worth the musl risk.
- **Drop Node.** Playwright MCP runs via `npx`; mise-managed Node would shadow
  `npx` (see Dockerfile). The node base layer is shared and rarely changes.
- **Install Claude Code at container start** (native installer into a volume,
  self-updating). Removes 239 MB and most rebuilds, but reverses the pinned,
  Renovate-driven versions from #116, and the sandbox firewall would need the
  download host allowlisted. Revisit only if per-bump pulls are still painful
  after Tier 1.

## Small follow-ups noticed

- mise is installed unpinned (`curl https://mise.run | sh`): non-reproducible,
  and only refreshed when the layer cache busts. Move it to a pinned
  GitHub-release download stage under Renovate, like rtk/ralphex.

---

## Measurements log

| Date | Change | default disk | default download | sandbox download | Claude layer (compressed) |
|---|---|---|---|---|---|
| 2026-10-06 | baseline (`latest`) | 2.82 GB | 812 MB (852 local) | 715 MB | 214 MB |
| 2026-10-06 | Tier 1 (local build, before publish) | 2.32 GB | 633 MB local | 631 MB local, 18 MB on top of default | 108 MB |
