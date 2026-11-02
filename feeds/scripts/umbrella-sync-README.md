# Cisco Umbrella Destination List Sync Script

Syncs the Narge domain list to a Cisco Umbrella destination list via the Management API.

## Requirements

- Python 3.7 or later
- `requests` library: `pip install requests`
- Cisco Umbrella account with API access
- Management API key with destination list permissions

## Setup

### 1. Create API Credentials

1. Log in to the Umbrella dashboard
2. Navigate to **Admin > API Keys**
3. Create a new **Management API** key
4. Save the Key and Secret (you won't see the secret again)
5. Ensure the key has permissions for Destination Lists

Docs: https://developer.cisco.com/docs/cloud-security/#!authentication

### 2. Create a Destination List

1. In Umbrella dashboard, go to **Policies > Destination Lists**
2. Click **Add** to create a new destination list
3. Name it "Narge" or similar
4. Note the **Destination List ID** (visible in the URL or API)

### 3. Configure Environment Variables

```bash
export UMBRELLA_API_KEY="your-api-key-here"
export UMBRELLA_API_SECRET="your-api-secret-here"
export UMBRELLA_ORG_ID="12345678"
export UMBRELLA_DEST_LIST_ID="87654321"
```

To find your Organization ID:
- Dashboard → Admin → Organization → Organization ID

### 4. Attach List to a Policy

After creating the destination list:
1. Go to **Policies > DNS Policies**
2. Edit your policy
3. Under **Block Destinations**, add your "Narge" destination list
4. Save the policy

## Usage

**Run the sync:**
```bash
python3 umbrella-sync.py
```

**Schedule it (cron example, daily at 3 AM):**
```bash
0 3 * * * /usr/bin/python3 /path/to/umbrella-sync.py >> /var/log/narge-umbrella-sync.log 2>&1
```

**Custom feed URL:**
```bash
export NARGE_FEED_URL="https://feeds.thecutline.org/v1/<your-org-token>/narge-plain-nocomments.txt"
python3 umbrella-sync.py
```

## How It Works

1. Fetches the Narge domain list from the feed URL
2. Retrieves current destinations in the specified destination list
3. Deletes all current destinations
4. Adds new destinations in batches of 500 (API limit)
5. Idempotent: safe to run repeatedly

## Limitations

- Umbrella file upload supports up to 5,000 entries (Narge is well within this)
- API batch limit: 500 destinations per call
- The destination list must be created via the dashboard first

## Testing

After sync completes:
1. Check the destination list in the Umbrella dashboard
2. Verify domain count matches the sync output
3. Test a blocked domain: `nslookup blocked-domain.com`
4. Test a normal domain: `nslookup example.com`

## Troubleshooting

**Authentication errors (401/403):**
- Verify API key and secret are correct
- Check that the API key has Destination List permissions
- Confirm Organization ID is correct

**Destination list not found (404):**
- Verify `UMBRELLA_DEST_LIST_ID` is correct
- Check that the destination list exists in the dashboard

**Rate limits:**
- The script respects Umbrella API rate limits
- If you hit limits, add delays between batches or reduce frequency

## API References

- Umbrella Management API: https://developer.cisco.com/docs/cloud-security/
- Destination Lists: https://developer.cisco.com/docs/cloud-security/add-destinations-to-destination-list/
