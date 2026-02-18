#!/bin/bash

# NordVPN Captive Portal Handler - Control Script

PLIST_PATH="$HOME/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist"
SERVICE_NAME="com.user.nordvpn.captiveportal"
TRUSTED_NETWORKS_FILE="$HOME/.nordvpn_trusted_networks"

# ── Helper: get current WiFi SSID ─────────────────────────────
current_ssid() {
    /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I 2>/dev/null \
        | awk '/ SSID:/ {print $2}'
}

# ── Helper: resolve SSID from arg or current network ──────────
resolve_ssid() {
    local ssid="$1"
    if [[ -z "$ssid" ]]; then
        ssid=$(current_ssid)
        if [[ -z "$ssid" ]]; then
            echo "Error: Not connected to WiFi and no SSID provided."
            echo "Usage: $0 trust \"Network Name\""
            exit 1
        fi
    fi
    echo "$ssid"
}

case "$1" in

    # ── Service management ─────────────────────────────────────

    start|enable|on)
        echo "Enabling NordVPN Captive Portal Handler..."
        if [ ! -f "$PLIST_PATH" ]; then
            echo "Error: Launch Agent not found at $PLIST_PATH"
            echo "Please run the installation first."
            exit 1
        fi
        launchctl load "$PLIST_PATH" 2>/dev/null || launchctl load -w "$PLIST_PATH" 2>/dev/null
        sleep 1
        if launchctl list | grep -q "$SERVICE_NAME"; then
            echo "✓ Script enabled and running"
        else
            echo "Warning: Script may not have started. Check logs:"
            echo "  $0 logs"
        fi
        ;;

    stop|disable|off)
        echo "Disabling NordVPN Captive Portal Handler..."
        launchctl unload "$PLIST_PATH" 2>/dev/null
        sleep 1
        if launchctl list | grep -q "$SERVICE_NAME"; then
            echo "Warning: Script may still be running. Try:"
            echo "  launchctl unload -w $PLIST_PATH"
        else
            echo "✓ Script disabled"
        fi
        ;;

    status|check)
        if launchctl list | grep -q "$SERVICE_NAME"; then
            echo "✓ Script is RUNNING"
            echo ""
            echo "Recent log entries:"
            tail -5 ~/Library/Logs/nordvpn_captive_portal.log 2>/dev/null \
                | sed 's/^/  /' || echo "  No log entries yet"
        else
            echo "✗ Script is STOPPED"
        fi
        echo ""
        if [[ -f "$TRUSTED_NETWORKS_FILE" ]] && [[ -s "$TRUSTED_NETWORKS_FILE" ]]; then
            echo "Trusted networks ($(grep -c . "$TRUSTED_NETWORKS_FILE")):"
            grep -v '^$' "$TRUSTED_NETWORKS_FILE" | sed 's/^/  - /'
        else
            echo "Trusted networks: none"
        fi
        ;;

    restart|reload)
        echo "Restarting NordVPN Captive Portal Handler..."
        launchctl unload "$PLIST_PATH" 2>/dev/null
        sleep 2
        launchctl load "$PLIST_PATH" 2>/dev/null
        sleep 1
        if launchctl list | grep -q "$SERVICE_NAME"; then
            echo "✓ Script restarted"
        else
            echo "Warning: Script may not have restarted. Check logs:"
            echo "  $0 logs"
        fi
        ;;

    logs)
        echo "Live logs (Ctrl+C to stop):"
        echo ""
        tail -f ~/Library/Logs/nordvpn_captive_portal.log
        ;;

    # ── Trusted network management ─────────────────────────────

    trust)
        # trust [SSID]  — add current or named network to trusted list
        SSID=$(resolve_ssid "$2")
        touch "$TRUSTED_NETWORKS_FILE"
        if grep -qxF "$SSID" "$TRUSTED_NETWORKS_FILE" 2>/dev/null; then
            echo "Already trusted: '$SSID'"
        else
            echo "$SSID" >> "$TRUSTED_NETWORKS_FILE"
            echo "✓ Added to trusted networks: '$SSID'"
            echo "  VPN will not connect on this network."
        fi
        ;;

    untrust)
        # untrust [SSID]  — remove current or named network from trusted list
        SSID=$(resolve_ssid "$2")
        if [[ ! -f "$TRUSTED_NETWORKS_FILE" ]] || ! grep -qxF "$SSID" "$TRUSTED_NETWORKS_FILE" 2>/dev/null; then
            echo "Not in trusted list: '$SSID'"
        else
            # Remove the line. Use ; not && so mv runs even when grep
            # produces no output (exit 1) — i.e. when removing the last entry.
            grep -vxF "$SSID" "$TRUSTED_NETWORKS_FILE" > "${TRUSTED_NETWORKS_FILE}.tmp"; \
                mv "${TRUSTED_NETWORKS_FILE}.tmp" "$TRUSTED_NETWORKS_FILE"
            echo "✓ Removed from trusted networks: '$SSID'"
            echo "  VPN will now connect on this network."
        fi
        ;;

    trusted)
        # List all trusted networks
        if [[ ! -f "$TRUSTED_NETWORKS_FILE" ]] || [[ ! -s "$TRUSTED_NETWORKS_FILE" ]]; then
            echo "No trusted networks configured."
            echo ""
            echo "To add the current network:  $0 trust"
            echo "To add a named network:      $0 trust \"Network Name\""
        else
            CURRENT=$(current_ssid)
            echo "Trusted networks:"
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                if [[ "$line" == "$CURRENT" ]]; then
                    echo "  - $line  (currently connected)"
                else
                    echo "  - $line"
                fi
            done < "$TRUSTED_NETWORKS_FILE"
        fi
        ;;

    *)
        echo "NordVPN Captive Portal Handler"
        echo ""
        echo "Service:"
        echo "  $0 start              Enable and start"
        echo "  $0 stop               Disable and stop"
        echo "  $0 status             Show status and trusted networks"
        echo "  $0 restart            Restart"
        echo "  $0 logs               View live logs"
        echo ""
        echo "Trusted networks (networks where VPN will NOT connect):"
        echo "  $0 trust              Trust the current WiFi network"
        echo "  $0 trust \"Name\"       Trust a specific network by name"
        echo "  $0 untrust            Remove current WiFi from trusted list"
        echo "  $0 untrust \"Name\"     Remove a specific network by name"
        echo "  $0 trusted            List all trusted networks"
        exit 1
        ;;
esac

exit 0
