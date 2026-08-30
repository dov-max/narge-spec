#!/usr/bin/env python3
"""
One-shot seed from StevenBlack porn-only list.

This script fetches the StevenBlack hosts porn-only list once,
extracts apex domains, and creates initial candidate and core files.

Run once to bootstrap the Narge list. After this, core/ is ours.
"""

import urllib.request
from datetime import datetime, timezone
from collections import Counter
import os
import re

# Configuration
STEVENBLACK_URL = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"
FANOUT_THRESHOLD = 10  # >=10 hostnames per apex

# Try public suffix list approach, fallback to naive
try:
    import publicsuffix2
    def get_apex(hostname):
        """Get apex domain using public suffix list."""
        try:
            psl = publicsuffix2.PublicSuffixList()
            apex = psl.get_public_suffix(hostname)
            return apex if apex else hostname
        except:
            # Fallback to naive
            parts = hostname.split('.')
            if len(parts) >= 2:
                return '.'.join(parts[-2:])
            return hostname
except ImportError:
    # Naive 2-label fallback
    def get_apex(hostname):
        """Get apex domain using naive 2-label approach."""
        parts = hostname.split('.')
        if len(parts) >= 2:
            return '.'.join(parts[-2:])
        return hostname


def parse_hosts_file(content):
    """Parse hosts file format and extract unique hostnames."""
    hostnames = set()
    for line in content.splitlines():
        line = line.strip()
        # Skip empty lines and comments
        if not line or line.startswith('#'):
            continue
        # Parse "0.0.0.0 hostname" or "127.0.0.1 hostname" format
        parts = line.split()
        if len(parts) >= 2 and parts[0] in ('0.0.0.0', '127.0.0.1'):
            hostname = parts[1]
            # Skip localhost entries
            if hostname not in ('localhost', 'localhost.localdomain', 'local'):
                hostnames.add(hostname)
    return hostnames


def main():
    print(f"Fetching StevenBlack porn-only list from {STEVENBLACK_URL}")
    
    # Fetch the list
    with urllib.request.urlopen(STEVENBLACK_URL) as response:
        content = response.read().decode('utf-8')
    
    # Parse hostnames
    hostnames = parse_hosts_file(content)
    print(f"Parsed {len(hostnames)} unique hostnames")
    
    # Extract apex domains and count fanout
    apex_to_hosts = {}
    for hostname in hostnames:
        apex = get_apex(hostname)
        if apex not in apex_to_hosts:
            apex_to_hosts[apex] = set()
        apex_to_hosts[apex].add(hostname)
    
    # Get all unique apexes
    all_apexes = sorted(apex_to_hosts.keys())
    print(f"Found {len(all_apexes)} unique apex domains")
    
    # Get high-fanout apexes (likely type 1 or 2)
    high_fanout = sorted([
        apex for apex, hosts in apex_to_hosts.items()
        if len(hosts) >= FANOUT_THRESHOLD
    ])
    print(f"Found {len(high_fanout)} apex domains with >={FANOUT_THRESHOLD} hostnames")
    
    # Create timestamp
    timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
    
    # Write candidates/from-import.txt (all unique apexes)
    os.makedirs('candidates', exist_ok=True)
    with open('candidates/from-import.txt', 'w') as f:
        f.write(f"# Narge candidate domains from StevenBlack import\n")
        f.write(f"# Source: {STEVENBLACK_URL}\n")
        f.write(f"# License: MIT (StevenBlack hosts)\n")
        f.write(f"# Import date: {timestamp}\n")
        f.write(f"# Total unique apex domains: {len(all_apexes)}\n")
        f.write(f"#\n")
        f.write(f"# This file contains ALL unique apex domains extracted from the import.\n")
        f.write(f"# It is NOT the production list. See likely-type12.txt for the selected subset.\n")
        f.write(f"\n")
        for apex in all_apexes:
            f.write(f"{apex}\n")
    
    print(f"Wrote candidates/from-import.txt ({len(all_apexes)} domains)")
    
    # Write candidates/likely-type12.txt (high fanout apexes)
    with open('candidates/likely-type12.txt', 'w') as f:
        f.write(f"# Narge candidate domains: likely type 1 (watch) or type 2 (paid creator)\n")
        f.write(f"# Source: {STEVENBLACK_URL}\n")
        f.write(f"# License: MIT (StevenBlack hosts)\n")
        f.write(f"# Import date: {timestamp}\n")
        f.write(f"# Selection criteria: apex domains with >={FANOUT_THRESHOLD} distinct hostnames in import\n")
        f.write(f"# Total selected: {len(high_fanout)}\n")
        f.write(f"#\n")
        f.write(f"# These apex domains show high subdomain fanout, suggesting streaming/gallery (type 1)\n")
        f.write(f"# or paid creator platforms (type 2). This is the initial core seed.\n")
        f.write(f"\n")
        for apex in high_fanout:
            host_count = len(apex_to_hosts[apex])
            f.write(f"{apex}\n")
    
    print(f"Wrote candidates/likely-type12.txt ({len(high_fanout)} domains)")
    
    # Copy to core/ (this becomes the owned list)
    os.makedirs('core', exist_ok=True)
    with open('core/from-stevenblack-seed.txt', 'w') as f:
        f.write(f"# Narge core domains seeded from StevenBlack\n")
        f.write(f"# Original source: {STEVENBLACK_URL}\n")
        f.write(f"# Original license: MIT (StevenBlack hosts)\n")
        f.write(f"# Import date: {timestamp}\n")
        f.write(f"# Selection: apex domains with >={FANOUT_THRESHOLD} distinct hostnames\n")
        f.write(f"#\n")
        f.write(f"# From this point forward, this list is maintained by the Narge project.\n")
        f.write(f"# Changes are made via overlay/block.txt and overlay/allow.txt.\n")
        f.write(f"\n")
        for apex in high_fanout:
            f.write(f"{apex}\n")
    
    print(f"Wrote core/from-stevenblack-seed.txt ({len(high_fanout)} domains)")
    print("\nSeed complete. The core/ directory is now owned by Narge.")
    print("Do not re-run this script. Future updates use overlay files.")


if __name__ == '__main__':
    main()
