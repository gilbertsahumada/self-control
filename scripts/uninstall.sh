#!/bin/bash
# MonkMode uninstaller.
#
# Removes every file, daemon, and system modification the app installs.
# Safe to re-run. Requires sudo because it touches /etc, /Library/LaunchDaemons,
# and /usr/local/bin.
#
# Usage:
#   sudo ./uninstall.sh                 # normal uninstall, keeps /Applications/MonkMode.app
#   sudo ./uninstall.sh --delete-app    # also removes /Applications/MonkMode.app

set -u
DELETE_APP=0
if [ "${1:-}" = "--delete-app" ]; then
  DELETE_APP=1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "error: run with sudo (needs root to touch /etc and /Library/LaunchDaemons)" >&2
  exit 1
fi

log() { echo "[uninstall] $*"; }

SUPPORT_DIR="/Library/Application Support/MonkMode"
LEGACY_SUPPORT_DIRS=(
  "/Library/Application Support/BlockSites"
  "/Library/Application Support/SelfControl"
)

DAEMON_LABELS=(
  com.monkmode.enforcer
  com.monkmode.cleanup
  com.blocksites.enforcer
  com.blocksites.cleanup
  com.selfcontrol.enforcer
  com.selfcontrol.cleanup
)

DAEMON_PLISTS=(
  /Library/LaunchDaemons/com.monkmode.enforcer.plist
  /Library/LaunchDaemons/com.monkmode.cleanup.plist
  /Library/LaunchDaemons/com.blocksites.enforcer.plist
  /Library/LaunchDaemons/com.blocksites.cleanup.plist
  /Library/LaunchDaemons/com.selfcontrol.enforcer.plist
  /Library/LaunchDaemons/com.selfcontrol.cleanup.plist
)

ENFORCER_BINARIES=(
  /usr/local/bin/monkmode-enforcer
  /usr/local/bin/monkmode
  /usr/local/bin/selfcontrol-enforcer
  /usr/local/bin/selfcontrol
  /usr/local/bin/blocksites-enforcer
  /usr/local/bin/blocksites
)

PF_ANCHORS=(
  /etc/pf.anchors/com.monkmode
  /etc/pf.anchors/com.blocksites
  /etc/pf.anchors/com.selfcontrol
)

log "1/6 — stopping LaunchDaemons"
for label in "${DAEMON_LABELS[@]}"; do
  /bin/launchctl unload -w "/Library/LaunchDaemons/${label}.plist" >/dev/null 2>&1 || true
  /bin/launchctl remove "${label}" >/dev/null 2>&1 || true
done
for plist in "${DAEMON_PLISTS[@]}"; do
  [ -e "$plist" ] && rm -f "$plist" && log "    removed $plist"
done

log "2/6 — cleaning /etc/hosts"
for marker in "# MONKMODE" "# BLOCKSITES" "# SELFCONTROL"; do
  if grep -q "$marker" /etc/hosts 2>/dev/null; then
    sed -i '' "/$marker/d" /etc/hosts
    log "    stripped '$marker' entries"
  fi
done

log "3/6 — cleaning /etc/pf.conf and pf anchors"
for anchor_name in "com.monkmode" "com.blocksites" "com.selfcontrol"; do
  if grep -q "\"$anchor_name\"" /etc/pf.conf 2>/dev/null; then
    sed -i '' "/$anchor_name/d" /etc/pf.conf
    log "    stripped '$anchor_name' anchor lines from pf.conf"
  fi
done
/sbin/pfctl -d >/dev/null 2>&1 || true
/sbin/pfctl -f /etc/pf.conf >/dev/null 2>&1 || true
for anchor in "${PF_ANCHORS[@]}"; do
  [ -e "$anchor" ] && rm -f "$anchor" && log "    removed $anchor"
done

log "4/6 — removing installed enforcer binaries"
for bin in "${ENFORCER_BINARIES[@]}"; do
  [ -e "$bin" ] && rm -f "$bin" && log "    removed $bin"
done

log "5/6 — removing application support directories"
for dir in "$SUPPORT_DIR" "${LEGACY_SUPPORT_DIRS[@]}"; do
  [ -d "$dir" ] && rm -rf "$dir" && log "    removed $dir"
done

log "6/6 — flushing DNS cache"
/usr/bin/dscacheutil -flushcache >/dev/null 2>&1 || true
/usr/bin/killall -HUP mDNSResponder >/dev/null 2>&1 || true

if [ "$DELETE_APP" -eq 1 ]; then
  for app in /Applications/MonkMode.app /Applications/SelfControl.app; do
    [ -d "$app" ] && rm -rf "$app" && log "    removed $app"
  done
fi

log "done. MonkMode has been fully uninstalled."
if [ "$DELETE_APP" -eq 0 ] && [ -d /Applications/MonkMode.app ]; then
  log "note: /Applications/MonkMode.app was left in place. Pass --delete-app to remove it, or drag it to the Trash manually."
fi
