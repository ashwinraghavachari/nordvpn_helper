#!/bin/bash

# NordVPN Captive Portal Handler - Control Script
# Easy way to enable/disable the script

PLIST_PATH="$HOME/Library/LaunchAgents/com.user.nordvpn.captiveportal.plist"
SERVICE_NAME="com.user.nordvpn.captiveportal"

case "$1" in
    start|enable|on)
        echo "Enabling NordVPN Captive Portal Handler..."
        if [ ! -f "$PLIST_PATH" ]; then
            echo "Error: Launch Agent not found at $PLIST_PATH"
            echo "Please run the installation first."
            exit 1
        fi
        
        # Load the Launch Agent
        launchctl load "$PLIST_PATH" 2>/dev/null || launchctl load -w "$PLIST_PATH" 2>/dev/null
        
        sleep 1
        if launchctl list | grep -q "$SERVICE_NAME"; then
            echo "✅ Script enabled and running"
        else
            echo "⚠️  Script may not have started. Check logs:"
            echo "   tail -f ~/Library/Logs/nordvpn_captive_portal.log"
        fi
        ;;
        
    stop|disable|off)
        echo "Disabling NordVPN Captive Portal Handler..."
        launchctl unload "$PLIST_PATH" 2>/dev/null
        
        sleep 1
        if launchctl list | grep -q "$SERVICE_NAME"; then
            echo "⚠️  Script may still be running. Try:"
            echo "   launchctl unload -w $PLIST_PATH"
        else
            echo "✅ Script disabled"
        fi
        ;;
        
    status|check)
        if launchctl list | grep -q "$SERVICE_NAME"; then
            echo "✅ Script is ENABLED and running"
            echo ""
            echo "Process info:"
            ps aux | grep nordvpn_captive_portal_handler | grep -v grep | sed 's/^/   /'
            echo ""
            echo "Recent log entries:"
            tail -3 ~/Library/Logs/nordvpn_captive_portal.log 2>/dev/null | sed 's/^/   /' || echo "   No log entries"
        else
            echo "❌ Script is DISABLED"
        fi
        ;;
        
    restart|reload)
        echo "Restarting NordVPN Captive Portal Handler..."
        launchctl unload "$PLIST_PATH" 2>/dev/null
        sleep 2
        launchctl load "$PLIST_PATH" 2>/dev/null
        sleep 1
        if launchctl list | grep -q "$SERVICE_NAME"; then
            echo "✅ Script restarted"
        else
            echo "⚠️  Script may not have restarted. Check logs:"
            echo "   tail -f ~/Library/Logs/nordvpn_captive_portal.log"
        fi
        ;;
        
    logs)
        echo "Showing recent log entries (Ctrl+C to exit):"
        echo ""
        tail -f ~/Library/Logs/nordvpn_captive_portal.log
        ;;
        
    *)
        echo "NordVPN Captive Portal Handler - Control Script"
        echo ""
        echo "Usage: $0 {start|stop|status|restart|logs}"
        echo ""
        echo "Commands:"
        echo "  start, enable, on    - Enable and start the script"
        echo "  stop, disable, off   - Disable and stop the script"
        echo "  status, check        - Check if script is running"
        echo "  restart, reload      - Restart the script"
        echo "  logs                 - View live logs"
        echo ""
        echo "Examples:"
        echo "  $0 start              # Enable the script"
        echo "  $0 stop               # Disable the script"
        echo "  $0 status             # Check status"
        echo ""
        exit 1
        ;;
esac

exit 0
