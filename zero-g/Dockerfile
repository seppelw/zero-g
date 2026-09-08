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

# Ensure Bashio is available (included by default in official Home Assistant base images)
RUN which bashio >/dev/null 2>&1 || ( \
        curl -fsSL "https://github.com/hassio-addons/bashio/archive/v0.16.2.tar.gz" \
            | tar -xz --strip-components=1 -C /tmp/ \
        && mkdir -p /usr/lib/bashio \
        && mv /tmp/lib /usr/lib/bashio \
        && ln -sf /usr/lib/bashio/bashio.sh /usr/bin/bashio \
        && rm -rf /tmp/* \
    )

# Copy filesystem overlay
COPY rootfs /

# Ensure execution permissions on all scripts
RUN chmod +x /usr/bin/run.sh /usr/bin/ha-mcp-setup.sh

WORKDIR /data

CMD ["/usr/bin/run.sh"]
