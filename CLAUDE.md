# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BlockSites is a macOS CLI tool (Swift 5.9+, macOS 13+) that blocks websites for a set duration with no way to undo until the timer expires. It uses dual-layer blocking (DNS via `/etc/hosts` + firewall via macOS `pf`) and a background daemon that re-enforces blocks every 60 seconds. Includes an interactive TUI mode and a live countdown status display.

## Build & Run

```bash
swift build                    # Debug build
swift build -c release         # Release build

# Install after building
sudo cp .build/release/BlockSites /usr/local/bin/blocksites
sudo cp .build/release/BlockSitesEnforcer /usr/local/bin/blocksites-enforcer

# Usage (requires root)
sudo blocksites                                        # Interactive TUI mode
sudo blocksites --hours 2 --sites facebook.com,twitter.com
sudo blocksites --minutes 30 --sites instagram.com
blocksites --status                                    # Live countdown
```

No test suite or linter is configured.

## Architecture

Two executable targets in `Sources/`:

- **BlockSites/** — Main CLI with interactive TUI.
  - `main.swift` — `BlockSites` command (argument-parser) with interactive mode, confirmation flow, and live status. Contains `BlockManager` (singleton) for blocking operations.
  - `TerminalUI.swift` — ANSI escape code utilities: colors, box-drawing (`┌─┐│└─┘├┤`), progress bar, cursor control, input helpers.
  - `FirewallManager.swift` — Manages pf anchor rules. Includes `removePfAnchor()` to clean anchor references from `/etc/pf.conf` on unblock.
  - `BlockConfiguration.swift` — Codable data model.

- **BlockSitesEnforcer/** — Background daemon launched via LaunchDaemon. Runs every 60 seconds to re-apply blocks if the user tampers with `/etc/hosts` or firewall rules. Auto-unloads itself when the timer expires.
  - `main.swift` — Enforcement logic (apply/remove blocks).
  - `ProcessHelper.swift` — Shared `runCommand()` helper with `waitUntilExit()`.
  - `FirewallManager.swift` — Simplified firewall manager for re-applying cached rules. Also cleans pf.conf anchors on removal.

### Blocking mechanism

1. DNS-level: writes `127.0.0.1` entries to `/etc/hosts` (marked with `# BLOCKSITES`)
2. Network-level: resolves domain IPs and creates pf firewall anchor rules at `/etc/pf.anchors/com.blocksites`
3. Covers subdomains automatically (www, mobile, m, api, cdn, etc.) with special exhaustive handling for Twitter/X domains

### Cleanup on expiry

Both targets perform full cleanup when the timer expires:
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

- Singleton pattern: `BlockManager.shared`, `FirewallManager.shared`
- File-based JSON persistence using `Codable`
- Requires root (`getuid() == 0`) for all blocking operations
- Block/subdomain logic is duplicated between BlockSites and BlockSitesEnforcer targets — keep them in sync when modifying
- TUI uses raw ANSI escape codes (no external dependency) via `TerminalUI` enum
- All `Process` calls use `waitUntilExit()` — enforcer uses `ProcessHelper.runCommand()`, main target uses `BlockManager.runCommand()`
