# Narge List Rules

Draft, October 2026. These rules govern the hostname feed at
`https://raw.githubusercontent.com/dov-max/narge-spec/main/dist/narge.txt`.
The class itself is defined in [README.md](README.md). Nothing here adds a class or a rating.

## 1. What qualifies

A hostname is listed when the purpose of the **whole domain** is Narge: video or stills of real or
photorealistic humans, produced or posted primarily to sexually arouse
([definition](README.md#definition)). In practice: watch sites (tubes, galleries, cams),
paid creator sites, and the delivery hosts (CDNs, ad and traffic hosts) that serve only those sites.

## 2. What does not qualify

- Lingerie, clothing, sex-toy, and wellness shops.
- Sex education, health, medical, news, and editorial sites.
- Written-only text and non-photoreal illustration.
- **General platforms and mixed-use hosts**: blog and site hosts, free web hosting, general image
  and file hosts, shared CDNs, cloud and app domains, URL shorteners, general web proxies, search
  engines, social networks, marketplaces. This holds even if a lot of Narge sits on them.
- Public suffixes (see 5).

## 3. Subdomain rule (platforms)

Consumers match a listed name **including all its subdomains** (`example.com` also blocks
`www.example.com` and `anything.example.com`). So a listed domain must be Narge-primary across every
subdomain. If any meaningful part of a domain is not Narge (other users' blogs, other customers'
sites, a general-audience section), the domain is not listed. We do not list individual
subdomains of a general platform, and we never list a URL path.

## 4. Adding a name

A new name needs all of:

1. **Fits sections 1–3.** The proposer states the purpose type (see [LIST.md](LIST.md)).
2. **Active** (see 6) on the day it is added.
3. **Real traffic**: in the [Tranco](https://tranco-list.eu/) top 50,000 on the current list, or
   a delivery host for a listed site.
4. **Evidence without visiting**: the site's own public description, an app-store or
   company listing, news coverage, or presence on at least one independent NSFW blocklist
   (OISD NSFW, HaGeZi NSFW). We do not crawl and we do not visit sites to judge them.
5. A reviewer other than the proposer agrees, in a public issue or pull request.

## 5. Public suffixes

No entry may be a public suffix or a registry-controlled name (`co.uk`, `com.br`, `blogspot.com`,
etc.), checked against the [Public Suffix List](https://publicsuffix.org/), ICANN and private
sections, before merge. The weekly check (section 6) also flags any that slip in.

## 6. Active, and removal for inactivity

A name is **active** when, over DNS-over-HTTPS (Cloudflare and Google):

- it resolves (not NXDOMAIN, not SERVFAIL), and
- it answers: the apex, or a known delivery subdomain for CDN names, returns an A or AAAA address, and
- it is not parked or for sale (its nameservers are not a parking or domain-sale service).

A GitHub Action checks every entry **weekly** and keeps one open issue listing names that failed
**2 or more consecutive weeks**. It never removes anything. A maintainer removes a name only after
it has failed at least **2 checks spanning at least 2 weeks** (3 checks if the failure is SERVFAIL
or a timeout). Tranco rank is a review signal for existing names, not a removal rule.

## 7. Removal for fit

A name is removed when it no longer fits sections 1–3 (for example, it became a general platform
or changed owner and purpose). Fit removals do not wait for the weekly check.

## 8. False positives and appeals

- Anyone (site owner, consumer, user) can report a wrongly listed name with the
  **False positive** issue template. No account with us is needed beyond GitHub.
- **Response target: first reply within 2 business days.** If the name does not fit, it goes into
  `overlay/allow.txt` and is out of the feed on the next build (builds run daily).
- An unblock comes before any new add. When in doubt, a disputed name stays out until resolved.
- A decision can be appealed by commenting on the closed issue with new facts.

## 9. Changes, changelog, versions

- Every list change is a pull request with a one-line reason per name.
- Every merged change gets a dated entry in [CHANGELOG.md](CHANGELOG.md): names added, names
  removed, reason.
- The feed version is its **build date** (`# Build date:` header). The spec version
  (`# Spec version:`) changes only when README.md changes.
- Removals are batched; adds are rare (most weeks: zero).

## 10. Feed guarantees for consumers

- **URL** above does not change. If hosting ever moves, the old URL keeps serving for at least
  12 months, with notice in the header and changelog.
- **Format**: UTF-8 / ASCII text, LF line endings, one lowercase hostname per line, IDNs in
  punycode (`xn--`), lines starting with `#` are comments. No wildcards, no paths, no IPs, no
  ports. `dist/narge.hosts` carries the same names in `0.0.0.0 host` form.
- **Match semantics**: each entry is meant to cover the name and all its subdomains.
- **Cadence**: rebuilt daily (06:00 UTC) and on every merged change.
- **No breaking changes**: header lines may be added, never removed or renamed; the line format
  above is permanent. A new format would be a new file, never a change to this one.
- **License**: CC0 1.0. Use it in anything, commercial included.
