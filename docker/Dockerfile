FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    bash \
    gettext-base \
    jq \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://opencode.ai/install | bash && \
    find /root/.opencode/bin -name opencode -exec mv {} /usr/local/bin/ \;
ENV PATH="/root/.opencode/bin:${PATH}"

RUN curl -L -o /usr/local/bin/kubernetes-mcp-server \
    https://github.com/containers/kubernetes-mcp-server/releases/latest/download/kubernetes-mcp-server-linux-amd64 && \
    chmod +x /usr/local/bin/kubernetes-mcp-server

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

RUN mkdir -p /config /work /tmp

WORKDIR /work
