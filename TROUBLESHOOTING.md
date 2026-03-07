# Troubleshooting - SelfControl

## Sites still blocked after timer expired

If you can't access websites even after SelfControl's timer has ended, the cleanup didn't complete properly. Follow these steps:

### Quick Fix (run all commands)

```bash
# 1. Remove blocksites anchor lines from pf.conf
sudo sed -i '' '/# BlockSites anchor/d;/anchor "com.blocksites"/d;/load anchor "com.blocksites"/d' /etc/pf.conf

# 2. Disable pf firewall
sudo pfctl -d

# 3. Remove blocksites entries from /etc/hosts (if any remain)
sudo sed -i '' '/# BLOCKSITES/d' /etc/hosts

# 4. Flush DNS cache
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder

# 5. Clean up residual files
sudo rm -rf "/Library/Application Support/BlockSites/"

# 6. Remove anchor file (if it still exists)
sudo rm -f /etc/pf.anchors/com.blocksites

# 7. Unload daemon (if still running)
sudo launchctl unload /Library/LaunchDaemons/com.blocksites.enforcer.plist 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.blocksites.enforcer.plist
```

### Diagnosing the issue

Run these to check what's still active:

```bash
# Check if pf.conf still references blocksites
grep -i blocksites /etc/pf.conf

# Check if /etc/hosts has leftover entries
grep -i BLOCKSITES /etc/hosts

# Check if the daemon is still loaded
launchctl list | grep -i block

# Check if pf firewall is enabled
sudo pfctl -s info | head -5

# Check residual files
ls -la "/Library/Application Support/BlockSites/" 2>/dev/null

# Check if anchor file exists
ls -la /etc/pf.anchors/com.blocksites 2>/dev/null
```

### Common causes

1. **pf.conf has anchor references but anchor file was deleted** - pf fails to load rules properly, which can disrupt network traffic. Fix: remove the anchor lines from `/etc/pf.conf` and disable pf.

2. **DNS cache not flushed** - Even after removing `/etc/hosts` entries, macOS caches DNS. Fix: flush with `dscacheutil -flushcache && killall -HUP mDNSResponder`.

3. **Enforcer daemon still running** - The daemon re-applies blocks every 60 seconds. Fix: unload with `launchctl unload`.

4. **Residual files in /Library/Application Support/BlockSites/** - Config, IP cache, and backup files can persist. Safe to delete after block expires.

### Nuclear option (full reset)

If nothing else works, run this single script:

```bash
sudo bash -c '
  # Remove all blocksites entries from hosts
  sed -i "" "/# BLOCKSITES/d" /etc/hosts

  # Clean pf.conf
  sed -i "" "/# BlockSites anchor/d;/anchor \"com.blocksites\"/d;/load anchor \"com.blocksites\"/d" /etc/pf.conf

  # Disable firewall
  pfctl -d 2>/dev/null

  # Remove anchor
  rm -f /etc/pf.anchors/com.blocksites

  # Flush DNS
  dscacheutil -flushcache
  killall -HUP mDNSResponder

  # Remove all app data
  rm -rf "/Library/Application Support/BlockSites/"

  # Unload and remove daemon
  launchctl unload /Library/LaunchDaemons/com.blocksites.enforcer.plist 2>/dev/null
  rm -f /Library/LaunchDaemons/com.blocksites.enforcer.plist

  echo "Full cleanup complete. Restart your browser."
'
```

After running any fix, **restart your browser** to clear its internal DNS/connection cache.
