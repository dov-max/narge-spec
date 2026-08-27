# Narge Host List Process

This process sits next to the [Narge specification](README.md). It produces a hostname list a DNS resolver can load.

## Temporary feed

Until a public host registry exists, the list pulls from the [StevenBlack hosts porn-only list](https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts) (MIT license, attributed). This is an approximation of Narge, not Narge. It is pulled on a timer.

## Overlay

Two small public files add corrections:

- `overlay/block.txt` — extra hosts to block
- `overlay/allow.txt` — StevenBlack entries to unblock

A day-one steward may edit these files. This is not a stamp. These files exist to refine the temporary feed until a later public host registry exists.

## Resolver implementation

See [resolver/](resolver/) for a ready-to-run Blocky DNS configuration that loads the temporary feed and overlay files. This is for VPS deployment, not a hosted service.

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

A day-one steward exists until a later anti-gaming vote system is built. No Community Notes implementation now.

## Output

The process produces a plain text file of hostnames. Big tech would consume a file, not a voting UI.

## Contributing

Use the [issue templates](.github/ISSUE_TEMPLATE/) to propose a host or a new type.
