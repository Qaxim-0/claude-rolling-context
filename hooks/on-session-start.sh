#!/usr/bin/env bash
# Auto-start the rolling context proxy if it's not already running.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_DIR="$SCRIPT_DIR/../proxy"
PIDFILE="$HOME/.claude/rolling-context-proxy.pid"
PORT="${ROLLING_CONTEXT_PORT:-5588}"

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
    if curl -s "http://127.0.0.1:$PORT/health" &>/dev/null; then
        exit 0
    fi
fi

# Start the proxy in the background
cd "$PROXY_DIR" || exit 1

if [ ! -d "venv" ]; then
    python3 -m venv venv
    ./venv/bin/pip install -q -r requirements.txt
fi

nohup ./venv/bin/python server.py > "$HOME/.claude/rolling-context-proxy.log" 2>&1 &
echo $! > "$PIDFILE"

# Wait a moment for it to start
sleep 1

# Verify it started
if curl -s "http://127.0.0.1:$PORT/health" &>/dev/null; then
    echo "Rolling context proxy started on port $PORT"
else
    echo "Warning: Rolling context proxy may not have started correctly. Check ~/.claude/rolling-context-proxy.log" >&2
fi

exit 0
