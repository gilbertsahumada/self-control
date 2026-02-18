# BlockSites

A native macOS SwiftUI app to block websites for a set duration. Once activated, **there is no way to undo it** until the timer expires.

## Installation

```bash
# Build
swift build -c release

# Install binaries
sudo cp .build/release/BlockSitesApp /usr/local/bin/blocksites
sudo cp .build/release/BlockSitesEnforcer /usr/local/bin/blocksites-enforcer

# Set execute permissions
sudo chmod +x /usr/local/bin/blocksites
sudo chmod +x /usr/local/bin/blocksites-enforcer
```

## Usage

```bash
# Launch the app
blocksites

# Or run directly from build
.build/debug/BlockSitesApp
```

The app opens a SwiftUI window with two states:

### Setup (no active block)

- Toggle popular sites (Instagram, Facebook, Twitter/X, YouTube, TikTok, Reddit)
- Add custom domains (comma-separated)
- Set duration with hours/minutes steppers
- Click "Start Blocking" and confirm — the native macOS password dialog appears once

### Active block

- Shows blocked sites with subdomain counts
- Live countdown timer (HH:MM:SS)
- Progress bar
- End time display

No `sudo` needed — the app requests admin privileges via the native macOS password dialog when starting a block.

## How it works

1. **Dual-layer blocking**: Modifies `/etc/hosts` AND configures firewall rules (`pf`)
2. **DNS-level**: Redirects sites to `127.0.0.1`
3. **Network-level**: Blocks site IPs at the firewall (prevents DoH/DNS over HTTPS bypass)
4. **Privilege escalation**: Uses `NSAppleScript` with `do shell script ... with administrator privileges` — one password prompt per block action
5. **Enforcer daemon**: Checks every minute that blocks are still active
6. **Auto-restore**: If you tamper with `/etc/hosts` or the firewall, it restores them automatically
7. **Full cleanup**: When the timer expires, everything is cleaned up — hosts, firewall rules, anchor references, cached IPs, and the daemon itself

## Warning

This tool is **intentionally difficult to bypass**. The only way to stop it early is:
- Reboot into Recovery Mode and modify system files
- Or just wait for the timer to expire

Use responsibly.
