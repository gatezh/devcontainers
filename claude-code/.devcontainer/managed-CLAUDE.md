# Cloudflare

When interacting with Cloudflare, use the `cf` CLI unless the project has a Wrangler configuration file (`wrangler.jsonc`, `wrangler.json` or `wrangler.toml`) and no `cloudflare.config.ts`. In such a project, never run `cf dev`, `cf build` or `cf deploy`: without a terminal they rewrite `package.json`, the lockfile and `vite.config.ts` without asking. Use Wrangler there, or migrate first with `cf migrate --dry-run`.

To find a `cf` command, run `cf cli search "<task>"`. Preview changes with `--dry-run`.
