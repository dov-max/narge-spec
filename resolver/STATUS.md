# Resolver Status and Operations

This document describes the operational status requirements for the Narge DNS resolvers.

## Public Status Site

A public status site (not hosted on narge.net; narge.net is specification-only) displays real-time operational information about the resolver infrastructure.

### Status Metrics Displayed

The status site shows:

1. **Technical Health** (per resolver)
   - Resolver is up and responding
   - Blocky process is running
   - Disk space available
   - DNS queries answering locally (not failing upstream)

2. **Capacity Metrics**
   - Bandwidth usage toward 1TB/month plan limit
   - CPU utilization
   - Query flood detection (rate of queries)

3. **Usage Count**
   - Count of distinct source IPs that queried in the last 7 days
   - **Label:** "distinct source IPs" (NOT "households")

4. **Geographic Distribution**
   - Inferred US states from GeoIP of query source IPs
   - **Label:** "inferred" (GeoIP is approximate)

### Status Investigation

If a status metric looks wrong, humans investigate. No fake numbers.

## Resolver Addresses

Two shared DNS resolvers exist:

- **Newark:** `64.176.200.99`
- **Los Angeles:** `149.28.79.49`

**Current state:** Resolvers exist and filter locally. Port 53 is not yet open publicly.

## How It Works

Households configure their home router with the two DNS addresses above. No account or signup required.

### Rate Limiting

Rate limiting protects port 53 from open-resolver abuse:

- **Per public source IP:** Rate limit based on the client's public IP address
- **Global cap:** Overall query limit across all sources

This prevents the resolver from being an open-resolver abuse hole. We cannot see MAC addresses, only public source IPs.

### Privacy

- **Source IP storage:** Source IPs (or hashes) are stored for 7 days to count distinct users
- **Query names:** DNS query names (domains requested) are NOT logged
- **Purpose:** IP storage is for counting only, not surveillance

## Capacity Management

When capacity limits are approached (bandwidth, CPU, query volume):

- **Response:** Add more boxes, set alarms, investigate
- **NOT:** Freeze signups or cap user count

There is no 500-token freeze or signup freeze. The system scales by adding infrastructure.

## Configuration

See the [Blocky DNS Resolver Configuration](README.md) for deployment instructions.

Stock Blocky with StevenBlack porn-only list + overlay, returning `NXDOMAIN` for blocked domains.
