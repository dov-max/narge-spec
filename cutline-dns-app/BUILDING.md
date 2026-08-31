# Building Cutline DNS Settings App

Quick guide for building and testing the Cutline DNS app on Mac.

## Prerequisites

- **macOS** 14.0 or later
- **Xcode** 15.0 or later
- **Apple Developer Account** with access to Team ID H4R564J4LK (Optivantage Solutions LLC)
- **Physical iOS/iPadOS/Mac device** (DNS Settings do not work in simulators)

## Initial Setup

1. Open `CutlineDNS.xcodeproj` in Xcode
2. Select the CutlineDNS target
3. In Signing & Capabilities:
   - Ensure Team is set to "Optivantage Solutions LLC (H4R564J4LK)"
   - Verify "Automatically manage signing" is enabled
   - Confirm Network Extensions capability is present with DNS Settings

## Building for iOS/iPadOS

1. Connect your iPhone or iPad via USB
2. Select your device in the Xcode toolbar
3. Press ⌘R to build and run
4. **Important:** If you see "Untrusted Developer":
   - Go to Settings → General → VPN & Device Management
   - Trust the developer profile
   - Return to Xcode and run again

## Building for macOS

1. Select "My Mac" as the run destination
2. Press ⌘R to build and run
3. The app should launch on your Mac

## Testing DNS Configuration

After building and running the app:

1. Tap "Enable Cutline DNS"
2. Wait for the configuration to save
3. **You must approve the configuration:**
   - iOS/iPadOS: Settings → General → VPN & Device Management → DNS → Cutline DNS
   - macOS: System Settings → VPN → DNS Settings
4. Approve the configuration
5. Return to the app - status should show "Enabled"
6. Tap "Verify It Works" link to test DNS resolution at https://thecutline.org/verify

## Common Issues

### "Failed to save DNS settings"
- Ensure you have Network Extensions entitlement
- Check that provisioning profile includes the capability
- Verify you're running on a physical device (not simulator)

### Simulator Not Working
DNS Settings cannot be configured in iOS/iPadOS simulators. You must use a physical device.

### "Untrusted Developer"
After first install, trust the developer certificate in device Settings.

### Configuration Doesn't Take Effect
Make sure to approve the DNS configuration in Settings after enabling it in the app.

## Verifying Configuration

Once enabled and approved:

```bash
# On macOS, check DNS settings
scutil --dns | grep thecutline

# Should show:
# nameserver[0] : 64.176.200.99
# nameserver[1] : 149.28.79.49
```

Or visit https://thecutline.org/verify in Safari.

## Debugging

Enable verbose logging in Xcode console to see NEDNSSettingsManager errors:
1. Product → Scheme → Edit Scheme
2. Run → Arguments
3. Add environment variable: `OS_ACTIVITY_MODE = disable`

## App Store Build

For App Store submission:

1. Archive the app: Product → Archive
2. In Organizer, select the archive
3. Click "Distribute App"
4. Choose "App Store Connect"
5. Follow Xcode's distribution wizard
6. Upload to App Store Connect (SKU: cutline-dns)

**Note:** Do not submit to App Store Connect without explicit approval. This project creates the buildable app; submission is a separate step.

## Project Structure

- `CutlineDNSApp.swift` - SwiftUI app entry point
- `ContentView.swift` - Main UI with enable/disable button
- `DNSManager.swift` - NEDNSSettingsManager wrapper
- `CutlineDNS.entitlements` - Network Extensions DNS Settings capability
- `Info.plist` - App metadata and privacy descriptions

## Privacy & Permissions

The app requests Network Extensions capability (DNS Settings). No other permissions are needed.

Usage description in Info.plist:
> "Cutline uses DNS configuration to provide encrypted DNS resolution for all your network connections."
