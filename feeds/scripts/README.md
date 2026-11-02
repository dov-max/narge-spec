# Narge Feed Sync Scripts

Collection of scripts to sync the Narge domain list to various DNS and security platforms.

## Available Scripts

### Native URL Feed Support

These platforms can fetch the Narge list directly via HTTPS URL. No sync script needed:

- **Palo Alto Networks (PAN-OS)** - External Dynamic Lists
- **Fortinet FortiGate** - External Connector, Domain Name feed
- **Infoblox** - TIDE custom feed or CSV import
- **DigiCert UltraDDR** - Lists Engine URL import
- **pfSense (pfBlockerNG)** - DNSBL source URL
- **OPNsense** - Unbound custom blocklist URL
- **WatchGuard Firebox** - Custom Dynamic Alias
- **Unbound** - RPZ url: (use narge.rpz)
- **PowerDNS Recursor** - rpzFile() or rpzPrimary()
- **BIND** - RPZ zone (via AXFR or local file)

See the main [For IT Teams](https://thecutline.org/for-it) page for configuration instructions.

### API Sync Scripts

These platforms require API push via scheduled script:

| Script | Platform | README |
|--------|----------|--------|
| `windows-dns-sync.ps1` | Windows Server DNS | [README](./windows-dns-sync-README.md) |
| `umbrella-sync.py` | Cisco Umbrella | [README](./umbrella-sync-README.md) |
| `cloudflare-gateway-sync.py` | Cloudflare Gateway | [README](./cloudflare-gateway-sync-README.md) |
| `defender-sync.py` | Microsoft Defender for Endpoint | [README](./defender-sync-README.md) |

Additional platforms (Zscaler, DNSFilter, Meraki, Control D, UniFi) can be scripted similarly using their APIs.

## Feed URLs

### Public Feed (GitHub mirror)

```
https://raw.githubusercontent.com/dov-max/narge-spec/main/dist/narge.txt
```

### Hosted Feed (with telemetry)

```
https://feeds.thecutline.org/v1/narge.txt
https://feeds.thecutline.org/v1/narge-wildcard.txt
https://feeds.thecutline.org/v1/narge.rpz
https://feeds.thecutline.org/v1/narge-adguard.txt
https://feeds.thecutline.org/v1/narge-plain-nocomments.txt
https://feeds.thecutline.org/v1/narge.csv
https://feeds.thecutline.org/v1/narge-controld.json
```

**Note:** Hosted feed infrastructure is in progress. Per-organization feed URLs (with unique tokens) will be issued on request for verified deployments.

## File Formats

| Format | Description | Use Case |
|--------|-------------|----------|
| `narge.txt` | Plain domains, one per line, with header | Most platforms (PAN-OS with auto-expand, Fortinet, Infoblox) |
| `narge-wildcard.txt` | Each domain plus `*.domain` on separate lines | Platforms without subdomain auto-expand |
| `narge.rpz` | RPZ zone file with SOA/NS headers, `CNAME .` | Unbound, PowerDNS, BIND |
| `narge-adguard.txt` | AdGuard/AdBlock format `\|\|domain^` | AdGuard Home, AdGuard DNS, pfBlockerNG |
| `narge-plain-nocomments.txt` | Plain domains, no comments | UniFi, Windows DNS script |
| `narge.csv` | CSV with `domain` header | Infoblox custom lists, general import |
| `narge-controld.json` | Control D folder JSON | Control D folder import |
| `narge.hosts` | Hosts file format `0.0.0.0 domain` | Legacy use (cannot block subdomains) |

## Scheduling

All sync scripts are designed to run idempotently on a schedule. Recommended frequency: **daily**.

### Cron Example (Linux/macOS)

```bash
# Daily at 3 AM
0 3 * * * /usr/bin/python3 /path/to/script.py >> /var/log/narge-sync.log 2>&1
```

### Windows Scheduled Task (PowerShell)

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Scripts\script.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 3am
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Narge Sync" -Action $action -Trigger $trigger -Principal $principal
```

### GitHub Actions

Run sync scripts as GitHub Actions to keep credentials in GitHub Secrets:

```yaml
name: Narge Sync
on:
  schedule:
    - cron: '0 3 * * *'  # Daily at 3 AM UTC
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install requests
      - run: python3 feeds/scripts/your-script.py
        env:
          PLATFORM_API_KEY: ${{ secrets.PLATFORM_API_KEY }}
```

## Security Notes

- **Never commit credentials** to version control
- Use environment variables for all secrets
- Rotate API keys/secrets regularly
- Use least-privilege API permissions
- Review sync logs for errors or unauthorized access

## Support

- GitHub Issues: https://github.com/dov-max/narge-spec/issues
- Narge Specification: https://thecutline.org/spec
- For IT Teams Guide: https://thecutline.org/for-it

## License

CC0 1.0 (Public Domain). Scripts are provided as-is with no warranty.
