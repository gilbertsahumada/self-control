# BlockSites

A native macOS SwiftUI app to block websites for a set duration. Once activated, **there is no way to undo it** until the timer expires.

Built with Swift 5.9+ and SwiftUI. Requires macOS 13 (Ventura) or later.

## Features

- **Dual-layer blocking** — DNS (`/etc/hosts`) + firewall (`pf`) for maximum effectiveness
- **Popular site presets** — One-click toggles for Instagram, Facebook, Twitter/X, YouTube, TikTok, Reddit
- **Custom domains** — Block any website by entering its domain
- **Subdomain coverage** — Automatically blocks www, mobile, CDN, API, and platform-specific subdomains
- **DNS-over-HTTPS protection** — Blocks known DoH providers to prevent browser bypass
- **CIDR range blocking** — Blocks entire IP ranges for major platforms at the firewall level
- **Enforcer daemon** — Re-applies blocks every 60 seconds if you tamper with system files
- **No sudo needed** — Uses the native macOS password dialog for privilege escalation
- **Full cleanup** — Everything is automatically restored when the timer expires

## Installation

### Build from source

```bash
git clone https://github.com/your-username/blocksites.git
cd blocksites
swift build -c release
```

### Install

```bash
sudo cp .build/release/BlockSitesApp /usr/local/bin/blocksites
sudo cp .build/release/BlockSitesEnforcer /usr/local/bin/blocksites-enforcer
sudo chmod +x /usr/local/bin/blocksites
sudo chmod +x /usr/local/bin/blocksites-enforcer
```

## Usage

```bash
blocksites
```

The app opens a native macOS window:

### Setup

1. Toggle popular sites or type custom domains (comma-separated)
2. Set the duration (hours and minutes)
3. Click **Start Blocking** and confirm
4. Enter your admin password once — done

### Active block

- Live countdown timer (HH:MM:SS)
- Progress bar
- Blocked sites list with subdomain counts
- End time display

## How it works

1. **DNS-level**: Redirects blocked domains to `127.0.0.1` via `/etc/hosts`
2. **Network-level**: Resolves domain IPs and creates `pf` firewall rules to block traffic
3. **DoH blocking**: Blocks DNS-over-HTTPS providers so browsers can't bypass `/etc/hosts`
4. **Privilege escalation**: Single `NSAppleScript` call with `do shell script ... with administrator privileges`
5. **Enforcer daemon**: LaunchDaemon that checks every 60 seconds and re-applies blocks if tampered with
6. **Auto-cleanup**: When the timer expires, the enforcer removes all hosts entries, firewall rules, config files, and unloads itself

## Architecture

```
Sources/
  BlockSitesCore/       # Shared library — domain expansion, hosts generation, models
  BlockSitesApp/        # SwiftUI macOS app — UI, view models, privilege escalation
  BlockSitesEnforcer/   # Background daemon — re-enforces blocks every 60s
```

## Warning

This tool is **intentionally difficult to bypass**. The only way to stop it early is:
- Reboot into Recovery Mode and modify system files
- Or just wait for the timer to expire

Use responsibly.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
