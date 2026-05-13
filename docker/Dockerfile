FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    bash \
    gettext-base \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install opencode (sst/opencode — the real one, distributed via npm)
RUN npm install -g opencode-ai@1.14.48

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
