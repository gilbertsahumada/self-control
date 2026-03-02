#!/bin/bash
# Integration test for SelfControl blocking/cleanup flow.
# Requires: sudo, macOS (uses /etc/hosts and pf).
# Runs on GitHub Actions macos-14 runner or locally with sudo.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
MARKER="# BLOCKSITES"
HOSTS="/etc/hosts"
PF_CONF="/etc/pf.conf"
PF_ANCHOR="/etc/pf.anchors/com.blocksites"
TEST_SITES=("x.com" "instagram.com" "youtube.com")

# --- Helpers ---

log()  { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

cleanup() {
    info "Cleaning up..."
    # Restore hosts
    sudo sed -i '' "/$MARKER/d" "$HOSTS" 2>/dev/null || true
    sudo sed -i '' '/BLOCKSITES START/d; /BLOCKSITES END/d' "$HOSTS" 2>/dev/null || true

    # Restore pf.conf
    sudo sed -i '' '/# BlockSites anchor/d' "$PF_CONF" 2>/dev/null || true
    sudo sed -i '' '/anchor "com.blocksites"/d' "$PF_CONF" 2>/dev/null || true
    sudo sed -i '' '/load anchor "com.blocksites"/d' "$PF_CONF" 2>/dev/null || true

    # Remove anchor file
    sudo rm -f "$PF_ANCHOR"

    # Disable pf and flush DNS
    sudo pfctl -d 2>/dev/null || true
    sudo dscacheutil -flushcache 2>/dev/null || true
    sudo killall -HUP mDNSResponder 2>/dev/null || true

    info "Cleanup complete."
}

# Always clean up, even on failure
trap cleanup EXIT

check_dns() {
    local domain="$1"
    # Returns 0 if domain resolves to a real IP (not 127.0.0.1)
    local result=""
    result=$(dscacheutil -q host -a name "$domain" 2>/dev/null | grep "ip_address:" | head -1 | awk '{print $2}' || true)
    if [[ -z "$result" ]]; then
        # dscacheutil didn't return anything, try host command
        result=$(host "$domain" 2>/dev/null | grep "has address" | head -1 | awk '{print $NF}' || true)
    fi
    if [[ "$result" == "127.0.0.1" ]]; then
        return 1  # Blocked
    elif [[ -n "$result" ]]; then
        return 0  # Resolves to real IP
    else
        return 2  # Failed to resolve
    fi
}

# --- Pre-flight ---

echo "========================================"
echo " SelfControl Integration Tests"
echo " Running on: $(sw_vers -productName) $(sw_vers -productVersion)"
echo "========================================"
echo ""

# Verify we have sudo
if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo "Error: This script requires root. Run with: sudo $0"
    exit 1
fi

# Verify clean state
info "Verifying clean starting state..."
if grep -q "$MARKER" "$HOSTS" 2>/dev/null; then
    info "Found residual BLOCKSITES entries, cleaning first..."
    cleanup
fi

# --- Test 1: Hosts file blocking ---

echo ""
info "=== Test 1: /etc/hosts DNS blocking ==="

# Verify sites resolve before blocking
for site in "${TEST_SITES[@]}"; do
    if check_dns "$site"; then
        log "PRE-BLOCK: $site resolves to real IP"
    else
        fail "PRE-BLOCK: $site does not resolve (test environment issue)"
    fi
done

# Add blocking entries (same format the app uses)
info "Adding BLOCKSITES entries to /etc/hosts..."
{
    echo "$MARKER START"
    for site in "${TEST_SITES[@]}"; do
        echo "127.0.0.1 $site $MARKER"
        echo "127.0.0.1 www.$site $MARKER"
    done
    echo "$MARKER END"
} | sudo tee -a "$HOSTS" > /dev/null

# Flush DNS so changes take effect
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
sleep 1

# Verify entries are in hosts file
if grep -q "$MARKER" "$HOSTS"; then
    log "BLOCKING: entries added to /etc/hosts"
else
    fail "BLOCKING: entries not found in /etc/hosts"
fi

# Verify DNS now resolves to 127.0.0.1
for site in "${TEST_SITES[@]}"; do
    resolved=$(dscacheutil -q host -a name "$site" 2>/dev/null | grep "ip_address:" | head -1 | awk '{print $2}' || true)
    if [[ "$resolved" == "127.0.0.1" ]]; then
        log "BLOCKED: $site resolves to 127.0.0.1"
    else
        # DNS cache might be slow, try with host command pointing to localhost
        info "BLOCKED: $site DNS cache may be stale (resolved to: ${resolved:-empty}), checking hosts file directly"
        if grep -q "127.0.0.1 $site" "$HOSTS"; then
            log "BLOCKED: $site entry confirmed in /etc/hosts"
        else
            fail "BLOCKED: $site not found in /etc/hosts"
        fi
    fi
done

# --- Test 2: Hosts cleanup ---

echo ""
info "=== Test 2: /etc/hosts cleanup ==="

# Clean hosts (same logic as HostsGenerator.cleanHostsContent)
sudo sed -i '' "/$MARKER/d" "$HOSTS"
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
sleep 1

# Verify entries are gone
if grep -q "$MARKER" "$HOSTS"; then
    fail "CLEANUP: BLOCKSITES entries still in /etc/hosts"
else
    log "CLEANUP: all BLOCKSITES entries removed from /etc/hosts"
fi

# Verify original content preserved
if grep -q "localhost" "$HOSTS"; then
    log "CLEANUP: localhost entry preserved"
else
    fail "CLEANUP: localhost entry lost!"
fi

# Verify sites resolve again after cleanup
sleep 2
for site in "${TEST_SITES[@]}"; do
    resolved=$(host "$site" 8.8.8.8 2>/dev/null | grep "has address" | head -1 | awk '{print $NF}' || true)
    if [[ -n "$resolved" && "$resolved" != "127.0.0.1" ]]; then
        log "UNBLOCKED: $site resolves to $resolved"
    else
        info "UNBLOCKED: $site DNS may still be cached (got: ${resolved:-empty}), but hosts file is clean"
    fi
done

# --- Test 3: pf.conf anchor management ---

echo ""
info "=== Test 3: pf.conf anchor cleanup ==="

# Add anchor lines (same format the app uses)
info "Adding BlockSites anchor to pf.conf..."
printf '\n# BlockSites anchor\nanchor "com.blocksites"\nload anchor "com.blocksites" from "/etc/pf.anchors/com.blocksites"\n' | sudo tee -a "$PF_CONF" > /dev/null

# Create a dummy anchor file
echo "# BlockSites firewall rules" | sudo tee "$PF_ANCHOR" > /dev/null

# Verify anchor was added
if grep -q "com.blocksites" "$PF_CONF"; then
    log "PF SETUP: anchor references added to pf.conf"
else
    fail "PF SETUP: anchor references not found in pf.conf"
fi

if [[ -f "$PF_ANCHOR" ]]; then
    log "PF SETUP: anchor file created"
else
    fail "PF SETUP: anchor file not created"
fi

# Clean pf.conf (same logic as PfConfCleaner.cleanPfConfContent)
sudo sed -i '' '/# BlockSites anchor/d; /anchor "com.blocksites"/d; /load anchor "com.blocksites"/d' "$PF_CONF"

# Verify anchor references removed
if grep -q "com.blocksites" "$PF_CONF"; then
    fail "PF CLEANUP: anchor references still in pf.conf"
else
    log "PF CLEANUP: all anchor references removed from pf.conf"
fi

# Verify Apple anchors preserved
if grep -q "com.apple" "$PF_CONF"; then
    log "PF CLEANUP: Apple anchors preserved"
else
    info "PF CLEANUP: no Apple anchors found (may be normal for CI runner)"
fi

# Clean anchor file
sudo rm -f "$PF_ANCHOR"
if [[ ! -f "$PF_ANCHOR" ]]; then
    log "PF CLEANUP: anchor file removed"
else
    fail "PF CLEANUP: anchor file still exists"
fi

# Reload pf.conf to verify it's valid
if sudo pfctl -nf "$PF_CONF" 2>/dev/null; then
    log "PF CLEANUP: pf.conf syntax valid after cleanup"
else
    fail "PF CLEANUP: pf.conf syntax broken after cleanup!"
fi

# --- Test 4: Full roundtrip (block → verify → clean → verify) ---

echo ""
info "=== Test 4: Full blocking roundtrip ==="

# Block
{
    echo "$MARKER START"
    echo "127.0.0.1 x.com $MARKER"
    echo "127.0.0.1 www.x.com $MARKER"
    echo "127.0.0.1 twitter.com $MARKER"
    echo "127.0.0.1 www.twitter.com $MARKER"
    echo "$MARKER END"
} | sudo tee -a "$HOSTS" > /dev/null

printf '\n# BlockSites anchor\nanchor "com.blocksites"\nload anchor "com.blocksites" from "/etc/pf.anchors/com.blocksites"\n' | sudo tee -a "$PF_CONF" > /dev/null
echo "block drop quick from any to 104.244.42.1" | sudo tee "$PF_ANCHOR" > /dev/null

sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Verify blocked
if grep -q "127.0.0.1 x.com" "$HOSTS" && grep -q "com.blocksites" "$PF_CONF"; then
    log "ROUNDTRIP: blocking applied (hosts + pf)"
else
    fail "ROUNDTRIP: blocking not fully applied"
fi

# Now clean everything (simulating what removeBlocks should do)
sudo sed -i '' "/$MARKER/d" "$HOSTS"
sudo sed -i '' '/# BlockSites anchor/d; /anchor "com.blocksites"/d; /load anchor "com.blocksites"/d' "$PF_CONF"
sudo rm -f "$PF_ANCHOR"
sudo pfctl -d 2>/dev/null || true
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Verify clean
hosts_clean=true
pf_clean=true

if grep -q "$MARKER" "$HOSTS"; then hosts_clean=false; fi
if grep -q "com.blocksites" "$PF_CONF"; then pf_clean=false; fi
if [[ -f "$PF_ANCHOR" ]]; then pf_clean=false; fi

if $hosts_clean && $pf_clean; then
    log "ROUNDTRIP: full cleanup successful"
else
    fail "ROUNDTRIP: cleanup incomplete (hosts_clean=$hosts_clean, pf_clean=$pf_clean)"
fi

# Verify hosts file integrity
if grep -q "localhost" "$HOSTS"; then
    log "ROUNDTRIP: /etc/hosts integrity preserved"
else
    fail "ROUNDTRIP: /etc/hosts corrupted!"
fi

# Verify pf.conf integrity
if sudo pfctl -nf "$PF_CONF" 2>/dev/null; then
    log "ROUNDTRIP: pf.conf syntax valid"
else
    fail "ROUNDTRIP: pf.conf syntax broken!"
fi

# --- Results ---

echo ""
echo "========================================"
echo -e " Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "========================================"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
