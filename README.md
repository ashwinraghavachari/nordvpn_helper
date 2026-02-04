# NordVPN Captive Portal Handler

Automatically prevents NordVPN crash loops when connecting to WiFi networks with captive portals by waiting for internet connectivity before connecting the VPN.

## Problem Solved

When connecting to WiFi networks with captive portals (public WiFi login pages) while NordVPN has auto-connect enabled, NordVPN attempts to connect before you can authenticate with the captive portal. This causes:
- Connection failures
- NordVPN spinning/loading indefinitely  
- Inability to access the captive portal login page
- Network connection issues and crash loops

This script solves this by **disconnecting NordVPN when network changes are detected**, waiting for internet connectivity (captive portal completion), then automatically reconnecting VPN once internet is confirmed.

## How It Works

1. **No Network = VPN Disabled**: Disconnects VPN when there's no network connection
2. **Network Change = Disconnect & Wait**: When connecting to a new WiFi network, VPN is immediately disconnected
3. **Wait for Internet**: Script waits for internet connectivity (captive portal completion)
4. **Connect After Internet**: Only connects VPN once internet connectivity is confirmed

This proactive approach prevents VPN connection attempts during captive portal authentication.

## Features

- ✅ **Proactive VPN Management**: Disconnects VPN on network changes before connection attempts
- ✅ **Automatic Internet Detection**: Waits for real internet connectivity before reconnecting VPN
- ✅ **Background Operation**: Runs as Launch Agent, no terminal window needed
- ✅ **Auto-Restart**: Automatically restarts if it crashes
- ✅ **Easy Control**: Simple master switch to enable/disable
- ✅ **Comprehensive Logging**: Detailed logs for monitoring and troubleshooting

## Requirements

### System Requirements
- **macOS 10.14 (Mojave) or later**
- Standard user account (no admin/root required)

### Software Requirements
- **NordVPN macOS App** (from App Store or NordVPN website)
  - Download from: https://nordvpn.com/download/mac/
  - Must be logged into the NordVPN app
- Active NordVPN account

### System Dependencies

All dependencies are built into macOS - **no additional installation needed**:

| Command | Purpose | Location |
|---------|---------|----------|
| `bash` | Shell interpreter | `/bin/bash` |
| `curl` | HTTP client for connectivity checks | `/usr/bin/curl` |
| `osascript` | AppleScript interpreter for VPN control | `/usr/bin/osascript` |
| `ifconfig` | Network interface configuration | `/sbin/ifconfig` |
| `route` | Network routing table | `/sbin/route` |
| `pgrep` | Process search | `/usr/bin/pgrep` |
| `open` | Application launcher | `/usr/bin/open` |
| `netstat` | Network statistics | `/usr/sbin/netstat` |
| `awk` | Text processing | `/usr/bin/awk` |
| `grep` | Text search | `/usr/bin/grep` |
| `date` | Date/time utility | `/bin/date` |

**Verify all dependencies:**
```bash
which bash curl osascript ifconfig route pgrep open netstat awk grep date
```

### System Permissions

#### Accessibility Permissions (Required)

The script uses AppleScript to control NordVPN, which requires accessibility permissions:

1. Open **System Settings** (or **System Preferences** on older macOS)
2. Navigate to **Privacy & Security** → **Accessibility**
3. Click the lock icon and enter your password
4. Click the **+** button
5. Navigate to `/usr/bin` and add **Terminal** (or add **Script Editor** for testing)
6. Ensure the checkbox is enabled

**Verify permissions:**
```bash
osascript -e 'tell application "NordVPN" to get state'
```

If this works without errors or prompts, permissions are correctly set.

#### Network Permissions

Standard user network access is sufficient - **no special permissions needed**.

## Installation

### Step 1: Download

Download or clone this repository to your Mac.

### Step 2: Verify Prerequisites

```bash
# Check macOS version
sw_vers

# Check if NordVPN app is installed
ls -la /Applications/NordVPN.app

# Verify required commands (all should return paths)
which curl osascript ifconfig route pgrep open awk grep date
```

### Step 3: Set Up Accessibility Permissions

**Important**: Do this before installing the script.

1. System Settings → Privacy & Security → Accessibility
2. Add Terminal (or Script Editor)
3. Test: `osascript -e 'tell application "NordVPN" to get state'`

### Step 4: Install Script

```bash
# Navigate to the repository directory
cd /path/to/nordvpn_helper

# Copy script to home directory
cp nordvpn_captive_portal_handler.sh ~/nordvpn_captive_portal_handler.sh
chmod +x ~/nordvpn_captive_portal_handler.sh

# Copy control script to home directory (for easy enable/disable)
cp control.sh ~/nordvpn_helper_control.sh
chmod +x ~/nordvpn_helper_control.sh
```

### Step 5: Set Up Launch Agent

