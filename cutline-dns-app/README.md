# Cutline DNS Settings App

iOS, iPadOS, and macOS app that uses NEDNSSettingsManager to configure system-wide encrypted DNS-over-HTTPS.

## Overview

This app configures your device to use Cutline's encrypted DNS resolvers. It installs a DNS Settings configuration (not a VPN, not a content filter) that routes all DNS queries through HTTPS.

**Bundle ID:** `org.thecutline.dns`  
**Developer Team:** Optivantage Solutions LLC (Team ID: H4R564J4LK)  
**App Store Connect:** Cutline DNS (SKU: cutline-dns)

## Features

- **Clean State-Based UI:** Clear status with minimal clutter
- **Guided Setup Flow:** Visual instructions with Settings screenshot (macOS)
- **Fail-Closed Verification:** Only shows "working" when DNS is provably cutting
- **Encrypted DNS-over-HTTPS:** All DNS queries encrypted using `https://dns.thecutline.org/dns-query`
- **Multi-Platform:** iPhone, iPad, Mac (native), and visionOS
- **System-Wide:** Works for all network connections (Wi-Fi and cellular)
- **Privacy First:** No account required, no tracking
- **Smart Problem Detection:** Live Private Relay detection, specific error messages

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
2. Add Settings screenshot images to `Assets.xcassets/SettingsFilters.imageset/`:
   - `settings-filters.png` (1x resolution)
   - `settings-filters@2x.png` (2x resolution)
   - Should show System Settings → Network → Filters with Cutline DNS enabled
3. Select your target device or simulator
4. Build and run (⌘R)

**Note:** DNS Settings configuration requires:
- A physical device (does not work in simulators)
- Proper provisioning profile with Network Extensions capability
- Team ID set to H4R564J4LK (Optivantage Solutions LLC)

## User Experience

### Turn-On Flow

1. User taps "Turn on Cutline DNS"
2. App saves DNS configuration (treating "unchanged" as success, not error)
3. App automatically opens System Settings
4. **macOS:** Shows screenshot of Settings → Network → Filters with instructions
5. **iOS/visionOS:** Shows text instructions for Settings → General → VPN & Device Management → DNS
6. User manually enables Cutline DNS in Settings (Apple requirement)
7. User returns to app and taps "I've enabled it"
8. App verifies DNS is working with fail-closed probes
9. Shows green "Cutline is on" when both probes confirm cutting

### States

- **Off:** Minimal info, "Free and open source. No account."
- **Waiting:** Shows Settings instructions and confirmation button
- **Working:** Single green line, collapse Advanced by default
- **Problem:** Shows specific issue (Private Relay, verification failure) with Retry

### Important Notes

- **Fail-Closed Verification:** Green status only when `on.thecutline.org/ok` succeeds AND `off.thecutline.org/ok` fails
- **Live Private Relay Detection:** Checks CFNetwork proxy settings on macOS, shows problem only when detected and enabled
- **Not a VPN:** This uses NEDNSSettingsManager, not a VPN profile. It only affects DNS resolution.
- **User Approval Required:** Apple requires user approval in Settings for DNS configuration changes.
- **Never Sets isEnabled Locally:** Always reads Apple's flag from NEDNSSettingsManager

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
