# NordVPN Captive Portal Handler - Installation Guide

This script automatically detects captive portals (public WiFi login pages) and temporarily pauses NordVPN to allow you to log in, then automatically resumes it once you're connected.

## Quick Start

1. **Prerequisites**: macOS 10.14+, NordVPN app installed, Accessibility permissions enabled
2. **Install**: Copy script and plist, load Launch Agent
3. **Verify**: Check logs to confirm it's running

See detailed instructions below.

## System Requirements

### macOS Version
- **macOS 10.14 (Mojave) or later** (tested on macOS 12+)
- The script uses system frameworks and commands available in modern macOS versions

### Required Software

1. **NordVPN macOS App**
   - **Required**: NordVPN app must be installed from the App Store or NordVPN website
   - Download from: https://nordvpn.com/download/mac/
   - **Note**: This script works with the NordVPN macOS GUI app, not a CLI tool
   - The script uses AppleScript to control the NordVPN app

2. **NordVPN Account**
   - You must have an active NordVPN account
   - Logged into the NordVPN app on your Mac

### System Dependencies

The script uses the following built-in macOS commands (all included with macOS):

- `bash` - Shell interpreter (version 3.2+)
- `curl` - HTTP client for captive portal detection
- `osascript` - AppleScript interpreter for controlling NordVPN app
- `ifconfig` - Network interface configuration
- `route` - Network routing table
- `pgrep` - Process search utility
- `open` - macOS application launcher
- `netstat` - Network statistics
- `awk` - Text processing
- `grep` - Text search
- `date` - Date/time utility

**All dependencies are included with macOS** - no additional installation required.

### System Settings & Permissions

#### 1. Accessibility Permissions (Required for VPN Control)

The script uses AppleScript to control NordVPN, which requires accessibility permissions:

1. Open **System Settings** (or **System Preferences** on older macOS)
2. Go to **Privacy & Security** → **Accessibility**
3. Click the **+** button or check the list
4. Add one of the following (depending on how the script runs):
   - **Terminal** (if running manually)
   - **Script Editor** (for testing)
   - **bash** or the script itself

**Why this is needed**: macOS requires explicit permission for applications to control other apps via AppleScript.

**To verify permissions are working:**
```bash
osascript -e 'tell application "NordVPN" to get state'
```
If this command works without prompting, permissions are correctly set.

#### 2. Network Permissions

The script needs network access to:
- Check internet connectivity
- Detect captive portals
- Monitor network changes

**No special permissions needed** - standard user network access is sufficient.

#### 3. Launch Agent Permissions

The Launch Agent runs as your user account and has access to:
- Your home directory
- Network interfaces
- System logs

**No special permissions needed** - standard user permissions are sufficient.

### Optional: Airport Command (for WiFi SSID detection)

The script uses the `airport` command to detect WiFi SSID. On some macOS versions, this may require:

1. Creating a symlink (if airport command is not found):
   ```bash
   sudo ln -s /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/local/bin/airport
   ```

2. Or the script will use network interface detection as a fallback

**Note**: The script includes fallback methods if the airport command is unavailable.

## Pre-Installation Checklist

Before installing, verify you have:

- [ ] macOS 10.14 (Mojave) or later
- [ ] NordVPN macOS app installed and running
- [ ] Active NordVPN account and logged into the app
- [ ] Terminal access with standard user permissions

## Installation Steps

### Step 1: Verify Dependencies

Check that all required commands are available:

```bash
# Check macOS version
sw_vers

# Check if NordVPN app is installed
ls -la /Applications/NordVPN.app

# Verify required commands
which curl osascript ifconfig route pgrep open awk grep date
```

