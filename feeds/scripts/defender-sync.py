#!/usr/bin/env python3
"""
Narge Microsoft Defender for Endpoint Indicator Sync

Syncs the Narge domain list to Microsoft Defender custom indicators.
Runs idempotently - safe to run on a schedule.

Requirements:
  - Python 3.7+
  - requests library: pip install requests

Environment variables (required):
  DEFENDER_TENANT_ID      - Azure AD tenant ID
  DEFENDER_CLIENT_ID      - App registration client ID
  DEFENDER_CLIENT_SECRET  - App registration client secret
  
Optional:
  NARGE_FEED_URL - Custom feed URL (defaults to public feed)

Usage:
  export DEFENDER_TENANT_ID="your-tenant-id"
  export DEFENDER_CLIENT_ID="your-client-id"
  export DEFENDER_CLIENT_SECRET="your-client-secret"
  python3 defender-sync.py
"""

import os
import sys
import requests
from typing import List

FEED_URL = os.getenv('NARGE_FEED_URL', 'https://feeds.thecutline.org/v1/narge-plain-nocomments.txt')
TENANT_ID = os.getenv('DEFENDER_TENANT_ID')
CLIENT_ID = os.getenv('DEFENDER_CLIENT_ID')
CLIENT_SECRET = os.getenv('DEFENDER_CLIENT_SECRET')

GRAPH_URL = "https://api.securitycenter.microsoft.com"
LOGIN_URL = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"


def get_access_token() -> str:
    """Get OAuth2 access token for Defender API."""
    print("Obtaining access token...")
    
    data = {
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET,
        'scope': 'https://api.securitycenter.microsoft.com/.default',
        'grant_type': 'client_credentials'
    }
    
    resp = requests.post(LOGIN_URL, data=data)
    resp.raise_for_status()
    
    return resp.json()['access_token']


def fetch_narge_domains() -> List[str]:
    """Fetch domain list from feed URL."""
    print(f"Fetching Narge list from {FEED_URL}...")
    resp = requests.get(FEED_URL)
    resp.raise_for_status()
    
    domains = [line.strip() for line in resp.text.splitlines() 
               if line.strip() and not line.startswith('#')]
    print(f"Fetched {len(domains)} domains")
    return domains


def get_existing_indicators(session: requests.Session) -> List[dict]:
    """Get existing Narge indicators."""
    url = f"{GRAPH_URL}/api/indicators"
    params = {
        '$filter': "indicatorType eq 'DomainName' and title eq 'Narge'"
    }
    
    print("Fetching existing Narge indicators...")
    resp = session.get(url, params=params)
    resp.raise_for_status()
    
    indicators = resp.json().get('value', [])
    print(f"Found {len(indicators)} existing Narge indicators")
    return indicators


def delete_indicators(session: requests.Session, indicator_ids: List[str]):
    """Delete indicators by ID."""
    if not indicator_ids:
        return
    
    print(f"Removing {len(indicator_ids)} old indicators...")
    for indicator_id in indicator_ids:
        url = f"{GRAPH_URL}/api/indicators/{indicator_id}"
        resp = session.delete(url)
        if resp.status_code not in (200, 204):
            print(f"Warning: Failed to delete {indicator_id}: {resp.status_code}")


def import_indicators_batch(session: requests.Session, domains: List[str]):
    """Import indicators in batches (max 500 per call)."""
    url = f"{GRAPH_URL}/api/indicators/import"
    batch_size = 500
    
    for i in range(0, len(domains), batch_size):
        batch = domains[i:i+batch_size]
        
        indicators = []
        for domain in batch:
            indicators.append({
                "indicatorValue": domain,
                "indicatorType": "DomainName",
                "action": "Block",
                "title": "Narge",
                "description": "Narge content class domain block",
                "severity": "Informational",
                "recommendedActions": "Block access to this domain",
                "rbacGroupNames": []
            })
        
        print(f"Importing batch {i//batch_size + 1} ({len(batch)} indicators)...")
        payload = {"Indicators": indicators}
        resp = session.post(url, json=payload)
        
        if resp.status_code == 200:
            result = resp.json()
            errors = result.get('Errors', [])
            if errors:
                print(f"Warning: {len(errors)} errors in batch")
                for err in errors[:5]:  # Show first 5
                    print(f"  - {err}")
        else:
            print(f"Warning: Batch import returned {resp.status_code}")
            print(f"Response: {resp.text[:500]}")


def main():
    # Validate environment variables
    if not all([TENANT_ID, CLIENT_ID, CLIENT_SECRET]):
        print("Error: Missing required environment variables", file=sys.stderr)
        print("Required: DEFENDER_TENANT_ID, DEFENDER_CLIENT_ID, DEFENDER_CLIENT_SECRET", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Get access token
        token = get_access_token()
        
        # Create authenticated session
        session = requests.Session()
        session.headers.update({
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        })
        
        # Fetch new domain list
        domains = fetch_narge_domains()
        
        # Get existing Narge indicators
        existing = get_existing_indicators(session)
        existing_ids = [ind['id'] for ind in existing]
        
        # Delete old indicators
        delete_indicators(session, existing_ids)
        
        # Import new indicators
        import_indicators_batch(session, domains)
        
        print(f"\nSuccess! Synced {len(domains)} indicators to Microsoft Defender")
        print(f"Note: Defender has a limit of 15,000 active indicators per tenant.")
        print(f"Narge uses {len(domains)} indicators (~{(len(domains)/15000)*100:.1f}% of limit).")
        
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
