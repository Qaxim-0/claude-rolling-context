#!/usr/bin/env bash
# Uninstall the Rolling Context plugin.

set -e

PIDFILE="$HOME/.claude/rolling-context-proxy.pid"
PLUGIN_LINK="$HOME/.claude/plugins/rolling-context"

echo "=== Uninstalling Rolling Context ==="

# Stop proxy if running
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        echo "Stopped proxy (PID $PID)"
    fi
    rm -f "$PIDFILE"
fi

# Remove plugin link
if [ -L "$PLUGIN_LINK" ] || [ -d "$PLUGIN_LINK" ]; then
    rm -rf "$PLUGIN_LINK"
    echo "Removed plugin link"
fi

# Remove ANTHROPIC_BASE_URL from shell profiles
for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [ -f "$profile" ]; then
        if grep -q "Rolling Context Proxy" "$profile" 2>/dev/null; then
            sed -i '/# Rolling Context Proxy/d' "$profile"
            sed -i '/ANTHROPIC_BASE_URL.*127.0.0.1.*5588/d' "$profile"
            echo "Cleaned $profile"
        fi
    fi
done

echo ""
echo "Uninstalled. Restart your terminal to complete."
