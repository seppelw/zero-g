ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install system dependencies, Node.js 22 LTS, and MCP server packages
RUN apt-get update     && apt-get install -y --no-install-recommends         curl         ca-certificates         tar         nginx         jq         git         procps         openssl         sed         net-tools         gnupg     && mkdir -p /etc/apt/keyrings     && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg     && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list     && apt-get update     && apt-get install -y --no-install-recommends nodejs     && npm install -g @samik081/mcp-pve @warnyin/nginx-proxy-manager-mcp     && npm cache clean --force     && rm -rf /var/lib/apt/lists/*

# Copy filesystem overlay
COPY rootfs /

# Ensure execution permissions on all scripts
RUN chmod +x /usr/bin/run.sh /usr/bin/ha-mcp-setup.sh /usr/bin/agy-auth.sh

WORKDIR /data

CMD ["/usr/bin/run.sh"]
