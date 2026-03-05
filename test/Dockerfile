FROM node:22-slim

RUN apt-get update && apt-get install -y python3 python3-venv python3-pip curl && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Non-root user (required for --dangerously-skip-permissions)
RUN useradd -m -s /bin/bash testuser

# Set up the proxy
WORKDIR /opt/rolling-context
COPY proxy/ ./proxy/
RUN cd proxy && python3 -m venv venv && ./venv/bin/pip install -q -r requirements.txt
RUN chown -R testuser:testuser /opt/rolling-context

COPY test/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /home/testuser/.claude && chown -R testuser:testuser /home/testuser/.claude

WORKDIR /workspace
RUN chown testuser:testuser /workspace

USER testuser
ENTRYPOINT ["/entrypoint.sh"]
