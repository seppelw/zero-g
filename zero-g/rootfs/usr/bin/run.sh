#!/usr/bin/env bash
# ==============================================================================
# Home Assistant Zero-G Add-on: Main Entrypoint
# ==============================================================================
set -euo pipefail

# Ensure HOME is set, as some base images or s6-overlay v3 environments might omit it.
export HOME=/root

# In s6-overlay v3, CMD scripts might lose environment variables (like SUPERVISOR_TOKEN).
# Re-execute with /command/with-contenv if available and SUPERVISOR_TOKEN is missing.
if [[ -z "${SUPERVISOR_TOKEN:-}" ]] && [[ -x /command/with-contenv ]]; then
    exec /command/with-contenv "$0" "$@"
fi


# Load Bashio — installed in the Dockerfile from the hassio-addons/bashio repo.
# If somehow absent, fall back to plain logging and jq-based config parsing.
if [[ -f /usr/lib/bashio/bashio.sh ]]; then
    # shellcheck source=/dev/null
    source /usr/lib/bashio/bashio.sh
else
    bashio::log.info()    { echo "[INFO]    $*"; }
    bashio::log.warning() { echo "[WARNING] $*"; }
    bashio::log.error()   { echo "[ERROR]   $*"; }
    bashio::config() {
        if [[ -f /data/options.json ]]; then
            jq -r --arg k "$1" 'if has($k) and (.[$k] != null) then .[$k] else empty end' /data/options.json
        fi
    }
fi

bashio::log.info "Starting Zero-G Home Assistant Add-on..."

# ------------------------------------------------------------------------------
# 1. Architecture Detection
# ------------------------------------------------------------------------------
ARCH="$(uname -m)"
PLATFORM=""
case "$ARCH" in
    x86_64|amd64)   PLATFORM="linux_amd64" ;;
    aarch64|arm64)   PLATFORM="linux_arm64" ;;
    *)
        bashio::log.error "Unsupported CPU architecture: ${ARCH}. Requires amd64 or aarch64."
        exit 1
        ;;
esac
bashio::log.info "Detected platform: ${PLATFORM} (${ARCH})"

# ------------------------------------------------------------------------------
# 1.5 Hardware Compatibility Check
# ------------------------------------------------------------------------------
if [[ "$PLATFORM" == "linux_amd64" ]]; then
    if ! grep -q 'pclmulqdq' /proc/cpuinfo; then
        bashio::log.error "======================================================================="
        bashio::log.error " FATAL HARDWARE INCOMPATIBILITY DETECTED"
        bashio::log.error "======================================================================="
        bashio::log.error "This add-on requires a CPU with the 'pclmul' (PCLMULQDQ) instruction set."
        bashio::log.error "Your current processor environment does NOT expose this feature."
        bashio::log.error ""
        bashio::log.error "TROUBLESHOOTING:"
        bashio::log.error "If you are running Home Assistant inside a Virtual Machine (e.g., Proxmox,"
        bashio::log.error "ESXi, VirtualBox, UNRAID):"
        bashio::log.error "  -> You MUST change the VM's CPU Type from 'kvm64' or 'qemu64' to 'host'."
        bashio::log.error "  -> This passes your physical CPU's features to the VM."
        bashio::log.error ""
        bashio::log.error "If you are running on bare-metal hardware, your processor is unfortunately"
        bashio::log.error "too old to run this software (requires Intel Westmere / AMD Bulldozer or newer)."
        bashio::log.error "======================================================================="
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# 2. Setup Persistent Directories & Symlinks
#
#   /data is the only volume that survives add-on updates.
#   We store all mutable state there and symlink from ~root.
# ------------------------------------------------------------------------------
DATA_DIR="/data"
BIN_DIR="${DATA_DIR}/bin"
AGY_BIN="${BIN_DIR}/agy"
WORKSPACE_DIR="${DATA_DIR}/workspace"
GEMINI_DIR="${DATA_DIR}/.gemini"
ANTIGRAVITY_DIR="${DATA_DIR}/.antigravity"

mkdir -p "$BIN_DIR" "$WORKSPACE_DIR" \
         "${GEMINI_DIR}/config" "${GEMINI_DIR}/antigravity-cli" \
         "$ANTIGRAVITY_DIR" \
         /root/.local/bin

# ln -sfn: -n prevents following existing symlink-as-directory, -f overwrites.
# This avoids the rm -rf race and handles both fresh start and restart cleanly.
ln -sfn "$GEMINI_DIR"       /root/.gemini
ln -sfn "$ANTIGRAVITY_DIR"  /root/.antigravity
ln -sf  "$AGY_BIN"          /root/.local/bin/agy
ln -sf  "$AGY_BIN"          /usr/local/bin/agy

