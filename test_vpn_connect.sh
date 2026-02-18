#!/bin/bash

# Quick test: connect NordVPN from command line and verify it worked

echo "NordVPN Command Line Connect Test"
echo "=================================="
echo ""

# Step 1: Check app is installed
echo "1. Checking NordVPN is installed..."
if [ ! -d "/Applications/NordVPN.app" ]; then
    echo "   ❌ NordVPN.app not found at /Applications/NordVPN.app"
    exit 1
fi
echo "   ✅ NordVPN.app found"

# Step 2: Check app is running, launch if not
echo ""
echo "2. Checking NordVPN is running..."
if ! pgrep -f "NordVPN.app" > /dev/null; then
    echo "   Not running - launching..."
    open -a NordVPN
    sleep 3
fi
echo "   ✅ NordVPN is running (PID: $(pgrep -f 'NordVPN.app' | head -1))"

# Step 3: Disconnect first for a clean test
echo ""
echo "3. Disconnecting VPN (clean start)..."
osascript -e 'open location "nordvpn://disconnect"' 2>/dev/null
sleep 4
echo "   Done"

# Step 4: Connect via URL scheme
echo ""
echo "4. Sending connect command via URL scheme..."
osascript -e 'open location "nordvpn://connect"' 2>/dev/null
echo "   Command sent - waiting up to 15s..."

# Step 5: Poll for connection using canary ping
echo ""
connected=false
for i in {1..15}; do
    sleep 1
    # Check the plist flag NordVPN sets when connected
    vpn_flag=$(defaults read ~/Library/Preferences/com.nordvpn.macos.plist isAppWasConnectedToVPN 2>/dev/null)
    # Also check internet reachability
    ping -c 1 -W 1 google.com > /dev/null 2>&1
    ping_ok=$?

    echo "   [$i/15] isAppWasConnectedToVPN=$vpn_flag  internet=$([ $ping_ok -eq 0 ] && echo yes || echo no)"

    if [ "$vpn_flag" = "1" ] && [ $ping_ok -eq 0 ]; then
        connected=true
        break
    fi
done

# Step 6: Result
echo ""
echo "=================================="
if $connected; then
    echo "✅ SUCCESS - NordVPN connected from command line"
else
    echo "❌ FAILED - VPN did not connect within 15s"
    echo "   Check NordVPN app is logged in and has network access"
fi
