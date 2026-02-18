# NordVPN Captive Portal Handler

Automatically manages NordVPN connections to prevent crash loops on WiFi networks with captive portals.

## Problem Solved

When connecting to WiFi networks with captive portals (public WiFi login pages), NordVPN's auto-connect triggers before you can authenticate. This causes:
- Connection failures and NordVPN spinning indefinitely
- Inability to reach the captive portal login page
- Crash loops requiring manual intervention

## How It Works

1. **Disables NordVPN auto-connect** on startup so the script has full control
2. **Disconnects VPN** immediately when a network change is detected
3. **Pings a canary** (google.com) every 2 seconds to detect real internet
4. **Connects VPN** automatically once the canary responds (captive portal cleared)
5. **Re-enables auto-connect** when the script is stopped cleanly

**Trusted networks**: SSIDs you add to `~/.nordvpn_trusted_networks` skip VPN connection entirely (e.g. home, office).

```
No Network ──► Waiting ──► (canary succeeds) ──► VPN Connected
                  │                                    │
                  └──► (trusted network) ──► Trusted   │
                                                       │
              (network lost) ◄────────────────────────┘
```

## Requirements

### System Requirements
- **macOS 10.14 (Mojave) or later**
- Standard user account (no admin/root required)

### Software Requirements
- **NordVPN macOS App** installed and logged in
  - Download: https://nordvpn.com/download/mac/
- **Disable NordVPN auto-connect** — the script manages this automatically, but verify it is off in NordVPN → Settings → Auto-connect

### Dependencies
All built into macOS — no additional installation needed:

| Command | Purpose |
|---------|---------|
| `bash` | Shell interpreter |
| `ping` | Canary connectivity check |
| `osascript` | Controls NordVPN app via AppleScript |
| `defaults` | Reads/writes NordVPN preferences |
| `route` | Detects active network interface |
| `pgrep` | Checks if NordVPN is running |
| `open` | Launches NordVPN app if needed |

**Verify:**
```bash
which bash ping osascript defaults route pgrep open
```

### Accessibility Permissions (Required)

The script uses AppleScript to control NordVPN:

1. **System Settings → Privacy & Security → Accessibility**
2. Click the lock icon, enter your password
3. Click **+** and add **Terminal**
4. Ensure the checkbox is enabled

**Test it works:**
```bash
osascript -e 'tell application "NordVPN" to get state'
```

## Installation

### 1. Download

Clone or download this repository.

### 2. Verify Accessibility Permissions

Set them up now (see above) before installing.

### 3. Install the scripts

```bash
cd /path/to/nordvpn_helper

# Install main script
cp nordvpn_captive_portal_handler.sh ~/nordvpn_captive_portal_handler.sh
chmod +x ~/nordvpn_captive_portal_handler.sh

# Install control script
cp control.sh ~/nordvpn_helper_control.sh
chmod +x ~/nordvpn_helper_control.sh
```

### 4. Set up the Launch Agent

```bash
mkdir -p ~/Library/LaunchAgents
sed "s/YOUR_USERNAME/$(whoami)/g" com.user.nordvpn.captiveportal.plist \
    > ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
```

### 5. Enable and start

```bash
~/nordvpn_helper_control.sh start
```

### 6. Verify

```bash
~/nordvpn_helper_control.sh status
tail -f ~/Library/Logs/nordvpn_captive_portal.log
```

## Trusted Networks

Networks where you don't want the VPN to connect (e.g. home, office).

**Add a trusted network:**
```bash
echo "MyHomeNetwork" >> ~/.nordvpn_trusted_networks
```

**View trusted networks:**
```bash
cat ~/.nordvpn_trusted_networks
```

**Remove a trusted network:**
```bash
# Edit the file and delete the line
nano ~/.nordvpn_trusted_networks
```

One SSID per line, exact match. Example `~/.nordvpn_trusted_networks`:
```
MyHomeWiFi
OfficeNetwork
```

## Control Script (Master Switch)

```bash
~/nordvpn_helper_control.sh start    # Enable and start
~/nordvpn_helper_control.sh stop     # Disable and stop
~/nordvpn_helper_control.sh status   # Check if running
~/nordvpn_helper_control.sh restart  # Restart
~/nordvpn_helper_control.sh logs     # View live logs
```

## Logs

```bash
# Live logs
tail -f ~/Library/Logs/nordvpn_captive_portal.log

# Error logs
cat ~/Library/Logs/nordvpn_captive_portal_stderr.log
```

## Troubleshooting

### VPN not connecting after captive portal login

- Check if canary is reachable: `ping -c 1 google.com`
- Check logs: `~/nordvpn_helper_control.sh logs`

### VPN not disconnecting on network change

- Check accessibility permissions for Terminal
- Test manually: `osascript -e 'tell application "NordVPN" to disconnect'`

### Auto-connect not being disabled

- Check NordVPN preferences key:
  ```bash
  defaults read ~/Library/Preferences/com.nordvpn.macos.plist isAutoConnectOn
  ```
  Should be `0`. If not, disable it manually in NordVPN → Settings → Auto-connect.

### Script not running

```bash
~/nordvpn_helper_control.sh status
launchctl list | grep nordvpn
cat ~/Library/Logs/nordvpn_captive_portal_stderr.log
```

## Customization

Edit `~/nordvpn_captive_portal_handler.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `CHECK_INTERVAL` | `2` | Seconds between canary pings |
| `NETWORK_SETTLE_DELAY` | `2` | Seconds to wait after network change |
| `CANARY_HOST` | `google.com` | Host to ping to detect internet |

After editing, restart: `~/nordvpn_helper_control.sh restart`

## Uninstall

```bash
~/nordvpn_helper_control.sh stop
rm ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
rm ~/nordvpn_captive_portal_handler.sh
rm ~/nordvpn_helper_control.sh
rm ~/.nordvpn_trusted_networks  # optional
```

## Files

| File | Description |
|------|-------------|
| `nordvpn_captive_portal_handler.sh` | Main script |
| `control.sh` | Master switch |
| `com.user.nordvpn.captiveportal.plist` | Launch Agent config |
| `test_script.sh` | Automated test suite |
| `TESTING.md` | Detailed testing guide |
| `~/.nordvpn_trusted_networks` | Your trusted SSIDs (you create this) |

## Security & Privacy

- Runs with standard user permissions (no root/admin)
- Only monitors network status and controls NordVPN app
- All logs stored locally
- No external data transmission beyond the canary ping to google.com
