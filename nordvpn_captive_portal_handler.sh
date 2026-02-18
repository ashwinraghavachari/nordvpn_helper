#!/bin/bash

# NordVPN Captive Portal Handler for macOS
#
# Architecture (hybrid approach):
#   - NordVPN's auto-connect stays ON normally; NordVPN owns the connection
#     decision, including its own trusted networks list.
#   - On any network change, the script temporarily disables auto-connect and
#     disconnects VPN to prevent NordVPN from spin-looping on a captive portal.
#   - A canary ping to google.com detects when real internet is available
#     (i.e. captive portal has been authenticated or never existed).
#   - Once the canary passes, auto-connect is re-enabled and NordVPN reconnects
#     on its own, respecting its own trusted-network settings.
#   - On clean exit the script always re-enables auto-connect so NordVPN is
#     left in a normal state.
#
# Result: no separate trusted-networks file needed; NordVPN's built-in
# "Trusted Networks" setting works as expected.

# ─────────────────────────── Config ───────────────────────────

LOGFILE="$HOME/Library/Logs/nordvpn_captive_portal.log"

CHECK_INTERVAL=2          # seconds between canary checks while waiting
NETWORK_SETTLE_DELAY=2    # seconds to wait after a network change before pinging
CANARY_HOST="google.com"  # host used to detect real internet connectivity
NORDVPN_PLIST="$HOME/Library/Preferences/com.nordvpn.macos.plist"

# ─────────────────────────── States ───────────────────────────

STATE_NO_NETWORK="no_network"  # no active network interface
STATE_PAUSED="paused"          # auto-connect temporarily off; waiting for internet
STATE_ACTIVE="active"          # internet confirmed; auto-connect re-enabled; NordVPN owns VPN

# ─────────────────────────── Logging ──────────────────────────

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" | tee -a "$LOGFILE"
}

# ──────────────────────── NordVPN checks ──────────────────────

nordvpn_installed() {
    [ -d "/Applications/NordVPN.app" ]
}

nordvpn_running() {
    pgrep -f "NordVPN.app" > /dev/null 2>&1
}

ensure_nordvpn_running() {
    if ! nordvpn_running; then
        log "INFO" "NordVPN not running - launching..."
        open -a NordVPN 2>/dev/null
        sleep 3
    fi
}

# ──────────────────── Auto-connect management ──────────────────
# These write directly to NordVPN's preferences plist.
# The running app picks up the change immediately on reconnect.

disable_autoconnect() {
    if defaults write "$NORDVPN_PLIST" isAutoConnectOn -bool false 2>/dev/null; then
        log "INFO" "NordVPN auto-connect temporarily disabled"
    else
        log "WARN" "Could not disable NordVPN auto-connect"
    fi
}

enable_autoconnect() {
    if defaults write "$NORDVPN_PLIST" isAutoConnectOn -bool true 2>/dev/null; then
        log "INFO" "NordVPN auto-connect re-enabled - NordVPN will reconnect"
    else
        log "WARN" "Could not re-enable NordVPN auto-connect"
    fi
}

# ─────────────────────── VPN connect/disconnect ────────────────

vpn_disconnect() {
    if ! nordvpn_installed; then
        return 1
    fi
    ensure_nordvpn_running
    log "INFO" "Disconnecting VPN..."
    osascript -e 'open location "nordvpn://disconnect"' 2>/dev/null
    sleep 1
}

# ─────────────────────── Network helpers ──────────────────────

get_ssid() {
    /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I 2>/dev/null \
        | awk '/ SSID:/ {print $2}'
}

has_network_interface() {
    route get default 2>/dev/null | grep -q "interface:"
}

canary_reachable() {
    ping -c 1 -W 2 "$CANARY_HOST" > /dev/null 2>&1
}

# ──────────────────────── Pause helpers ───────────────────────

# Called whenever a network change is detected or no internet is found after
# connecting to a new network.  Temporarily prevents NordVPN from
# auto-connecting so it doesn't spin against a captive portal.
pause_vpn() {
    disable_autoconnect
    vpn_disconnect
}

# Called once the canary confirms real internet.  Hands control back to
# NordVPN so it can apply its own auto-connect / trusted-network logic.
resume_vpn() {
    enable_autoconnect
    log "INFO" "Handing VPN control back to NordVPN"
}

# ─────────────────────────── Main loop ────────────────────────

main_loop() {
    log "INFO" "NordVPN Captive Portal Handler started (hybrid mode)"

    if ! nordvpn_installed; then
        log "WARN" "NordVPN not installed at /Applications/NordVPN.app"
        log "WARN" "Script will monitor network but skip VPN management"
    else
        log "INFO" "NordVPN detected - auto-connect stays ON; will pause only during captive portals"
    fi

    local state
    local last_ssid=""

    # ── Determine initial state ────────────────────────────────
    if ! has_network_interface; then
        state="$STATE_NO_NETWORK"
        log "INFO" "Starting in state: no_network"
    elif canary_reachable; then
        # Already on a working network - don't disturb the VPN
        state="$STATE_ACTIVE"
        log "INFO" "Starting in state: active (internet already reachable)"
    else
        # Network present but no internet - captive portal likely
        log "INFO" "Captive portal suspected on startup - pausing VPN"
        pause_vpn
        state="$STATE_PAUSED"
        log "INFO" "Starting in state: paused"
    fi

    last_ssid=$(get_ssid)

    while true; do
        local ssid
        ssid=$(get_ssid)

        # ── Detect network change (SSID change or interface appearing) ──
        if [[ "$ssid" != "$last_ssid" ]]; then
            if [[ -n "$ssid" ]]; then
                log "INFO" "Network changed: '$last_ssid' → '$ssid' - pausing VPN"
            else
                log "INFO" "Network disconnected - pausing VPN"
            fi
            last_ssid="$ssid"
            pause_vpn
            state="$STATE_PAUSED"
            sleep "$NETWORK_SETTLE_DELAY"
            continue
        fi

        # ── State machine ──────────────────────────────────────
        case "$state" in

            "$STATE_NO_NETWORK")
                if has_network_interface; then
                    log "INFO" "Network interface appeared - pausing VPN while checking for captive portal"
                    pause_vpn
                    state="$STATE_PAUSED"
                fi
                ;;

            "$STATE_PAUSED")
                if ! has_network_interface; then
                    log "INFO" "Network lost"
                    state="$STATE_NO_NETWORK"

                elif canary_reachable; then
                    log "INFO" "Internet confirmed on '$ssid' - resuming NordVPN auto-connect"
                    resume_vpn
                    state="$STATE_ACTIVE"

                else
                    log "INFO" "Waiting for internet on '$ssid' (captive portal?)..."
                fi
                ;;

            "$STATE_ACTIVE")
                # NordVPN owns the VPN; we just watch for network loss
                if ! has_network_interface; then
                    log "INFO" "Network lost - pausing VPN"
                    pause_vpn
                    state="$STATE_NO_NETWORK"
                fi
                ;;

        esac

        sleep "$CHECK_INTERVAL"
    done
}

# ─────────────────────────── Cleanup ──────────────────────────

# Always re-enable auto-connect on exit so NordVPN is left in a normal state
cleanup() {
    log "INFO" "Script stopping - re-enabling NordVPN auto-connect"
    enable_autoconnect
    exit 0
}
trap cleanup SIGTERM SIGINT

main_loop
