# NordVPN Captive Portal Handler

Automatically pauses NordVPN when connecting to WiFi networks with captive portals, preventing connection failures and crash loops.

## Problem Solved

When connecting to WiFi networks with captive portals (public WiFi login pages) while NordVPN is active, NordVPN attempts to connect before you can authenticate with the captive portal. This causes:
- Connection failures
- NordVPN spinning/loading indefinitely
- Inability to access the captive portal login page
- Network connection issues

This script solves this by **immediately disconnecting NordVPN when network changes are detected**, allowing you to complete captive portal authentication, then automatically reconnecting VPN once internet connectivity is confirmed.

## Features

- ✅ **Immediate VPN Disconnect**: Detects network changes instantly and disconnects VPN before connection attempts
- ✅ **Automatic Captive Portal Detection**: Uses Apple's detection mechanism to identify login pages
- ✅ **Auto-Resume VPN**: Reconnects VPN automatically after captive portal completion
- ✅ **Background Operation**: Runs as Launch Agent, no terminal window needed
- ✅ **Auto-Restart**: Automatically restarts if it crashes
- ✅ **Comprehensive Logging**: Detailed logs for monitoring and troubleshooting

## Requirements

### System Requirements
- **macOS 10.14 (Mojave) or later**
- Standard user account (no admin/root required)

### Software Requirements
- **NordVPN macOS App** (from App Store or NordVPN website)
- Active NordVPN account and logged into the app

### System Permissions
- **Accessibility Permissions** (required for VPN control)
  - System Settings → Privacy & Security → Accessibility
  - Enable Terminal or Script Editor

### Dependencies
All dependencies are built into macOS - no additional installation needed:
- `bash`, `curl`, `osascript`, `ifconfig`, `route`, `pgrep`, `open`, `netstat`, `awk`, `grep`, `date`

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

**Quick Install:**
```bash
# 1. Set up accessibility permissions (see INSTALL.md)

# 2. Copy script
cp nordvpn_captive_portal_handler.sh ~/nordvpn_captive_portal_handler.sh
chmod +x ~/nordvpn_captive_portal_handler.sh

# 3. Set up Launch Agent
sed "s/YOUR_USERNAME/$(whoami)/g" com.user.nordvpn.captiveportal.plist > ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
launchctl load ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist

# 4. Verify it's running
tail -f ~/Library/Logs/nordvpn_captive_portal.log
```

## Usage

Once installed, the script runs automatically in the background. No manual intervention needed.

**Monitor the script:**
```bash
tail -f ~/Library/Logs/nordvpn_captive_portal.log
```

**Test the script:**
```bash
cd ~/cursor_workspace/nordvpn_helper
./test_script.sh
```

## How It Works

1. **Continuous Monitoring**: Checks network status every 2 seconds
2. **Network Change Detection**: Immediately detects WiFi SSID or interface changes
3. **Immediate VPN Disconnect**: Disconnects NordVPN as soon as network change is detected
4. **Captive Portal Detection**: Uses Apple's mechanism to detect login pages
5. **Browser Integration**: Opens captive portal page automatically
6. **Auto-Resume**: Reconnects VPN once internet connectivity is confirmed

## Files

- `nordvpn_captive_portal_handler.sh` - Main script
- `com.user.nordvpn.captiveportal.plist` - Launch Agent configuration
- `INSTALL.md` - Detailed installation guide
- `TESTING.md` - Testing guide and troubleshooting
- `test_script.sh` - Automated test suite
- `README.md` - This file

## Logs

All logs are stored in `~/Library/Logs/`:
- `nordvpn_captive_portal.log` - Main activity log
- `nordvpn_captive_portal_stdout.log` - Standard output
- `nordvpn_captive_portal_stderr.log` - Error messages

## Management

### Easy Control (Recommended)

Use the control script for easy enable/disable:

```bash
# Enable the script
~/nordvpn_helper_control.sh start
# or: ~/nordvpn_helper_control.sh enable
# or: ~/nordvpn_helper_control.sh on

# Disable the script
~/nordvpn_helper_control.sh stop
# or: ~/nordvpn_helper_control.sh disable
# or: ~/nordvpn_helper_control.sh off

# Check status
~/nordvpn_helper_control.sh status

# Restart the script
~/nordvpn_helper_control.sh restart

# View live logs
~/nordvpn_helper_control.sh logs
```

### Manual Control

If you prefer manual control:

```bash
# Stop
launchctl unload ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist

# Start
launchctl load ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist

# Check status
launchctl list | grep nordvpn
ps aux | grep nordvpn_captive_portal_handler | grep -v grep
```

**Uninstall:**
```bash
launchctl unload ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
rm ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
rm ~/nordvpn_captive_portal_handler.sh
```

## Troubleshooting

See [INSTALL.md](INSTALL.md) troubleshooting section or [TESTING.md](TESTING.md) for detailed troubleshooting.

**Common Issues:**
- **VPN not disconnecting**: Check accessibility permissions
- **Script not running**: Check Launch Agent status and error logs
- **Network not detected**: Verify WiFi is connected and airport command works

## Customization

Edit `~/nordvpn_captive_portal_handler.sh` to customize:
- `CHECK_INTERVAL` - How often to check (default: 2 seconds)
- `CAPTIVE_PORTAL_TIMEOUT` - Max wait time (default: 300 seconds)
- `NETWORK_STABILIZATION_DELAY` - Delay after network change (default: 3 seconds)

After editing, restart the service.

## Security & Privacy

- Runs with user permissions (not root/admin)
- No network traffic interception
- Only monitors network status and controls NordVPN
- All logs stored locally
- No external data transmission
- Open source - review the code

## License

This script is provided as-is for personal use.

## Support

For issues or questions:
1. Check [INSTALL.md](INSTALL.md) troubleshooting section
2. Review logs: `tail -50 ~/Library/Logs/nordvpn_captive_portal.log`
3. Run test script: `./test_script.sh`
