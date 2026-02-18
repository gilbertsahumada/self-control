#!/bin/bash
# BlockSites E2E Test Script
# Requires: sudo, builds the project, blocks a site for 2 minutes, validates all layers
#
# Usage: sudo ./test_blocking.sh [site]
# Default site: instagram.com

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

SITE="${1:-instagram.com}"
BINARY=".build/debug/BlockSites"
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

# --- Pre-checks ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This test must run as root: sudo ./test_blocking.sh${RESET}"
    exit 1
fi

section "SETUP"
echo -e "  Test site: ${BOLD}${SITE}${RESET}"
echo -e "  Duration: ${BOLD}2 minutes${RESET}"

# Build
echo -e "  Building..."
swift build 2>&1 | tail -1
if [ -f "$BINARY" ]; then
    pass "Binary built"
else
    fail "Binary not found"
    exit 1
fi

# --- Capture baseline ---
section "BASELINE"

HOSTS_BEFORE=$(grep -c "BLOCKSITES" /etc/hosts 2>/dev/null || echo "0")
if [ "$HOSTS_BEFORE" -eq 0 ]; then
    pass "No existing BLOCKSITES entries in /etc/hosts"
else
    fail "Found $HOSTS_BEFORE pre-existing BLOCKSITES entries (dirty state)"
fi

# --- Activate block ---
section "ACTIVATING BLOCK"

# Use 'yes' to auto-confirm
echo "s" | $BINARY --minutes 2 --sites "$SITE" 2>&1 | while IFS= read -r line; do echo "  > $line"; done

sleep 2 # Let DNS flush settle

# --- Test Layer 1: /etc/hosts ---
section "LAYER 1: DNS (/etc/hosts)"

HOSTS_COUNT=$(grep -c "BLOCKSITES" /etc/hosts 2>/dev/null || echo "0")
if [ "$HOSTS_COUNT" -gt 0 ]; then
    pass "/etc/hosts has $HOSTS_COUNT BLOCKSITES entries"
else
    fail "No BLOCKSITES entries found in /etc/hosts"
fi

if grep -q "127.0.0.1 ${SITE}" /etc/hosts 2>/dev/null; then
    pass "${SITE} redirected to 127.0.0.1"
else
    fail "${SITE} NOT found in /etc/hosts"
fi

if grep -q "127.0.0.1 www.${SITE}" /etc/hosts 2>/dev/null; then
    pass "www.${SITE} redirected to 127.0.0.1"
else
    fail "www.${SITE} NOT found in /etc/hosts"
fi

# Check DNS resolution
DNS_RESULT=$(dscacheutil -q host -a name "$SITE" 2>/dev/null | grep "ip_address" | head -1 || echo "")
if echo "$DNS_RESULT" | grep -q "127.0.0.1"; then
    pass "DNS resolves ${SITE} -> 127.0.0.1"
else
    fail "DNS does NOT resolve ${SITE} to 127.0.0.1 (got: ${DNS_RESULT:-empty})"
fi

# --- Test Layer 2: Firewall (pf) ---
section "LAYER 2: FIREWALL (pf)"

if [ -f "/etc/pf.anchors/com.blocksites" ]; then
    RULE_COUNT=$(wc -l < /etc/pf.anchors/com.blocksites | tr -d ' ')
    pass "Anchor file exists ($RULE_COUNT lines)"
else
    fail "Anchor file /etc/pf.anchors/com.blocksites not found"
fi

if grep -q "anchor \"com.blocksites\"" /etc/pf.conf 2>/dev/null; then
    pass "Anchor registered in pf.conf"
else
    fail "Anchor NOT in pf.conf"
fi

PF_RULES=$(pfctl -sr 2>/dev/null | grep -c "block" || echo "0")
if [ "$PF_RULES" -gt 0 ]; then
    pass "pf has $PF_RULES active block rules"
else
    fail "No block rules found in pfctl -sr"
fi

# --- Test Layer 3: Config & Daemon ---
section "LAYER 3: CONFIG & DAEMON"

if [ -f "/Library/Application Support/BlockSites/config.json" ]; then
    pass "Config file exists"
else
    fail "Config file not found"
fi

if [ -f "/Library/Application Support/BlockSites/ip_cache.json" ]; then
    pass "IP cache file exists"
else
    fail "IP cache file not found"
fi

if [ -f "/Library/LaunchDaemons/com.blocksites.enforcer.plist" ]; then
    pass "Daemon plist exists"
else
    fail "Daemon plist not found"
fi

if launchctl list 2>/dev/null | grep -q "com.blocksites.enforcer"; then
    pass "Daemon is loaded"
else
    fail "Daemon is NOT loaded"
fi

# --- Test Layer 4: HTTP connectivity ---
section "LAYER 4: HTTP CONNECTIVITY"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "https://${SITE}" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "000" ] || [ "$HTTP_CODE" = "007" ]; then
    pass "HTTPS to ${SITE} is BLOCKED (connection failed)"
else
    fail "HTTPS to ${SITE} returned HTTP ${HTTP_CODE} (should be blocked!)"
fi

# --- Test status command ---
section "STATUS COMMAND"

STATUS_OUTPUT=$($BINARY --status 2>&1 | head -5)
if echo "$STATUS_OUTPUT" | grep -qi "activo\|ACTIVE\|bloqu"; then
    pass "--status shows active block"
else
    fail "--status output unexpected: $STATUS_OUTPUT"
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

# --- Cleanup instructions ---
echo -e "${YELLOW}${BOLD}NOTE:${RESET} Block is still active for ~2 minutes."
echo -e "  Run ${BOLD}$BINARY --status${RESET} to watch the countdown."
echo -e "  After expiry, run ${BOLD}sudo ./test_cleanup.sh${RESET} to verify cleanup."

exit $FAIL
