# Cutline DNS UI/UX Rewrite Summary

This document describes the complete UI/UX rewrite of the Cutline DNS app.

## Problems with Original UI

1. **Confusing State Display**: Showed "Disabled" at top but "Cutline DNS is Working" in green box below
2. **Always-On Lectures**: Private Relay warning displayed even when not relevant
3. **Prominent Diagnostics**: Stats and technical details cluttered the main view
4. **Error Mishandling**: "configuration is unchanged" shown as red error (it's actually success)
5. **Poor Layout**: Narrow 460pt column in huge empty window with inner scrollbar

## New Design Philosophy

### Clean State Machine
Every app state shows exactly one clear status:
- **Checking**: Spinner, no stale information
- **Off**: Minimal info, clear call to action
- **Waiting**: Specific instructions with visual aid
- **Working**: Single green confirmation line
- **Problem**: One focused issue with retry option

### Never Show Contradictions
- If Apple says disabled, don't verify or show "Working"
- If Apple says enabled but verification fails, show the specific problem
- Clear all leftover state on launch and when app becomes active

### Fail-Closed Verification
Only show green "Cutline is on" when BOTH conditions met:
1. `https://on.thecutline.org/ok` succeeds (reachable through DNS)
2. `https://off.thecutline.org/ok` fails (blocked by DNS)

Uses ephemeral URLSession with cache disabled.

## Implementation Details

### DNSManager Rewrite

#### New Properties
```swift
@Published var verificationResult: VerificationResult = .notTested
@Published var waitingForUserToEnable = false
@Published var showAdvanced = false
```

#### Key Methods
- `onAppear()`: Clears state, loads Apple's flag
- `loadStatus()`: Reads NEDNSSettingsManager.isEnabled (never sets it)
- `detectPrivateRelay()`: Live detection via CFNetwork proxy settings
- `verifyConnection()`: Fail-closed verification with both probes
- `saveConfiguration()`: Writes config, opens Settings
- `userConfirmedEnabled()`: Reloads status after user confirms

### ContentView Rewrite

#### Window Configuration
```swift
.frame(minWidth: 480, idealWidth: 520, minHeight: 640, idealHeight: 720)
```

Full-width layout with proper padding, no narrow column.

#### State Views
- `offStateView`: Turn-on button with tagline
- `waitingForEnableView`: Screenshot + instructions + confirm button
- `workingView`: Green status + disable button + collapsed Advanced
- `privateRelayView`: Specific Private Relay problem + retry
- `problemView`: Specific verification failure + retry
- `advancedView`: Diagnostics, probe details, GitHub link

### Platform Differences

#### macOS
- Shows System Settings screenshot (SettingsFilters asset)
- Opens Network Settings via URL scheme
- Detects Private Relay via CFNetwork

#### iOS/visionOS
- Text instructions only (no screenshot)
- Opens VPN & Device Management settings
- No Private Relay detection (not available on iOS)

## Turn-On Flow

1. User taps "Turn on Cutline DNS"
2. App calls `saveToPreferences()`
3. If error code 9 ("configuration is unchanged"): treat as success
4. Opens System Settings automatically
5. Shows screenshot of Filters page with Cutline DNS enabled
6. Instructions: "Apple requires you to set Cutline DNS to Enabled"
7. User flips switch in Settings
8. Returns to app, taps "I've enabled it"
9. App reloads flag from Apple
10. If enabled: runs verification → shows "Cutline is on"
11. If still disabled: shows "still disabled" message

Auto-reload also happens when app becomes active (user returns from Settings).

## Advanced Section

Collapsed by default. Contains:
- Verification details (which probes passed/failed)
- Probe URLs explained
- DNS statistics (placeholder for future implementation)
- GitHub repository link

Only shown when user taps "Advanced" or when troubleshooting problems.

## Error Handling

### "Configuration is unchanged" (Error Code 9)
**Old behavior**: Red error message
**New behavior**: Treated as success, proceed to Settings flow

This happens when DNS config is already saved. Not an error condition.

### Private Relay Detected
**Old behavior**: Always-on blue info box
**New behavior**: Only shown as active problem when enabled and affecting verification

### Verification Failures
Shows specific failure mode:
- "Cannot reach verification server" (on.thecutline.org failed)
- "DNS not cutting" (off.thecutline.org succeeded when it should fail)
- "Network error: [details]" (connection issues)

Each with Retry button and Advanced section for details.

## Asset Requirements

Screenshot needs to be added to `Assets.xcassets/SettingsFilters.imageset/`:
- `settings-filters.png` (1x resolution)
- `settings-filters@2x.png` (2x resolution)

Should show clean macOS System Settings → Network → Filters page with:
- Cutline DNS row visible
- Status showing "Enabled" in dropdown
- No personal information or unrelated system settings

## Version Bump

- `CURRENT_PROJECT_VERSION`: 3 → 10
- `MARKETING_VERSION`: 1.0 (unchanged)

Build 10 reflects significant UX improvements over TestFlight build 9.

## Content Policy

Visible copy uses only:
- "Cutline" or "Cutline DNS" for branding
- "DNS" for technical references
- "Narge" only in GitHub repository link (under Advanced)

No mentions of prohibited terms. No instructions to disable Apple features.

## Testing Checklist

- [ ] Build succeeds on Xcode 15+ (macOS)
- [ ] Window sizes correctly (520×720 default, can resize to 480×640 minimum)
- [ ] Turn-on flow: save → open Settings → show screenshot → confirm
- [ ] Settings screenshot displays (after adding image files)
- [ ] Verification probes work (on succeeds, off fails)
- [ ] Private Relay detection works on macOS
- [ ] Auto-reload when returning from Settings
- [ ] Disable button removes configuration
- [ ] Advanced section expands/collapses
- [ ] iOS/visionOS: text instructions instead of screenshot
- [ ] No stale state after app relaunch

## Migration Path

Users with old version installed:
1. Existing DNS configuration remains active
2. New UI reads current state correctly
3. Can disable and re-enable to test new flow
4. No data migration needed

## Future Enhancements

Possible additions (not in this PR):
- DNS query statistics in Advanced section
- Per-network DNS info on macOS
- Network reachability indicator
- Verification history log
- Manual refresh button when verification is stale

Keep Advanced section as home for power-user features.
