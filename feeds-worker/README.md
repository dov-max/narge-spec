# cutline-feeds: Cloudflare Worker for feeds.thecutline.org

Serves the Narge list in 9 formats at `https://feeds.thecutline.org/v1/<token>/<file>`, plus an
IP-free fetch counter. Deployed automatically when the list or worker code changes.

## Routes
| Path | Result |
|---|---|
| `/v1/<token>/<file>` | `<token>`: 26 chars `[a-z2-7]` (per company), or `public` |
| `/v1/<file>` | Alias for `public` (the URL printed in PR #66 file headers) |
| `/stats.json` | Last finalised UTC day, per-ASN rows only when distinct >= 10 |
| anything else | 404 `not found` (same body for unknown, malformed and revoked tokens) |

Files: `narge.txt`, `narge.hosts`, `narge-wildcard.txt`, `narge.rpz`, `narge-adguard.txt`,
`narge-plain-nocomments.txt`, `narge.csv`, `narge-controld.json` (from narge-spec
`scripts/build_narge_list.py`, PR #66), and `version.json` (made by `scripts/build-assets.mjs`).
GET and HEAD, ETag + `If-None-Match` give 304, `Cache-Control: public, max-age=3600, stale-if-error=86400`.

## Layout
- `wrangler.toml`: name `cutline-feeds`, Custom Domain only (`workers_dev=false`, `preview_urls=false`),
  observability, logs and logpush **off**, static assets with `run_worker_first=true`, KV `TOKENS` + `STATS`,
  SQLite Durable Object `FetchCounter`, rate limit `RL` (per org, never per IP), 2 cron triggers.
- `src/index.ts`: router, token check, asset fetch, counter hand-off via `ctx.waitUntil`.
- `src/tokens.ts`: `SHA-256(token)` lookup in KV (`t:<hex>`), 5-minute isolate cache.
- `src/crypto.ts`: daily key `K_day = HMAC(COUNTER_SECRET, "cutline-feeds/counter/v1/"+day)`, fetcher id
  `= first 8 bytes of HMAC(K_day, normalised address)`.
- `src/ip.ts`: IPv4 as-is, IPv6 reduced to its /64.
- `src/counter.ts`: `FetchCounter` DO. De-dup sets in memory only. Persists counts only. Finalises a
  day into KV `agg:<day>` (private), `pub:<day>` and `pub:latest` (k-thresholded).
- `scripts/build-assets.mjs`: copies the canonical `../dist/` into `feed-dist/`, writes `version.json`,
  refuses to build if < 200 domains or a > 20% drop vs. previous build.
- `scripts/issue-token.mjs <org-slug>`: makes a token, prints it once plus the KV command storing only its hash.

## Privacy rules (enforced by tests)
- No `console.*` anywhere in `src/`. No Workers Logs, Logpush, Tail Workers or `wrangler tail` in production.
- The connecting address is read once in the request isolate, normalised, HMAC'd and dropped. The DO only
  ever receives `(day, org, asn, as_org, fetcher id, status)`.
- Nothing derived from an address (no address, /64, or fetcher id) is written to DO storage or KV.
  `test/counter.test.ts` dumps all KV keys/values and DO storage and searches for every test address,
  its /64 and its fetcher id.
- Caveat: Worker isolates and DOs don't keep memory forever. If the counter DO is evicted mid-day its
  de-dup set is lost, `resets` increments and that day's distinct counts are an upper bound (flagged in
  `stats.json`). The minute cron keeps the DO resident to make this rare.
- `COUNTER_SECRET` + a fetcher id would let someone brute-force an IPv4 address. That's why fetcher ids
  never leave memory. Rotate the secret if it's ever exposed (that only resets de-dup for the day).

## Local use
```sh
npm install
npm test              # builds feed-dist from ../dist/, runs vitest in workerd (miniflare)
npm run dev           # wrangler dev --local on :8787 (needs .dev.vars with COUNTER_SECRET; gitignored)
npx wrangler deploy --dry-run --outdir bundled   # config validation, no network
```
The feed assets are built from the canonical `../dist/` directory at the repo root.

## Deploy (automated via GitHub Actions)
```sh
npx wrangler login                                   # neutral Cloudflare account
npx wrangler kv namespace create TOKENS              # put ids into wrangler.toml
npx wrangler kv namespace create STATS
openssl rand -hex 32 | npx wrangler secret put COUNTER_SECRET   # never echoed or stored elsewhere
npm run build:assets && npx wrangler deploy          # creates Custom Domain feeds.thecutline.org + cert
```
Then check in the dashboard that Worker > Settings > Observability is **off**, and that no WAF or
rate-limiting *rules* exist on the zone (Security Events would record IPs).
