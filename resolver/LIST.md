# Block Lists

This document describes the block list sources used by Narge DNS resolvers.

**Status:** Design document. No resolvers are currently running.

## Sources

The resolver uses:

1. **StevenBlack hosts file** – porn-only category
   - Source: https://github.com/StevenBlack/hosts
   - Category: `fakenews-gambling-porn` or similar (porn-only subset)
   - Updated: Automatically via Blocky's list refresh

2. **GitHub-hosted overlay lists** (URLs configurable)
   - Additional domains specific to Narge content
   - Hosted as public GitHub URLs
   - Can be updated independently of the main StevenBlack list

## Response

Blocked domains return **NXDOMAIN** (non-existent domain), identical to a normal DNS miss.

This is a content-class filter, not an ad or malware blocker. Rate limiting is a capacity management feature, not part of the filtering logic (see [JOIN.md](JOIN.md)).

## List Management

Block lists are:
- Configured in Blocky's YAML configuration
- Fetched automatically by Blocky on a refresh schedule
- Not forked or modified by the token front

The token-aware DoH front (Caddy, etc.) does not touch the lists. It only handles tokens and rate limiting.

## Principles

- **Narge is a content class** (see main [README](../README.md))
- Lists block domains, not IPs or URLs
- `NXDOMAIN` is the only response for blocked queries
- No logging of query names
