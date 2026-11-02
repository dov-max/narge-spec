#!/usr/bin/env python3
"""
Build Narge distribution files from core and overlay sources.

Inputs:
  - core/*.txt (one domain per line)
  - overlay/block.txt (extra domains to block)
  - overlay/allow.txt (domains to allow - takes precedence)

Outputs:
  - dist/narge.txt (one domain per line)
  - dist/narge.hosts (0.0.0.0 format)
  - dist/narge-wildcard.txt (domain and *.domain on separate lines)
  - dist/narge.rpz (RPZ zone file with CNAME .)
  - dist/narge-adguard.txt (||domain^ format)
  - dist/narge-plain-nocomments.txt (plain domains, no comments, for UniFi)
  - dist/narge.csv (CSV format)
  - dist/narge-controld.json (Control D folder JSON format)
"""

import os
import glob
import json
from datetime import datetime, timezone


SUBSCRIBE_URL = "https://raw.githubusercontent.com/dov-max/narge-spec/main/dist/narge.txt"
FEED_BASE_URL = "https://feeds.thecutline.org/v1"
SPEC_VERSION = "0.2"


def parse_domain_file(filepath):
    """Parse a domain file, returning a set of domains (comments and blank lines stripped)."""
    domains = set()
    if not os.path.exists(filepath):
        return domains
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            # Skip empty lines and comments
            if line and not line.startswith('#'):
                domains.add(line)
    
    return domains


def collect_core_domains():
    """Collect all domains from core/*.txt files."""
    domains = set()
    core_files = sorted(glob.glob('core/*.txt'))
    
    for filepath in core_files:
        domains.update(parse_domain_file(filepath))
    
    return domains, core_files


