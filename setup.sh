#!/bin/bash
#
# setup.sh — Install nordvpn-helper and wire it into your shell PATH.
#
# What this does:
#   1. Makes repo scripts executable
#   2. Creates ~/.local/bin/nordvpn-helper → <this repo>/nordvpn-helper (symlink)
#   3. Adds ~/.local/bin to PATH in ~/.zshrc (if not already present)
#   4. Installs the Launch Agent plist pointing at this repo's handler script
#   5. Starts the Launch Agent so the handler runs immediately and on every login
#
# Nothing is copied out of the repo — all scripts stay here.
# Re-run this script any time you move the repo to a new location.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
PLIST_SRC="$REPO_DIR/com.user.nordvpn.captiveportal.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist"
SHELL_RC="$HOME/.zshrc"

echo "Setting up nordvpn-helper from: $REPO_DIR"
echo ""

# ── 1. Make scripts executable ─────────────────────────────────
echo "[1/5] Making scripts executable..."
chmod +x "$REPO_DIR/nordvpn-helper"
chmod +x "$REPO_DIR/nordvpn_captive_portal_handler.sh"
echo "      Done."

# ── 2. Symlink nordvpn-helper into ~/.local/bin ────────────────
echo "[2/5] Creating symlink in $BIN_DIR..."
mkdir -p "$BIN_DIR"
ln -sf "$REPO_DIR/nordvpn-helper" "$BIN_DIR/nordvpn-helper"
echo "      $BIN_DIR/nordvpn-helper → $REPO_DIR/nordvpn-helper"

# ── 3. Add ~/.local/bin to PATH in ~/.zshrc ────────────────────
echo "[3/5] Checking PATH in $SHELL_RC..."
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if grep -qF '.local/bin' "$SHELL_RC" 2>/dev/null; then
    echo "      ~/.local/bin already in $SHELL_RC — skipping."
else
    echo "" >> "$SHELL_RC"
    echo "# Added by nordvpn-helper setup" >> "$SHELL_RC"
    echo "$PATH_LINE" >> "$SHELL_RC"
    echo "      Added to $SHELL_RC."
fi

# Make it available in this shell session too
export PATH="$BIN_DIR:$PATH"

# ── 4. Install Launch Agent plist ─────────────────────────────
echo "[4/5] Installing Launch Agent..."
mkdir -p "$HOME/Library/LaunchAgents"
sed \
    -e "s|REPO_DIR|$REPO_DIR|g" \
    -e "s|HOME_DIR|$HOME|g" \
    "$PLIST_SRC" > "$PLIST_DEST"
echo "      Installed: $PLIST_DEST"
echo "      Handler path: $REPO_DIR/nordvpn_captive_portal_handler.sh"

# ── 5. Start the Launch Agent ──────────────────────────────────
echo "[5/5] Starting the handler..."
launchctl unload "$PLIST_DEST" 2>/dev/null || true
sleep 1
launchctl load "$PLIST_DEST"
sleep 2

if launchctl list | grep -q "com.user.nordvpn.captiveportal"; then
    echo "      Handler is running."
else
    echo "      Warning: handler may not have started. Check logs:"
    echo "      nordvpn-helper logs"
fi

# ── Done ───────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setup complete."
echo ""
echo "Reload your shell to use nordvpn-helper from anywhere:"
echo "  source ~/.zshrc"
echo ""
echo "Then try:"
echo "  nordvpn-helper status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
