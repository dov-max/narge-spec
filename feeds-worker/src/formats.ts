// The 9 feed files: the 8 produced by narge-spec scripts/build_narge_list.py (PR #66)
// plus version.json produced by scripts/build-assets.mjs.
export const FORMATS: Record<string, string> = {
  "narge.txt": "text/plain; charset=utf-8",
  "narge.hosts": "text/plain; charset=utf-8",
  "narge-wildcard.txt": "text/plain; charset=utf-8",
  "narge.rpz": "text/plain; charset=utf-8",
  "narge-adguard.txt": "text/plain; charset=utf-8",
  "narge-plain-nocomments.txt": "text/plain; charset=utf-8",
  "narge.csv": "text/csv; charset=utf-8",
  "narge-controld.json": "application/json; charset=utf-8",
  "version.json": "application/json; charset=utf-8",
};
