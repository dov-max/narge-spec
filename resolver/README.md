# Blocky DNS Resolver Configuration

This directory contains a ready-to-run DNS resolver configuration using [Blocky](https://github.com/0xERR0R/blocky) to block domains from the Narge temporary feed.

## What This Is

This is a **configuration file** for the Blocky DNS resolver. We do not fork or vendor Blocky. This is not a security product, a complete filtering solution, or a hardened service. It is a working example for VPS deployment.

## What It Does

The resolver loads:
- **StevenBlack porn-only list** (MIT license) as the temporary Narge feed
- **`overlay/block.txt`** from GitHub for extra denials
- **`overlay/allow.txt`** from GitHub for exceptions (takes precedence)

Blocked domains return `NXDOMAIN`. Upstream DNS: Cloudflare (1.1.1.1, 1.0.0.1).

**List updates:** Blocky automatically refreshes all lists every 24 hours from their sources (including the GitHub overlay URLs). To update the overlay lists, edit the files in the `overlay/` directory on GitHub; you do not need to SSH to the VPS or restart the service. Changes will be picked up on the next refresh cycle.

**Note:** Blocky the program itself does not auto-update. Only the domain lists auto-refresh.

## Running with Docker

### Quick Start

From the repository root:

```bash
docker run -d \
  --name blocky \
  -v "$(pwd)/resolver/config.yml:/app/config.yml:ro" \
  -v "$(pwd)/overlay:/overlay:ro" \
  -p 53:53/udp \
  -p 53:53/tcp \
  ghcr.io/0xerr0r/blocky
```

Or use the alternative image:

```bash
docker run -d \
  --name blocky \
  -v "$(pwd)/resolver/config.yml:/app/config.yml:ro" \
  -v "$(pwd)/overlay:/overlay:ro" \
  -p 53:53/udp \
  -p 53:53/tcp \
  spx01/blocky
```

### Using Docker Compose

See `docker-compose.yml` in this directory for a ready-to-use compose file.

From the repository root:

```bash
docker compose -f resolver/docker-compose.yml up -d
```

### Testing

Query the running resolver:

```bash
dig @127.0.0.1 example.com
```

## What to Edit

- **`overlay/block.txt`**: Edit this file on GitHub to add hostnames (one per line) to block beyond the StevenBlack list. Blocky will fetch the updated file automatically within 24 hours.
- **`overlay/allow.txt`**: Edit this file on GitHub to add hostnames (one per line) to unblock from the StevenBlack list. Blocky will fetch the updated file automatically within 24 hours.
- **`config.yml`**: Change upstream DNS servers, refresh period, or other Blocky settings

**Optional:** You can still mount local overlay files as a fallback if you need offline operation or want to override the GitHub sources. The docker commands show how to mount the local `overlay/` directory, though this is not required since the config now loads from GitHub URLs.

See the [Blocky configuration documentation](https://0xerr0r.github.io/blocky/latest/configuration/) for all options.

## Production Notes

- **Port 53 requires root or `CAP_NET_BIND_SERVICE`**: On Linux, either run the container with `--cap-add=NET_BIND_SERVICE` or use a higher port and redirect traffic.
- **No DoH/DoT in this config**: This is plain DNS on port 53. Add DoH or DoT upstream in `config.yml` if needed.
- **No query logging**: Domain names are not logged. If you need logging, add a `queryLog` section to `config.yml`.
- **Not for public resolvers**: This setup is for internal or VPS use, not for operating a public DNS service.

## Attribution

- **Blocky** DNS resolver: Apache-2.0 license, by Dimitri Herzog ([0xERR0R](https://github.com/0xERR0R/blocky))
- **StevenBlack hosts**: MIT license, by Steven Black ([StevenBlack/hosts](https://github.com/StevenBlack/hosts))

We run their software and reference their list. The overlay files and this configuration are part of the Narge specification repository (CC0 1.0).
