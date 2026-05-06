---
name: sandbox-playwright
description: Use when verifying UI changes in a real browser, taking screenshots of the running app, clicking or typing into the dev server to confirm behavior, or running the project's E2E suite — in THIS devcontainer. Triggers on "check in a browser", "take a screenshot", "verify the UI", "click that button", "open the page", "run e2e tests", or whenever about to say "Playwright isn't available".
compatibility: Designed for the gatezh/devcontainers claude-code image (system chromium at /usr/bin/chromium, PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH preset, playwright MCP plugin enabled). Not applicable outside that devcontainer.
metadata:
  author: Serge Gatezh
  url: https://github.com/gatezh
  version: "1.1.0"
---

# Playwright in This Sandbox

Playwright is reachable through **multiple independent paths**, any combination of which a project may use:

- **MCP plugin** (`playwright@claude-plugins-official`) — interactive, ad-hoc browser work.
- **`@playwright/test` CLI** — the project's scripted E2E suite.
- **`@vitest/browser-playwright`** — vitest browser mode (used by `@storybook/addon-vitest` for storybook interaction tests, by `@vitest/browser` for browser-mode unit tests).
- **Direct `playwright-core` / `playwright`** — custom scripts that import `chromium` and call `chromium.launch(...)` themselves (CI scrapers, codegen).

Don't install anything. Don't spawn a dev server — the user keeps one running on a port they chose.

## Pick the right path

| Goal | Use | How |
|---|---|---|
| Ad-hoc: "does this button work?", "take a screenshot" | **MCP plugin** | `ToolSearch` → `browser_navigate` → `browser_snapshot` / `browser_click` |
| Reproducible E2E suite | **`@playwright/test` CLI** | `bun run test:e2e` (whatever the script in the project's `package.json` is) |
| Storybook interaction tests / vitest browser tests | **`@vitest/browser-playwright`** | The project's `vitest`/`storybook` test script (e.g. `bun run test`, `bun run test-storybook`). Config lives in `vitest.config.ts`, NOT `playwright.config.ts`. |
| Custom script with `chromium.launch(...)` | **Direct** | Run the script as the project does. Requires `executablePath` wired at the call site (image-set env var). |

## Discovery first — never hardcode

Every concrete fact in this section must come from the project at invocation time, not from this skill's prose. Stale skills are worse than missing ones.

1. **Find the relevant config.** RTK rewrites `find` and rejects compound predicates (`-not`, `! -path`, also `\( … -o … \)` grouping), so use plain single-predicate `find` and filter with `grep` — works whether RTK is in the loop or not.
   ```sh
   # For E2E ("run the e2e suite"):
   find . -maxdepth 6 -name 'playwright.config.*' | grep -v node_modules
   # For storybook / vitest browser tests:
   find . -maxdepth 6 -name 'vitest.config.*' | grep -v node_modules
   ```
   - 0 `playwright.config.*` matches AND the user asked for E2E → tell them there's no Playwright E2E suite. Stop.
   - 0 `vitest.config.*` matches with `test.browser.enabled = true` AND the user asked for storybook/vitest browser tests → tell them browser-mode isn't configured. Stop.
   - 2+ matches of the same kind → ask which one (a monorepo can ship one config per service, e.g. one for the React app, one for the marketing site).
   - Note: a plain unit-test `vitest.config.*` (no `test.browser.enabled`) doesn't drive Playwright — read the file to confirm browser mode is on before assuming.

2. **Read the config.** Note `testDir`, the entries in `projects[]` (with their `testMatch` / `testIgnore` patterns — they are usually regexes, not filename allowlists), and `webServer` (its `url` and `reuseExistingServer`).

3. **Discover the dev-server port** — never assume `5173` or any other Vite/Next/etc. default.
   - Check the env var the project uses. Common conventions: `APP_PORT`, `PORT`, `VITE_PORT`, `WEB_PORT`. Try `echo $APP_PORT $PORT $VITE_PORT $WEB_PORT` first; the project's `.env.example` (or the Playwright config's `webServer.url`) usually names which one.
   - `grep -E '^[A-Z_]*PORT=' .env.local .env 2>/dev/null` — if it's a monorepo, also grep service-level `.env*` files.
   - `ss -tlnp 2>/dev/null | grep -E 'node|bun'` — what's actually listening.
   - Confirm: `curl -sI http://localhost:$PORT/ | head -1`.
   - Last resort: ask the user.

