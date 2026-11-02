# Windows Server DNS Sync Script

Syncs the Narge domain list to Windows Server DNS Query Resolution Policies.

## Requirements

- Windows Server 2016 or later
- DNS Server role installed
- PowerShell 5.1 or later
- Administrator privileges

## Installation

1. **Download the script:**
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/dov-max/narge-spec/main/feeds/scripts/windows-dns-sync.ps1" -OutFile "windows-dns-sync.ps1"
   ```

2. **Run as Administrator:**
   ```powershell
   .\windows-dns-sync.ps1 -Install
   ```

3. **Set up scheduled task (recommended):**
   ```powershell
   $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Scripts\windows-dns-sync.ps1 -Install"
   $trigger = New-ScheduledTaskTrigger -Daily -At 3am
   $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
   Register-ScheduledTask -TaskName "Narge DNS Sync" -Action $action -Trigger $trigger -Principal $principal
   ```

## Usage

**Install/Update blocks:**
```powershell
.\windows-dns-sync.ps1 -Install
```

**Uninstall all blocks:**
```powershell
.\windows-dns-sync.ps1 -Uninstall
```

**Custom feed URL:**
```powershell
$env:NARGE_FEED_URL = "https://feeds.thecutline.org/v1/<your-org-token>/narge-plain-nocomments.txt"
.\windows-dns-sync.ps1 -Install
```

## How It Works

- Fetches the Narge domain list from the feed URL
- Creates DNS Query Resolution Policies with action IGNORE (SERVFAIL response)
- Each policy blocks `domain` and `*.domain`
- Idempotent: safe to run repeatedly (removes old policies first)
- Policies are named `Narge-Block-0`, `Narge-Block-1`, etc.

## Testing

After installation, test DNS resolution:

```powershell
# Should fail (blocked)
Resolve-DnsName example-blocked-domain.com -Server 127.0.0.1

# Should work (not blocked)
Resolve-DnsName example.com -Server 127.0.0.1
```

## Notes

- Query Resolution Policies are per-server and do not replicate to other DNS servers
- Each domain creates one policy with both apex and wildcard patterns
- The script cleans up old policies on each run
- No native RPZ support in Windows Server DNS; this uses Query Resolution Policies instead

## Troubleshooting

**Policies not applied:**
- Verify DNS Server role is installed: `Get-WindowsFeature DNS`
- Check policies exist: `Get-DnsServerQueryResolutionPolicy | Where-Object { $_.Name -like "Narge-Block-*" }`
- Restart DNS Server: `Restart-Service DNS`

**Fetch fails:**
- Verify internet connectivity from the server
- Check firewall allows HTTPS outbound
- Test feed URL manually: `Invoke-WebRequest -Uri $FEED_URL`