# ------------------------------------------------------------------------------
# 3. Authentication Configuration
# ------------------------------------------------------------------------------
AUTH_TOKEN="$(bashio::config 'auth_token' || true)"
if [[ -z "$AUTH_TOKEN" ]] || [[ "$AUTH_TOKEN" == "null" ]]; then
    if [[ -f /data/options.json ]]; then
        AUTH_TOKEN="$(jq -r '.auth_token // empty' /data/options.json)"
    fi
fi

TOKEN_FILE="${GEMINI_DIR}/jetski-standalone-oauth-token"

if [[ -n "${AUTH_TOKEN:-}" ]] && [[ "$AUTH_TOKEN" != "null" ]]; then
    bashio::log.info "Processing OAuth token from Add-on options..."
    if [[ "$AUTH_TOKEN" == "{"* ]]; then
        # User supplied raw JSON token object
        printf '%s\n' "$AUTH_TOKEN" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
    elif [[ "$AUTH_TOKEN" == "4/"* ]]; then
        # User supplied an Authorization Code
        bashio::log.info "Found Google Authorization Code. Exchanging for access token..."
        rm -f "$TOKEN_FILE"
        # Since agy doesn't have a standalone 'auth' command, we trigger a dummy prompt
        # which will force it to ask for the code on stdin, exchange it, and save the token.
        echo "$AUTH_TOKEN" | "$AGY_BIN" -p "test" >/dev/null 2>&1 || bashio::log.warning "Auth exchange failed. Code might be expired."
    else
        # User supplied a bare access-token string
        printf '{"token":{"access_token":"%s","token_type":"Bearer"}}\n' "$AUTH_TOKEN" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
    fi
fi

# ------------------------------------------------------------------------------
# 4. Home Assistant MCP Server Setup
# ------------------------------------------------------------------------------
bashio::log.info "Configuring Home Assistant MCP Server..."
if [[ -x /usr/bin/ha-mcp-setup.sh ]]; then
    /usr/bin/ha-mcp-setup.sh || bashio::log.warning "MCP setup returned non-zero. Continuing."
fi

# ------------------------------------------------------------------------------
# 5. Download / Auto-Update Antigravity Binary
# ------------------------------------------------------------------------------
AUTO_UPDATE="$(bashio::config 'auto_update' || true)"
: "${AUTO_UPDATE:=true}"

DOWNLOAD_BASE_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app"
MANIFEST_URL="${DOWNLOAD_BASE_URL}/manifests/${PLATFORM}.json"

# Fetch the current version from the installed binary, if any.
current_installed_version() {
    if [[ -x "$AGY_BIN" ]]; then
        "$AGY_BIN" --version 2>/dev/null || echo "unknown"
    else
        echo "none"
    fi
}

download_latest_agy() {
    bashio::log.info "Querying release manifest: ${MANIFEST_URL}"

    local manifest_json
    manifest_json="$(curl -fsSL --connect-timeout 15 "$MANIFEST_URL" 2>/dev/null)" || {
        bashio::log.warning "Failed to fetch release manifest."
        return 1
    }

    if [[ -z "$manifest_json" ]]; then
        bashio::log.warning "Empty manifest received."
        return 1
    fi

    local version download_url sha512
    version="$(printf '%s' "$manifest_json"   | jq -r '.version // empty')"
    download_url="$(printf '%s' "$manifest_json" | jq -r '.url // empty')"
    sha512="$(printf '%s' "$manifest_json"    | jq -r '.sha512 // empty')"

    if [[ -z "$download_url" ]] || [[ -z "$sha512" ]]; then
        bashio::log.warning "Incomplete manifest — missing url or sha512."
        return 1
    fi

    # Skip download if already on the target version
    local current_ver
    current_ver="$(current_installed_version)"
    if [[ "$current_ver" == "$version" ]]; then
        bashio::log.info "Already on latest version (${version}). Skipping download."
        return 0
    fi

    bashio::log.info "Updating: ${current_ver} → ${version}"

    local staging_dir="/tmp/antigravity_staging"
    rm -rf "$staging_dir"
    mkdir -p "$staging_dir" || { bashio::log.error "Cannot create staging dir"; return 1; }
    local archive_path="${staging_dir}/agy_package.tar.gz"

    bashio::log.info "Downloading from: ${download_url}"
    curl -fsSL --connect-timeout 30 -o "$archive_path" "$download_url" || {
        bashio::log.error "Download failed."
        rm -rf "$staging_dir"
        return 1
    }

    bashio::log.info "Verifying SHA-512 checksum..."
    local actual_sha512
    actual_sha512="$(sha512sum "$archive_path" | awk '{print $1}')"
    if [[ "$actual_sha512" != "$sha512" ]]; then
        bashio::log.error "Checksum mismatch! Expected: ${sha512}  Got: ${actual_sha512}"
        rm -rf "$staging_dir"
        return 1
    fi
    bashio::log.info "Checksum verified."

    bashio::log.info "Extracting binary..."
    tar -xzf "$archive_path" -C "$staging_dir" || {
        bashio::log.error "tar extraction failed."
        rm -rf "$staging_dir"
        return 1
    }

    # The archive contains the binary as 'antigravity' or 'agy'.
    local extracted_bin=""
    if   [[ -f "${staging_dir}/antigravity" ]]; then extracted_bin="${staging_dir}/antigravity"
    elif [[ -f "${staging_dir}/agy" ]];         then extracted_bin="${staging_dir}/agy"
    else
        # Fallback: find any executable (POSIX-safe flag instead of GNU -executable)
        extracted_bin="$(find "$staging_dir" -type f -perm -0111 2>/dev/null | head -n 1)"
    fi

    if [[ -z "$extracted_bin" ]] || [[ ! -f "$extracted_bin" ]]; then
        bashio::log.error "No executable found in archive!"
        rm -rf "$staging_dir"
        return 1
    fi

    cp -f "$extracted_bin" "$AGY_BIN" || {
        bashio::log.error "Failed to copy binary to ${AGY_BIN}."
        rm -rf "$staging_dir"
        return 1
    }
    chmod +x "$AGY_BIN"
    rm -rf "$staging_dir"
    bashio::log.info "Antigravity ${version} installed at ${AGY_BIN}."
    return 0
}