```bash
# Create LaunchAgents directory if it doesn't exist
mkdir -p ~/Library/LaunchAgents

# Create Launch Agent plist (replace YOUR_USERNAME with your actual username)
sed "s/YOUR_USERNAME/$(whoami)/g" com.user.nordvpn.captiveportal.plist > ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
```

### Step 6: Enable and Start

```bash
# Enable the script (starts automatically)
~/nordvpn_helper_control.sh start

# Or manually:
# launchctl load ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
```

### Step 7: Verify Installation

```bash
# Check status
~/nordvpn_helper_control.sh status

# Or manually check:
# ps aux | grep nordvpn_captive_portal_handler | grep -v grep
# launchctl list | grep nordvpn
# tail -20 ~/Library/Logs/nordvpn_captive_portal.log
```

You should see the script running and log entries indicating it has started.

## Control Script (Master Switch)

The control script (`~/nordvpn_helper_control.sh`) provides an easy way to enable/disable the script.

### Enable the Script

```bash
~/nordvpn_helper_control.sh start
# or: ~/nordvpn_helper_control.sh enable
# or: ~/nordvpn_helper_control.sh on
```

### Disable the Script

```bash
~/nordvpn_helper_control.sh stop
# or: ~/nordvpn_helper_control.sh disable
# or: ~/nordvpn_helper_control.sh off
```

### Check Status

```bash
~/nordvpn_helper_control.sh status
```

### Restart the Script

```bash
~/nordvpn_helper_control.sh restart
```

### View Live Logs

```bash
~/nordvpn_helper_control.sh logs
```

### Help

```bash
~/nordvpn_helper_control.sh
```

## Usage

Once installed and enabled, the script runs automatically in the background. No manual intervention needed.

**Enable NordVPN Auto-Connect**: You can now safely enable auto-connect in the NordVPN app settings. The script will handle captive portals automatically.

**Monitor the script:**
```bash
tail -f ~/Library/Logs/nordvpn_captive_portal.log
```

## Logs

All logs are stored in `~/Library/Logs/`:
- `nordvpn_captive_portal.log` - Main activity log
- `nordvpn_captive_portal_stdout.log` - Standard output
- `nordvpn_captive_portal_stderr.log` - Error messages

## Troubleshooting

### Script Not Running

```bash
# Check status
~/nordvpn_helper_control.sh status

# Check Launch Agent
launchctl list | grep nordvpn

# Check error logs
cat ~/Library/Logs/nordvpn_captive_portal_stderr.log

# Restart the script
~/nordvpn_helper_control.sh restart
```

### VPN Not Disconnecting/Connecting

**Check Accessibility Permissions:**
1. System Settings → Privacy & Security → Accessibility
2. Ensure Terminal (or Script Editor) is enabled
3. Test manually:
   ```bash
   osascript -e 'tell application "NordVPN" to disconnect'
   osascript -e 'tell application "NordVPN" to connect'
   ```

**Check if NordVPN app is running:**
```bash
pgrep -f NordVPN
```

**Test AppleScript access:**
```bash
osascript -e 'tell application "NordVPN" to get state'
```

### Network Detection Issues

**Check WiFi SSID detection:**
```bash
/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I
```

If airport command not found, the script uses network interface detection as fallback.

**Check network interface:**
```bash
route get default | grep interface
ifconfig | grep "^en"
```

### View All Logs

```bash
# Main log
tail -50 ~/Library/Logs/nordvpn_captive_portal.log

# Error log
tail -50 ~/Library/Logs/nordvpn_captive_portal_stderr.log

# Standard output
tail -50 ~/Library/Logs/nordvpn_captive_portal_stdout.log
```

## Customization

Edit `~/nordvpn_captive_portal_handler.sh` to customize:

- `CHECK_INTERVAL` - How often to check network status (default: 2 seconds)
- `NETWORK_STABILIZATION_DELAY` - Time to wait after network change (default: 3 seconds)

After editing, restart the service:
```bash
~/nordvpn_helper_control.sh restart
```

## Uninstall

```bash
# Disable the script
~/nordvpn_helper_control.sh stop

# Remove files
rm ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
rm ~/nordvpn_captive_portal_handler.sh
rm ~/nordvpn_helper_control.sh
```

## Files

- `nordvpn_captive_portal_handler.sh` - Main script
- `control.sh` - Control script (master switch)
- `com.user.nordvpn.captiveportal.plist` - Launch Agent configuration
- `test_script.sh` - Automated test suite
- `TESTING.md` - Detailed testing guide

## Security & Privacy

- Runs with user permissions (not root/admin)
- No network traffic interception
- Only monitors network status and controls NordVPN app
- All logs stored locally in your home directory
- No external data transmission
- Open source - review the code

## License

This script is provided as-is for personal use.
