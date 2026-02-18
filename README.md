# NordVPN Captive Portal Handler

Automatically manages NordVPN on macOS to prevent crash loops when connecting to WiFi networks with captive portals (hotel, coffee shop, airport logins).

## Quick Reference

```bash
# Service
~/nordvpn_helper_control.sh start       # Turn the script ON
~/nordvpn_helper_control.sh stop        # Turn the script OFF
~/nordvpn_helper_control.sh restart     # Restart (also relaunches NordVPN)
~/nordvpn_helper_control.sh status      # Is it running? What networks are trusted?
~/nordvpn_helper_control.sh logs        # Watch live logs (Ctrl+C to exit)

# Trusted networks (WiFi SSIDs where VPN will NOT connect)
~/nordvpn_helper_control.sh trust       # Trust the WiFi you're on right now
~/nordvpn_helper_control.sh trust "Name"    # Trust a network by name
~/nordvpn_helper_control.sh untrust         # Remove current WiFi from trust list
~/nordvpn_helper_control.sh untrust "Name"  # Remove a network by name
~/nordvpn_helper_control.sh trusted         # List all trusted networks
```

## Problem Solved

When connecting to a captive portal network, NordVPN's auto-connect triggers before you can reach the login page. This causes:
- NordVPN spinning and failing to connect indefinitely
- No way to reach the captive portal login page
- Crash loops requiring manual intervention

## How It Works

1. **Disables NordVPN auto-connect** on startup so this script has full control
2. **Disconnects VPN** immediately on any network change
3. **Pings a canary** (google.com) every 2 seconds to detect when real internet is available
4. **Connects VPN** automatically once the canary responds — unless the network is trusted
5. **Re-enables auto-connect** when the script is stopped cleanly

```
No Network ──► Waiting ──► (canary passes, not trusted) ──► VPN Connected
                  │                                               │
                  └──► (canary passes, trusted SSID) ──► VPN Off │
                                                                  │
              (network lost) ◄────────────────────────────────────┘
```

> **Why disable auto-connect?** NordVPN loads `isAutoConnectOn` into memory at app startup and caches it. The only way to reliably prevent NordVPN from fighting the script is to disable auto-connect before the session begins. The script re-enables it on clean exit.

## Required NordVPN Settings

| Setting | Required value | Notes |
|---------|----------------|-------|
| **Auto-connect** | ON in NordVPN app | Script manages this automatically — it disables auto-connect on startup, re-enables on stop |

No other NordVPN settings need to change. Trusted networks are managed by this script (see below), not by NordVPN's built-in Trusted Networks feature.

## Requirements

### System
- macOS 10.14 (Mojave) or later
- Standard user account (no admin/root required)

### Software
- **NordVPN** for macOS, installed and logged in — https://nordvpn.com/download/mac/

### Dependencies (all built into macOS)

| Command | Purpose |
|---------|---------|
| `bash` | Shell interpreter |
| `ping` | Canary connectivity check |
| `osascript` | Sends `nordvpn://connect` / `nordvpn://disconnect` URL schemes to NordVPN |
| `defaults` | Reads/writes NordVPN's auto-connect preference |
| `route` | Detects active network interface |
| `pgrep` | Checks if NordVPN process is running |
| `open` | Launches NordVPN app if not already running |

**Verify all are present:**
```bash
which bash ping osascript defaults route pgrep open
```

### Accessibility Permissions

The script uses AppleScript to send URL schemes to NordVPN. Terminal needs Accessibility access:

1. **System Settings → Privacy & Security → Accessibility**
2. Click the lock icon and authenticate
3. Click **+**, add **Terminal**, enable the checkbox

**Quick test:**
```bash
osascript -e 'open location "nordvpn://disconnect"'
osascript -e 'open location "nordvpn://connect"'
```

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/ashwinraghavachari/nordvpn_helper.git
cd nordvpn_helper
```

### 2. Grant Accessibility permissions to Terminal (see above)

### 3. Install the scripts

```bash
cp nordvpn_captive_portal_handler.sh ~/nordvpn_captive_portal_handler.sh
chmod +x ~/nordvpn_captive_portal_handler.sh

cp control.sh ~/nordvpn_helper_control.sh
chmod +x ~/nordvpn_helper_control.sh
```

### 4. Install the Launch Agent

```bash
mkdir -p ~/Library/LaunchAgents
sed "s/YOUR_USERNAME/$(whoami)/g" com.user.nordvpn.captiveportal.plist \
    > ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