# Decide whether to download
if [[ ! -x "$AGY_BIN" ]]; then
    bashio::log.info "No existing binary — performing initial download..."
    if ! download_latest_agy; then
        bashio::log.error "Fatal: initial download failed and no fallback binary exists."
        exit 1
    fi
elif [[ "$AUTO_UPDATE" == "true" ]]; then
    bashio::log.info "Auto-update enabled — checking for newer version..."
    download_latest_agy || bashio::log.warning "Update check failed; using existing binary."
fi

INSTALLED_VER="$(current_installed_version)"
bashio::log.info "Antigravity CLI version: ${INSTALLED_VER}"

# ------------------------------------------------------------------------------
# 6. Start Nginx Ingress Reverse Proxy  (background)
#
#    nginx.conf already contains 'daemon off;' so `nginx` runs in the foreground.
#    We background it and track the PID for clean shutdown.
# ------------------------------------------------------------------------------
bashio::log.info "Starting Nginx Ingress proxy (port 8099)..."
mkdir -p /run /var/log/nginx
nginx -t 2>&1 || { bashio::log.error "Nginx config test failed."; exit 1; }
nginx &
NGINX_PID=$!

# ------------------------------------------------------------------------------
# 7. Signal Handling & Clean Shutdown
#
#    Bash only processes traps between foreground commands.  By running agy in
#    the background and using `wait`, SIGTERM is handled promptly instead of
#    being blocked by the foreground process.
# ------------------------------------------------------------------------------
AGY_PID=""
cleanup() {
    bashio::log.info "Shutting down..."
    [[ -n "${AGY_PID:-}" ]]   && kill -TERM "$AGY_PID"   2>/dev/null || true
    [[ -n "${NGINX_PID:-}" ]] && kill -TERM "$NGINX_PID" 2>/dev/null || true
    wait 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

# ------------------------------------------------------------------------------
# 8. Start Antigravity Remote-Control Server  (foreground loop)
# ------------------------------------------------------------------------------
RC_NAME="$(bashio::config 'remote_control_name' || true)"
: "${RC_NAME:=homeassistant-zero-g}"
HUB_PORT=4400

bashio::log.info "Launching Antigravity (port ${HUB_PORT}, name '${RC_NAME}')..."
cd "$WORKSPACE_DIR"

while true; do
    "$AGY_BIN" --remote-control \
               --hub-port "$HUB_PORT" \
               --remote-control-name "$RC_NAME" &
    AGY_PID=$!

    # `wait` returns immediately when a trapped signal arrives, letting
    # the cleanup handler fire without waiting for agy to exit on its own.
    wait "$AGY_PID" || true
    AGY_PID=""

    # If we reach here, agy exited (crash or normal).  Restart after a delay
    # unless we were killed by a signal (cleanup already called exit).
    bashio::log.warning "Antigravity exited. Restarting in 5 s..."
    sleep 5 &
    wait $! || true   # interruptible sleep
done
