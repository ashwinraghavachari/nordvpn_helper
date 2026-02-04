#!/bin/bash

# NordVPN Captive Portal Handler for macOS
# This script prevents NordVPN crash loops when connecting to WiFi networks with captive portals
# 
# Strategy:
# 1. Disable NordVPN when there is no network connection
# 2. After connecting to a WiFi network, wait for internet connectivity (captive portal completion)
# 3. Only enable/connect NordVPN once there is a real internet connection
#
# This proactive approach prevents VPN connection attempts during captive portal authentication

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

# Note: We no longer use explicit captive portal detection
# Instead, we simply check for internet connectivity - if there's no internet,
# we assume it could be a captive portal and keep VPN disconnected

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
    
    local last_ssid=""
    local last_interface=""
    local network_stabilization_wait=0
    local waiting_for_internet=false
    
    while true; do
        current_ssid=$(get_current_ssid)
        current_interface=$(get_network_interface)
        
        # STEP 1: Check if we have a network connection at all
        if [[ -z "$current_ssid" && -z "$current_interface" ]]; then
            # No network connection - disconnect VPN and keep it disconnected
            if is_vpn_connected || is_vpn_connecting; then
                log_message "No network connection detected - disconnecting VPN"
                disconnect_vpn
            fi
            waiting_for_internet=false
            last_ssid=""
            last_interface=""
            sleep $CHECK_INTERVAL
            continue
        fi
        
        # STEP 2: Detect network changes (SSID or interface change)
        local network_changed=false
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
        
        # STEP 3: When network changes, disconnect VPN and wait for internet
        if [[ "$network_changed" == true ]]; then
            log_message "Network change detected - disconnecting VPN and waiting for internet connectivity"
            
            # Disconnect VPN immediately when network changes
            if is_vpn_connected || is_vpn_connecting; then
                disconnect_vpn
            fi
            
            # Set flag to wait for internet before reconnecting VPN
            waiting_for_internet=true
            network_stabilization_wait=$NETWORK_STABILIZATION_DELAY
            
            # Wait for network to stabilize
            sleep $CHECK_INTERVAL
            continue
        fi
        
        # STEP 4: Wait for network stabilization after change
        if [[ $network_stabilization_wait -gt 0 ]]; then
            network_stabilization_wait=$((network_stabilization_wait - CHECK_INTERVAL))
            sleep $CHECK_INTERVAL
            continue
        fi
        
        # STEP 5: Check for internet connectivity (captive portal completion)
        if check_internet_connectivity; then
            # We have internet connectivity - captive portal is complete (or never existed)
            if $waiting_for_internet; then
                log_message "Internet connectivity confirmed on network '$current_ssid' - connecting VPN"
                waiting_for_internet=false
            fi
            
            # Connect VPN if not already connected
            if ! is_vpn_connected && ! is_vpn_connecting; then
                log_message "VPN not connected - connecting now"
                connect_vpn
            elif is_vpn_connecting; then
                # VPN is connecting, just wait
                :
            fi
            
        else
            # No internet connectivity - keep VPN disconnected
            # This means we're either:
            # 1. On a network with captive portal (waiting for user to complete login)
            # 2. Network issue
            # 3. VPN was blocking (but VPN should be disconnected)
            
            if ! $waiting_for_internet; then
                # First time detecting no internet - log it
                log_message "No internet connectivity detected on network '$current_ssid' - keeping VPN disconnected"
                waiting_for_internet=true
            fi
            
            # Ensure VPN is disconnected while waiting for internet
            if is_vpn_connected || is_vpn_connecting; then
                log_message "Disconnecting VPN - waiting for internet connectivity"
                disconnect_vpn
            fi
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Trap signals for clean shutdown
trap 'log_message "Script stopped"; exit 0' SIGTERM SIGINT

# Run the main loop
main_loop
