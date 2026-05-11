FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    bash \
    gettext-base \
    jq \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L -o /tmp/opencode.tar.gz https://github.com/opencode-ai/opencode/releases/download/v0.0.55/opencode-linux-x86_64.tar.gz && \
    tar -xzf /tmp/opencode.tar.gz -C /tmp && \
    mv /tmp/opencode /usr/local/bin/ && \
    rm -rf /tmp/opencode.tar.gz

RUN curl -L -o /usr/local/bin/kubernetes-mcp-server \
    https://github.com/containers/kubernetes-mcp-server/releases/v0.0.62/download/kubernetes-mcp-server-linux-amd64 && \
    chmod +x /usr/local/bin/kubernetes-mcp-server

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

RUN mkdir -p /config /work /tmp

WORKDIR /work
