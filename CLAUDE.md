# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SelfControl is a native macOS SwiftUI app (Swift 5.9+, macOS 13+) that blocks websites for a set duration with no way to undo until the timer expires. It uses dual-layer blocking (DNS via `/etc/hosts` + firewall via macOS `pf`) and a background daemon that re-enforces blocks every 60 seconds. The app uses `NSAppleScript` for privilege escalation via the native macOS password dialog.

## Build & Run

```bash
swift build                    # Debug build
swift build -c release         # Release build
swift test                     # Run tests

# Install after building
sudo cp .build/release/SelfControl /usr/local/bin/selfcontrol
sudo cp .build/release/SelfControlEnforcer /usr/local/bin/selfcontrol-enforcer

# Run (no sudo needed — app requests admin privileges via password dialog)
.build/debug/SelfControl
```

## Architecture

Three targets in `Sources/`:

- **BlockSitesCore/** (now SelfControlCore) — Shared library with pure business logic.
  - `BlockConfiguration.swift` — Codable data model (sites, startTime, endTime).
  - `DomainExpander.swift` — Domain expansion (subdomains, CIDR ranges, DoH blocking).
  - `DomainValidator.swift` — Domain validation for security.
  - `HostsGenerator.swift` — Generates/cleans `/etc/hosts` entries.
  - `TimeFormatter.swift` — Duration formatting utilities.

- **BlockSitesApp/** (now SelfControl) — SwiftUI macOS app.
  - `BlockSitesApp.swift` → `SelfControlApp.swift` — `@main` SwiftUI App entry point.
  - `ContentView.swift` — Switches between SetupView and ActiveBlockView.
  - `Views/SetupView.swift` — Site toggles, custom domain field, duration picker.
  - `Views/ActiveBlockView.swift` — Countdown timer, progress bar, blocked sites list.
  - `ViewModels/BlockViewModel.swift` — All state + blocking logic.
  - `Services/PrivilegedExecutor.swift` — `NSAppleScript` admin privilege escalation.
  - `Services/FirewallManager.swift` — IP resolution + pf rule generation.

- **BlockSitesEnforcer/** (now SelfControlEnforcer) — Background daemon.
  - `main.swift` — Enforcement logic with hash-based change detection.
  - `ProcessHelper.swift` — Shared `runCommand()` helper.
  - `FirewallManager.swift` — Firewall rule management with pf cleanup.

### Blocking flow

1. User selects sites + duration in the UI, clicks "Start Blocking", confirms
2. App generates all file contents in memory (hosts entries, pf rules, config JSON, IP cache, daemon plist)
3. App writes these to temp files (no root needed)
4. App builds a single shell script for privileged execution
5. `PrivilegedExecutor` runs the script via `NSAppleScript` — one password prompt
6. Temp files cleaned up
7. UI switches to active block countdown

### Blocking mechanism

1. DNS-level: writes `127.0.0.1` entries to `/etc/hosts` (marked with `# BLOCKSITES`)
2. Network-level: resolves domain IPs and creates pf firewall anchor rules at `/etc/pf.anchors/com.blocksites`
3. Covers subdomains automatically (www, mobile, m, api, cdn, etc.)

### Cleanup on expiry

The enforcer performs full cleanup when the timer expires:
- Removes BLOCKSITES entries from `/etc/hosts` and flushes DNS cache
- Removes pf anchor file and cleans anchor references from `/etc/pf.conf`
- **Disables pf** (`pfctl -d`) to restore normal network performance
- Deletes config files, IP cache, hosts backup
- Unloads and deletes the LaunchDaemon plist

### Key file paths used at runtime

- `/Library/Application Support/BlockSites/config.json` — active block configuration
- `/Library/Application Support/BlockSites/ip_cache.json` — resolved IP cache
- `/Library/Application Support/BlockSites/hosts.backup` — hosts file backup
- `/Library/Application Support/BlockSites/enforcer.log` — daemon logs
- `/etc/pf.anchors/com.blocksites` — firewall anchor rules
- `/Library/LaunchDaemons/com.blocksites.enforcer.plist` — daemon config

### Code patterns

- `ObservableObject` + `@Published` + `@StateObject`/`@EnvironmentObject` for macOS 13 compatibility
- `PrivilegedExecutor` uses `NSAppleScript` for admin privilege escalation
- Async/await with TaskGroup for parallel DNS resolution
- Adaptive timer (1s/<1hr, 10s/<1hr, 60s/>1hr)
- Hash-based change detection in enforcer to minimize system impact

## Distribution

```bash
# Build DMG installer
./scripts/build_dmg.sh

# Output:
# - dist/SelfControl.app
# - dist/SelfControl-1.0.0.dmg
```
