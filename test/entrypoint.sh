#!/bin/bash
set -e

# Start the proxy in background
cd /opt/rolling-context/proxy
./venv/bin/python server.py &
PROXY_PID=$!

# Wait for proxy to be ready
for i in $(seq 1 10); do
    if curl -s http://127.0.0.1:5588/health > /dev/null 2>&1; then
        echo "Proxy is ready!"
        break
    fi
    sleep 1
done

# Point Claude Code at the proxy
export ANTHROPIC_BASE_URL="http://127.0.0.1:5588"

# Run Claude Code with whatever args were passed
cd /workspace
exec claude "$@"
