#!/usr/bin/env node
// Slice a package's changelog to the range you are upgrading across, save the full
// text, and print only the lines that signal work (breaking, deprecated, removed,
// renamed, migration, ...). Two sources, because projects split unevenly:
//
//   raw  <name> <CHANGELOG.md raw URL> <from> <to>
//        Monorepos with changesets (workers-sdk, better-auth, vite-plugin-react, posthog-js).
//        Headings must look like "## 1.2.3", "## v1.2.3", "## [1.2.3]", or "## <small>1.2.3 …</small>".
//
//   rel  <name> <owner/repo> <tagPrefix> <from> <to> [pages=2]
//        GitHub Releases. The prefix is the part of the tag before the version:
//        "v" (zod, hono, hugo), "" (lucide), "bun-v" (bun), "@tanstack/ai@" (per-package
//        monorepo tags), "oxlint_v" (oxc). Wrong prefix = empty result, so the script
//        prints the prefixes it did see when nothing matches.
//
// Output: ./changelogs/<name>.md (full slice) + flagged lines on stdout.
// <from> is exclusive (your current version), <to> is inclusive (the target).
// Unauthenticated GitHub API allows 60 requests/hour — enough for one upgrade session.

import { mkdirSync, writeFileSync } from "node:fs";

const FLAG = /breaking|deprecat|migrat|remov|renam|drop|no longer|now requires|minimum|\bBREAKING\b|⚠|^#{1,4} /i;
const NOISE = /Thanks \[@|^\s*- @|^- \[#\d+\]\(|Updated dependencies/;
const OUT = process.env.CHANGELOG_DIR ?? "changelogs";

const semver = (s) => s.replace(/^v/, "").split(/[.-]/).map((x) => (isNaN(+x) ? x : +x));
const cmp = (a, b) => {
  a = semver(a); b = semver(b);
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    const x = a[i] ?? 0, y = b[i] ?? 0;
    if (x === y) continue;
    return typeof x === "number" && typeof y === "number" ? x - y : String(x).localeCompare(String(y));
  }
  return 0;
};
const inRange = (v, from, to) => cmp(v, from) > 0 && cmp(v, to) <= 0;

function emit(name, text) {
  mkdirSync(OUT, { recursive: true });
  writeFileSync(`${OUT}/${name}.md`, text);
  const flagged = text.split("\n").filter((l) => FLAG.test(l) && !NOISE.test(l)).map((l) => l.slice(0, 240));
  console.log(`\n##### ${name} (${text.length} chars saved to ${OUT}/${name}.md; ${flagged.length} flagged lines)`);
  console.log(flagged.join("\n"));
  if (text.length === 0) console.log("(empty slice — check the heading format / tag prefix before concluding 'no changes')");
}

async function raw(name, url, from, to) {
  const r = await fetch(url);
  if (!r.ok) return console.log(`\n##### ${name}: HTTP ${r.status} for ${url}`);
  const heading = /^##\s+(?:<small>)?\[?v?(\d+\.\d+\.\d+[^\s<\]]*)/;
  let keep = false;
  const out = [];
  for (const line of (await r.text()).split("\n")) {
    const m = line.match(heading);
    if (m) keep = inRange(m[1], from, to);
    if (keep) out.push(line);
  }
  emit(name, out.join("\n"));
}

async function rel(name, repo, prefix, from, to, pages = 2) {
  const out = [], seen = new Set();
  for (let page = 1; page <= pages; page++) {
    const r = await fetch(`https://api.github.com/repos/${repo}/releases?per_page=100&page=${page}`, {
      headers: { accept: "application/vnd.github+json" },
    });
    if (!r.ok) return console.log(`\n##### ${name}: GitHub API ${r.status} (rate limit? private repo?)`);
    const releases = await r.json();
    if (!releases.length) break;
    for (const rel of releases) {
      const tag = rel.tag_name ?? "";
      seen.add(tag.replace(/\d.*$/, ""));
      if (!tag.startsWith(prefix)) continue;
      const v = tag.slice(prefix.length);
      if (/^v?\d/.test(v) && inRange(v, from, to)) out.push(`## ${tag}\n${rel.body ?? ""}`);
    }
  }
  if (!out.length) console.log(`\n##### ${name}: no releases matched prefix "${prefix}" in (${from}, ${to}]. Prefixes seen: ${[...seen].slice(0, 8).join(" | ") || "(none — releases may not exist; try raw)"}`);
  else emit(name, out.join("\n\n"));
}

const [mode, ...args] = process.argv.slice(2);
if (mode === "raw" && args.length === 4) await raw(...args);
else if (mode === "rel" && args.length >= 5) await rel(args[0], args[1], args[2], args[3], args[4], Number(args[5] ?? 2));
else {
  console.error("usage:\n  changelog-slice.mjs raw <name> <url> <from> <to>\n  changelog-slice.mjs rel <name> <owner/repo> <tagPrefix> <from> <to> [pages]");
  process.exit(2);
}
