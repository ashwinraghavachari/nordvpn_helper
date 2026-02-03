#!/bin/bash

# Test script for NordVPN Captive Portal Handler
# This script helps you test various aspects of the handler

LOGFILE="$HOME/Library/Logs/nordvpn_captive_portal.log"
SCRIPT_PID=$(pgrep -f "nordvpn_captive_portal_handler.sh" | head -1)

echo "=========================================="
echo "NordVPN Captive Portal Handler - Test Suite"
echo "=========================================="
echo ""

# Test 1: Check if script is running
echo "Test 1: Checking if script is running..."
if [ -n "$SCRIPT_PID" ]; then
    echo "✅ Script is running (PID: $SCRIPT_PID)"
else
    echo "❌ Script is NOT running"
    echo "   Start it with: launchctl load ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist"
    exit 1
fi
echo ""

# Test 2: Check recent log activity
echo "Test 2: Checking recent log activity..."
if [ -f "$LOGFILE" ]; then
    echo "Recent log entries:"
    tail -5 "$LOGFILE" | sed 's/^/   /'
    echo ""
else
    echo "⚠️  Log file not found: $LOGFILE"
    echo ""
fi

# Test 3: Check VPN detection
echo "Test 3: Testing VPN connection detection..."
if ifconfig | grep -q "^utun[0-9]"; then
    echo "✅ VPN interface detected (utun)"
    echo "   Interfaces found:"
    ifconfig | grep "^utun[0-9]" | sed 's/^/   /'
else
    echo "ℹ️  No VPN interface detected (VPN may not be connected)"
fi
echo ""

# Test 4: Check current network
echo "Test 4: Current network status..."
CURRENT_SSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I 2>/dev/null | awk '/ SSID:/ {print $2}')
CURRENT_INTERFACE=$(route get default 2>/dev/null | awk '/interface:/ {print $2}' | head -1)

if [ -n "$CURRENT_SSID" ]; then
    echo "   WiFi SSID: $CURRENT_SSID"
else
    echo "   WiFi SSID: Not connected"
fi
if [ -n "$CURRENT_INTERFACE" ]; then
    echo "   Network Interface: $CURRENT_INTERFACE"
else
    echo "   Network Interface: Not detected"
fi
echo ""

# Test 5: Test captive portal detection
echo "Test 5: Testing captive portal detection..."
echo "   Checking captive.apple.com..."
RESPONSE=$(curl -s -I -m 3 http://captive.apple.com/hotspot-detect.html 2>/dev/null)
if echo "$RESPONSE" | grep -qi "HTTP/1.1 200"; then
    BODY=$(curl -s -m 3 http://captive.apple.com/hotspot-detect.html 2>/dev/null)
    if echo "$BODY" | grep -qi "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"; then
        echo "   ✅ No captive portal detected (normal internet connection)"
    else
        echo "   ⚠️  Possible captive portal detected"
    fi
else
    echo "   ⚠️  Possible captive portal detected (non-200 response)"
fi
echo ""

# Test 6: Test internet connectivity
echo "Test 6: Testing internet connectivity..."
if curl -s -m 3 --connect-timeout 3 https://www.google.com > /dev/null 2>&1; then
    echo "   ✅ Internet connectivity confirmed"
else
    echo "   ⚠️  No internet connectivity detected"
fi
echo ""

# Test 7: Monitor script for 10 seconds
echo "Test 7: Monitoring script activity for 10 seconds..."
echo "   (Watch for network change detection and VPN control attempts)"
echo ""
TIMESTAMP_BEFORE=$(tail -1 "$LOGFILE" 2>/dev/null | cut -d' ' -f1-2)
sleep 10
TIMESTAMP_AFTER=$(tail -1 "$LOGFILE" 2>/dev/null | cut -d' ' -f1-2)

if [ "$TIMESTAMP_BEFORE" != "$TIMESTAMP_AFTER" ]; then
    echo "   ✅ Script is actively logging (new entries detected)"
    echo "   Recent activity:"
    tail -3 "$LOGFILE" | sed 's/^/      /'
else
    echo "   ℹ️  No new log entries (script may be idle, which is normal)"
fi
echo ""

# Test 8: Check Launch Agent status
echo "Test 8: Checking Launch Agent status..."
if launchctl list | grep -q "com.user.nordvpn.captiveportal"; then
    echo "   ✅ Launch Agent is loaded"
    launchctl list | grep "com.user.nordvpn.captiveportal" | sed 's/^/      /'
else
    echo "   ❌ Launch Agent is NOT loaded"
fi
echo ""

echo "=========================================="
echo "Testing Complete!"
echo "=========================================="
echo ""
echo "To monitor the script in real-time, run:"
echo "   tail -f $LOGFILE"
echo ""
echo "To test with a real network change:"
echo "   1. Connect to a different WiFi network"
echo "   2. Watch the logs: tail -f $LOGFILE"
echo "   3. The script should detect the change and disconnect VPN"
echo ""
