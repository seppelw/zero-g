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

# Install Bashio (not bundled in Debian-based HA images, only in Alpine ones).
# Bashio provides the standard HA add-on logging and configuration API.
ARG BASHIO_VERSION="0.16.2"
RUN curl -fsSL "https://github.com/hassio-addons/bashio/archive/v${BASHIO_VERSION}.tar.gz" \
        | tar -xz --strip-components=1 -C /tmp/ \
    && mv /tmp/lib /usr/lib/bashio \
    && ln -s /usr/lib/bashio/bashio.sh /usr/bin/bashio \
    && rm -rf /tmp/*

# Copy filesystem overlay
COPY rootfs /

# Ensure execution permissions on all scripts
RUN chmod +x /usr/bin/run.sh /usr/bin/ha-mcp-setup.sh

WORKDIR /data

CMD ["/usr/bin/run.sh"]
