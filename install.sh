#!/usr/bin/env bash
# Install the Rolling Context plugin for Claude Code.
#
# This script:
# 1. Sets up the Python venv and installs dependencies
# 2. Configures ANTHROPIC_BASE_URL to route through the proxy
# 3. Registers the plugin with Claude Code

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_DIR="$SCRIPT_DIR/proxy"
PORT="${ROLLING_CONTEXT_PORT:-5588}"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo "=== Rolling Context Proxy Installer ==="
echo ""

# 1. Set up Python venv
echo "[1/3] Setting up Python environment..."
cd "$PROXY_DIR"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
./venv/bin/pip install -q -r requirements.txt
echo "  Done."

# 2. Configure ANTHROPIC_BASE_URL in shell profile
echo "[2/3] Configuring ANTHROPIC_BASE_URL..."

PROXY_URL="http://127.0.0.1:$PORT"
EXPORT_LINE="export ANTHROPIC_BASE_URL=\"$PROXY_URL\""

# Detect shell profile
SHELL_PROFILE=""
if [ -f "$HOME/.bashrc" ]; then
    SHELL_PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_PROFILE="$HOME/.bash_profile"
fi

if [ -n "$SHELL_PROFILE" ]; then
    if ! grep -q "ANTHROPIC_BASE_URL" "$SHELL_PROFILE" 2>/dev/null; then
        echo "" >> "$SHELL_PROFILE"
        echo "# Rolling Context Proxy for Claude Code" >> "$SHELL_PROFILE"
        echo "$EXPORT_LINE" >> "$SHELL_PROFILE"
        echo "  Added ANTHROPIC_BASE_URL to $SHELL_PROFILE"
    else
        echo "  ANTHROPIC_BASE_URL already set in $SHELL_PROFILE"
    fi
else
    echo "  Could not detect shell profile. Add this to your shell config manually:"
    echo "  $EXPORT_LINE"
fi

# Also export for current session
export ANTHROPIC_BASE_URL="$PROXY_URL"

# 3. Register plugin
echo "[3/3] Registering Claude Code plugin..."

# Create the plugins directory entry
PLUGIN_LINK="$HOME/.claude/plugins/rolling-context"
mkdir -p "$HOME/.claude/plugins"

# Create a symlink or config pointing to our plugin
if [ -L "$PLUGIN_LINK" ] || [ -d "$PLUGIN_LINK" ]; then
    rm -rf "$PLUGIN_LINK"
fi
ln -s "$SCRIPT_DIR" "$PLUGIN_LINK"
echo "  Plugin linked at $PLUGIN_LINK"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "The proxy will auto-start when you launch Claude Code."
echo "To start it manually: cd $PROXY_DIR && ./venv/bin/python server.py"
echo ""
echo "Configuration (via environment variables):"
echo "  ROLLING_CONTEXT_PORT    = $PORT"
echo "  ROLLING_CONTEXT_TRIGGER = ${ROLLING_CONTEXT_TRIGGER:-80000} tokens"
echo "  ROLLING_CONTEXT_TARGET  = ${ROLLING_CONTEXT_TARGET:-40000} tokens"
echo "  ROLLING_CONTEXT_MODEL   = ${ROLLING_CONTEXT_MODEL:-claude-haiku-latest}"
echo ""
echo "Restart your terminal or run: source $SHELL_PROFILE"
