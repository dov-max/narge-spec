# Cutline DNS Windows Installer

One-click Windows DNS installer for Cutline DNS. This self-contained executable configures encrypted DNS (DoH) on Windows 10 and 11.

## Features

- **One-click install**: Double-click, approve UAC, done
- **Encrypted DNS**: Configures DNS-over-HTTPS (DoH) on Windows 11
- **Complete coverage**: Configures all Wi-Fi, Ethernet, and cellular/WWAN adapters
- **IPv6 protection**: Disables IPv6 to prevent DNS leaks
- **Auto-configuration**: New adapters are automatically configured via scheduled task
- **Easy uninstall**: Settings → Apps → Cutline DNS

## Building

Requires .NET 8 SDK:

```bash
dotnet publish -c Release -r win-x64 --self-contained
```

The output will be in `bin/Release/net8.0-windows/win-x64/publish/cutline-dns-setup.exe`

## Usage

**Install:**
```
cutline-dns-setup.exe
```

**Uninstall:**
```
cutline-dns-setup.exe /uninstall
```

Or uninstall via Settings → Apps → Cutline DNS

**Silent mode** (for scheduled task):
```
cutline-dns-setup.exe /silent
```

## Return codes

| Code | Meaning |
|------|---------|
| 0    | Success: wizard finished, or silent install/uninstall succeeded. Re-running when already installed also returns 0 (re-applies DNS). Cancel on the Welcome screen currently returns 0. |
| 1    | Failure: not running as Administrator, or any exception during wizard/silent install. |

This executable does not return Windows Installer codes. Partner Center standard-scenario boxes are filled with unused MSI codes (1602 cancelled, 1638 already exists, 1618 in progress, 112 disk full, 3010 reboot, 1625 package rejected) which this EXE does not emit. Miscellaneous failures return 1.

## What it does

1. Configures DNS servers (64.176.200.99, 149.28.79.49) on all physical network adapters
2. Disables IPv6 on those adapters to prevent DNS leaks
3. Registers DoH templates on Windows 11 (skipped on Windows 10)
4. Flushes DNS cache
5. Creates a scheduled task that re-runs on logon and network profile changes
6. Registers in Add/Remove Programs

## What it skips

- Loopback adapters
- Hyper-V/vEthernet adapters
- WSL adapters
- Bluetooth adapters
- ISATAP/Teredo adapters
- VPN adapters (TAP, WireGuard, OpenVPN, etc.)
