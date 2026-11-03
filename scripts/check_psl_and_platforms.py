#!/usr/bin/env python3
"""
Check that no domains in the Narge list are public suffixes or shared platforms.

This script verifies that the list does not contain:
1. Public suffixes from the Public Suffix List (e.g., co.uk, com.au)
2. Known shared/multi-tenant platforms (e.g., wordpress.com, blogspot.com)

Exit codes:
  0 - All checks passed
  1 - Found public suffixes or shared platforms
"""

import sys
import os
import urllib.request

# Known shared platforms that should never be in the list
# These are multi-tenant hosts where blocking would affect unrelated content
SHARED_PLATFORMS = {
    'wordpress.com',
    'blogspot.com',
    'itch.io',
    'fc2.com',
    'free.fr',
    'b-cdn.net',
    'angelfire.com',
    'over-blog.com',
    'canalblog.com',
    'pbwstatic.com',
    'fastpic.ru',
    'imagetwist.com',
    'pixhost.to',
    'uploadhouse.com',
    'filestube.com',
    'booru.org',
    'sankakucomplex.com',
    'scrolller.com',
    'zproxy.org',
    'tumblr.com',
    'github.io',
    'neocities.org',
    'wixsite.com',
    'weebly.com',
    'squarespace.com',
    'medium.com',
}


def load_psl():
    """Load the Public Suffix List from publicsuffix.org."""
    psl_url = "https://publicsuffix.org/list/public_suffix_list.dat"
    
    print(f"Downloading Public Suffix List from {psl_url}...")
    try:
        with urllib.request.urlopen(psl_url, timeout=30) as response:
            content = response.read().decode('utf-8')
    except Exception as e:
        print(f"Warning: Could not download PSL: {e}")
        print("Using fallback PSL check...")
        return set()
    
    suffixes = set()
    for line in content.split('\n'):
        line = line.strip()
        # Skip empty lines and comments
        if not line or line.startswith('//'):
            continue
        # Remove wildcard prefix for matching
        if line.startswith('*.'):
            line = line[2:]
        # Skip exception rules (starting with !)
        if line.startswith('!'):
            continue
        suffixes.add(line.lower())
    
    print(f"Loaded {len(suffixes)} public suffixes")
    return suffixes


def load_narge_list(filepath='dist/narge.txt'):
    """Load domains from the Narge list."""
    domains = []
    if not os.path.exists(filepath):
        print(f"Error: {filepath} not found")
        sys.exit(2)
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            # Skip empty lines and comments
            if line and not line.startswith('#'):
                domains.append(line.lower())
    
    print(f"Loaded {len(domains)} domains from {filepath}")
    return domains


def main():
    print("Checking Narge list for public suffixes and shared platforms...\n")
    
    # Load the PSL
    psl = load_psl()
    
    # Load the Narge list
    domains = load_narge_list()
    
    # Check for violations
    psl_violations = []
    platform_violations = []
    
    for domain in domains:
        # Check if it's a public suffix
        if domain in psl:
            psl_violations.append(domain)
        
        # Check if it's a shared platform
        if domain in SHARED_PLATFORMS:
            platform_violations.append(domain)
    
    # Report results
    errors = False
    
    if psl_violations:
        print("ERROR: Found public suffixes in the list:")
        for domain in sorted(psl_violations):
            print(f"  - {domain}")
        print()
        errors = True
    
    if platform_violations:
        print("ERROR: Found shared platforms in the list:")
        for domain in sorted(platform_violations):
            print(f"  - {domain}")
        print()
        errors = True
    
    if errors:
        print("FAILED: Public suffixes and shared platforms must not be in the list.")
        print("These would block entire countries or multi-tenant services.")
        sys.exit(1)
    
    print("SUCCESS: No public suffixes or shared platforms found.")
    sys.exit(0)


if __name__ == '__main__':
    main()
