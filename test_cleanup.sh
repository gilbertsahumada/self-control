#!/bin/bash
# BlockSites Cleanup Verification Test
# Run AFTER the block timer has expired to verify full cleanup
#
# Usage: sudo ./test_cleanup.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

PASS=0
FAIL=0

pass() {
    echo -e "  ${GREEN}✓${RESET} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "  ${RED}✗${RESET} $1"
    FAIL=$((FAIL + 1))
}

section() {
    echo ""
    echo -e "${CYAN}${BOLD}[$1]${RESET}"
}

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This test must run as root: sudo ./test_cleanup.sh${RESET}"
    exit 1
fi

section "CLEANUP VERIFICATION"

# /etc/hosts
HOSTS_COUNT=$(grep -c "BLOCKSITES" /etc/hosts 2>/dev/null || echo "0")
if [ "$HOSTS_COUNT" -eq 0 ]; then
    pass "/etc/hosts is clean (no BLOCKSITES entries)"
else
    fail "/etc/hosts still has $HOSTS_COUNT BLOCKSITES entries"
fi

# pf anchor file
if [ ! -f "/etc/pf.anchors/com.blocksites" ]; then
    pass "Anchor file removed"
else
    fail "Anchor file still exists at /etc/pf.anchors/com.blocksites"
fi

# pf.conf
if grep -q "com.blocksites" /etc/pf.conf 2>/dev/null; then
    fail "pf.conf still contains blocksites anchor references"
else
    pass "pf.conf is clean (no anchor references)"
fi

# pf rules
PF_BLOCKSITES=$(pfctl -a "com.blocksites" -sr 2>/dev/null | wc -l | tr -d ' ')
if [ "$PF_BLOCKSITES" -eq 0 ]; then
    pass "No active pf rules in blocksites anchor"
else
    fail "Found $PF_BLOCKSITES residual pf rules in anchor"
fi

# Config file
if [ ! -f "/Library/Application Support/BlockSites/config.json" ]; then
    pass "config.json removed"
else
    fail "config.json still exists"
fi

# IP cache
if [ ! -f "/Library/Application Support/BlockSites/ip_cache.json" ]; then
    pass "ip_cache.json removed"
else
    fail "ip_cache.json still exists"
fi

# Hosts backup
if [ ! -f "/Library/Application Support/BlockSites/hosts.backup" ]; then
    pass "hosts.backup removed"
else
    fail "hosts.backup still exists"
fi

# Daemon plist
if [ ! -f "/Library/LaunchDaemons/com.blocksites.enforcer.plist" ]; then
    pass "Daemon plist removed"
else
    fail "Daemon plist still exists"
fi

# Daemon loaded
if launchctl list 2>/dev/null | grep -q "com.blocksites.enforcer"; then
    fail "Daemon is still loaded"
else
    pass "Daemon is not loaded"
fi

# --- Summary ---
section "RESULTS"
TOTAL=$((PASS + FAIL))
echo ""
echo -e "  ${GREEN}Passed: $PASS${RESET} / ${BOLD}$TOTAL${RESET}"
if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}Failed: $FAIL${RESET}"
fi
echo ""

exit $FAIL
