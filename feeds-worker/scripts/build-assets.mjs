// Build ./feed-dist from a narge-spec dist/ directory.
// Usage: node scripts/build-assets.mjs <dist-dir> <out-dir> [previous-version.json]
// Sanity gate (same idea as narge-sync): refuse if narge.txt has < 200 domains, or drops
// more than 20% versus the previous build. On refusal nothing is written, so the
// previously deployed feed keeps serving.
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from "node:fs";
import { join } from "node:path";

const FILES = [
  "narge.txt", "narge.hosts", "narge-wildcard.txt", "narge.rpz", "narge-adguard.txt",
  "narge-plain-nocomments.txt", "narge.csv", "narge-controld.json",
];
const [src = "dist-src", out = "feed-dist", prevPath] = process.argv.slice(2);

const missing = FILES.filter((f) => !existsSync(join(src, f)));
if (missing.length) { console.error("refusing: missing " + missing.join(", ")); process.exit(2); }

const data = Object.fromEntries(FILES.map((f) => [f, readFileSync(join(src, f))]));
const domains = data["narge.txt"].toString("utf8").split("\n").map((l) => l.trim()).filter((l) => l && !l.startsWith("#"));
const count = domains.length;
if (count < 200) { console.error(`refusing: only ${count} domains (< 200)`); process.exit(3); }
const prevFile = prevPath ?? join(out, "version.json");
if (existsSync(prevFile)) {
  const prev = JSON.parse(readFileSync(prevFile, "utf8"));
  if (prev.count && count < prev.count * 0.8) { console.error(`refusing: ${count} is >20% below previous ${prev.count}`); process.exit(4); }
}
JSON.parse(data["narge-controld.json"].toString("utf8")); // must parse

const sha = (b) => createHash("sha256").update(b).digest("hex");
const generated = new Date().toISOString();
const version = {
  version: generated.replace(/[-:]/g, "").slice(0, 15) + "Z-" + sha(data["narge.txt"]).slice(0, 8),
  generated,
  count,
  sha256: sha(data["narge.txt"]),
  files: Object.fromEntries(FILES.map((f) => [f, { bytes: data[f].length, sha256: sha(data[f]) }])),
  source: "https://github.com/dov-max/narge-spec/tree/main/dist",
};
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
for (const f of FILES) writeFileSync(join(out, f), data[f]);
writeFileSync(join(out, "version.json"), JSON.stringify(version, null, 2) + "\n");
console.log(`built ${FILES.length + 1} files, ${count} domains, version ${version.version}`);
