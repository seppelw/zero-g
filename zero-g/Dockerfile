ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        tar \
        nginx \
        jq \
        git \
        procps \
        openssl \
        sed \
        net-tools \
    && rm -rf /var/lib/apt/lists/*

# Copy filesystem overlay
COPY rootfs /

# Ensure execution permissions on all scripts
RUN chmod +x /usr/bin/run.sh /usr/bin/ha-mcp-setup.sh

WORKDIR /data

CMD ["/usr/bin/run.sh"]
