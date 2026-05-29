FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    bash \
    gettext-base \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 (required by opencode plugins such as @vymalo/opencode-oauth2)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install OpenCode CLI (via official install script)
RUN curl -fsSL https://opencode.ai/install | bash && \
    find /root/.opencode/bin -name opencode -exec mv {} /usr/local/bin/ \;

ENV PATH="/root/.opencode/bin:${PATH}"

# Install kubernetes-mcp-server
RUN curl -fsSL -o /usr/local/bin/kubernetes-mcp-server \
    https://github.com/containers/kubernetes-mcp-server/releases/download/v0.0.62/kubernetes-mcp-server-linux-amd64 && \
    chmod +x /usr/local/bin/kubernetes-mcp-server

# Install kubectl
RUN curl -fsSL -o /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x /usr/local/bin/kubectl

RUN mkdir -p /config /work /tmp

WORKDIR /work
