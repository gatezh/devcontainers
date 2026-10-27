# Turn on the built-in You should know plugin — review (PR #260)

Reviewed: PR #260, branch `feat/enable-you-should-know` (commit `9a5f5a7`), changing
`claude-code/.devcontainer/init-plugins.sh` and `claude-code/README.md`. There is no plan or spec for it, so it was
reviewed against the PR description.

Versions checked against: Claude Code 2.1.310 (the image's `CLAUDE_CODE_VERSION`, and the local CLI), the
`ghcr.io/gatezh/devcontainers/claude-code:latest` image, jq 1.7, shellcheck 0.11.0. Docs: Claude Code
[interactive mode: You should know](https://code.claude.com/docs/en/interactive-mode#you-should-know-suggestions),
[mods overview: built-in mods](https://code.claude.com/docs/en/plugins/mods/overview#mods-built-into-claude-code),
[settings precedence](https://code.claude.com/docs/en/settings#settings-precedence),
[plugins for your organization](https://code.claude.com/docs/en/plugins/org) and
[env vars: features that need feature-flag fetching](https://code.claude.com/docs/en/env-vars#features-that-need-feature-flag-fetching).

## Review Round 1

### Summary

The goal is right, and so is the scope: user settings, not managed. A managed `enabledPlugins` entry can't be turned
off per user. But the PR's main design choice rests on a premise that doesn't reproduce. `claude plugin enable
cc-plugin-you-should-know@builtin` succeeds in the image with a fresh `~/.claude`, no sign-in, no feature flags, and even
with no network. It writes exactly the setting the PR builds by hand. The hand-written jq write should go. The CLI
replaces it, and that also fixes the two real bugs the custom write has: a 0-byte `settings.json` is silently left
empty, and a `600` settings file comes back as `644`. The README should also say that the mod spends the user's usage.

### Important

#### 1. `claude plugin enable` works before feature flags load; use it instead of writing `settings.json` by hand

`claude-code/.devcontainer/init-plugins.sh:97-109`

The code comment and the PR description both say `claude plugin enable` "fails until feature flags load". It doesn't.
Probes in `ghcr.io/gatezh/devcontainers/claude-code:latest` (2.1.310), each with a fresh `CLAUDE_CONFIG_DIR`, no
credentials and no cached flags, which is the sandbox's `postCreateCommand` state:

| Probe | Result |
| --- | --- |
| `claude plugin enable cc-plugin-you-should-know@builtin` | `✔ Successfully enabled plugin`, writes `{"enabledPlugins":{"cc-plugin-you-should-know@builtin":true}}` |
| Same, with `docker run --network none` | Same result, so no flag fetch was involved |
| Same, with a misspelled id (`cc-plugin-you-shuld-know@builtin`) | Also succeeds: the CLI does no availability check at all |
| Same, on a 0-byte `settings.json` | Writes valid JSON with the key |
| Same, on a `chmod 600` settings file | Mode stays `600` |

The message the PR describes, `Plugin "…" is not installed in this project`, comes from the interactive `/plugin`
component. In the binary it sits in the React `/plugin` UI code next to `failed-plugin-details`. The
[docs](https://code.claude.com/docs/en/interactive-mode#you-should-know-suggestions) say the same: "Where `/plugin`
doesn't list the mod, the enable **command** answers …", meaning the slash command. The shell CLI doesn't have this
check.

Two parts of the custom code are still needed, and both were checked:

- **A guard for an existing key.** The CLI overwrites an explicit `false`: `disable` then `enable` gives `true`. So
  keep a read-only "is the key set?" check to respect `/plugin disable`.
- **A settings-file read for that guard.** `claude plugin list --json` returns `[]` in the image and doesn't list
  built-ins, so it can't serve as the guard the way it does for `DISABLED_PLUGINS`.

The fix replaces lines 97-109 with the same pattern the `DISABLED_PLUGINS` block above it uses (CLI write plus
`✔`/`⚠` output):

```bash
# ── Built-in plugins ────────────────────────────────────────────────────────
# Off by default. Enabled only while unset, so a `/plugin disable` (stored as
# false) survives re-runs; `claude plugin enable` alone would overwrite it.
ENABLED_PLUGINS=(
    "cc-plugin-you-should-know@builtin"   # "You should know" notes above the prompt
)

for plugin in "${ENABLED_PLUGINS[@]}"; do
    if ! jq -e --arg id "$plugin" '.enabledPlugins | has($id)' \
        "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" &>/dev/null; then
        if claude plugin enable "$plugin" 2>&1; then
            echo "✔ Enabled: $plugin"
        else
            echo "⚠ Failed to enable: $plugin" >&2
        fi
    fi
done
```

This was tested in the image with `--network none`. Results by settings-file state:

| Settings file | Result |
| --- | --- |
| None, 0-byte, `{}`, `enabledPlugins: null` | Enabled |
| Has other plugins | Enabled, other keys kept |
| Explicit `false` | Left alone |
| Invalid JSON | `⚠ Failed to enable`, with the CLI's `Invalid JSON syntax in settings file at …`, and the script continues |

shellcheck passes. The fix removes the `/tmp/settings.json` write, the `echo '{}'` seed and the jq write expression,
and with them findings #2 and #3. Correct the PR description's "Why not `claude plugin enable`" note in the same
change.

### Minor

#### 2. A 0-byte `settings.json` is left empty, and the plugin isn't enabled

`claude-code/.devcontainer/init-plugins.sh:104-108`

`[ -f "$SETTINGS" ]` is true for an empty file, so no `{}` is seeded. jq then reads no input and prints nothing with
exit code 0, so `mv` replaces the file with an empty one. No error appears. Probe: `printf '' > s.json; jq … s.json`
gives 0 bytes of output and `rc=0`. A whitespace-only file behaves the same. The PR description lists "empty" among
the tested cases, so that test presumably used `{}`. Fixed by #1. If the jq write stays, use `[ -s "$SETTINGS" ]`.

#### 3. Writing through `/tmp/settings.json` resets the file mode and replaces a symlink

`claude-code/.devcontainer/init-plugins.sh:108`

The write produces a new file in `/tmp`, then `mv`s it over `settings.json`:

- **File mode.** The new file has the default umask mode, not the original's. Probe in the image: a settings file at
  `600` with an `env` token came back as `644`. `settings.json` is where users keep `env` secrets and `apiKeyHelper`.
- **Symlinks.** `mv` renames over the destination, so a symlinked `settings.json` (common with dotfile managers)
  becomes a regular file.
- **Atomicity.** `/tmp` and the `~/.claude` volume are different filesystems, so the `mv` is a copy plus delete, not
  an atomic rename.

The repo's own settings editor, `drop-rtk-hook.sh:15-16`, already avoids the cross-filesystem move by writing
`"$SETTINGS.tmp"` next to the file. The CLI keeps the mode (probe: `600` stays `600`). Fixed by #1.

#### 4. The README doesn't say the mod spends the user's usage, and "telemetry on" is imprecise

`claude-code/README.md:152`

The PR turns on a feature with a recurring cost for every project that copies the template. The PR description
mentions this ("the side agent spends the user's usage"), but the README, which consumers read, doesn't. Per the
[docs](https://code.claude.com/docs/en/interactive-mode#cost-of-checks), checks "count toward your plan's usage limits
or your API costs". The mod's instructions, "several thousand tokens", are "billed in full on every check".

"Needs telemetry on" is also narrower than the real requirement. The mod needs **feature-flag fetching**, which
`DISABLE_TELEMETRY`, `DO_NOT_TRACK`, `DISABLE_GROWTHBOOK` and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` all turn off.
It also isn't listed through an LLM gateway, a Claude apps gateway or an `apiKeyHelper`, or when the organization
doesn't offer it. Suggested text:

> It also turns on Claude Code's built-in [You should know](…) mod (`ENABLED_PLUGINS`), unless you've turned it off
> with `/plugin disable`. A side agent rereads the conversation during longer tasks, and each check counts toward your
> plan's usage or API costs. It needs a direct claude.ai or Console API-key login and feature-flag fetching, so
> `DISABLE_TELEMETRY` or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` turns it off.

### Nits

- **No status output.** Every other section prints `✔`/`⚠` per item, and the new block prints nothing. A failed
  write shows only a raw jq error. #1's code fixes this.
- **No section header.** The new block has none, while its neighbours use `# ── Conflicting plugins ──…`. #1's code
  adds `# ── Built-in plugins ──…`.
- **Config path.** The block uses `$HOME/.claude/settings.json`. `claude plugin enable` and `/plugin disable` write to
  `$CLAUDE_CONFIG_DIR/settings.json`, and `drop-rtk-hook.sh` and the root `.devcontainer/init-plugins.sh` both read
  `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`. The two paths are the same in both devcontainer.json files
  (`CLAUDE_CONFIG_DIR=/home/node/.claude`). Still, the guard should read the file the CLI writes. #1's code does.

### Native-first audit

| Custom piece | Built-in checked (where) | Verdict |
| --- | --- | --- |
| jq write of `enabledPlugins[$id] = true` | `claude plugin enable <id>@builtin` (2.1.310 probes, fresh config, offline) | **Replace** (#1) |
| `[ -f ] \|\| echo '{}'` seed | CLI creates the file and handles the 0-byte case (probe) | **Replace** (#1) |
| "Key already set?" guard | `claude plugin list --json`: returns `[]`, doesn't list built-ins (probe). `claude plugin enable` overwrites `false` (probe) | **Keep**: read-only, and the CLI has no "enable unless set" mode |
| User-scope settings instead of managed | Managed `enabledPlugins` "force-enables… disabling one at their own scope doesn't stop it from loading" ([org docs](https://code.claude.com/docs/en/plugins/org#require-a-marketplace-and-its-plugins)) | **Keep**: user scope is the only one that's on by default and can be turned off |
| Enabling per project with `/plugin enable` | None at build time; the mod is off by default ([mods overview](https://code.claude.com/docs/en/plugins/mods/overview#mods-built-into-claude-code)) | **Keep**: this is the PR's purpose |
| Seed dir (`CLAUDE_CODE_PLUGIN_SEED_DIR`) | For marketplace plugin caches; a built-in needs no install, and seeds still need `enabledPlugins` ([seed docs](https://code.claude.com/docs/en/plugins/org#seed-containers-and-ci)) | **N/A** |

### Checked and correct

- **Plugin id.** `cc-plugin-you-should-know@builtin` matches the docs, and the image's 2.1.310 meets the mod's
  v2.1.287 minimum.
- **Sandbox.** `init-plugins.sh` runs in `postCreateCommand`, before `postStartCommand` brings the firewall up.
  Feature flags and the side agent's requests go to `api.anthropic.com`: it's the only Anthropic API host in the
  binary, and `allowed-domains.txt:18` allows it. Neither devcontainer.json sets `DISABLE_TELEMETRY`, `DO_NOT_TRACK`,
  `DISABLE_GROWTHBOOK` or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`.
- **Respecting `/plugin disable`.** A stored `false` survives a re-run, with both the PR's jq filter and #1's guard
  (probes).
- **`set -e`.** A jq parse failure on the left of `&&` doesn't abort the script, so the update step and agent-browser
  still run.
- **Injection.** The id reaches jq through `--arg`, not string interpolation.
- **CI and wiki.** CI is green: actionlint, both image builds, Hadolint. No wiki page mentions `init-plugins`,
  `enabledPlugins` or built-in plugins (fresh clone grep), so no wiki update is needed.

## Round 1 resolution

Every finding was re-checked against the round's probes before it was fixed. All held, so all were applied. The
comment above the block is two lines: the rationale is in the commit message and finding #1.

| # | Resolution | Verification |
| --- | --- | --- |
| 1 | Fixed (`d7e6b0f`). The jq write is replaced with `claude plugin enable`, guarded by a read-only `has($id)` check on `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`. | shellcheck passes. The extracted block was run in the image with `--network none`. No file, 0-byte, `{}` and `null` are enabled; other keys are kept; an explicit `false` is left alone; invalid JSON prints `⚠ Failed to enable` and the script continues. A re-run prints nothing. |
| 2 | Fixed by #1 | The 0-byte case above now ends with the key set |
| 3 | Fixed by #1 | A `600` settings file stays `600` after the block runs |
| 4 | Fixed (`docs(claude-code): note You should know's usage cost…`). The README states the usage cost and the real requirements: a direct login, plus feature-flag fetching, which `DISABLE_TELEMETRY` and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` turn off. | Checked against the [Cost of checks](https://code.claude.com/docs/en/interactive-mode#cost-of-checks) and [feature-flag fetching](https://code.claude.com/docs/en/env-vars#features-that-need-feature-flag-fetching) docs |
| Nits | Fixed by #1: `✔`/`⚠` status lines, a `# ── Built-in plugins ──` header, and the `CLAUDE_CONFIG_DIR` path | In the diff |
| PR description | Not done here. The "Why not `claude plugin enable`" note is now wrong, and "empty" in the tested cases should be "0-byte". It needs a `gh pr edit` after the push. | — |
