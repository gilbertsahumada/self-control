# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BlockSites is a native macOS SwiftUI app (Swift 5.9+, macOS 13+) that blocks websites for a set duration with no way to undo until the timer expires. It uses dual-layer blocking (DNS via `/etc/hosts` + firewall via macOS `pf`) and a background daemon that re-enforces blocks every 60 seconds. The app uses `NSAppleScript` for privilege escalation via the native macOS password dialog.

## Build & Run

```bash
swift build                    # Debug build
swift build -c release         # Release build
swift test                     # Run tests (50 tests in BlockSitesCore)

# Install after building
sudo cp .build/release/BlockSitesApp /usr/local/bin/blocksites
sudo cp .build/release/BlockSitesEnforcer /usr/local/bin/blocksites-enforcer

# Run (no sudo needed — app requests admin privileges via password dialog)
.build/debug/BlockSitesApp
```

## Architecture

Three targets in `Sources/`:

- **BlockSitesCore/** — Shared library with pure business logic.
  - `BlockConfiguration.swift` — Codable data model (sites, startTime, endTime).
  - `DomainExpander.swift` — Domain expansion (subdomains, CIDR ranges, DoH blocking).
  - `HostsGenerator.swift` — Generates/cleans `/etc/hosts` entries.
  - `TimeFormatter.swift` — Duration formatting utilities.

- **BlockSitesApp/** — SwiftUI macOS app (replaces the old CLI/TUI).
  - `BlockSitesApp.swift` — `@main` SwiftUI App entry point with `WindowGroup`.
  - `ContentView.swift` — Switches between SetupView and ActiveBlockView.
  - `Views/SetupView.swift` — Site toggles, custom domain field, duration picker, "Start Blocking" button.
  - `Views/ActiveBlockView.swift` — Countdown timer, progress bar, blocked sites list.
  - `ViewModels/BlockViewModel.swift` — All state + blocking logic. Generates file contents in memory, writes to temp files, builds a single shell script for privileged execution.
  - `Services/PrivilegedExecutor.swift` — `NSAppleScript` admin privilege escalation (one password prompt per action).
  - `Services/FirewallManager.swift` — IP resolution + pf rule generation (in-memory, no root needed). IPCache struct matches the enforcer's.
  - `Models/PopularSite.swift` — Predefined popular sites (Instagram, Facebook, Twitter/X, YouTube, TikTok, Reddit).

- **BlockSitesEnforcer/** — Background daemon launched via LaunchDaemon. Runs every 60 seconds to re-apply blocks if the user tampers with `/etc/hosts` or firewall rules. Auto-unloads itself when the timer expires.
  - `main.swift` — Enforcement logic (apply/remove blocks).
  - `ProcessHelper.swift` — Shared `runCommand()` helper with `waitUntilExit()`.
  - `FirewallManager.swift` — Simplified firewall manager for re-applying cached rules. Also cleans pf.conf anchors on removal.

### Blocking flow (SwiftUI app)

1. User selects sites + duration in the UI, clicks "Start Blocking", confirms
2. App generates all file contents in memory (hosts entries, pf rules, config JSON, IP cache, daemon plist)
3. App writes these to temp files (no root needed)
4. App builds a single shell script that copies temp files to system paths + runs pfctl + flushes DNS + loads daemon
5. `PrivilegedExecutor` runs the script via `NSAppleScript` — one password prompt
6. Temp files cleaned up
7. UI switches to active block countdown

### Blocking mechanism

1. DNS-level: writes `127.0.0.1` entries to `/etc/hosts` (marked with `# BLOCKSITES`)
2. Network-level: resolves domain IPs and creates pf firewall anchor rules at `/etc/pf.anchors/com.blocksites`
3. Covers subdomains automatically (www, mobile, m, api, cdn, etc.) with special exhaustive handling for Twitter/X domains

### Cleanup on expiry

The enforcer performs full cleanup when the timer expires:
- Removes BLOCKSITES entries from `/etc/hosts` and flushes DNS cache (including `mDNSResponder`)
- Removes pf anchor file and cleans anchor references from `/etc/pf.conf`
- Deletes `config.json`, `ip_cache.json`, `hosts.backup`
- Unloads and deletes the LaunchDaemon plist

### Key file paths used at runtime

- `/Library/Application Support/BlockSites/config.json` — active block configuration
- `/Library/Application Support/BlockSites/ip_cache.json` — resolved IP cache
- `/Library/Application Support/BlockSites/hosts.backup` — hosts file backup
- `/etc/pf.anchors/com.blocksites` — firewall anchor rules
- `/Library/LaunchDaemons/com.blocksites.enforcer.plist` — daemon config

### Code patterns

- `ObservableObject` + `@Published` + `@StateObject`/`@EnvironmentObject` for macOS 13 compatibility
- `PrivilegedExecutor` uses `NSAppleScript` for admin privilege escalation — no `sudo` or `getuid() == 0` checks in the app
- `FirewallManager` (app) generates data in memory; `FirewallManager` (enforcer) reads from cached files on disk
- IPCache struct must stay in sync between `Sources/BlockSitesApp/Services/FirewallManager.swift` and `Sources/BlockSitesEnforcer/FirewallManager.swift`
- DomainExpander logic lives in BlockSitesCore — shared by both app and enforcer
- All `Process` calls in enforcer use `waitUntilExit()` via `ProcessHelper.runCommand()`
