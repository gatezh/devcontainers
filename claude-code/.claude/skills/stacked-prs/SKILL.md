---
name: stacked-prs
description: Use when opening PRs for branches that depend on each other, splitting work into a chain of PRs, or merging several dependent PRs together — in THIS devcontainer. Triggers on "stacked PRs", "stack these PRs", "open PRs for dependent branches", "chain PRs", "PR on top of PR", "merge all at once", or whenever about to run `gh pr create --base <another-feature-branch>`.
compatibility: Designed for the gatezh/devcontainers claude-code image, which bakes in the github/gh-stack gh extension. Elsewhere, run `gh extension install github/gh-stack` first.
metadata:
  author: Serge Gatezh
  url: https://github.com/gatezh
  version: "1.0.0"
---

# Stacked PRs with `gh stack`

## Overview

GitHub has native stacked PRs, driven by the `gh stack` extension (preinstalled in this image — check with `gh stack --version`). A native stack links the PRs on GitHub, keeps each PR's base on the branch below it, and can merge the stack atomically.

**Never hand-chain PRs with `gh pr create --base <feature-branch>`.** GitHub cannot merge that chain as one unit, and every merge below forces a manual retarget and rebase above. If PRs are already hand-chained, convert them with `gh stack link`.

Order is always **bottom → top**: the bottom branch is based on trunk and merges first.

## Which command

| Situation | Command |
|---|---|
| New multi-part work | `gh stack init <first-branch>`, commit, then `gh stack add <next-branch>` per layer |
| Adopt existing local branches | `gh stack init <bottom> <middle> <top>` |
| Push everything and open the PRs | `gh stack submit --auto` (drafts; add `--open` for ready-for-review) |
| PRs or branches already exist | `gh stack link <bottom> ... <top>` — PR numbers, URLs or branch names |
| Merge up to and including PR N | `gh stack merge <N> --yes` — all-or-nothing |
| Trunk moved / a lower PR merged | `gh stack sync` (fetch, rebase, push, refresh PR state) |
| Inspect the stack | `gh stack view --json` |

`link` pushes branch arguments, opens PRs for branches that lack one, and fixes wrong base branches. It only adds to a stack, never removes.

## Rules for non-interactive use

Agent shells may look like a TTY, and bare commands then block on a prompt or TUI. Always pass arguments and flags:

- `init` and `add` with explicit branch names; `submit --auto`; `merge <target> --yes`; `view --json`.
- Never run `gh stack modify` or `gh stack switch` — both are TUI-only.
- With more than one git remote, pass `--remote <name>` to `submit`, `push`, `sync`, `rebase` and `link`, or set `git config remote.pushDefault <name>`.
- `submit --auto` generates PR titles and bodies. Set them afterwards with `gh pr edit <N> --title ... --body-file ...`.
- Use `gh stack merge`, not `gh pr merge`, for stacked PRs. Pass `--squash`, `--merge` or `--rebase`, or it reuses the last method.

## More detail

- `gh stack <command> --help` is authoritative. `gh stack help <command>` prints only the top-level help.
- Docs: https://gh.io/stacks. For the upstream skill, which covers rebase conflicts, stack design and troubleshooting, run `gh skill install github/gh-stack`.
