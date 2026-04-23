#!/bin/bash
# Read-only smoke test for a local MonkMode install.
# This script NEVER modifies system state — it only reads files and reports.
#
# Exit 0: system is clean (no stale block state), or state is consistent with
#         an active block.
# Exit 1: stale state detected — e.g. /etc/hosts has MONKMODE entries but
#         there is no active block config, meaning cleanup failed.

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MARKER="# MONKMODE"
HOSTS="/etc/hosts"
PF_CONF="/etc/pf.conf"
PF_ANCHOR="/etc/pf.anchors/com.monkmode"
ENFORCER_BIN="/usr/local/bin/monkmode-enforcer"
ENFORCER_PLIST="/Library/LaunchDaemons/com.monkmode.enforcer.plist"
CLEANUP_PLIST="/Library/LaunchDaemons/com.monkmode.cleanup.plist"
CONFIG_FILE="/Library/Application Support/MonkMode/config.json"

STATUS=0

ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; STATUS=1; }
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }

echo "MonkMode smoke test (read-only)"
echo "=================================="

# 1. Enforcer binary
if [[ -x "$ENFORCER_BIN" ]]; then
    ok "Enforcer binary present and executable: $ENFORCER_BIN"
    HAS_ENFORCER=1
elif [[ -f "$ENFORCER_BIN" ]]; then
    warn "Enforcer binary exists but is not executable: $ENFORCER_BIN"
    HAS_ENFORCER=1
else
    warn "Enforcer binary not installed at $ENFORCER_BIN (first run of the app will install it)"
    HAS_ENFORCER=0
fi

# 2. Active config
if [[ -f "$CONFIG_FILE" ]]; then
    info "Active config present: $CONFIG_FILE"
    HAS_ACTIVE_CONFIG=1
else
    info "No active block config ($CONFIG_FILE not present)"
    HAS_ACTIVE_CONFIG=0
fi

# 3. /etc/hosts marker check
if [[ -r "$HOSTS" ]] && grep -q "$MARKER" "$HOSTS" 2>/dev/null; then
    if [[ $HAS_ACTIVE_CONFIG -eq 1 ]]; then
        ok "/etc/hosts contains $MARKER entries (consistent with active block)"
    else
        fail "/etc/hosts contains $MARKER entries but no active config — STALE STATE"
    fi
    HOSTS_HAS_MARKER=1
else
    if [[ $HAS_ACTIVE_CONFIG -eq 1 ]]; then
        warn "/etc/hosts has no $MARKER entries but an active config exists (enforcer may not have run yet)"
    else
        ok "/etc/hosts is clean of $MARKER entries"
    fi
    HOSTS_HAS_MARKER=0
fi

# 4. /etc/pf.conf anchor check
if [[ -r "$PF_CONF" ]] && grep -q "com.monkmode" "$PF_CONF" 2>/dev/null; then
    if [[ $HAS_ACTIVE_CONFIG -eq 1 ]]; then
        ok "/etc/pf.conf contains com.monkmode anchor (consistent with active block)"
    else
        fail "/etc/pf.conf contains com.monkmode anchor but no active config — STALE STATE"
    fi
else
    ok "/etc/pf.conf is clean of com.monkmode anchor"
fi

# 5. pf anchor file
if [[ -f "$PF_ANCHOR" ]]; then
    if [[ $HAS_ACTIVE_CONFIG -eq 1 ]]; then
        ok "PF anchor file present: $PF_ANCHOR"
    else
        warn "PF anchor file exists at $PF_ANCHOR but no active config (leftover file)"
    fi
else
    info "No PF anchor file at $PF_ANCHOR"
fi

# 6. Support dir permissions (see #24)
SUPPORT_DIR="/Library/Application Support/MonkMode"
check_mode() {
    local path="$1"
    local expected="$2"
    if [[ ! -e "$path" ]]; then
        return 0
    fi
    local mode
    mode=$(/usr/bin/stat -f "%Lp" "$path" 2>/dev/null)
    if [[ "$mode" == "$expected" ]]; then
        ok "$path mode is $mode (expected $expected)"
    else
        fail "$path mode is $mode, expected $expected"
    fi
}
if [[ -d "$SUPPORT_DIR" ]]; then
    check_mode "$SUPPORT_DIR" "755"
    # config.json + ip_cache.json must be world-readable (0644) so the
    # unprivileged app can check block state; root-only write protects
    # against tampering. See #24.
    check_mode "$SUPPORT_DIR/config.json" "644"
    check_mode "$SUPPORT_DIR/ip_cache.json" "644"
    check_mode "$SUPPORT_DIR/hosts.backup" "600"
fi

# 7. Launch daemon plists
report_plist() {
    local path="$1"
    local label="$2"
    if [[ -f "$path" ]]; then
        if [[ $HAS_ACTIVE_CONFIG -eq 1 ]]; then
            ok "$label plist present: $path"
        else
            warn "$label plist present at $path but no active config"
        fi
    else
        info "$label plist not present: $path"
    fi
}

report_plist "$ENFORCER_PLIST" "Enforcer daemon"
report_plist "$CLEANUP_PLIST"  "Cleanup daemon"

# Summary
echo ""
echo "Summary"
echo "-------"
if [[ $STATUS -eq 0 ]]; then
    if [[ $HAS_ACTIVE_CONFIG -eq 1 ]]; then
        echo -e "${GREEN}State is consistent with an active block.${NC}"
    else
        echo -e "${GREEN}System is clean. No stale MonkMode state detected.${NC}"
    fi
else
    echo -e "${RED}Stale state detected. Launch MonkMode and use 'Clean up leftover block' to recover,${NC}"
    echo -e "${RED}or manually inspect the failing paths above.${NC}"
fi

exit $STATUS
