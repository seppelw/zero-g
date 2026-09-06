#!/usr/bin/env bash
# ==============================================================================
# Home Assistant Antigravity Add-on: Main Entrypoint
# ==============================================================================
set -e

# Load Bashio if available
if [[ -f /usr/lib/bashio/bashio.sh ]]; then
    # shellcheck source=/dev/null
    source /usr/lib/bashio/bashio.sh
    LOG_INFO() { bashio::log.info "$*"; }
    LOG_WARN() { bashio::log.warning "$*"; }
    LOG_ERR() { bashio::log.error "$*"; }
    GET_CONFIG() { bashio::config "$1"; }
else
    LOG_INFO() { echo "[INFO] $*"; }
    LOG_WARN() { echo "[WARN] $*"; }
    LOG_ERR() { echo "[ERROR] $*"; }
    GET_CONFIG() {
        if [[ -f /data/options.json ]]; then
            jq -r --arg k "$1" '.[$k] // empty' /data/options.json
        else
            echo ""
        fi
    }
fi

LOG_INFO "Starting Antigravity Home Assistant Add-on..."

# ------------------------------------------------------------------------------
# 1. Architecture Detection
# ------------------------------------------------------------------------------
ARCH="$(uname -m)"
PLATFORM=""
case "$ARCH" in
    x86_64|amd64)
        PLATFORM="linux_amd64"
        ;;
    aarch64|arm64)
        PLATFORM="linux_arm64"
        ;;
    *)
        LOG_ERR "Unsupported CPU architecture: $ARCH. Antigravity requires amd64 or aarch64."
        exit 1
        ;;
esac
LOG_INFO "Detected platform: $PLATFORM ($ARCH)"

# ------------------------------------------------------------------------------
# 2. Setup Persistent Directories & Symlinks
# ------------------------------------------------------------------------------
DATA_DIR="/data"
BIN_DIR="${DATA_DIR}/bin"
AGY_BIN="${BIN_DIR}/agy"
WORKSPACE_DIR="${DATA_DIR}/workspace"
GEMINI_DIR="${DATA_DIR}/.gemini"
ANTIGRAVITY_DIR="${DATA_DIR}/.antigravity"

mkdir -p "$BIN_DIR" "$WORKSPACE_DIR" "$GEMINI_DIR" "$ANTIGRAVITY_DIR" "/root/.local/bin"

# Symlink persistence to root user home
mkdir -p /root/.gemini /root/.antigravity
rm -rf /root/.gemini && ln -s "$GEMINI_DIR" /root/.gemini
rm -rf /root/.antigravity && ln -s "$ANTIGRAVITY_DIR" /root/.antigravity
ln -sf "$AGY_BIN" /root/.local/bin/agy
ln -sf "$AGY_BIN" /usr/local/bin/agy

# ------------------------------------------------------------------------------
# 3. Authentication Configuration
# ------------------------------------------------------------------------------
AUTH_TOKEN="$(GET_CONFIG 'auth_token')"
TOKEN_FILE="${GEMINI_DIR}/jetski-standalone-oauth-token"

if [[ -n "$AUTH_TOKEN" ]] && [[ "$AUTH_TOKEN" != "null" ]]; then
    LOG_INFO "Injecting OAuth authentication token from Add-on options..."
    # If the user supplied raw JSON token or token string
    if [[ "$AUTH_TOKEN" =~ ^\{.*\}$ ]]; then
        echo "$AUTH_TOKEN" > "$TOKEN_FILE"
    else
        cat <<EOF > "$TOKEN_FILE"
{"token":{"access_token":"${AUTH_TOKEN}","token_type":"Bearer"}}
EOF
    fi
    chmod 600 "$TOKEN_FILE"
fi

# ------------------------------------------------------------------------------
# 4. Home Assistant MCP Server Setup
# ------------------------------------------------------------------------------
LOG_INFO "Executing Home Assistant MCP Server configuration..."
if [[ -x /usr/bin/ha-mcp-setup.sh ]]; then
    /usr/bin/ha-mcp-setup.sh || LOG_WARN "MCP Setup finished with non-zero status. Continuing."
fi

# ------------------------------------------------------------------------------
# 5. Check, Download & Auto-Update Antigravity Binary
# ------------------------------------------------------------------------------
AUTO_UPDATE="$(GET_CONFIG 'auto_update')"
[[ -z "$AUTO_UPDATE" ]] && AUTO_UPDATE="true"

DOWNLOAD_BASE_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"
MANIFEST_URL="${DOWNLOAD_BASE_URL}/manifests/${PLATFORM}.json"

