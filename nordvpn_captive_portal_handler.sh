#!/bin/bash

# NordVPN Captive Portal Handler for macOS
#
# Architecture:
#   1. On startup: disable NordVPN auto-connect so this script has full control.
#   2. On network change: immediately disconnect VPN.
#   3. Ping a canary host (google.com) to detect when real internet is available.
#   4. Once the canary responds: connect VPN (unless the SSID is in the trusted
#      networks file, in which case leave VPN off).
#   5. On clean exit: re-enable auto-connect so NordVPN is left in a normal state.
#
# Why disable auto-connect permanently?
#   NordVPN caches the auto-connect setting in memory at startup.  Writing to
#   the plist while the app is running has no real-time effect, so the only
#   reliable way to prevent NordVPN from fighting the script is to disable
#   auto-connect before NordVPN's session begins (i.e. at script startup).
#
# Trusted networks: add SSIDs one per line to ~/.nordvpn_trusted_networks.
# Use `control.sh trust` / `control.sh untrust` for easy management.

# ─────────────────────────── Config ───────────────────────────

LOGFILE="$HOME/Library/Logs/nordvpn_captive_portal.log"
TRUSTED_NETWORKS_FILE="$HOME/.nordvpn_trusted_networks"

CHECK_INTERVAL=2          # seconds between canary checks while waiting
NETWORK_SETTLE_DELAY=2    # seconds to wait after a network change before pinging
CANARY_HOST="google.com"  # host to ping to detect real internet
NORDVPN_PLIST="$HOME/Library/Preferences/com.nordvpn.macos.plist"

# ─────────────────────────── States ───────────────────────────

STATE_NO_NETWORK="no_network"   # no active network interface / WiFi
STATE_WAITING="waiting"         # connected to network, waiting for internet
STATE_READY="internet_ready"    # internet confirmed, VPN connecting/connected
STATE_TRUSTED="trusted_network" # on a trusted SSID, VPN intentionally off

# ─────────────────────────── Logging ──────────────────────────

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" | tee -a "$LOGFILE"
}

# ──────────────────────── NordVPN checks ──────────────────────

nordvpn_installed() {
    [ -d "/Applications/NordVPN.app" ]
}

nordvpn_running() {
    pgrep -xf "/Applications/NordVPN.app/Contents/MacOS/NordVPN" > /dev/null 2>&1
}

ensure_nordvpn_running() {
    if ! nordvpn_running; then
        log "INFO" "NordVPN not running - launching..."
        open -a NordVPN 2>/dev/null
        sleep 3
    fi
}

# ──────────────────── Auto-connect management ──────────────────
# NordVPN reads isAutoConnectOn from its plist at startup.
# Disabling it before the app session means it stays off for the
# entire session; the script then owns all connect/disconnect calls.

disable_autoconnect() {
    if defaults write "$NORDVPN_PLIST" isAutoConnectOn -bool false 2>/dev/null; then
        log "INFO" "NordVPN auto-connect disabled"
    else
        log "WARN" "Could not disable NordVPN auto-connect"
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

get_wifi_interface() {
    networksetup -listallhardwareports 2>/dev/null \
        | awk '/Wi-Fi/{found=1} found && /Device:/{print $2; exit}'
}

get_gateway_ip() {
    route get default 2>/dev/null | awk '/gateway:/{print $2}'
}

# Returns a stable identifier for the current network.
# Prefers the Wi-Fi SSID (requires Terminal → Location Services on Sequoia).
# Falls back to "gw:<gateway-ip>" which requires no permissions and is unique
# enough for trusted-network purposes on most networks.
get_network_id() {
    local iface
    iface=$(get_wifi_interface)
    if [[ -n "$iface" ]]; then
        local raw
        raw=$(networksetup -getairportnetwork "$iface" 2>/dev/null)
        case "$raw" in
            "Current Wi-Fi Network: "*)
                echo "${raw#Current Wi-Fi Network: }"
                return
                ;;
        esac
        # airport fallback for older macOS (removed in Sequoia)
        local ssid
        ssid=$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport \
                   -I 2>/dev/null | awk '/ SSID:/ {print $2}')
        [[ -n "$ssid" ]] && { echo "$ssid"; return; }
    fi
    # No SSID readable — fall back to gateway IP as network identifier
    local gw
    gw=$(get_gateway_ip)
    [[ -n "$gw" ]] && echo "gw:$gw"
}

# Keep get_ssid as an alias so nothing else breaks
get_ssid() { get_network_id; }

has_network_interface() {
    route get default 2>/dev/null | grep -q "interface:"
}

canary_reachable() {
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
        disable_autoconnect
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
            vpn_disconnect
            state="$STATE_WAITING"
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
                    if is_trusted_network "$ssid"; then
                        log "INFO" "Trusted network '$ssid' - leaving VPN off"
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
                if ! has_network_interface; then
                    log "INFO" "Network lost - disconnecting VPN"
                    vpn_disconnect
                    state="$STATE_NO_NETWORK"
                fi
                ;;

            "$STATE_TRUSTED")
                if ! has_network_interface; then
                    log "INFO" "Network lost"
                    state="$STATE_NO_NETWORK"
                fi
                ;;

        esac

        sleep "$CHECK_INTERVAL"
    done
}

# ─────────────────────────── Cleanup ──────────────────────────

cleanup() {
    log "INFO" "Script stopped - re-enabling NordVPN auto-connect"
    enable_autoconnect
    exit 0
}
trap cleanup SIGTERM SIGINT

main_loop
