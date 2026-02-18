# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BlockSites is a macOS CLI tool (Swift 5.9+, macOS 13+) that blocks websites for a set duration with no way to undo until the timer expires. It uses dual-layer blocking (DNS via `/etc/hosts` + firewall via macOS `pf`) and a background daemon that re-enforces blocks every 60 seconds.

## Build & Run

```bash
swift build                    # Debug build
swift build -c release         # Release build

# Install after building
sudo cp .build/release/BlockSites /usr/local/bin/blocksites
sudo cp .build/release/BlockSitesEnforcer /usr/local/bin/blocksites-enforcer

# Usage (requires root)
sudo blocksites --hours 2 --sites facebook.com,twitter.com
sudo blocksites --minutes 30 --sites instagram.com
blocksites --status
```

No test suite or linter is configured.

## Architecture

Two executable targets in `Sources/`:

- **BlockSites/** — Main CLI. Uses `swift-argument-parser` for CLI flags (`--hours`, `--minutes`, `--sites`, `--status`). Entry point is `main.swift` which contains `BlockManager` (singleton). `FirewallManager` handles pf rules. `BlockConfiguration` is the Codable data model.

- **BlockSitesEnforcer/** — Background daemon launched via LaunchDaemon. Runs every 60 seconds to re-apply blocks if the user tampers with `/etc/hosts` or firewall rules. Auto-unloads itself when the timer expires.

### Blocking mechanism

1. DNS-level: writes `127.0.0.1` entries to `/etc/hosts` (marked with `# BLOCKSITES`)
2. Network-level: resolves domain IPs and creates pf firewall anchor rules at `/etc/pf.anchors/com.blocksites`
3. Covers subdomains automatically (www, mobile, m, api, cdn, etc.) with special exhaustive handling for Twitter/X domains

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
