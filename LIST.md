# Narge Host List Process

This process sits next to the [Narge specification](README.md). It produces a hostname list a DNS resolver can load.

## Subscribe URL

The stable Narge list is available at:

**https://raw.githubusercontent.com/dov-max/narge-spec/main/dist/narge.txt**

A hosts file format is also available:

**https://raw.githubusercontent.com/dov-max/narge-spec/main/dist/narge.hosts**

The list is rebuilt daily and on every change to the source files. It is dedicated to the public domain under CC0 1.0.

## Initial seed

The list was seeded once from the [StevenBlack hosts porn-only list](https://github.com/StevenBlack/hosts) (MIT license). Apex domains with high subdomain fanout (≥10 hostnames) were selected as likely type 1 (watch) or type 2 (paid creator) sites. This was a one-time candidate source. The seed is attributed in the distribution file headers.

## Overlay

Two small public files add corrections:

- `overlay/block.txt` — extra hosts to block
- `overlay/allow.txt` — domains to allow (takes precedence)

A day-one steward may edit these files. These files exist to refine the core list through targeted additions and exceptions.

## Resolver implementation

See [resolver/](resolver/) for a ready-to-run Blocky DNS configuration that loads the Narge list and overlay files. This is for VPS deployment, not a hosted service.

## Host grain

A DNS product judges site-level intent: is this host's purpose arousal?

A modest shop or a sex education site is not Narge even if a picture slips. An arousal-first lingerie shop can be.

## Purpose types

A host fits one of eight relevant types. Type is not voted.

1. **Watch** — streaming or gallery
2. **Paid creator** — subscription or tip platform
3. **Dating** — hookup or relationship
4. **Sex education / health** — information, therapy, clinics
5. **Lingerie / clothing shop** — apparel sale
6. **Toy / wellness shop** — product sale
7. **Editorial** — news, magazine, review
8. **Mixed social / art** — community, portfolio, mixed media

Irrelevant types (grocery, banks) are cleared and never asked. A porn CDN is delivery for type 1, not a ninth type.

## Defaults by type

- Types **1** and **2** default to Narge unless shown otherwise.
- Types **4** and **8** default to not Narge, unless the host's purpose is arousal.
- Types **3**, **5**, **6**, and **7** are the margin. Each host is judged.

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

## Contributing

Use the [issue templates](.github/ISSUE_TEMPLATE/) to propose a host or a new type.