```

### 5. Start

```bash
~/nordvpn_helper_control.sh start
```

### 6. Verify

```bash
~/nordvpn_helper_control.sh status
```

## Trusted Networks

Networks where you **don't want VPN** (e.g. home, office). On these networks the script lets the canary pass but skips connecting VPN.

### Using control.sh (recommended)

```bash
# Trust the network you're currently connected to
~/nordvpn_helper_control.sh trust

# Trust a specific network by name
~/nordvpn_helper_control.sh trust "My Home WiFi"

# Remove the current network from the trusted list
~/nordvpn_helper_control.sh untrust

# Remove a specific network by name
~/nordvpn_helper_control.sh untrust "My Home WiFi"

# Show all trusted networks
~/nordvpn_helper_control.sh trusted
```

### Editing the file directly

Trusted networks are stored one SSID per line in `~/.nordvpn_trusted_networks`:

```bash
# Add a network
echo "My Home WiFi" >> ~/.nordvpn_trusted_networks

# View all
cat ~/.nordvpn_trusted_networks

# Edit
nano ~/.nordvpn_trusted_networks
```

No restart needed — the script reads the file on every network change.

## Control Commands

```bash
~/nordvpn_helper_control.sh start       # Enable and start
~/nordvpn_helper_control.sh stop        # Disable and stop
~/nordvpn_helper_control.sh status      # Status + trusted network list
~/nordvpn_helper_control.sh restart     # Restart
~/nordvpn_helper_control.sh logs        # Live log stream (Ctrl+C to exit)

~/nordvpn_helper_control.sh trust       # Trust current WiFi
~/nordvpn_helper_control.sh trust NAME  # Trust a named network
~/nordvpn_helper_control.sh untrust     # Untrust current WiFi
~/nordvpn_helper_control.sh untrust NAME # Untrust a named network
~/nordvpn_helper_control.sh trusted     # List trusted networks
```

## Logs

```bash
tail -f ~/Library/Logs/nordvpn_captive_portal.log
cat ~/Library/Logs/nordvpn_captive_portal_stderr.log
```

## Troubleshooting

**VPN not connecting after captive portal login**
- Confirm canary is reachable: `ping -c 1 google.com`
- Check logs: `~/nordvpn_helper_control.sh logs`
- Make sure the network is not in the trusted list: `~/nordvpn_helper_control.sh trusted`

**VPN not disconnecting on network change**
- Verify Terminal has Accessibility permission (see above)
- Test manually: `osascript -e 'open location "nordvpn://disconnect"'`

**NordVPN reconnecting on its own (fighting the script)**
- The script should have disabled auto-connect at startup
- Check: `defaults read ~/Library/Preferences/com.nordvpn.macos.plist isAutoConnectOn`
  - Should be `0` while the script is running
- Restart the script: `~/nordvpn_helper_control.sh restart`

**Script not running**
```bash
~/nordvpn_helper_control.sh status
launchctl list | grep nordvpn
cat ~/Library/Logs/nordvpn_captive_portal_stderr.log
```

## Customization

Edit `~/nordvpn_captive_portal_handler.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `CHECK_INTERVAL` | `2` | Seconds between canary pings while waiting |
| `NETWORK_SETTLE_DELAY` | `2` | Seconds to wait after a network change |
| `CANARY_HOST` | `google.com` | Host to ping to detect internet |

After editing: `~/nordvpn_helper_control.sh restart`

## Uninstall

```bash
~/nordvpn_helper_control.sh stop
rm ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
rm ~/nordvpn_captive_portal_handler.sh
rm ~/nordvpn_helper_control.sh
rm ~/.nordvpn_trusted_networks   # optional
```

## Files

| File | Description |
|------|-------------|
| `nordvpn_captive_portal_handler.sh` | Main background script |
| `control.sh` | Service and trusted-network management |
| `com.user.nordvpn.captiveportal.plist` | Launch Agent (auto-start on login) |
| `test_pause_resume.sh` | Pause/resume mechanism test |
| `TESTING.md` | Manual testing guide |

## Security & Privacy

- Runs with standard user permissions (no root/admin)
- Only monitors network state and controls NordVPN
- All logs stored locally in `~/Library/Logs/`
- No external data transmission beyond the canary ping to google.com
