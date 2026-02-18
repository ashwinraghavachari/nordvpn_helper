# NordVPN Captive Portal Handler

Automatically prevents NordVPN from spin-looping on WiFi networks with captive portals, while leaving NordVPN's own auto-connect and trusted-network settings fully in charge.

## Problem Solved

When connecting to WiFi networks with captive portals (public WiFi login pages), NordVPN's auto-connect triggers before you can authenticate. This causes:
- Connection failures and NordVPN spinning indefinitely
- Inability to reach the captive portal login page
- Crash loops requiring manual intervention

## How It Works (Hybrid Approach)

NordVPN's **auto-connect stays ON** at all times. The script acts only as a temporary "hold" during captive portal authentication, then hands full control back to NordVPN.

1. **On network change**: temporarily disables auto-connect and disconnects VPN to stop NordVPN fighting the captive portal
2. **Pings a canary** (google.com) every 2 seconds to detect when real internet is available
3. **Once the canary passes**: re-enables auto-connect — NordVPN reconnects on its own, applying its own **Trusted Networks** logic
4. **On clean exit**: always re-enables auto-connect so NordVPN is left in a normal state

Because NordVPN handles the reconnect decision, its built-in **Trusted Networks** setting works exactly as configured in the NordVPN app — no separate config file needed.

```
No Network ──► Paused (auto-connect off, VPN disconnected)
                  │
                  │  canary ping succeeds
                  ▼
              Active (auto-connect re-enabled → NordVPN decides)
                  │
                  │  network lost
                  ▼
              No Network
```

## Required NordVPN Settings

| Setting | Value | Why |
|---------|-------|-----|
| **Auto-connect** | ON | The script re-enables this; NordVPN uses it to reconnect after captive portal auth |
| **Trusted Networks** | Configure in NordVPN app | NordVPN's own logic — the script does not interfere |

Configure Trusted Networks in: **NordVPN → Preferences → Auto-connect → Trusted Networks**

## Requirements

### System Requirements
- **macOS 10.14 (Mojave) or later**
- Standard user account (no admin/root required)

### Software Requirements
- **NordVPN macOS App** installed and logged in
  - Download: https://nordvpn.com/download/mac/
- **Auto-connect must be ON** in NordVPN settings (the script temporarily disables/re-enables it as needed)

### Dependencies
All built into macOS — no additional installation needed:

| Command | Purpose |
|---------|---------|
| `bash` | Shell interpreter |
| `ping` | Canary connectivity check |
| `osascript` | Controls NordVPN via URL scheme (`nordvpn://disconnect`) |
| `defaults` | Reads/writes NordVPN preferences (auto-connect toggle) |
| `route` | Detects active network interface |
| `pgrep` | Checks if NordVPN is running |
| `open` | Launches NordVPN app if not already running |

**Verify:**
```bash
which bash ping osascript defaults route pgrep open
```

### Accessibility Permissions (Required)

The script uses AppleScript URL schemes to control NordVPN:

1. **System Settings → Privacy & Security → Accessibility**
2. Click the lock icon, enter your password
3. Click **+** and add **Terminal**
4. Ensure the checkbox is enabled

**Test it works:**
```bash
osascript -e 'open location "nordvpn://disconnect"'
osascript -e 'open location "nordvpn://connect"'
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

### VPN not reconnecting after captive portal login

- Check logs: `~/nordvpn_helper_control.sh logs`
- Verify auto-connect is ON in NordVPN → Preferences → Auto-connect
- Confirm canary is reachable: `ping -c 1 google.com`

### VPN not disconnecting on network change

- Check Accessibility permissions for Terminal (see above)
- Test manually:
  ```bash
  osascript -e 'open location "nordvpn://disconnect"'
  ```

### Auto-connect toggle not working

- Check the plist key directly:
  ```bash
  defaults read ~/Library/Preferences/com.nordvpn.macos.plist isAutoConnectOn
  ```
  Should flip between `0` (paused) and `1` (active) as the script runs.

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
| `CHECK_INTERVAL` | `2` | Seconds between canary pings while waiting |
| `NETWORK_SETTLE_DELAY` | `2` | Seconds to wait after a network change |
| `CANARY_HOST` | `google.com` | Host to ping to detect real internet |

After editing, restart: `~/nordvpn_helper_control.sh restart`

## Uninstall

```bash
~/nordvpn_helper_control.sh stop
rm ~/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist
rm ~/nordvpn_captive_portal_handler.sh
rm ~/nordvpn_helper_control.sh
```

## Files

| File | Description |
|------|-------------|
| `nordvpn_captive_portal_handler.sh` | Main script |
| `control.sh` | Master switch |
| `com.user.nordvpn.captiveportal.plist` | Launch Agent config |
| `test_vpn_connect.sh` | VPN control diagnostic script |
| `TESTING.md` | Detailed testing guide |

## Security & Privacy

- Runs with standard user permissions (no root/admin)
- Only monitors network status and temporarily toggles NordVPN's auto-connect
- All logs stored locally
- No external data transmission beyond the canary ping to google.com
