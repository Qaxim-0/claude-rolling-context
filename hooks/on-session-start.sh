#!/usr/bin/env bash
# Auto-start the rolling context proxy if it's not already running.
# Also ensures ANTHROPIC_BASE_URL is set for future sessions.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_DIR="$SCRIPT_DIR/../proxy"
PIDFILE="$HOME/.claude/rolling-context-proxy.pid"
PORT="${ROLLING_CONTEXT_PORT:-5588}"
PROXY_URL="http://127.0.0.1:$PORT"

# Ensure ANTHROPIC_BASE_URL is set for future sessions
if [ -z "$ANTHROPIC_BASE_URL" ]; then
    SHELL_RC=""
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        SHELL_RC="$HOME/.bash_profile"
    fi
    if [ -n "$SHELL_RC" ]; then
        if ! grep -q "ANTHROPIC_BASE_URL" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# Rolling Context proxy for Claude Code" >> "$SHELL_RC"
            echo "export ANTHROPIC_BASE_URL=$PROXY_URL" >> "$SHELL_RC"
            echo "Rolling context: added ANTHROPIC_BASE_URL to $SHELL_RC (restart terminal to activate)"
        fi
    fi
fi

# Check if proxy is already running
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        exit 0
    fi
    rm -f "$PIDFILE"
fi

# Check if something is already listening on the port
if command -v curl &>/dev/null; then
    if curl -s "$PROXY_URL/health" &>/dev/null; then
        exit 0
    fi
fi

# Start the proxy in the background
cd "$PROXY_DIR" || exit 1

if [ ! -d "venv" ]; then
    python3 -m venv venv 2>/dev/null || python -m venv venv 2>/dev/null
    ./venv/bin/pip install -q -r requirements.txt 2>/dev/null
fi

nohup ./venv/bin/python server.py > "$HOME/.claude/rolling-context-proxy.log" 2>&1 &
echo $! > "$PIDFILE"

# Wait a moment for it to start
sleep 1

# Verify it started
if curl -s "$PROXY_URL/health" &>/dev/null; then
    echo "Rolling context proxy started on port $PORT"
else
    echo "Warning: Rolling context proxy may not have started correctly. Check ~/.claude/rolling-context-proxy.log" >&2
fi

exit 0
