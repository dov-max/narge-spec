# Join Path Design

This document describes how households can request access to Narge-filtering DNS resolvers.

**Status:** Design document. No resolvers are currently running.

## Overview

When you request access, you receive:
- A random access token
- Two DNS resolver IP addresses (planned: US East + US West)
- A DNS-over-HTTPS (DoH) URL that includes your token

Your token identifies your household for rate limiting and capacity planning. It is not tied to your IP address.

## How It Works

### 1. Getting a Token

When you join, the system mints a random token for your household. This token is:
- Randomly generated
- Not tied to your IP address
- Valid across dynamic IP changes and VPN connections

### 2. Using the Resolvers

Configure your devices with:
- **DNS IPs:** Two resolver addresses (east and west coast US preferred)
- **DoH URL:** Contains your token in the path, e.g., `https://doh.example.com/{token}/dns-query`

Your devices can use either traditional DNS (UDP/TCP port 53) or DNS-over-HTTPS. Both use your token for identification.

### 3. Rate Limiting

Each token has a per-token query-per-second (QPS) limit. This prevents abuse while allowing normal household usage.

A typical household will never hit this limit. A token shared on a public DoH URL would.

**The rate limit is per token, not per IP address.** Your dynamic IP or VPN usage does not affect your access.

### 4. Privacy

- Query names are **not logged**
- Your token is stored and counted for capacity planning
- No IP address is permanently associated with your token

#### Optional: Geographic Stats

When you join, the system may geolocate your request IP address **once** to determine your US state. This is:
- Used only for aggregate statistics ("N households in Y states")
- Labeled as inferred (not verified)
- Not used to restrict access
- Never updated or tracked after initial join

### 5. Capacity Management

The system tracks how many unique tokens actually query DNS in a rolling 7-day window.

**Trip point:** When the count of 7-day active tokens reaches a threshold (initially 500, configurable), the system:
- **Freezes new signups**
- Shows a waitlist where you can provide a notification email
- **Continues serving all existing tokens**

This ensures capacity is protected while allowing current households to keep working.

## What Gets Blocked

The resolvers use:
- StevenBlack's hosts file (porn-only category)
- GitHub-hosted overlay block lists (URLs configurable)
- `NXDOMAIN` response for blocked queries

Blocked domains return "non-existent domain" just like a normal DNS miss.

## Architecture Notes

The planned architecture is:
- **Token-aware front:** Caddy (or similar) handles DoH, extracts tokens, applies rate limiting
- **DNS resolver:** Unmodified Blocky with configured block lists
- Rate limiting is a token/capacity feature, not part of the ad/malware filtering logic

## Principles

1. **Narge is a content class, not a movement name.** There is no "Narge Coalition."
2. **No charges.** This service will not charge users.
3. **No IP pinning.** Dynamic IP and VPN connections must work.
4. **Privacy by default.** Query names are never logged.
5. **Honest capacity limits.** When capacity is reached, we show a waitlist instead of degrading service.

## Future

This document describes a planned system. Implementation requires:
- Provisioning two VPS instances (US East + West)
- Setting up the token-aware DoH front
- Configuring Blocky with the chosen block lists
- Building or deploying a simple token minting page

That work is not in this PR.
