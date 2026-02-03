# Testing Guide for NordVPN Captive Portal Handler

This guide explains how to test that the script is working correctly.

## Quick Test

Run the automated test script:

```bash
cd ~/cursor_workspace/nordvpn_helper
./test_script.sh
```

This will check:
- ✅ Script is running
- ✅ Log file is being written
- ✅ VPN detection works
- ✅ Network status detection
- ✅ Captive portal detection
- ✅ Internet connectivity checks

## Manual Testing Methods

### 1. Monitor Logs in Real-Time

Open a terminal and watch the logs:

```bash
tail -f ~/Library/Logs/nordvpn_captive_portal.log
```

You should see entries every 2 seconds showing the script is checking your network status.

### 2. Test Network Change Detection

**Method A: Switch WiFi Networks**
1. Connect to a different WiFi network
2. Watch the logs - you should see:
   ```
   Network changed to: [SSID]
   Network change detected - immediately disconnecting VPN to prevent captive portal conflicts
   ```

**Method B: Disconnect/Reconnect WiFi**
1. Turn WiFi off
2. Turn WiFi back on
3. Watch the logs for network change detection

### 3. Test Captive Portal Detection

**Method A: Connect to a Public WiFi with Captive Portal**
1. Connect to a public WiFi (coffee shop, airport, hotel)
2. The script should detect the captive portal
3. You should see in logs:
   ```
   Captive portal detected on network '[SSID]'
   VPN disconnected. Please complete captive portal login in your browser.
   ```
4. Complete the captive portal login
5. After login, you should see:
   ```
   Internet connectivity confirmed. Captive portal cleared. Reconnecting VPN.
   ```

**Method B: Simulate Captive Portal (Advanced)**
You can temporarily block the captive portal detection endpoint to simulate a captive portal:

```bash
# This requires admin access and is just for testing
sudo pfctl -f /dev/stdin <<EOF
block return in proto tcp from any to captive.apple.com port 80
EOF

# Watch logs - script should detect captive portal
tail -f ~/Library/Logs/nordvpn_captive_portal.log

# Remove the block when done testing
sudo pfctl -F all
```

### 4. Test VPN Disconnect/Connect

**Test VPN Disconnection:**
1. Connect to NordVPN manually
2. Connect to a new WiFi network
3. Watch logs - script should attempt to disconnect VPN
4. Check if VPN actually disconnected (look at NordVPN app or check `ifconfig` for utun interfaces)

**Test VPN Reconnection:**
1. After completing captive portal login
2. Watch logs - script should attempt to reconnect VPN
3. Check if VPN reconnects successfully

### 5. Verify Script Status

Check if the script is running:

```bash
# Check process
ps aux | grep nordvpn_captive_portal_handler | grep -v grep

# Check Launch Agent
launchctl list | grep nordvpn

# Check recent logs
tail -20 ~/Library/Logs/nordvpn_captive_portal.log
```

### 6. Test Error Handling

**Test with VPN App Closed:**
1. Quit NordVPN app completely
2. Connect to a new network
3. Script should launch NordVPN app automatically
4. Check logs for: "NordVPN app not running, launching..."

**Test with No Internet:**
1. Disconnect from all networks
2. Script should detect no network connection
3. Check logs for appropriate messages

## Expected Behavior

### Normal Operation (No Captive Portal)
- Script runs silently in background
- Checks network every 2 seconds
- No VPN disconnection if network is stable
- VPN stays connected if already connected

### Network Change Detected
- Script immediately disconnects VPN
- Waits 3 seconds for network stabilization
- Checks for captive portal
- If no captive portal, reconnects VPN after confirming internet

### Captive Portal Detected
- Script disconnects VPN immediately
- Opens captive portal page in browser
- Waits for user to complete login
- Checks internet connectivity every 2 seconds
- Reconnects VPN once internet is confirmed

### Timeout Scenario
- If captive portal not completed within 5 minutes
- Script checks connectivity one more time
- If internet available, reconnects VPN
- If still no internet, keeps VPN disconnected

## Troubleshooting Tests

### If Script Doesn't Detect Network Changes

1. Check script is running:
   ```bash
   ps aux | grep nordvpn_captive_portal_handler
   ```

2. Check logs for errors:
   ```bash
   tail -50 ~/Library/Logs/nordvpn_captive_portal_stderr.log
   ```

3. Verify network detection:
   ```bash
   /System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I
   route get default
   ```

### If VPN Doesn't Disconnect/Connect

1. Check if NordVPN app is running:
   ```bash
   pgrep -f NordVPN
   ```

2. Test AppleScript manually:
   ```bash
   osascript -e 'tell application "NordVPN" to get state'
   ```

3. Check accessibility permissions:
   - System Settings → Privacy & Security → Accessibility
   - Ensure Terminal (or Script Editor) has permissions

4. Try manual disconnect:
   ```bash
   osascript -e 'tell application "NordVPN" to disconnect'
   ```

## Success Indicators

✅ **Script is working correctly if:**
- Logs show regular activity every 2 seconds
- Network changes are detected immediately
- VPN disconnects when network changes
- Captive portals are detected
- VPN reconnects after captive portal completion
- No errors in stderr log

## Continuous Monitoring

To continuously monitor the script:

```bash
# Watch logs in real-time
tail -f ~/Library/Logs/nordvpn_captive_portal.log

# In another terminal, watch for errors
tail -f ~/Library/Logs/nordvpn_captive_portal_stderr.log
```

## Test Checklist

- [ ] Script is running (check with `ps aux | grep nordvpn_captive_portal_handler`)
- [ ] Logs are being written (check `tail ~/Library/Logs/nordvpn_captive_portal.log`)
- [ ] Network change detection works (switch WiFi networks)
- [ ] VPN disconnects on network change
- [ ] Captive portal detection works (connect to public WiFi)
- [ ] VPN reconnects after captive portal completion
- [ ] Script restarts automatically if it crashes (test by killing process)
- [ ] Script starts on system boot (restart Mac and check)

## Notes

- The script checks every 2 seconds, so changes may take up to 2 seconds to be detected
- Network stabilization delay is 3 seconds after network change
- Captive portal timeout is 5 minutes
- Script runs continuously in background via Launch Agent