download_latest_agy() {
    LOG_INFO "Querying official release manifest: $MANIFEST_URL"
    local manifest_json
    manifest_json="$(curl -fsSL "$MANIFEST_URL" 2>/dev/null || true)"

    if [[ -z "$manifest_json" ]]; then
        LOG_WARN "Failed to fetch release manifest. Internet connection or firewall might be restricted."
        return 1
    fi

    local version download_url sha512
    version="$(echo "$manifest_json" | jq -r '.version // empty')"
    download_url="$(echo "$manifest_json" | jq -r '.url // empty')"
    sha512="$(echo "$manifest_json" | jq -r '.sha512 // empty')"

    if [[ -z "$download_url" ]] || [[ -z "$sha512" ]]; then
        LOG_WARN "Corrupted or incomplete manifest received."
        return 1
    fi

    LOG_INFO "Target version: $version"

    local staging_dir="/tmp/antigravity_staging"
    rm -rf "$staging_dir" && mkdir -p "$staging_dir"
    local archive_path="${staging_dir}/agy_package.tar.gz"

    LOG_INFO "Downloading Antigravity package from: $download_url"
    if ! curl -fsSL -o "$archive_path" "$download_url"; then
        LOG_ERR "Download failed!"
        rm -rf "$staging_dir"
        return 1
    fi

    LOG_INFO "Verifying SHA512 checksum..."
    local actual_sha512
    actual_sha512="$(sha512sum "$archive_path" | awk '{print $1}')"

    if [[ "$actual_sha512" != "$sha512" ]]; then
        LOG_ERR "Security Verification Failed! Checksum mismatch."
        LOG_ERR "Expected: $sha512"
        LOG_ERR "Got:      $actual_sha512"
        rm -rf "$staging_dir"
        return 1
    fi
    LOG_INFO "Checksum verified successfully."

    LOG_INFO "Extracting binary..."
    if ! tar -xzf "$archive_path" -C "$staging_dir"; then
        LOG_ERR "Failed to unpack tar archive."
        rm -rf "$staging_dir"
        return 1
    fi

    local extracted_bin=""
    if [[ -f "${staging_dir}/antigravity" ]]; then
        extracted_bin="${staging_dir}/antigravity"
    elif [[ -f "${staging_dir}/agy" ]]; then
        extracted_bin="${staging_dir}/agy"
    else
        # Find any executable in staging
        extracted_bin="$(find "$staging_dir" -type f -executable | head -n 1)"
    fi

    if [[ -n "$extracted_bin" ]] && [[ -f "$extracted_bin" ]]; then
        cp -f "$extracted_bin" "$AGY_BIN"
        chmod +x "$AGY_BIN"
        LOG_INFO "Antigravity binary successfully installed at: $AGY_BIN"
        rm -rf "$staging_dir"
        return 0
    else
        LOG_ERR "Could not find extracted binary in payload!"
        rm -rf "$staging_dir"
        return 1
    fi
}

NEEDS_DOWNLOAD=false
if [[ ! -x "$AGY_BIN" ]]; then
    LOG_INFO "No Antigravity executable found. Performing initial installation..."
    NEEDS_DOWNLOAD=true
elif [[ "$AUTO_UPDATE" == "true" ]]; then
    CURRENT_VER="$("$AGY_BIN" --version 2>/dev/null || echo "none")"
    LOG_INFO "Current Antigravity version: $CURRENT_VER. Checking for updates..."
    NEEDS_DOWNLOAD=true
fi

if [[ "$NEEDS_DOWNLOAD" == "true" ]]; then
    if ! download_latest_agy; then
        if [[ -x "$AGY_BIN" ]]; then
            LOG_WARN "Update failed; falling back to existing binary."
        else
            LOG_ERR "Fatal: No executable binary available."
            exit 1
        fi
    fi
fi

INSTALLED_VER="$("$AGY_BIN" --version 2>/dev/null || echo "unknown")"
LOG_INFO "Antigravity CLI Version: $INSTALLED_VER"

# ------------------------------------------------------------------------------
# 6. Start Ingress Reverse Proxy (Nginx)
# ------------------------------------------------------------------------------
LOG_INFO "Starting Nginx Ingress reverse proxy on port 8099..."
mkdir -p /run /var/log/nginx
nginx -t || { LOG_ERR "Nginx configuration test failed"; exit 1; }
nginx &
NGINX_PID=$!

# Trap signals for clean shutdown
cleanup() {
    LOG_INFO "Shutting down services..."
    kill -TERM "$NGINX_PID" 2>/dev/null || true
    pkill -f "agy.*--remote-control" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# ------------------------------------------------------------------------------
# 7. Start Antigravity Remote Control Server
# ------------------------------------------------------------------------------
RC_NAME="$(GET_CONFIG 'remote_control_name')"
[[ -z "$RC_NAME" ]] && RC_NAME="homeassistant-antigravity"
HUB_PORT=4400

LOG_INFO "Starting Antigravity Remote Control Server on port ${HUB_PORT} (Instance: ${RC_NAME})..."
cd "$WORKSPACE_DIR"

while true; do
    "$AGY_BIN" --remote-control \
               --hub-port "$HUB_PORT" \
               --remote-control-name "$RC_NAME" || true

    LOG_WARN "Antigravity server exited. Restarting in 5 seconds..."
    sleep 5
done
