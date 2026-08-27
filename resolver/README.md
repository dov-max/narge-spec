# Narge DNS Resolver

This directory contains design documentation and configuration for Narge-filtering DNS resolvers.

**Status:** Design phase. No resolvers are currently deployed.

## Documents

- **[JOIN.md](JOIN.md)** – How households request and use access tokens, rate limiting, capacity management, and privacy guarantees
- **[LIST.md](LIST.md)** – Block list sources and management

## What It Does

A Narge DNS resolver returns `NXDOMAIN` for domains that primarily host Narge content (see [main README](../README.md) for the definition).

The resolver:
- Uses curated block lists (StevenBlack porn-only + GitHub-hosted overlays)
- Requires an access token per household
- Rate-limits per token, not per IP
- Never logs query names
- Works with dynamic IP and VPN connections

## Architecture

Planned:
- Two US-based resolver locations (East + West coast preferred)
- Token-aware DoH front (Caddy or similar) for rate limiting and token validation
- Unmodified Blocky DNS resolver with configured block lists
- Token minting service (future)

See [JOIN.md](JOIN.md) for details on the join path and capacity management.
