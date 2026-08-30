# Narge List Maintenance

## Goal

Keep `dist/narge.txt` a trusted owned file, not a census.

This is a curated list of hostnames that fit the Narge definition. It is not a crawl of the internet or a vote on what to ban.

## Aggregator Trust

Aggregator trust comes from: stable URL, dated builds, fast unblocks, honest header.

Not from: query volume, completeness.

## Weekly Maintenance (about an hour)

### Prune Owned Core

DNS resolve the ~371 names in `core/`. Drop NXDOMAIN or dead domains. This is a DNS lookup of our owned list, not a web crawl and not a scan of the internet.

### False Positives First

False positives go in `overlay/allow.txt` before adding new blocks. Unblocking a wrongly-blocked site is more important than expanding coverage.

### GitHub Issues

Answer the question: **Does this host fit the definition?**

Never ask: "Should we block it?"

If a host's purpose is arousal and it meets the [Narge definition](README.md#definition), it fits. If not, it doesn't.

### Adds

Most weeks: zero adds. Add path is quarterly (see below) or GitHub issues only.

Never search for new Narge. Never use Cutline user volume as an add signal. Famous hosts may lag behind reality. Malware bar: incomplete coverage is expected.

When adding a name, record the type in the commit message and in a simple `core/TYPES.md` or a third column later:

**Type 1–2 default in** if the host's purpose is arousal:
- Type 1: Watch — streaming or gallery
- Type 2: Paid creator — subscription or tip platform

**Type 4 and 8 default out**:
- Type 4: Sex education / health — information, therapy, clinics
- Type 8: Mixed social / art — community, portfolio, mixed media

**Type 3, 5, 6, 7 are case-by-case**:
- Type 3: Dating — hookup or relationship
- Type 5: Lingerie / clothing shop — apparel sale
- Type 6: Toy / wellness shop — product sale
- Type 7: Editorial — news, magazine, review

Do not invent types for the existing seed names from StevenBlack.

### Rebuild

Rebuild `dist/` via the existing GitHub Action after changes.

## Quarterly Maintenance (optional)

The add path:

1. Take a noisy third-party list
2. Intersect with Tranco top 50,000 (https://tranco-list.eu/)
3. Drop names already in `core/`
4. Review the remaining hostnames (names only, do not visit)
5. Never auto-merge

Do not re-run `seed_from_stevenblack.py`.

## How to Edit

- **`overlay/block.txt`** — extra blocks (corrections to the seed)
- **`overlay/allow.txt`** — unblocks (false positives)
- **`core/`** — owned Narge names (new additions with type labels)

Push to `main`. The GitHub Action rebuilds `dist/` automatically.

## Never

- Crawl the web for new domains
- Store Cutline Blocky query names
- Scan random domains
- Block a URL path (DNS is host-level only; Type 8 platforms stay out)
- Use family/hechsher/movement/safe-clean framing

## Steward

One person (Dov). Malware bar: incomplete coverage is expected. No query-name logs. No DNS census.

## Catalog Requests

When a catalog asks to include this list, the answer is: separate Narge category or no.

## Subscribe URL

- **Hostname list**: https://raw.githubusercontent.com/dov-max/narge-spec/main/dist/narge.txt
- **Hosts format**: https://raw.githubusercontent.com/dov-max/narge-spec/main/dist/narge.hosts

Current service: Cutline Blocky is pointed at `dist/narge.txt`.
