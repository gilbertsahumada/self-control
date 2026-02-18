# BlockSites

A minimalist macOS CLI tool to block websites for a set duration. Once activated, **there is no way to undo it** until the timer expires.

## Installation

```bash
# Build
swift build -c release

# Install binaries
sudo cp .build/release/BlockSites /usr/local/bin/blocksites
sudo cp .build/release/BlockSitesEnforcer /usr/local/bin/blocksites-enforcer

# Set execute permissions
sudo chmod +x /usr/local/bin/blocksites
sudo chmod +x /usr/local/bin/blocksites-enforcer
```

## Usage

### Interactive mode

```bash
sudo blocksites
```

Launches a TUI menu where you can block sites, view status, or exit.

### Block sites (CLI flags)

```bash
# By hours
sudo blocksites --hours 2 --sites facebook.com,twitter.com,instagram.com

# By minutes (useful for testing)
sudo blocksites --minutes 1 --sites facebook.com,twitter.com

# Combining hours and minutes
sudo blocksites --hours 1 --minutes 30 --sites facebook.com,twitter.com
```

This will block the specified sites for the given duration. **There is no way to unblock them early.**

### View status (live countdown)

```bash
blocksites --status
```

Shows which sites are blocked with a live countdown that updates every second, including a progress bar. Press `Ctrl+C` to exit the status view (the block remains active).

## How it works

1. **Dual-layer blocking**: Modifies `/etc/hosts` AND configures firewall rules (`pf`)
2. **DNS-level**: Redirects sites to `127.0.0.1`
3. **Network-level**: Blocks site IPs at the firewall (prevents DoH/DNS over HTTPS bypass)
4. **Enforcer daemon**: Checks every minute that blocks are still active
5. **Auto-restore**: If you tamper with `/etc/hosts` or the firewall, it restores them automatically
6. **Full cleanup**: When the timer expires, everything is cleaned up — hosts, firewall rules, anchor references, cached IPs, and the daemon itself

## Warning

This tool is **intentionally difficult to bypass**. The only way to stop it early is:
- Reboot into Recovery Mode and modify system files
- Or just wait for the timer to expire

Use responsibly.
