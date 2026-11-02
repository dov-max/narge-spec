# Cloudflare Gateway List Sync Script

Syncs the Narge domain list to a Cloudflare Gateway domain list.

## Requirements

- Python 3.7 or later
- `requests` library: `pip install requests`
- Cloudflare account with Zero Trust (Gateway) enabled
- API token with Zero Trust edit permissions

## Setup

### 1. Enable Cloudflare Gateway

1. Log in to Cloudflare dashboard
2. Navigate to **Zero Trust** (formerly Teams)
3. If not already enabled, follow the setup wizard
4. Go to **Gateway > Policies**

### 2. Create API Token

1. Go to **Profile > API Tokens** (or https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Use the **Edit Cloudflare Zero Trust** template, or create custom with:
   - Zone:Zero Trust:Edit
   - Account:Zero Trust:Edit
4. Save the token (you won't see it again)

Docs: https://developers.cloudflare.com/fundamentals/api/get-started/create-token/

### 3. Create a Gateway List

1. In Zero Trust dashboard, go to **Gateway > Lists**
2. Click **Create a list**
3. Select **Domain** list type
4. Name it "Narge" or similar
5. Click **Save** (leave it empty for now)
6. Note the **List ID** from the URL or API

Docs: https://developers.cloudflare.com/cloudflare-one/policies/gateway/lists/

### 4. Find Your Account ID

1. Dashboard → Any domain → Overview
2. Account ID is shown in the right sidebar under **API**
3. Or visit https://dash.cloudflare.com/?to=/:account/workers and grab the ID from the URL

### 5. Configure Environment Variables

```bash
export CLOUDFLARE_ACCOUNT_ID="abc123def456..."
export CLOUDFLARE_API_TOKEN="your-api-token-here"
export CLOUDFLARE_LIST_ID="list-uuid-here"
```

### 6. Create a DNS Policy

After syncing the list:
1. Go to **Gateway > Firewall Policies > DNS**
2. Click **Add a policy**
3. Set up a rule:
   - **Selector**: Domain
   - **Operator**: in list
   - **Value**: Select your "Narge" list
   - **Action**: Block
4. Save and enable the policy

## Usage

**Run the sync:**
```bash
python3 cloudflare-gateway-sync.py
```

**Schedule it (cron example, daily at 3 AM):**
```bash
0 3 * * * /usr/bin/python3 /path/to/cloudflare-gateway-sync.py >> /var/log/narge-cf-sync.log 2>&1
```

**Custom feed URL:**
```bash
export NARGE_FEED_URL="https://feeds.thecutline.org/v1/<your-org-token>/narge-plain-nocomments.txt"
python3 cloudflare-gateway-sync.py
```

## How It Works

1. Fetches the Narge domain list from the feed URL
2. Verifies the Gateway list exists
3. Clears all existing items in the list
4. Adds new domains in batches of 1,000
5. Idempotent: safe to run repeatedly

## Limitations

- **Standard plan**: 1,000 items per list (Narge fits easily)
- **Enterprise plan**: 5,000 items per list
- The script batches items to handle future list growth
- List must be referenced in a DNS policy to enforce blocking

## Testing

After sync completes:
1. Check the list in the Gateway dashboard
2. Verify domain count matches the sync output
3. Test with `nslookup` or `dig`:
   ```bash
   # Should be blocked (if policy is active)
   nslookup blocked-domain.com 1.1.1.1
   
   # Should work normally
   nslookup example.com 1.1.1.1
   ```

## Troubleshooting

**Authentication errors (401/403):**
- Verify API token is correct and not expired
- Check that token has Zero Trust:Edit permissions
- Confirm Account ID is correct

**List not found (404):**
- Verify `CLOUDFLARE_LIST_ID` matches the list UUID in the dashboard
- Check that the list type is "Domain" (not IP or other types)

**Rate limits:**
- Cloudflare has generous API rate limits
- The script batches requests to stay within limits

**Items not blocking:**
- Verify the list is referenced in an active DNS policy
- Check policy order (policies are evaluated top-down)
- Test without WARP/1.1.1.1 for Families to isolate the Gateway policy

## API References

- Cloudflare Gateway API: https://developers.cloudflare.com/api/resources/zero_trust/subresources/gateway/
- Gateway Lists: https://developers.cloudflare.com/cloudflare-one/policies/gateway/lists/
- DNS Policies: https://developers.cloudflare.com/cloudflare-one/policies/gateway/dns-policies/
