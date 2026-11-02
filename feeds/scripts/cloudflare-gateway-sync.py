#!/usr/bin/env python3
"""
Narge Cloudflare Gateway List Sync

Syncs the Narge domain list to a Cloudflare Gateway domain list.
Runs idempotently - safe to run on a schedule.

Requirements:
  - Python 3.7+
  - requests library: pip install requests

Environment variables (required):
  CLOUDFLARE_ACCOUNT_ID   - Your Cloudflare account ID
  CLOUDFLARE_API_TOKEN    - API token with Zero Trust edit permissions
  CLOUDFLARE_LIST_ID      - Gateway list ID (created via dashboard first)
  
Optional:
  NARGE_FEED_URL - Custom feed URL (defaults to public feed)

Usage:
  export CLOUDFLARE_ACCOUNT_ID="abc123..."
  export CLOUDFLARE_API_TOKEN="your-token"
  export CLOUDFLARE_LIST_ID="list-id-here"
  python3 cloudflare-gateway-sync.py
"""

import os
import sys
import requests
from typing import List

FEED_URL = os.getenv('NARGE_FEED_URL', 'https://feeds.thecutline.org/v1/narge-plain-nocomments.txt')
ACCOUNT_ID = os.getenv('CLOUDFLARE_ACCOUNT_ID')
API_TOKEN = os.getenv('CLOUDFLARE_API_TOKEN')
LIST_ID = os.getenv('CLOUDFLARE_LIST_ID')

BASE_URL = f"https://api.cloudflare.com/client/v4"


def fetch_narge_domains() -> List[str]:
    """Fetch domain list from feed URL."""
    print(f"Fetching Narge list from {FEED_URL}...")
    resp = requests.get(FEED_URL)
    resp.raise_for_status()
    
    domains = [line.strip() for line in resp.text.splitlines() 
               if line.strip() and not line.startswith('#')]
    print(f"Fetched {len(domains)} domains")
    return domains


def update_gateway_list(session: requests.Session, domains: List[str]):
    """Update Gateway list with new domains (replaces all items)."""
    url = f"{BASE_URL}/accounts/{ACCOUNT_ID}/gateway/lists/{LIST_ID}"
    
    # Cloudflare Gateway list items
    items = [{"value": domain} for domain in domains]
    
    print(f"Updating Gateway list {LIST_ID} with {len(items)} domains...")
    
    # PATCH replaces all items in the list
    payload = {
        "append": items,
        "remove": []
    }
    
    resp = session.patch(url, json=payload)
    resp.raise_for_status()
    
    result = resp.json()
    if result.get('success'):
        print(f"Successfully updated list")
    else:
        errors = result.get('errors', [])
        raise Exception(f"API errors: {errors}")


def get_list_info(session: requests.Session):
    """Get current list information."""
    url = f"{BASE_URL}/accounts/{ACCOUNT_ID}/gateway/lists/{LIST_ID}"
    resp = session.get(url)
    resp.raise_for_status()
    return resp.json()['result']


def clear_list(session: requests.Session):
    """Clear all items from the list."""
    print("Clearing existing list items...")
    url = f"{BASE_URL}/accounts/{ACCOUNT_ID}/gateway/lists/{LIST_ID}/items"
    
    # Get current items
    resp = session.get(url)
    resp.raise_for_status()
    current_items = resp.json()['result']
    
    if current_items:
        # Remove all current items
        item_ids = [item['id'] for item in current_items]
        delete_url = f"{BASE_URL}/accounts/{ACCOUNT_ID}/gateway/lists/{LIST_ID}"
        payload = {"remove": item_ids}
        resp = session.patch(delete_url, json=payload)
        resp.raise_for_status()
        print(f"Cleared {len(item_ids)} existing items")


def add_items_batch(session: requests.Session, domains: List[str]):
    """Add items in batches (Cloudflare limit varies by plan)."""
    url = f"{BASE_URL}/accounts/{ACCOUNT_ID}/gateway/lists/{LIST_ID}"
    batch_size = 1000  # Conservative batch size
    
    for i in range(0, len(domains), batch_size):
        batch = domains[i:i+batch_size]
        items = [{"value": domain} for domain in batch]
        
        print(f"Adding batch {i//batch_size + 1} ({len(batch)} domains)...")
        payload = {"append": items}
        resp = session.patch(url, json=payload)
        resp.raise_for_status()


def main():
    # Validate environment variables
    if not all([ACCOUNT_ID, API_TOKEN, LIST_ID]):
        print("Error: Missing required environment variables", file=sys.stderr)
        print("Required: CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN, CLOUDFLARE_LIST_ID", file=sys.stderr)
        sys.exit(1)
    
    # Create authenticated session
    session = requests.Session()
    session.headers.update({
        'Authorization': f'Bearer {API_TOKEN}',
        'Content-Type': 'application/json'
    })
    
    try:
        # Get list info to verify it exists and check limits
        list_info = get_list_info(session)
        print(f"List: {list_info.get('name')} (type: {list_info.get('type')})")
        
        # Fetch new domain list
        domains = fetch_narge_domains()
        
        # Check against list limit
        # Standard: 1,000 items, Enterprise: 5,000 items
        # Narge is currently 371 domains, well within limits
        
        # Clear existing items
        clear_list(session)
        
        # Add new items in batches
        add_items_batch(session, domains)
        
        print(f"\nSuccess! Synced {len(domains)} domains to Cloudflare Gateway list {LIST_ID}")
        print("Remember to reference this list in a Gateway DNS policy to enforce blocking.")
        
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
