#!/usr/bin/env bash
# Ensure rolling context proxy is running
# Runs on SessionStart — must be fast, non-blocking
# Works on both real Unix AND git bash on Windows

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROXY_DIR="$SCRIPT_DIR/../proxy"
PIDFILE="$HOME/.claude/rolling-context-proxy.pid"
HOOKLOG="$HOME/.claude/rolling-context-hook.log"
PORT="${ROLLING_CONTEXT_PORT:-5588}"
PROXY_URL="http://127.0.0.1:$PORT"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HOOKLOG"
}

# Detect platform: git bash on Windows vs real Unix
if [ -d "$PROXY_DIR/venv/Scripts" ] || [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
    IS_WINDOWS=true
    VENV_PIP="$PROXY_DIR/venv/Scripts/pip.exe"
    VENV_PYTHON="$PROXY_DIR/venv/Scripts/python.exe"
else
    IS_WINDOWS=false
    VENV_PIP="$PROXY_DIR/venv/bin/pip"
    VENV_PYTHON="$PROXY_DIR/venv/bin/python"
fi

log "Hook started. SCRIPT_DIR=$SCRIPT_DIR PROXY_DIR=$PROXY_DIR IS_WINDOWS=$IS_WINDOWS"
log "CLAUDE_PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT:-not set}"

# Fast check: is proxy already running?
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        log "Proxy already running (PID $PID)"
        exit 0
    fi
    log "Stale PID file (PID $PID not running), removing"
    rm -f "$PIDFILE"
fi

# On Windows, set env var via PowerShell (shell rc files don't apply)
if [ "$IS_WINDOWS" = true ]; then
    CURRENT_URL=$(powershell -Command "[Environment]::GetEnvironmentVariable('ANTHROPIC_BASE_URL', 'User')" 2>/dev/null | tr -d '\r')
    if [ -z "$CURRENT_URL" ]; then
        powershell -Command "[Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', '$PROXY_URL', 'User')" 2>/dev/null
        log "Set ANTHROPIC_BASE_URL=$PROXY_URL (Windows user env var)"
    elif ! echo "$CURRENT_URL" | grep -q "127\.0\.0\.1.*$PORT"; then
        powershell -Command "[Environment]::SetEnvironmentVariable('ROLLING_CONTEXT_UPSTREAM', '$CURRENT_URL', 'User')" 2>/dev/null
        powershell -Command "[Environment]::SetEnvironmentVariable('ANTHROPIC_BASE_URL', '$PROXY_URL', 'User')" 2>/dev/null
        log "Chaining: upstream=$CURRENT_URL, ANTHROPIC_BASE_URL=$PROXY_URL"
    else
        log "ANTHROPIC_BASE_URL already set to $CURRENT_URL"
    fi
else
    # Unix: add to shell rc
    if [ -z "$ANTHROPIC_BASE_URL" ]; then
        SHELL_RC=""
        if [ -f "$HOME/.zshrc" ]; then
            SHELL_RC="$HOME/.zshrc"
        elif [ -f "$HOME/.bashrc" ]; then
            SHELL_RC="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            SHELL_RC="$HOME/.bash_profile"
        fi
        if [ -n "$SHELL_RC" ] && ! grep -q "ANTHROPIC_BASE_URL" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# Rolling Context proxy for Claude Code" >> "$SHELL_RC"
            echo "export ANTHROPIC_BASE_URL=$PROXY_URL" >> "$SHELL_RC"
            log "Added ANTHROPIC_BASE_URL to $SHELL_RC"
        fi
    elif ! echo "$ANTHROPIC_BASE_URL" | grep -q "127\.0\.0\.1.*$PORT"; then
        SHELL_RC=""
        if [ -f "$HOME/.zshrc" ]; then
            SHELL_RC="$HOME/.zshrc"
        elif [ -f "$HOME/.bashrc" ]; then
            SHELL_RC="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            SHELL_RC="$HOME/.bash_profile"
        fi
        if [ -n "$SHELL_RC" ]; then
            if ! grep -q "ROLLING_CONTEXT_UPSTREAM" "$SHELL_RC" 2>/dev/null; then
                echo "" >> "$SHELL_RC"
                echo "# Rolling Context proxy chaining" >> "$SHELL_RC"
                echo "export ROLLING_CONTEXT_UPSTREAM=$ANTHROPIC_BASE_URL" >> "$SHELL_RC"
            fi
            sed -i.bak "s|export ANTHROPIC_BASE_URL=.*|export ANTHROPIC_BASE_URL=$PROXY_URL|" "$SHELL_RC" 2>/dev/null
            log "Chaining: upstream=$ANTHROPIC_BASE_URL"
        fi
    else
        log "ANTHROPIC_BASE_URL already set to $ANTHROPIC_BASE_URL"
    fi
fi

# Start proxy in background — DO NOT WAIT
log "Launching background setup..."
(
    cd "$PROXY_DIR" || { log "ERROR: cannot cd to $PROXY_DIR"; exit 1; }
    log "[bg] Working dir: $(pwd) IS_WINDOWS=$IS_WINDOWS"
    if [ ! -f "$VENV_PYTHON" ]; then
        log "[bg] Creating venv..."
        python3 -m venv venv 2>/dev/null || python -m venv venv 2>/dev/null
        if [ ! -f "$VENV_PYTHON" ]; then
            log "[bg] ERROR: venv creation failed! Expected python at $VENV_PYTHON"
            exit 1
        fi
        log "[bg] Installing requirements..."
        "$VENV_PIP" install -q -r requirements.txt 2>/dev/null
        log "[bg] Requirements installed"
    fi
    log "[bg] Starting proxy with: $VENV_PYTHON server.py"
    nohup "$VENV_PYTHON" server.py > "$HOME/.claude/rolling-context-proxy.log" 2>&1 &
    echo $! > "$PIDFILE"
    log "[bg] Proxy started with PID $!"
) &

log "Background setup launched, hook exiting"
exit 0
