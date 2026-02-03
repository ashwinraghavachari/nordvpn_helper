#!/bin/bash

# NordVPN Captive Portal Handler for macOS
# This script monitors network connectivity and automatically pauses/unpauses NordVPN
# when encountering captive portals (public WiFi login pages)
# 
# Key improvement: Immediately disconnects VPN when network changes to prevent
# connection attempts during captive portal authentication

LOGFILE="$HOME/Library/Logs/nordvpn_captive_portal.log"
CHECK_INTERVAL=2  # seconds between checks (reduced for faster detection)
CAPTIVE_PORTAL_TIMEOUT=300  # 5 minutes max to complete captive portal login
NETWORK_STABILIZATION_DELAY=3  # seconds to wait after network change before checking

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

ensure_nordvpn_running() {
    # Check if NordVPN app is running, launch if not
    if ! pgrep -f "NordVPN.app" > /dev/null; then
        log_message "NordVPN app not running, launching..."
        open -a NordVPN 2>/dev/null
        sleep 3  # Wait for app to start
    fi
}

is_vpn_connected() {
    # Method 1: Try AppleScript (if NordVPN supports it)
    ensure_nordvpn_running
    state=$(osascript -e 'tell application "NordVPN" to get state' 2>/dev/null)
    if [[ $? -eq 0 ]] && echo "$state" | grep -qi "connected"; then
        return 0
    fi
    
    # Method 2: Check for VPN network interfaces (utun interfaces typically used by VPNs)
    # NordVPN on macOS typically creates utun interfaces when connected
    if ifconfig | grep -q "^utun[0-9]"; then
        # Check if any utun interface has an IP and is UP
        for interface in $(ifconfig | grep "^utun[0-9]" | cut -d: -f1); do
            if ifconfig "$interface" | grep -q "inet " && ifconfig "$interface" | grep -q "status: active"; then
                return 0
            fi
        done
    fi
    
    # Method 3: Check for NordVPN process with network activity
    if pgrep -f "NordVPN" > /dev/null && netstat -rn | grep -q "utun"; then
        return 0
    fi
    
    return 1
}

is_vpn_connecting() {
    # Check if NordVPN is in a connecting state
    ensure_nordvpn_running
    state=$(osascript -e 'tell application "NordVPN" to get state' 2>/dev/null)
    if [[ $? -eq 0 ]] && echo "$state" | grep -qiE "(connecting|reconnecting)"; then
        return 0
    fi
    
    # Fallback: Check if NordVPN process is running but no VPN interface yet
    if pgrep -f "NordVPN" > /dev/null && ! is_vpn_connected; then
        return 0
    fi
    
    return 1
}

disconnect_vpn() {
    log_message "Disconnecting NordVPN to prevent connection during captive portal..."
    
    ensure_nordvpn_running
    
    # Method 1: Try AppleScript disconnect
    osascript -e 'tell application "NordVPN" to disconnect' 2>/dev/null
    
    # Method 2: Try using keyboard shortcut (Cmd+Shift+D for disconnect in NordVPN)
    # This requires accessibility permissions but is more reliable
    osascript -e 'tell application "System Events" to tell process "NordVPN" to keystroke "d" using {command down, shift down}' 2>/dev/null
    
    # Wait a bit and check if still connected/connecting
    sleep 3
    if is_vpn_connected || is_vpn_connecting; then
        log_message "VPN still active, trying alternative disconnect method..."
        # Try clicking disconnect button via AppleScript
        osascript -e 'tell application "System Events" to tell process "NordVPN" to click button "Disconnect" of window 1' 2>/dev/null
        sleep 2
    fi
    
    log_message "NordVPN disconnect attempted"
}

connect_vpn() {
    log_message "Connecting NordVPN..."
    
    ensure_nordvpn_running
    
    # Method 1: Try AppleScript connect
    osascript -e 'tell application "NordVPN" to connect' 2>/dev/null
    
    # Method 2: Try using keyboard shortcut (Cmd+Shift+C for quick connect)
    osascript -e 'tell application "System Events" to tell process "NordVPN" to keystroke "c" using {command down, shift down}' 2>/dev/null
    
    # Wait for connection to establish
    sleep 4
    
    # Verify connection
    if is_vpn_connected; then
        log_message "NordVPN connected successfully"
        return 0
    else
        log_message "Warning: NordVPN connection attempt may have failed or is still connecting"
        return 1
    fi
}

