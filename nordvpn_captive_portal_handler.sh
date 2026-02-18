#!/bin/bash

# NordVPN Captive Portal Handler for macOS
#
# Architecture:
# 1. On startup: disable NordVPN auto-connect so this script has full control
# 2. On network change: immediately disconnect VPN
# 3. Ping a canary host (google.com) to detect when real internet is available
# 4. Once canary responds: connect VPN (unless on a trusted network)
#
# Trusted networks: add SSIDs to ~/.nordvpn_trusted_networks (one per line)
# to skip VPN connection on those networks (e.g. home, office)

# ─────────────────────────── Config ───────────────────────────

LOGFILE="$HOME/Library/Logs/nordvpn_captive_portal.log"
TRUSTED_NETWORKS_FILE="$HOME/.nordvpn_trusted_networks"

CHECK_INTERVAL=2          # seconds between canary checks
NETWORK_SETTLE_DELAY=2    # seconds to wait after network change before pinging
CANARY_HOST="google.com"  # host to ping to detect real internet
NORDVPN_PLIST="$HOME/Library/Preferences/com.nordvpn.macos.plist"

# ─────────────────────────── States ───────────────────────────

STATE_NO_NETWORK="no_network"       # no network interface / WiFi
STATE_WAITING="waiting"             # connected to network, no internet yet
STATE_READY="internet_ready"        # internet confirmed, VPN connecting/connected
STATE_TRUSTED="trusted_network"     # on a trusted network, VPN intentionally off

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

disable_autoconnect() {
    # Write directly to NordVPN's preferences plist
    if defaults write "$NORDVPN_PLIST" isAutoConnectOn -bool false 2>/dev/null; then
        log "INFO" "NordVPN auto-connect disabled"
    else
        log "WARN" "Could not disable NordVPN auto-connect - disable it manually in NordVPN Settings"
    fi
}

enable_autoconnect() {
    if defaults write "$NORDVPN_PLIST" isAutoConnectOn -bool true 2>/dev/null; then
        log "INFO" "NordVPN auto-connect re-enabled"
    else
        log "WARN" "Could not re-enable NordVPN auto-connect"
    fi
}

# ─────────────────────── VPN connect/disconnect ────────────────

vpn_connect() {
    if ! nordvpn_installed; then
        log "WARN" "NordVPN not installed - skipping connect"
        return 1
    fi
    ensure_nordvpn_running
    log "INFO" "Connecting VPN..."
    osascript -e 'open location "nordvpn://connect"' 2>/dev/null
}

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
    # Returns true if there's an active default route
    route get default 2>/dev/null | grep -q "interface:"
}

# ─────────────────────── Canary ping ──────────────────────────

canary_reachable() {
    # Ping canary host once with a short timeout
    ping -c 1 -W 2 "$CANARY_HOST" > /dev/null 2>&1
}

# ──────────────────── Trusted network check ───────────────────

is_trusted_network() {
    local ssid="$1"
    [ -z "$ssid" ] && return 1
    [ ! -f "$TRUSTED_NETWORKS_FILE" ] && return 1
    grep -qxF "$ssid" "$TRUSTED_NETWORKS_FILE"
}

# ─────────────────────────── Main loop ────────────────────────

main_loop() {
    log "INFO" "NordVPN Captive Portal Handler started"

    if ! nordvpn_installed; then
        log "WARN" "NordVPN not installed at /Applications/NordVPN.app"
        log "WARN" "Script will monitor network but skip VPN management"
    else
        log "INFO" "NordVPN detected"
        # Disable auto-connect so this script has full control
        disable_autoconnect
        # Disconnect any existing VPN connection on startup
        vpn_disconnect
    fi

    local state="$STATE_NO_NETWORK"
    local last_ssid=""

    while true; do
        local ssid
        ssid=$(get_ssid)

        # ── Detect network change ──────────────────────────────
        if [[ "$ssid" != "$last_ssid" ]]; then
            if [[ -n "$ssid" ]]; then
                log "INFO" "Network changed → '$ssid'"
            fi
            last_ssid="$ssid"
            # Immediately disconnect VPN on any network change
            vpn_disconnect
            state="$STATE_WAITING"
            # Brief settle delay before we start pinging
            sleep "$NETWORK_SETTLE_DELAY"
            continue
        fi

        # ── State machine ──────────────────────────────────────
        case "$state" in

            "$STATE_NO_NETWORK")
                if has_network_interface; then
                    log "INFO" "Network interface appeared"
                    state="$STATE_WAITING"
                fi
                ;;

            "$STATE_WAITING")
                if ! has_network_interface; then
                    log "INFO" "Network lost"
                    state="$STATE_NO_NETWORK"

                elif canary_reachable; then
                    # Internet is available - captive portal is cleared
                    if is_trusted_network "$ssid"; then
                        log "INFO" "Trusted network '$ssid' - VPN will not connect"
                        state="$STATE_TRUSTED"
                    else
                        log "INFO" "Internet confirmed on '$ssid' - connecting VPN"
                        vpn_connect
                        state="$STATE_READY"
                    fi
                else
                    log "INFO" "Waiting for internet on '$ssid' (captive portal?)..."
                fi
                ;;

            "$STATE_READY")
                # Healthy state - just watch for network loss
                if ! has_network_interface; then
                    log "INFO" "Network lost - disconnecting VPN"
                    vpn_disconnect
                    state="$STATE_NO_NETWORK"
                fi
                ;;

            "$STATE_TRUSTED")
                # On a trusted network - no VPN, watch for network loss
                if ! has_network_interface; then
                    log "INFO" "Network lost"
                    state="$STATE_NO_NETWORK"
                fi
                ;;

        esac

        sleep "$CHECK_INTERVAL"
    done
}

# Re-enable auto-connect on clean exit so NordVPN is left in a normal state
cleanup() {
    log "INFO" "Script stopped - re-enabling NordVPN auto-connect"
    enable_autoconnect
    exit 0
}
trap cleanup SIGTERM SIGINT

main_loop
