# Microsoft Defender for Endpoint Indicator Sync Script

Syncs the Narge domain list to Microsoft Defender custom indicators.

## Requirements

- Python 3.7 or later
- `requests` library: `pip install requests`
- Microsoft Defender for Endpoint license
- Azure AD app registration with API permissions

## Setup

### 1. Create Azure AD App Registration

1. Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Click **New registration**
3. Name: "Narge Defender Sync" (or similar)
4. Supported account types: **Single tenant**
5. Click **Register**
6. Note the **Application (client) ID** and **Directory (tenant) ID**

### 2. Create Client Secret

1. In your app registration, go to **Certificates & secrets**
2. Click **New client secret**
3. Add description: "Narge sync script"
4. Set expiration (recommend 6-12 months, then rotate)
5. Click **Add**
6. **Copy the secret value immediately** (you won't see it again)

### 3. Grant API Permissions

1. In your app registration, go to **API permissions**
2. Click **Add a permission** → **APIs my organization uses**
3. Search for "WindowsDefenderATP" and select it
4. Select **Application permissions** (not delegated)
5. Add these permissions:
   - `Ti.ReadWrite` (Read and write Indicators)
6. Click **Add permissions**
7. Click **Grant admin consent** (requires Global Admin or Security Admin)

Docs: https://learn.microsoft.com/en-us/defender-endpoint/api/exposed-apis-create-app-webapp

### 4. Configure Environment Variables

```bash
export DEFENDER_TENANT_ID="your-tenant-id"
export DEFENDER_CLIENT_ID="your-client-id"
export DEFENDER_CLIENT_SECRET="your-client-secret"
```

## Usage

**Run the sync:**
```bash
python3 defender-sync.py
```

**Schedule it (cron example, daily at 3 AM):**
```bash
0 3 * * * /usr/bin/python3 /path/to/defender-sync.py >> /var/log/narge-defender-sync.log 2>&1
```

**Custom feed URL:**
```bash
export NARGE_FEED_URL="https://feeds.thecutline.org/v1/<your-org-token>/narge-plain-nocomments.txt"
python3 defender-sync.py
```

## How It Works

1. Obtains an OAuth2 access token from Azure AD
2. Fetches the Narge domain list from the feed URL
3. Queries existing Defender indicators with title "Narge"
4. Deletes all existing Narge indicators
5. Imports new indicators in batches of 500 (API limit)
6. Each indicator is set to:
   - Type: DomainName
   - Action: Block
   - Severity: Informational
   - Title: "Narge" (for identification)

## Limitations

- **Per-tenant limit**: 15,000 active indicators (not raisable)
- Narge uses ~371 indicators (~2.5% of limit)
- **Batch import limit**: 500 indicators per API call
- Indicators apply to all devices in the tenant (no RBAC group filtering by default)

## Testing

After sync completes:

1. **Check indicators in portal:**
   - Go to **Microsoft Defender portal** → **Settings** → **Indicators**
   - Filter by Title = "Narge"
   - Verify count matches sync output

2. **Test on a managed device:**
   ```powershell
   # Should be blocked by Defender
   Resolve-DnsName blocked-domain.com
   
   # Should work normally
   Resolve-DnsName example.com
   ```

3. **Check alerts:**
   - Blocked connections may generate alerts in the Defender portal
   - Go to **Incidents & alerts** → **Alerts**

## Device Coverage

Defender indicators work on:
- Windows 10/11 devices with Defender for Endpoint agent
- macOS devices with Defender for Endpoint
- Linux devices with Defender for Endpoint
- **Works on roaming devices** (home networks, travel, etc.)

This makes Defender ideal for remote/hybrid workforces where router-level filtering isn't available.

## Troubleshooting

**Authentication errors (401/403):**
- Verify tenant ID, client ID, and client secret are correct
- Check that API permissions (`Ti.ReadWrite`) are granted
- Ensure admin consent was given
- Verify the app is in the correct tenant

**Import errors:**
- Check that domains are valid FQDNs
- Verify you haven't exceeded the 15,000 indicator limit
- Review error messages in sync output

**Indicators not blocking:**
- Verify Defender is active on the test device
- Check device onboarding: **Settings** → **Endpoints** → **Device management**
- Ensure cloud-delivered protection is enabled
- Indicators can take a few minutes to propagate to devices

**Secret expiration:**
- Client secrets expire (check **Certificates & secrets**)
- Create a new secret before the old one expires
- Update `DEFENDER_CLIENT_SECRET` with the new value

## API References

- Defender API: https://learn.microsoft.com/en-us/defender-endpoint/api/apis-intro
- Indicators: https://learn.microsoft.com/en-us/defender-endpoint/api/ti-indicator
- Import Indicators: https://learn.microsoft.com/en-us/defender-endpoint/api/import-ti-indicators
- App Authentication: https://learn.microsoft.com/en-us/defender-endpoint/api/exposed-apis-create-app-webapp