check_captive_portal() {
    # Try to detect captive portal by checking if we can reach the internet
    # Apple uses captive.apple.com for captive portal detection
    
    # Method 1: Check Apple's captive portal detection
    response=$(curl -s -I -m 3 http://captive.apple.com/hotspot-detect.html 2>/dev/null)
    
    if echo "$response" | grep -qi "HTTP/1.1 200"; then
        # Check if response contains actual content (not redirect to captive portal)
        body=$(curl -s -m 3 http://captive.apple.com/hotspot-detect.html 2>/dev/null)
        if echo "$body" | grep -qi "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"; then
            # No captive portal - normal internet connection
            return 1
        fi
    fi
    
    # Possible captive portal detected
    return 0
}

check_internet_connectivity() {
    # Check if we have actual internet connectivity (not just captive portal page)
    # Try multiple endpoints for reliability
    if curl -s -m 3 --connect-timeout 3 https://www.google.com > /dev/null 2>&1; then
        return 0
    fi
    
    # Fallback check
    if curl -s -m 3 --connect-timeout 3 https://www.cloudflare.com > /dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

get_current_ssid() {
    /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I 2>/dev/null | awk '/ SSID:/ {print $2}'
}

get_network_interface() {
    # Get the primary network interface (WiFi or Ethernet)
    route get default 2>/dev/null | awk '/interface:/ {print $2}' | head -1
}

main_loop() {
    log_message "NordVPN Captive Portal Handler started"
    
    local vpn_was_disconnected=false
    local disconnect_start_time=0
    local last_ssid=""
    local last_interface=""
    local network_changed=false
    local stabilization_wait=0
    
    while true; do
        current_ssid=$(get_current_ssid)
        current_interface=$(get_network_interface)
        
        # Detect network changes (SSID or interface change)
        network_changed=false
        if [[ "$current_ssid" != "$last_ssid" ]]; then
            if [[ -n "$current_ssid" && -n "$last_ssid" ]]; then
                network_changed=true
                log_message "WiFi network changed from '$last_ssid' to '$current_ssid'"
            elif [[ -n "$current_ssid" && -z "$last_ssid" ]]; then
                network_changed=true
                log_message "Connected to WiFi network: $current_ssid"
            fi
            last_ssid="$current_ssid"
        fi
        
        if [[ "$current_interface" != "$last_interface" && -n "$current_interface" ]]; then
            network_changed=true
            log_message "Network interface changed to: $current_interface"
            last_interface="$current_interface"
        fi
        
        # CRITICAL: Immediately disconnect VPN when network changes to prevent connection attempts
        if [[ "$network_changed" == true ]]; then
            log_message "Network change detected - immediately disconnecting VPN to prevent captive portal conflicts"
            
            # Disconnect VPN immediately, even if connecting
            if is_vpn_connected || is_vpn_connecting; then
                disconnect_vpn
                vpn_was_disconnected=true
                disconnect_start_time=$(date +%s)
                stabilization_wait=$NETWORK_STABILIZATION_DELAY
            else
                # Ensure VPN stays disconnected during network transition
                vpn_was_disconnected=true
                disconnect_start_time=$(date +%s)
                stabilization_wait=$NETWORK_STABILIZATION_DELAY
            fi
            
            # Wait for network to stabilize before checking for captive portal
            continue
        fi
        
        # Wait for network stabilization after change
        if [[ $stabilization_wait -gt 0 ]]; then
            stabilization_wait=$((stabilization_wait - CHECK_INTERVAL))
            sleep $CHECK_INTERVAL
            continue
        fi
        
        # Only proceed if we have a network connection
        if [[ -z "$current_ssid" && -z "$current_interface" ]]; then
            # No network connection
            if is_vpn_connected; then
                log_message "No network connection detected, disconnecting VPN"
                disconnect_vpn
                vpn_was_disconnected=false
            fi
            sleep $CHECK_INTERVAL
            continue
        fi
        
        # Check for captive portal
        if check_captive_portal; then
            # Captive portal detected
            if ! $vpn_was_disconnected; then
                log_message "Captive portal detected on network '$current_ssid'"
                
                if is_vpn_connected || is_vpn_connecting; then
                    disconnect_vpn
                    vpn_was_disconnected=true
                    disconnect_start_time=$(date +%s)
                    log_message "VPN disconnected. Please complete captive portal login in your browser."
                    
                    # Open the captive portal page
                    open "http://captive.apple.com/hotspot-detect.html" 2>/dev/null
                fi
            fi
            
            # Check if we've been waiting too long
            if $vpn_was_disconnected; then
                current_time=$(date +%s)
                elapsed=$((current_time - disconnect_start_time))
                
                if [[ $elapsed -gt $CAPTIVE_PORTAL_TIMEOUT ]]; then
                    log_message "Captive portal timeout reached (${CAPTIVE_PORTAL_TIMEOUT}s). Checking connectivity..."
                    if check_internet_connectivity; then
                        log_message "Internet connectivity detected. Reconnecting VPN."
                        connect_vpn
                        vpn_was_disconnected=false
                    else
                        log_message "Still no internet connectivity. VPN will remain disconnected."
                    fi
                fi
            fi
            
        else
            # No captive portal detected - check internet connectivity
            if check_internet_connectivity; then
                # We have internet connectivity
                if $vpn_was_disconnected; then
                    log_message "Internet connectivity confirmed. Captive portal cleared. Reconnecting VPN."
                    connect_vpn
                    vpn_was_disconnected=false
                else
                    # Normal operation - VPN should be connected if no captive portal
                    # Note: We don't auto-connect here to respect manual disconnections
                    # If you want auto-reconnect, uncomment the following:
                    # if ! is_vpn_connected && ! is_vpn_connecting; then
                    #     log_message "VPN not connected. Use 'nordvpn connect' to reconnect."
                    # fi
                    : # No-op to satisfy bash syntax
                fi
            else
                # No internet connectivity but no captive portal detected
                # This might be a temporary network issue
                if is_vpn_connected; then
                    log_message "No internet connectivity detected. VPN may be blocking or network issue."
                fi
            fi
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Trap signals for clean shutdown
trap 'log_message "Script stopped"; exit 0' SIGTERM SIGINT

# Run the main loop
main_loop
