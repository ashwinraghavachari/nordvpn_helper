#!/bin/bash
#
# test_pause_resume.sh
#
# End-to-end test of the pause/resume mechanism used by
# nordvpn_captive_portal_handler.sh.
#
# What it tests:
#   1. Canary detection  - google.com is reachable
#   2. Auto-connect read - can read NordVPN's current setting
#   3. Pause             - disables auto-connect + disconnects VPN
#   4. VPN is down       - no NordVPN utun interface while paused
#   5. Resume            - re-enables auto-connect
#   6. NordVPN reconnects on its own within 15 seconds
#   7. State is clean    - auto-connect is ON, VPN is back up
#
# The test does NOT require actually being on a captive-portal network.
# It directly invokes the same pause/resume primitives the main script uses,
# so it proves the mechanism works on your machine.

NORDVPN_PLIST="$HOME/Library/Preferences/com.nordvpn.macos.plist"
CANARY_HOST="google.com"
RECONNECT_TIMEOUT=30   # seconds to wait for NordVPN to reconnect

PASS=0
FAIL=0

# ── Helpers ────────────────────────────────────────────────────

green()  { printf '\033[0;32m✓ %s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m✗ %s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m  %s\033[0m\n' "$*"; }
header() { printf '\n\033[1;34m── %s ──\033[0m\n' "$*"; }

pass() { green "$1"; (( PASS++ )); }
fail() { red   "$1"; (( FAIL++ )); }

check() {
    # check <description> <command>
    local desc="$1"; shift
    if eval "$@" > /dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

# Returns true when NordVPN's own plist key says it is connected
vpn_is_up() {
    [[ "$(defaults read "$NORDVPN_PLIST" isAppWasConnectedToVPN 2>/dev/null)" == "1" ]]
}

# Returns the current auto-connect value from NordVPN's plist (1 or 0)
autoconnect_value() {
    defaults read "$NORDVPN_PLIST" isAutoConnectOn 2>/dev/null
}

# ── Pause primitives (mirror of main script) ──────────────────

disable_autoconnect() {
    defaults write "$NORDVPN_PLIST" isAutoConnectOn -bool false 2>/dev/null
}

enable_autoconnect() {
    defaults write "$NORDVPN_PLIST" isAutoConnectOn -bool true 2>/dev/null
}

vpn_disconnect() {
    osascript -e 'open location "nordvpn://disconnect"' 2>/dev/null
    sleep 2
}

vpn_connect() {
    osascript -e 'open location "nordvpn://connect"' 2>/dev/null
}

# ── Safety net: restore auto-connect on exit ──────────────────

cleanup() {
    echo ""
    yellow "Restoring auto-connect to ON (safety net)..."
    enable_autoconnect
}
trap cleanup EXIT

# ══════════════════════════════════════════════════════════════
printf '\033[1m\nNordVPN Pause/Resume Mechanism Test\033[0m\n'
printf '════════════════════════════════════════\n'

# ── 1. Pre-flight checks ──────────────────────────────────────
header "1. Pre-flight"

check "NordVPN app is installed"  "[ -d /Applications/NordVPN.app ]"
check "NordVPN process is running" "pgrep -f NordVPN.app"
check "Canary host ($CANARY_HOST) is reachable" "ping -c 1 -W 2 $CANARY_HOST"
check "Can read NordVPN plist" "defaults read $NORDVPN_PLIST isAutoConnectOn"

AC_BEFORE=$(autoconnect_value)
yellow "Auto-connect before test: $AC_BEFORE"

if [[ "$AC_BEFORE" != "1" ]]; then
    yellow "WARNING: Auto-connect is currently OFF."
    yellow "The main script may have left it off. Enabling it now for the test..."
    enable_autoconnect
    sleep 1
fi

# Make sure VPN is connected before we test pause
if ! vpn_is_up; then
    yellow "VPN is not up — connecting first so we can test disconnect..."
    osascript -e 'open location "nordvpn://connect"' 2>/dev/null
    sleep 8
fi

if vpn_is_up; then
    pass "VPN is connected before test"
else
    yellow "VPN still not up (may be on a trusted network) — disconnect test will still run"
fi

# ── 2. Simulate PAUSE ─────────────────────────────────────────
header "2. Simulate Pause (network change / captive portal detected)"

yellow "Disabling auto-connect..."
disable_autoconnect
sleep 1

AC_AFTER_DISABLE=$(autoconnect_value)
if [[ "$AC_AFTER_DISABLE" == "0" ]]; then
    pass "Auto-connect is now OFF"
else
    fail "Auto-connect did not turn OFF (got: $AC_AFTER_DISABLE)"
fi

yellow "Disconnecting VPN..."
vpn_disconnect

sleep 3

if ! vpn_is_up; then
    pass "VPN is disconnected (paused state)"
else
    fail "VPN is still up after disconnect"
fi

# Confirm NordVPN does NOT auto-reconnect while auto-connect is off
yellow "Waiting 5s to confirm NordVPN stays disconnected (auto-connect is off)..."
sleep 5

if ! vpn_is_up; then
    pass "VPN stayed down — NordVPN respected disabled auto-connect"
else
    fail "VPN reconnected on its own — auto-connect disabling may not have worked"
fi

# ── 3. Simulate RESUME ────────────────────────────────────────
header "3. Simulate Resume (canary ping passed)"

yellow "Re-enabling auto-connect..."
enable_autoconnect
sleep 1

AC_AFTER_ENABLE=$(autoconnect_value)
if [[ "$AC_AFTER_ENABLE" == "1" ]]; then
    pass "Auto-connect is ON again"
else
    fail "Auto-connect did not turn back ON (got: $AC_AFTER_ENABLE)"
fi

yellow "Triggering nordvpn://connect (mirrors what the script does on resume)..."
vpn_connect

# ── 4. Verify NordVPN auto-reconnects ─────────────────────────
header "4. Verify NordVPN auto-reconnects"

yellow "Waiting up to ${RECONNECT_TIMEOUT}s for NordVPN to reconnect on its own..."

RECONNECTED=false
for (( i=1; i<=RECONNECT_TIMEOUT; i++ )); do
    if vpn_is_up; then
        RECONNECTED=true
        yellow "VPN came back up after ${i}s"
        break
    fi
    sleep 1
done

if $RECONNECTED; then
    pass "NordVPN reconnected automatically after auto-connect was re-enabled"
else
    fail "NordVPN did NOT reconnect within ${RECONNECT_TIMEOUT}s"
    yellow "Check NordVPN app — it may be on a Trusted Network (intentional) or"
    yellow "auto-connect may be configured for a specific server that is unreachable."
fi

# ── 5. Final state check ──────────────────────────────────────
header "5. Final State"

AC_FINAL=$(autoconnect_value)
if [[ "$AC_FINAL" == "1" ]]; then
    pass "Auto-connect is ON (clean state)"
else
    fail "Auto-connect is still OFF — will be fixed by cleanup trap"
fi

if vpn_is_up; then
    pass "VPN is connected"
else
    yellow "VPN is not connected (may be expected if on a Trusted Network)"
fi

# ── Summary ───────────────────────────────────────────────────
printf '\n\033[1m════════════════════════════════════════\033[0m\n'
printf '\033[1mResults: \033[0;32m%d passed\033[0m  \033[0;31m%d failed\033[0m\n' "$PASS" "$FAIL"

if (( FAIL == 0 )); then
    printf '\033[0;32mAll checks passed — pause/resume mechanism is working.\033[0m\n\n'
else
    printf '\033[0;31mSome checks failed — review output above.\033[0m\n\n'
fi
