#!/usr/bin/env bash
# Ensure rolling context proxy is running
# Pure stdlib — no venv needed, just python

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_DIR="$SCRIPT_DIR/../proxy"
PIDFILE="$HOME/.claude/rolling-context-proxy.pid"
HOOKLOG="$HOME/.claude/rolling-context-hook.log"
PORT="${ROLLING_CONTEXT_PORT:-5588}"
PROXY_URL="http://127.0.0.1:$PORT"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HOOKLOG"
}

# Detect Windows (git bash)
if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
    IS_WINDOWS=true
else
    IS_WINDOWS=false
fi

log "Hook started. PROXY_DIR=$PROXY_DIR IS_WINDOWS=$IS_WINDOWS"

# Fast check: is proxy already running?
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        log "Proxy already running (PID $PID)"
        exit 0
    fi
    log "Stale PID, removing"
    rm -f "$PIDFILE"
fi

# Set ANTHROPIC_BASE_URL
if [ "$IS_WINDOWS" = true ]; then
    CURRENT_URL=$(powershell -Command "[Environment]::GetEnvironmentVariable('ANTHROPIC_BASE_URL', 'User')" 2>/dev/null | tr -d '\r')
    if [ -z "$CURRENT_URL" ]; then
        powershell -Command "[Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', '$PROXY_URL', 'User')" 2>/dev/null
        log "Set ANTHROPIC_BASE_URL=$PROXY_URL"
    elif ! echo "$CURRENT_URL" | grep -q "127\.0\.0\.1.*$PORT"; then
        powershell -Command "[Environment]::SetEnvironmentVariable('ROLLING_CONTEXT_UPSTREAM', '$CURRENT_URL', 'User')" 2>/dev/null
        powershell -Command "[Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', '$PROXY_URL', 'User')" 2>/dev/null
        log "Chaining: upstream=$CURRENT_URL"
    else
        log "ANTHROPIC_BASE_URL already set"
    fi
else
    if [ -z "$ANTHROPIC_BASE_URL" ]; then
        SHELL_RC=""
        if [ -f "$HOME/.zshrc" ]; then SHELL_RC="$HOME/.zshrc"
        elif [ -f "$HOME/.bashrc" ]; then SHELL_RC="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then SHELL_RC="$HOME/.bash_profile"; fi
        if [ -n "$SHELL_RC" ] && ! grep -q "ANTHROPIC_BASE_URL" "$SHELL_RC" 2>/dev/null; then
            echo -e "\n# Rolling Context proxy for Claude Code\nexport ANTHROPIC_BASE_URL=$PROXY_URL" >> "$SHELL_RC"
            log "Added ANTHROPIC_BASE_URL to $SHELL_RC"
        fi
    elif ! echo "$ANTHROPIC_BASE_URL" | grep -q "127\.0\.0\.1.*$PORT"; then
        log "Chaining not yet implemented for this shell rc"
    else
        log "ANTHROPIC_BASE_URL already set"
    fi
fi

# Start proxy directly — no venv needed (pure stdlib)
log "Starting proxy..."
(
    cd "$PROXY_DIR" || { log "ERROR: cannot cd to $PROXY_DIR"; exit 1; }
    PYTHON_CMD=""
    if [ "$IS_WINDOWS" = true ]; then
        PYTHON_CMD="python"
    elif command -v python3 &>/dev/null; then
        PYTHON_CMD="python3"
    else
        PYTHON_CMD="python"
    fi
    nohup $PYTHON_CMD server.py > "$HOME/.claude/rolling-context-proxy.log" 2>&1 &
    echo $! > "$PIDFILE"
    log "Proxy started with PID $!"
) &

exit 0
