# Cutline DNS Settings App

iOS, iPadOS, and macOS app that uses NEDNSSettingsManager to configure system-wide encrypted DNS-over-HTTPS.

## Overview

This app configures your device to use Cutline's encrypted DNS resolvers. It installs a DNS Settings configuration (not a VPN, not a content filter) that routes all DNS queries through HTTPS.

**Bundle ID:** `org.thecutline.dns`  
**Developer Team:** Optivantage Solutions LLC (Team ID: H4R564J4LK)  
**App Store Connect:** Cutline DNS (SKU: cutline-dns)

## Features

- **Simple One-Screen UI:** Enable/disable Cutline DNS with one tap
- **Encrypted DNS-over-HTTPS:** All DNS queries encrypted using `https://dns.thecutline.org/dns-query`
- **Multi-Platform:** iPhone, iPad, and Mac (native, not Catalyst)
- **System-Wide:** Works for all network connections (Wi-Fi and cellular)
- **Privacy First:** No account required, no tracking
- **iCloud Private Relay Warning:** Alerts users when Private Relay may bypass DNS settings

## Technical Details

### DNS Configuration

- **DoH Endpoint:** `https://dns.thecutline.org/dns-query`
- **Bootstrap Servers:** `64.176.200.99`, `149.28.79.49`
- **On-Demand Rules:** Connect by default for all interfaces (Wi-Fi and cellular)

### Requirements

- **iOS/iPadOS:** 17.0+
- **macOS:** 14.0+
- **Xcode:** 15.0+
- **Swift:** 5.0+

### Entitlements

- `com.apple.developer.networking.networkextension` with `dns-settings` capability

## Building

1. Open `CutlineDNS.xcodeproj` in Xcode 15 or later
2. Select your target device or simulator
3. Build and run (⌘R)

**Note:** DNS Settings configuration requires:
- A physical device (does not work in simulators)
- Proper provisioning profile with Network Extensions capability
- Team ID set to H4R564J4LK (Optivantage Solutions LLC)

## User Experience

When the user enables Cutline DNS:

1. The app configures DNS-over-HTTPS settings
2. **User must approve** the configuration in Settings → VPN & Device Management → DNS
3. The app shows an "Action Required" message until approved
4. Once approved, all DNS queries go through the encrypted Cutline resolver

### Important Notes

- **iCloud Private Relay:** When enabled, Private Relay bypasses custom DNS settings. The app warns users about this.
- **Not a VPN:** This uses NEDNSSettingsManager, not a VPN profile. It only affects DNS resolution.
- **User Approval Required:** Apple requires user approval in Settings for DNS configuration changes.

## Privacy

From Cutline's privacy policy:

- The resolver reads DNS query names to answer them
- Query names are not stored
- Source IPs are kept for 7 days for rate limiting, then deleted
- No account, no tracking, no user data collection

## App Store

This app is configured for distribution through the App Store:

- **Status:** Prepare for Submission
- **Platforms:** iOS, iPadOS, macOS, visionOS (configured)
- **Category:** Utilities

## License

Part of the Narge hostname feed reference implementation.  
See repository root LICENSE for details.

## Links

- **Verify It Works:** https://thecutline.org/verify
- **Privacy Policy:** https://thecutline.org/privacy
- **Main Site:** https://thecutline.org