def main():
    print("Building Narge distribution list...")
    
    # Collect domains from all sources
    core_domains, core_files = collect_core_domains()
    print(f"Loaded {len(core_domains)} domains from {len(core_files)} core file(s)")
    
    block_domains = parse_domain_file('overlay/block.txt')
    print(f"Loaded {len(block_domains)} domains from overlay/block.txt")
    
    allow_domains = parse_domain_file('overlay/allow.txt')
    print(f"Loaded {len(allow_domains)} domains from overlay/allow.txt")
    
    # Combine: core + block, then subtract allow
    all_domains = core_domains | block_domains
    final_domains = all_domains - allow_domains
    
    # Sort for stable output
    sorted_domains = sorted(final_domains)
    
    print(f"Final count: {len(sorted_domains)} unique domains")
    
    # Create timestamp
    timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
    
    # Determine source attribution
    source_note = "core sources (seeded from StevenBlack porn-only MIT license), overlay/block.txt, overlay/allow.txt"
    
    # Create dist/ directory
    os.makedirs('dist', exist_ok=True)
    
    # Write dist/narge.txt
    with open('dist/narge.txt', 'w') as f:
        f.write(f"# Narge domain list\n")
        f.write(f"# Spec version: {SPEC_VERSION}\n")
        f.write(f"# Build date: {timestamp}\n")
        f.write(f"# Subscribe URL: {SUBSCRIBE_URL}\n")
        f.write(f"# Sources: {source_note}\n")
        f.write(f"# License: CC0 1.0 (public domain)\n")
        f.write(f"# Attribution: Initial seed from StevenBlack hosts (MIT license)\n")
        f.write(f"#              https://github.com/StevenBlack/hosts\n")
        f.write(f"# Total domains: {len(sorted_domains)}\n")
        f.write(f"#\n")
        f.write(f"# Catalog ingest policy:\n")
        f.write(f"#   - Ingest as \"Narge,\" a separate optional category\n")
        f.write(f"#   - Do not merge into existing porn/adult/NSFW lists\n")
        f.write(f"#   - Do not relabel the class with those words\n")
        f.write(f"#   - See https://github.com/dov-max/narge-spec for definition\n")
        f.write(f"\n")
        for domain in sorted_domains:
            f.write(f"{domain}\n")
    
    print(f"Wrote dist/narge.txt ({len(sorted_domains)} domains)")
    
    # Write dist/narge.hosts
    with open('dist/narge.hosts', 'w') as f:
        f.write(f"# Narge domain list (hosts file format)\n")
        f.write(f"# Spec version: {SPEC_VERSION}\n")
        f.write(f"# Build date: {timestamp}\n")
        f.write(f"# Subscribe URL: {SUBSCRIBE_URL}\n")
        f.write(f"# Sources: {source_note}\n")
        f.write(f"# License: CC0 1.0 (public domain)\n")
        f.write(f"# Attribution: Initial seed from StevenBlack hosts (MIT license)\n")
        f.write(f"#              https://github.com/StevenBlack/hosts\n")
        f.write(f"# Total domains: {len(sorted_domains)}\n")
        f.write(f"#\n")
        f.write(f"# Catalog ingest policy:\n")
        f.write(f"#   - Ingest as \"Narge,\" a separate optional category\n")
        f.write(f"#   - Do not merge into existing porn/adult/NSFW lists\n")
        f.write(f"#   - Do not relabel the class with those words\n")
        f.write(f"#   - See https://github.com/dov-max/narge-spec for definition\n")
        f.write(f"\n")
        for domain in sorted_domains:
            f.write(f"0.0.0.0 {domain}\n")
    
    print(f"Wrote dist/narge.hosts ({len(sorted_domains)} domains)")
    
    # Write dist/narge-wildcard.txt (domain + *.domain on separate lines)
    with open('dist/narge-wildcard.txt', 'w') as f:
        f.write(f"# Narge domain list (wildcard format)\n")
        f.write(f"# Spec version: {SPEC_VERSION}\n")
        f.write(f"# Build date: {timestamp}\n")
        f.write(f"# Feed URL: {FEED_BASE_URL}/narge-wildcard.txt\n")
        f.write(f"# Format: domain and *.domain on separate lines\n")
        f.write(f"# License: CC0 1.0 (public domain)\n")
        f.write(f"# Total entries: {len(sorted_domains) * 2}\n")
        f.write(f"\n")
        for domain in sorted_domains:
            f.write(f"{domain}\n")
            f.write(f"*.{domain}\n")
    
    print(f"Wrote dist/narge-wildcard.txt ({len(sorted_domains) * 2} entries)")
    
    # Write dist/narge.rpz (RPZ zone file)
    # Serial format: YYYYMMDD01
    serial = datetime.now(timezone.utc).strftime('%Y%m%d01')
    with open('dist/narge.rpz', 'w') as f:
        f.write(f"$TTL 60\n")
        f.write(f"@ IN SOA rpz.thecutline.org. hostmaster.thecutline.org. (\n")
        f.write(f"    {serial}  ; Serial (YYYYMMDDNN)\n")
        f.write(f"    3600      ; Refresh (1 hour)\n")
        f.write(f"    600       ; Retry (10 minutes)\n")
        f.write(f"    604800    ; Expire (7 days)\n")
        f.write(f"    60        ; Minimum TTL\n")
        f.write(f"    )\n")
        f.write(f"@ IN NS rpz.thecutline.org.\n")
        f.write(f"\n")
        f.write(f"; Narge RPZ zone\n")
        f.write(f"; Spec version: {SPEC_VERSION}\n")
        f.write(f"; Build date: {timestamp}\n")
        f.write(f"; Feed URL: {FEED_BASE_URL}/narge.rpz\n")
        f.write(f"; Total domains: {len(sorted_domains)}\n")
        f.write(f"\n")
        for domain in sorted_domains:
            f.write(f"{domain} CNAME .\n")
            f.write(f"*.{domain} CNAME .\n")
    
    print(f"Wrote dist/narge.rpz ({len(sorted_domains)} domains, RPZ format)")
    
    # Write dist/narge-adguard.txt (AdGuard/AdBlock format)
    with open('dist/narge-adguard.txt', 'w') as f:
        f.write(f"! Title: Narge\n")
        f.write(f"! Description: Narge content class - adult content sites\n")
        f.write(f"! Spec version: {SPEC_VERSION}\n")
        f.write(f"! Build date: {timestamp}\n")
        f.write(f"! Feed URL: {FEED_BASE_URL}/narge-adguard.txt\n")
        f.write(f"! Homepage: https://github.com/dov-max/narge-spec\n")
        f.write(f"! License: CC0 1.0 (public domain)\n")
        f.write(f"! Total domains: {len(sorted_domains)}\n")
        f.write(f"!\n")
        for domain in sorted_domains:
            f.write(f"||{domain}^\n")
    
    print(f"Wrote dist/narge-adguard.txt ({len(sorted_domains)} domains)")
    
    # Write dist/narge-plain-nocomments.txt (for UniFi)
    with open('dist/narge-plain-nocomments.txt', 'w') as f:
        for domain in sorted_domains:
            f.write(f"{domain}\n")
    
    print(f"Wrote dist/narge-plain-nocomments.txt ({len(sorted_domains)} domains, no comments)")
    
    # Write dist/narge.csv
    with open('dist/narge.csv', 'w') as f:
        f.write("domain\n")
        for domain in sorted_domains:
            f.write(f"{domain}\n")
    
    print(f"Wrote dist/narge.csv ({len(sorted_domains)} domains)")
    
    # Write dist/narge-controld.json (Control D folder JSON format)
    controld_data = {
        "folder": {
            "title": "Narge",
            "description": "Narge content class - adult content sites",
            "rules": []
        },
        "metadata": {
            "spec_version": SPEC_VERSION,
            "build_date": timestamp,
            "feed_url": f"{FEED_BASE_URL}/narge-controld.json",
            "total_domains": len(sorted_domains)
        }
    }
    
    for domain in sorted_domains:
        controld_data["folder"]["rules"].append({
            "group": "domain",
            "do": "block",
            "status": 1,
            "PK": domain
        })
    
    with open('dist/narge-controld.json', 'w') as f:
        json.dump(controld_data, f, indent=2)
    
    print(f"Wrote dist/narge-controld.json ({len(sorted_domains)} domains)")
    
    print(f"\n=== Build complete! ===")
    print(f"Generated {len(sorted_domains)} domain entries across 9 formats")
    print(f"Files in dist/:")
    print(f"  - narge.txt (plain)")
    print(f"  - narge.hosts (hosts format)")
    print(f"  - narge-wildcard.txt (with *.domain)")
    print(f"  - narge.rpz (RPZ zone)")
    print(f"  - narge-adguard.txt (AdGuard/AdBlock)")
    print(f"  - narge-plain-nocomments.txt (UniFi)")
    print(f"  - narge.csv (CSV)")
    print(f"  - narge-controld.json (Control D)")


if __name__ == '__main__':
    main()