4. **Locate `@playwright/test`.** Bun workspaces typically hoist to `/workspace/node_modules/@playwright/test`; per-service installs are valid too. Don't claim a specific path — `bun run test:e2e` works regardless of where the binary physically sits.

## Interactive workflow (MCP)

1. **Load the deferred tool schemas before calling them.** All `mcp__plugin_playwright_playwright__browser_*` tools are deferred — calling one unloaded fails with `InputValidationError`. Start each session with:
   ```
   ToolSearch({ query: "select:mcp__plugin_playwright_playwright__browser_navigate,mcp__plugin_playwright_playwright__browser_snapshot,mcp__plugin_playwright_playwright__browser_click,mcp__plugin_playwright_playwright__browser_close" })
   ```
   Extend the comma-separated `select:` list as you need more tools.

2. **Navigate first.** `browser_navigate` to `http://localhost:<port>/<route>` using the port from discovery. Every other tool requires an active page.

3. **Prefer `browser_snapshot` over `browser_take_screenshot`.** The a11y snapshot is cheap and diff-able and usually enough. Screenshots are for when the user asked visually, or when CSS/layout itself is the thing being verified.

4. **When you do screenshot, write to `.playwright-mcp/`.** Pass `filename: ".playwright-mcp/<name>.png"` — never a bare filename. The MCP resolves relative filenames against the repo root, so `filename: "page.png"` lands in `/workspace` and leaves untracked artifacts in `git status`. `.playwright-mcp/` is already git-ignored and is where the MCP drops its console logs and page snapshots, so screenshots belong alongside them. (You'll see this dir in `.gitignore` next to `playwright-report/` and `.playwright/`.)

5. **`browser_close` when done.** The MCP session keeps one browser alive across calls; leaving it open leaks cookies, auth, and route into later tasks.

## MCP tool quick reference

All tools are registered with the prefix `mcp__plugin_playwright_playwright__`.

- **Navigation:** `browser_navigate`, `browser_navigate_back`, `browser_tabs`
- **Interaction:** `browser_click`, `browser_hover`, `browser_drag`, `browser_type`, `browser_fill_form`, `browser_select_option`, `browser_press_key`, `browser_file_upload`, `browser_handle_dialog`
- **Observation:** `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`, `browser_evaluate`, `browser_run_code`
- **Control:** `browser_wait_for`, `browser_resize`, `browser_close`

## Scripted workflow (CLI)

- The project's `package.json` defines the entry script (commonly `bun run test:e2e` or `bun run --filter <pkg> test:e2e`). Read it instead of guessing.
- The Playwright config's `webServer` entry has `reuseExistingServer: !process.env.CI`, so when the user already has the dev server up, the CLI reuses it; if not, Playwright spawns one. **Don't pre-spawn** — duplicates port-collide.
- Spec discovery is regex-driven via `testMatch` / `testIgnore` per project. To add a new spec, match the naming convention of an existing spec in the same project (e.g. `*.auth.spec.ts` for an authenticated project), don't edit `testMatch` arrays.

## What NEVER works in this sandbox

| Don't | Why |
|---|---|
| Say "Playwright isn't available" | It IS — the MCP plugin is enabled in `~/.claude/settings.json`, and `@playwright/test` is in `node_modules`. |
| `bun add @playwright/test` or any "reinstall Playwright" attempt | Already installed. Reinstalling risks an unintended version bump and violates the "no unauthorized installs" rule in the project's CLAUDE.md. |
| Spawn your own `bun run dev` | The user keeps one running; Playwright's `webServer` reuses it (`reuseExistingServer: true`). A duplicate port-collides. |
| Hardcode a port (`5173`, `5179`, etc.) in URLs, examples, or docs | Discover it per Step 3. Different projects use different env-var conventions (`APP_PORT`, `PORT`, `VITE_PORT`, …) and the user may override the default. |
| Pass a bare `filename` (e.g. `"page.png"`) to `browser_take_screenshot` | The MCP resolves it against the repo root, dropping untracked PNGs into `/workspace`. Use `".playwright-mcp/<name>.png"` — it's already git-ignored. |
| Run `npx playwright install` when a Vitest/Storybook test fails with `Executable doesn't exist at /home/node/.cache/ms-playwright/...` | The image deliberately ships system Chromium at `/usr/bin/chromium` and sets `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`. The fix is to wire `launchOptions.executablePath` in `vitest.config.ts` (`provider: playwright({ launchOptions: { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH } })`), not to download a Playwright-managed binary. |
| Call `mcp__plugin_playwright_playwright__browser_*` without `ToolSearch` first | Deferred tools — raw invocation returns `InputValidationError` because the parameter schema hasn't been loaded. |
| Navigate to non-localhost, non-GitHub, non-npm URLs and expect them to work | The devcontainer firewall (see `.claude/rules/devcontainer.md`) blocks arbitrary external domains. Localhost is fine. |
| Chain actions without re-observing | Page state is implicit. Re-`browser_snapshot` or `browser_wait_for` between interactions. |
| Leave the browser open across unrelated tasks | State leaks (cookies, auth, route). `browser_close` at scenario end. |

## Red flags — if you're about to type one of these, STOP

- "Playwright isn't available in this sandbox / devcontainer"
- "I need to install Playwright first"
- "Let me run `npx playwright install`" (the bundled binary is deliberately not used; wire `launchOptions.executablePath` instead)
- "Let me start a dev server on :<some-port>" — you don't know the user's port
- "I'll use `WebFetch` to check the rendered page instead"

All mean: do the discovery in §"Discovery first", then follow the interactive or scripted workflow above. If the dev server isn't running, ask the user to start it — don't start one yourself.

## How Playwright is wired here

For maintainers reading this: the upstream devcontainer image (`gatezh/devcontainers` claude-code, both `default` and `sandbox` targets) ships system chromium at `/usr/bin/chromium` and sets:

- `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` — keeps `npm install` from downloading bundled browsers.
- `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium` — project convention; Playwright doesn't read it automatically, so each consumer of `@playwright/test`, `@vitest/browser-playwright`, or direct `playwright-core` use must pass it explicitly through `launchOptions.executablePath`.
- `AGENT_BROWSER_EXECUTABLE_PATH=/usr/bin/chromium` (default target only) — `agent-browser` is a Rust CLI with its own env-var family; without this it would auto-detect or attempt a Chrome-for-Testing download on first use.

Beyond those env vars:

- The project's `playwright.config.ts` files wire `launchOptions.executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` so `playwright test` finds the binary.
- The project's `vitest.config.ts` (if it uses `@vitest/browser-playwright`, which `@storybook/addon-vitest` does) wires `provider: playwright({ launchOptions: { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH } })`.
- `@playwright/mcp` defaults to the `chrome` channel (Google Chrome stable at `/opt/google/chrome/chrome`), which isn't installed. The bundled `.mcp.json` is rewritten by `/usr/local/bin/patch-playwright-mcp` (baked into the image) to launch with `--browser chromium --executable-path /usr/bin/chromium --no-sandbox --headless`. It runs from `init-plugins.sh` (postCreate) AND from `postStartCommand` so plugin auto-updates between sessions don't leave fresh cache dirs unpatched. See gatezh/devcontainers#85, #87, #91.