All commands should return paths (they're built into macOS).

### Step 2: Set Up Accessibility Permissions

**Important**: Do this before installing the script to ensure VPN control works.

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the lock icon and enter your password
3. Click the **+** button
4. Navigate to `/usr/bin` and add **Terminal** (or add **Script Editor** for testing)
5. Ensure the checkbox is enabled

**Test permissions:**
```bash
osascript -e 'tell application "NordVPN" to get state'
```

If this works without errors, permissions are set correctly.

### Step 3: Copy the script to your home directory

```bash
cp nordvpn_captive_portal_handler.sh ~/nordvpn_captive_portal_handler.sh
chmod +x ~/nordvpn_captive_portal_handler.sh
```

### Step 4: Set up the Launch Agent (to run automatically at startup)

```bash
# Create LaunchAgents directory if it doesn't exist
mkdir -p ~/Library/LaunchAgents

# Edit the plist file and replace YOUR_USERNAME with your actual username
# You can find your username with: whoami
sed "s/YOUR_USERNAME/$(whoami)/g" com.user.nordvpn.captiveportal.plist > ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist

# Load the Launch Agent
launchctl load ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
```

### Step 5: Verify Installation

Check that the script is running:

```bash
# Check if script process is running
ps aux | grep nordvpn_captive_portal_handler | grep -v grep

# Check Launch Agent status
launchctl list | grep nordvpn

# Check logs
tail -20 ~/Library/Logs/nordvpn_captive_portal.log
```

You should see the script running and log entries indicating it has started.

## Manual Usage (Alternative)

If you prefer to run the script manually instead of automatically:

```bash
~/nordvpn_captive_portal_handler.sh
```

Keep this terminal window open. Press Ctrl+C to stop.

## How It Works

1. **Continuous Monitoring**: The script checks your network connection every 2 seconds
2. **Network Change Detection**: Immediately detects when you switch WiFi networks or network interfaces change
3. **Immediate VPN Disconnect**: When a network change is detected, it immediately disconnects NordVPN to prevent connection attempts during captive portal authentication
4. **Captive Portal Detection**: Uses Apple's captive portal detection mechanism (captive.apple.com) to identify login pages
5. **Automatic VPN Pause**: If a captive portal is detected, keeps VPN disconnected and opens the login page in your browser
6. **Auto-Resume**: Once you complete the login and internet connectivity is restored, it automatically reconnects NordVPN
7. **Timeout Protection**: If the captive portal isn't completed within 5 minutes, it checks connectivity and attempts to reconnect anyway

## Checking Logs

View the log file to see what the script is doing:

```bash
tail -f ~/Library/Logs/nordvpn_captive_portal.log
```

## Stopping the Script

### Temporarily stop:
```bash
launchctl stop com.user.nordvpn.captiveportal
```

### Permanently disable:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
```

### Remove completely:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
rm ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
rm ~/nordvpn_captive_portal_handler.sh
```

## Customization

You can edit the script (`~/nordvpn_captive_portal_handler.sh`) to adjust:

- `CHECK_INTERVAL`: How often to check network status (default: 2 seconds)
- `CAPTIVE_PORTAL_TIMEOUT`: Maximum time to wait for captive portal login (default: 300 seconds / 5 minutes)
- `NETWORK_STABILIZATION_DELAY`: Time to wait after network change before checking (default: 3 seconds)

After editing, restart the service:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
launchctl load ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
```

## Troubleshooting

### Script not running:
```bash
# Check if the Launch Agent is loaded
launchctl list | grep nordvpn

# Check if script process exists
ps aux | grep nordvpn_captive_portal_handler | grep -v grep

# View error logs
cat ~/Library/Logs/nordvpn_captive_portal_stderr.log
cat ~/Library/Logs/nordvpn_captive_portal_stdout.log

# Reload the Launch Agent
launchctl unload ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
launchctl load ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
```

### VPN not disconnecting/connecting:

**Check Accessibility Permissions:**
1. System Settings → Privacy & Security → Accessibility
2. Ensure Terminal (or Script Editor) is enabled
3. Try manually controlling NordVPN:
   ```bash
   osascript -e 'tell application "NordVPN" to disconnect'
   osascript -e 'tell application "NordVPN" to connect'
   ```

**Check if NordVPN app is running:**
```bash
pgrep -f NordVPN
# If not running, the script will launch it automatically
```

**Test AppleScript access:**
```bash
osascript -e 'tell application "NordVPN" to get state'
```
If this fails, check accessibility permissions.

### Network detection not working:

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

### Permissions issues:
```bash
# Ensure the script is executable
chmod +x ~/nordvpn_captive_portal_handler.sh

# Check file permissions
ls -la ~/nordvpn_captive_portal_handler.sh
ls -la ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
```

### Logs show errors:

**Check all log files:**
```bash
# Main log
tail -50 ~/Library/Logs/nordvpn_captive_portal.log

# Error log
tail -50 ~/Library/Logs/nordvpn_captive_portal_stderr.log

# Standard output log
tail -50 ~/Library/Logs/nordvpn_captive_portal_stdout.log
```

### Script keeps restarting:

This is normal - the Launch Agent has `KeepAlive` enabled, so it will restart if it crashes. Check error logs to see why it's crashing.

## System Integration

### Launch Agent Details

The script runs as a **Launch Agent**, which means:
- Starts automatically when you log in
- Runs in the background (no terminal window needed)
- Automatically restarts if it crashes
- Runs with your user permissions (not root)

### Log Files

All logs are stored in `~/Library/Logs/`:
- `nordvpn_captive_portal.log` - Main activity log
- `nordvpn_captive_portal_stdout.log` - Standard output
- `nordvpn_captive_portal_stderr.log` - Error messages

### Network Detection Methods

The script uses multiple methods to detect network changes:
1. WiFi SSID changes (via airport command or network interface)
2. Network interface changes (en0, en1, etc.)
3. Default route changes

### VPN Control Methods

The script uses multiple methods to control NordVPN:
1. AppleScript commands (primary method)
2. System Events keyboard shortcuts (fallback)
3. Network interface monitoring (for status detection)

## Notes

- The script uses Apple's captive portal detection mechanism (captive.apple.com)
- It automatically opens the captive portal page in your default browser when detected
- The script checks network status every 2 seconds for fast detection
- Network changes trigger immediate VPN disconnection to prevent conflicts
- The script will restart automatically if it crashes (KeepAlive is enabled)
- Works with NordVPN macOS GUI app (not CLI version)
- Requires accessibility permissions for AppleScript control

## Security & Privacy

- The script runs with your user permissions (not root/admin)
- No network traffic is intercepted or modified
- Only monitors network status and controls NordVPN app
- All logs are stored locally in your home directory
- No data is sent to external servers
- Script source code is available for review

## Complete Requirements Summary

### System Requirements
| Requirement | Details | How to Check |
|------------|---------|--------------|
| **macOS Version** | macOS 10.14 (Mojave) or later | `sw_vers` |
| **User Account** | Standard user account (admin not required) | `whoami` |
| **Terminal Access** | Terminal app or command line access | Open Terminal app |

### Software Requirements
| Software | Details | Installation |
|----------|---------|--------------|
| **NordVPN App** | macOS GUI app (not CLI) | Download from [nordvpn.com/download/mac](https://nordvpn.com/download/mac/) or App Store |
| **NordVPN Account** | Active subscription and logged in | Log into NordVPN app |

### System Dependencies (All Built-in)
All commands are included with macOS - **no installation needed**:

| Command | Purpose | Location |
|---------|---------|----------|
| `bash` | Shell interpreter | `/bin/bash` |
| `curl` | HTTP client for captive portal detection | `/usr/bin/curl` |
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

### System Settings & Permissions

#### 1. Accessibility Permissions (REQUIRED)

**Location**: System Settings → Privacy & Security → Accessibility

**Required For**: Controlling NordVPN app via AppleScript

**Steps**:
1. Open System Settings (or System Preferences on older macOS)
2. Navigate to Privacy & Security → Accessibility
3. Click lock icon and enter password
4. Click **+** button
5. Add **Terminal** (or **Script Editor** for testing)
6. Ensure checkbox is enabled

**Verify**:
```bash
osascript -e 'tell application "NordVPN" to get state'
```
Should work without errors or permission prompts.

#### 2. Network Permissions

**Required For**: Network monitoring and captive portal detection

**Status**: Standard user network access is sufficient - **no special permissions needed**

#### 3. Launch Agent Permissions

**Required For**: Running script as background service

**Status**: Standard user permissions sufficient - **no special permissions needed**

**Location**: `~/Library/LaunchAgents/` (user-specific, no admin required)

### File Locations

| File/Directory | Path | Purpose |
|----------------|------|---------|
| **Script** | `~/nordvpn_captive_portal_handler.sh` | Main script file |
| **Launch Agent** | `~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist` | Auto-start configuration |
| **Main Log** | `~/Library/Logs/nordvpn_captive_portal.log` | Activity log |
| **Error Log** | `~/Library/Logs/nordvpn_captive_portal_stderr.log` | Error messages |
| **Output Log** | `~/Library/Logs/nordvpn_captive_portal_stdout.log` | Standard output |

### Quick Verification Checklist

Before using the script, verify:

- [ ] macOS 10.14+ (`sw_vers`)
- [ ] NordVPN app installed (`ls -la /Applications/NordVPN.app`)
- [ ] NordVPN logged in (check NordVPN app)
- [ ] Accessibility permissions enabled (System Settings → Privacy & Security → Accessibility)
- [ ] AppleScript test works (`osascript -e 'tell application "NordVPN" to get state'`)
- [ ] All dependencies available (`which curl osascript ifconfig route pgrep`)
- [ ] Script is executable (`ls -la ~/nordvpn_captive_portal_handler.sh`)
- [ ] Launch Agent loaded (`launchctl list | grep nordvpn`)
- [ ] Script process running (`ps aux | grep nordvpn_captive_portal_handler`)
- [ ] Logs being written (`tail ~/Library/Logs/nordvpn_captive_portal.log`)

### Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| **VPN not disconnecting** | Enable accessibility permissions for Terminal |
| **Script not running** | Check Launch Agent status, reload if needed |
| **AppleScript errors** | Verify NordVPN app is running and permissions are set |
| **Network not detected** | Check WiFi connection and network interface |
| **Permission denied** | Ensure script is executable (`chmod +x`) |

For detailed troubleshooting, see the Troubleshooting section above.
