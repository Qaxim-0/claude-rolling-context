#!/usr/bin/env bash
# Install the Rolling Context plugin for Claude Code.
#
# Pure stdlib — no pip install needed. Just requires Python 3.7+.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_DIR="$SCRIPT_DIR/proxy"
PORT="${ROLLING_CONTEXT_PORT:-5588}"
PROXY_URL="http://127.0.0.1:$PORT"

echo "=== Rolling Context Proxy Installer ==="
echo ""

# 1. Check Python is available
echo "[1/3] Checking Python..."
if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 --version 2>&1)
    echo "  Found $PY_VERSION (pure stdlib — no pip install needed)"
elif command -v python &>/dev/null; then
    PY_VERSION=$(python --version 2>&1)
    echo "  Found $PY_VERSION (pure stdlib — no pip install needed)"
else
    echo "  ERROR: Python not found. Install Python 3.7+ and try again."
    exit 1
fi

# 2. Configure ANTHROPIC_BASE_URL in shell profile
echo "[2/3] Configuring ANTHROPIC_BASE_URL..."

SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_PROFILE="$HOME/.bash_profile"
fi

if [ -n "$SHELL_PROFILE" ]; then
    if grep -q "ANTHROPIC_BASE_URL" "$SHELL_PROFILE" 2>/dev/null; then
        EXISTING=$(grep "ANTHROPIC_BASE_URL" "$SHELL_PROFILE" | head -1)
        if echo "$EXISTING" | grep -q "127\.0\.0\.1.*$PORT"; then
            echo "  ANTHROPIC_BASE_URL already set in $SHELL_PROFILE"
        else
            # Chain through existing proxy
            echo "export ROLLING_CONTEXT_UPSTREAM=\"\$ANTHROPIC_BASE_URL\"" >> "$SHELL_PROFILE"
            sed -i.bak "s|export ANTHROPIC_BASE_URL=.*|export ANTHROPIC_BASE_URL=\"$PROXY_URL\"|" "$SHELL_PROFILE"
            rm -f "$SHELL_PROFILE.bak"
            echo "  Chaining: ANTHROPIC_BASE_URL=$PROXY_URL -> existing upstream"
        fi
    else
        echo "" >> "$SHELL_PROFILE"
        echo "# Rolling Context proxy for Claude Code" >> "$SHELL_PROFILE"
        echo "export ANTHROPIC_BASE_URL=\"$PROXY_URL\"" >> "$SHELL_PROFILE"
        echo "  Added ANTHROPIC_BASE_URL to $SHELL_PROFILE"
    fi
else
    echo "  Could not detect shell profile. Add this to your shell config manually:"
    echo "  export ANTHROPIC_BASE_URL=\"$PROXY_URL\""
fi

export ANTHROPIC_BASE_URL="$PROXY_URL"

# 3. Register plugin
echo "[3/3] Registering Claude Code plugin..."

PLUGIN_LINK="$HOME/.claude/plugins/rolling-context"
mkdir -p "$HOME/.claude/plugins"

if [ -L "$PLUGIN_LINK" ] || [ -d "$PLUGIN_LINK" ]; then
    rm -rf "$PLUGIN_LINK"
fi
ln -s "$SCRIPT_DIR" "$PLUGIN_LINK"
echo "  Plugin linked at $PLUGIN_LINK"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "The proxy will auto-start when you launch Claude Code."
echo "To start it manually: cd $PROXY_DIR && python3 server.py"
echo ""
echo "Configuration (via environment variables):"
echo "  ROLLING_CONTEXT_PORT    = $PORT"
echo "  ROLLING_CONTEXT_TRIGGER = ${ROLLING_CONTEXT_TRIGGER:-80000} tokens"
echo "  ROLLING_CONTEXT_TARGET  = ${ROLLING_CONTEXT_TARGET:-40000} tokens"
echo ""
echo "Restart your terminal or run: source $SHELL_PROFILE"
