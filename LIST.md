# Narge Host List Process

This process sits next to the [Narge specification](README.md). It produces a hostname list a DNS resolver can load.

**Rules**: [RULES.md](RULES.md) (what qualifies, adds, removals, appeals, feed guarantees).

**Maintenance**: See [MAINTENANCE.md](MAINTENANCE.md) for the weekly maintenance SOP.

## Feed URLs

The Narge list is available at **https://feeds.thecutline.org** in multiple formats:

**https://feeds.thecutline.org/v1/narge.txt** (primary feed URL)

GitHub mirror: **https://raw.githubusercontent.com/dov-max/narge-spec/main/dist/narge.txt**

Additional formats (RPZ, AdGuard, Control D, CSV, hosts file) are available at the same feed URL. See [For IT Teams](https://thecutline.org/for-it) for all formats.

The list is rebuilt daily and on every change to the source files. It is dedicated to the public domain under CC0 1.0.

## Initial seed

The list was seeded once from the StevenBlack hosts (MIT license) by selecting apex domains with high subdomain fanout (≥10 hostnames) as likely type 1 (watch) or type 2 (paid creator) sites. This was a one-time candidate source. The seed is attributed in the distribution file headers.

## Overlay

Two small public files add corrections:

- `overlay/block.txt` — extra hosts to block
- `overlay/allow.txt` — domains to allow (takes precedence)

A day-one steward may edit these files. These files exist to refine the core list through targeted additions and exceptions.


## Host grain

A DNS product judges site-level intent: is this host's purpose arousal?

A shop or a sex education site is not listed even if a picture slips. Lingerie, clothing, toy and wellness shops are not listed. General platforms and mixed-use hosts are not listed, because consumers match subdomains. See [RULES.md](RULES.md).

## Purpose types

A host fits one of eight relevant types. Type is not voted.

1. **Watch** — streaming or gallery
2. **Paid creator** — subscription or tip platform
3. **Dating** — case-by-case (hookup or relationship sites considered individually)
4. **Sex education / health** — information, therapy, clinics
5. **Lingerie / clothing shop** — apparel sale
6. **Toy / wellness shop** — product sale
7. **Editorial** — news, magazine, review
8. **Mixed social / art** — community, portfolio, mixed media

Irrelevant types (grocery, banks) are cleared and never asked. A CDN that primarily delivers type 1 content is considered delivery infrastructure for type 1, not a separate type.

## Defaults by type

- Types **1** and **2** default to Narge unless shown otherwise.
- Types **4** and **8** default to not Narge, unless the host's purpose is arousal.
- Types **3** and **7** are the margin. Each host is judged.
- Types **5** and **6** (shops) are not listed. See [RULES.md](RULES.md).

## Ranks inside a type

Within a relevant type, a host may be:

- Definitely Narge
- Clearly not Narge
- Spectrum (judgment depends on reviewer or evolving community view)

## The vote question

Does this host fit the [definition](README.md#definition)?

Never: should we block it?

Red is constitutional for watch and paid creator. This is not a weekly poll that turns lingerie into a ban.

## New types

New types have a high bar. A type must be a purpose, not a moral campaign. Suggest via issue.

## Steward model

A day-one steward maintains the list through overlay edits and periodic pruning. Upkeep is manual curation, not census or voting.

## Output

The process produces a plain text file of hostnames. Big tech would consume a file, not a voting UI.

## Catalog ingest

Third-party catalogs may ingest the Narge list as a separate, optional category. See [README.md](README.md#definition) for the class definition.

**Policy:**
- Ingest as "Narge," a distinct optional category
- Do not merge into existing lists with other class names
- Do not relabel the class with those words
- If a catalog will only accept it as "adult," skip that catalog

## Contributing

Use the [issue templates](.github/ISSUE_TEMPLATE/) to propose a host or a new type.
