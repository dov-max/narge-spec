#!/usr/bin/env python3
"""
Narge Cisco Umbrella Destination List Sync

Syncs the Narge domain list to a Cisco Umbrella destination list via API.
Runs idempotently - safe to run on a schedule.

Requirements:
  - Python 3.7+
  - requests library: pip install requests

Environment variables (required):
  UMBRELLA_API_KEY       - Umbrella Management API key
  UMBRELLA_API_SECRET    - Umbrella Management API secret
  UMBRELLA_ORG_ID        - Your Umbrella organization ID
  UMBRELLA_DEST_LIST_ID  - Destination list ID (created via dashboard first)
  
Optional:
  NARGE_FEED_URL - Custom feed URL (defaults to public feed)

Usage:
  export UMBRELLA_API_KEY="your-key"
  export UMBRELLA_API_SECRET="your-secret"
  export UMBRELLA_ORG_ID="12345678"
  export UMBRELLA_DEST_LIST_ID="87654321"
  python3 umbrella-sync.py
"""

import os
import sys
import requests
from typing import List

FEED_URL = os.getenv('NARGE_FEED_URL', 'https://feeds.thecutline.org/v1/narge-plain-nocomments.txt')
API_KEY = os.getenv('UMBRELLA_API_KEY')
API_SECRET = os.getenv('UMBRELLA_API_SECRET')
ORG_ID = os.getenv('UMBRELLA_ORG_ID')
DEST_LIST_ID = os.getenv('UMBRELLA_DEST_LIST_ID')

BASE_URL = "https://management.api.umbrella.com/v1"


def fetch_narge_domains() -> List[str]:
    """Fetch domain list from feed URL."""
    print(f"Fetching Narge list from {FEED_URL}...")
    resp = requests.get(FEED_URL)
    resp.raise_for_status()
    
    domains = [line.strip() for line in resp.text.splitlines() 
               if line.strip() and not line.startswith('#')]
    print(f"Fetched {len(domains)} domains")
    return domains


def get_current_destinations(session: requests.Session) -> List[dict]:
    """Get current destinations in the list."""
    url = f"{BASE_URL}/organizations/{ORG_ID}/destinationlists/{DEST_LIST_ID}/destinations"
    resp = session.get(url)
    resp.raise_for_status()
    data = resp.json()
    return data.get('data', [])


def delete_destinations(session: requests.Session, destination_ids: List[int]):
    """Delete destinations by ID."""
    if not destination_ids:
        return
    
    print(f"Removing {len(destination_ids)} old destinations...")
    # Umbrella API allows deleting in batches
    for dest_id in destination_ids:
        url = f"{BASE_URL}/organizations/{ORG_ID}/destinationlists/{DEST_LIST_ID}/destinations/{dest_id}"
        resp = session.delete(url)
        resp.raise_for_status()


def add_destinations(session: requests.Session, domains: List[str]):
    """Add destinations in batches (max 500 per call)."""
    url = f"{BASE_URL}/organizations/{ORG_ID}/destinationlists/{DEST_LIST_ID}/destinations"
    batch_size = 500
    
    for i in range(0, len(domains), batch_size):
        batch = domains[i:i+batch_size]
        payload = [{"destination": domain, "type": "domain"} for domain in batch]
        
        print(f"Adding batch {i//batch_size + 1} ({len(batch)} domains)...")
        resp = session.post(url, json=payload)
        resp.raise_for_status()


def main():
    # Validate environment variables
    if not all([API_KEY, API_SECRET, ORG_ID, DEST_LIST_ID]):
        print("Error: Missing required environment variables", file=sys.stderr)
        print("Required: UMBRELLA_API_KEY, UMBRELLA_API_SECRET, UMBRELLA_ORG_ID, UMBRELLA_DEST_LIST_ID", file=sys.stderr)
        sys.exit(1)
    
    # Create authenticated session
    session = requests.Session()
    session.auth = (API_KEY, API_SECRET)
    session.headers.update({'Content-Type': 'application/json'})
    
    try:
        # Fetch new domain list
        domains = fetch_narge_domains()
        
        # Get current destinations
        print("Fetching current destinations...")
        current = get_current_destinations(session)
        current_ids = [dest['id'] for dest in current]
        
        # Remove all current destinations
        delete_destinations(session, current_ids)
        
        # Add new destinations
        add_destinations(session, domains)
        
        print(f"\nSuccess! Synced {len(domains)} domains to Umbrella destination list {DEST_LIST_ID}")
        
    except requests.exceptions.HTTPError as e:
        print(f"HTTP error: {e}", file=sys.stderr)
        if hasattr(e.response, 'text'):
            print(f"Response: {e.response.text}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
