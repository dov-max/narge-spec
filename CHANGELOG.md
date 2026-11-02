# Changelog

Dated record of every change to the Narge feed (`dist/narge.txt`). Newest first.
Each entry lists names added and removed with a reason. See [RULES.md](RULES.md).

## Unreleased (PR #64, draft)

Proposed, not merged. 371 → 300 names.

- Removed 39 names that do not exist (NXDOMAIN on Cloudflare and Google, 2026-10-08).
- Removed 13 public suffixes (`co.uk`, `com.br`, ...): not sites.
- Removed 19 general platforms / mixed-use hosts that would block unrelated content under
  subdomain matching: `blogspot.com`, `wordpress.com`, `over-blog.com`, `canalblog.com`,
  `angelfire.com`, `free.fr`, `fc2.com`, `itch.io`, `b-cdn.net`, `pbwstatic.com`, `fastpic.ru`,
  `imagetwist.com`, `pixhost.to`, `uploadhouse.com`, `filestube.com`, `booru.org`,
  `sankakucomplex.com`, `scrolller.com`, `zproxy.org`.

## 2026-08-30

- Initial list: 370 names seeded once from StevenBlack porn-only hosts (MIT), plus overlay.
