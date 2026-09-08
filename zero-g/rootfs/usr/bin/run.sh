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
# 3. Download / Auto-Update Antigravity Binary
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
# 4. Home Assistant MCP Server Setup
# ------------------------------------------------------------------------------
bashio::log.info "Configuring Home Assistant MCP Server..."
if [[ -x /usr/bin/ha-mcp-setup.sh ]]; then
    /usr/bin/ha-mcp-setup.sh || bashio::log.warning "MCP setup returned non-zero. Continuing."
fi

MCP_INFO_FILE="/var/www/onboarding/mcp_info.json"

notify_ha_mcp_missing() {
    local core_stat="$1"
    local comm_stat="$2"
    if [[ -z "${SUPERVISOR_TOKEN:-}" ]]; then
        return
    fi

    local msg="Damit Zero-G dein Smart Home steuern und Konfigurationen bearbeiten kann, werden die entsprechenden MCP-Server in Home Assistant benötigt:\n\n"

    if [[ "$core_stat" == "missing" ]]; then
        msg+="- **1. Model Context Protocol Server (Core-Integration)**:\n"
        msg+="Empfohlen für direkte Gerätesteuerung & Assist-Intents (Lampen, Thermostate, Schalter, Skripte).\n"
        msg+="[<img src=\"https://my.home-assistant.io/badges/config_flow_start.svg\" alt=\"Integration hinzufügen\">](https://my.home-assistant.io/redirect/config_flow_start/?domain=mcp_server)\n\n"
    fi

    if [[ "$comm_stat" == "missing" ]]; then
        msg+="- **2. Native MCP for Home Assistant (Community-Integration via HACS)**:\n"
        msg+="Empfohlen für erweiterte Verwaltungs- und Entwicklertools (Lovelace Dashboards, YAML-Dateien, HACS, Backups).\n"
        msg+="*Schritt 1: In HACS öffnen & herunterladen:*\n"
        msg+="[<img src=\"https://my.home-assistant.io/badges/hacs_repository.svg\" alt=\"In HACS öffnen\">](https://my.home-assistant.io/redirect/hacs_repository/?owner=czechbol&repository=hass-mcp&category=integration)\n\n"
        msg+="*Schritt 2: Nach dem HA-Neustart hinzufügen:*\n"
        msg+="[<img src=\"https://my.home-assistant.io/badges/config_flow_start.svg\" alt=\"Integration hinzufügen\">](https://my.home-assistant.io/redirect/config_flow_start/?domain=hass_mcp)\n\n"
    fi

    local payload
    payload=$(jq -n \
        --arg msg "$msg" \
        '{
            notification_id: "zero_g_mcp",
            title: "🔌 Zero-G: Home Assistant MCP einrichten",
            message: $msg
        }')

    curl -s -m 5 -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        http://supervisor/core/api/services/persistent_notification/create >/dev/null 2>&1 || true
}

dismiss_ha_mcp_notification() {
    if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
        curl -s -m 5 -X POST \
            -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{"notification_id": "zero_g_mcp"}' \
            http://supervisor/core/api/services/persistent_notification/dismiss >/dev/null 2>&1 || true
    fi
}

check_and_notify_mcp() {
    if [[ -f "$MCP_INFO_FILE" ]]; then
        local core_stat comm_stat
        core_stat="$(jq -r '.core_status // "unknown"' "$MCP_INFO_FILE" 2>/dev/null || echo "unknown")"
        comm_stat="$(jq -r '.community_status // "unknown"' "$MCP_INFO_FILE" 2>/dev/null || echo "unknown")"

        if [[ "$core_stat" == "missing" || "$comm_stat" == "missing" ]]; then
            bashio::log.warning "Home Assistant MCP integration(s) not installed (Core: ${core_stat}, Community: ${comm_stat}). Notification sent."
            notify_ha_mcp_missing "$core_stat" "$comm_stat"
        elif [[ "$core_stat" == "active" ]]; then
            dismiss_ha_mcp_notification
        fi
    fi
}

check_and_notify_mcp

# ------------------------------------------------------------------------------
# 5. Authentication Configuration
# ------------------------------------------------------------------------------
AUTH_TOKEN="$(bashio::config 'auth_token' || true)"
if [[ -z "$AUTH_TOKEN" ]] || [[ "$AUTH_TOKEN" == "null" ]]; then
    if [[ -f /data/options.json ]]; then
        AUTH_TOKEN="$(jq -r '.auth_token // empty' /data/options.json)"
    fi
fi

TOKEN_FILE="${GEMINI_DIR}/jetski-standalone-oauth-token"
LAST_CODE_FILE="${GEMINI_DIR}/last_exchanged_code.txt"

AUTH_TOKEN="$(printf '%s' "${AUTH_TOKEN:-}" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

LAST_CODE=""
if [[ -f "$LAST_CODE_FILE" ]]; then
    LAST_CODE="$(tr -d '\r\n[:space:]' < "$LAST_CODE_FILE")"
fi

# Check if user provided an auth token or new code in options
if [[ -n "$AUTH_TOKEN" ]] && [[ "$AUTH_TOKEN" != "null" ]]; then
    if [[ "$AUTH_TOKEN" == "{"* ]]; then
        bashio::log.info "Processing raw JSON token from Add-on options..."
        printf '%s\n' "$AUTH_TOKEN" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
    elif [[ "$AUTH_TOKEN" != "$LAST_CODE" ]]; then
        CLEAN_CODE="$(/usr/bin/agy-auth.sh sanitize "$AUTH_TOKEN")"
        if [[ "$CLEAN_CODE" == "4/"* ]]; then
            bashio::log.info "Found new Google Authorization Code. Exchanging for access token..."
            if /usr/bin/agy-auth.sh exchange "$AUTH_TOKEN"; then
                bashio::log.info "Auth exchange successful! Token saved."
            else
                bashio::log.error "Auth exchange failed. Code may be expired or generated for an older session."
                /usr/bin/agy-auth.sh reset_verifier || true
            fi
        else
            bashio::log.info "Processing Bearer access token string from Add-on options..."
            printf '{"auth_method":"consumer","token":{"access_token":"%s","token_type":"Bearer"}}\n' "$AUTH_TOKEN" > "$TOKEN_FILE"
            chmod 600 "$TOKEN_FILE"
        fi
    fi
fi

AUTH_INFO_FILE="/var/www/onboarding/auth_info.json"

notify_ha_auth_required() {
    local auth_url="$1"
    if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
        local payload
        payload=$(jq -n \
            --arg url "$auth_url" \
            '{
                notification_id: "zero_g_auth",
                title: "🛸 Zero-G: Google-Anmeldung erforderlich",
                message: ("Zero-G benötigt eine einmalige Autorisierung mit deinem Google-Konto.\n\n[👉 **Hier klicken: Jetzt Google-Konto verbinden**](" + $url + ")\n\nKopiere danach den Autorisierungscode (beginnt mit `4/...`) und trage ihn in den [Add-on-Einstellungen](/hassio/addon/zero-g/config) unter `auth_token` ein.")
            }')

        curl -s -m 5 -X POST \
            -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            http://supervisor/core/api/services/persistent_notification/create >/dev/null 2>&1 || true
    fi
}

dismiss_ha_auth_notification() {
    if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
        curl -s -m 5 -X POST \
            -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{"notification_id": "zero_g_auth"}' \
            http://supervisor/core/api/services/persistent_notification/dismiss >/dev/null 2>&1 || true
    fi
}

update_auth_status() {
    local is_authed="$1"
    local auth_url="${2:-}"
    mkdir -p "$(dirname "$AUTH_INFO_FILE")"
    if [[ "$is_authed" == "true" ]]; then
        printf '{"authenticated":true,"auth_url":""}\n' > "$AUTH_INFO_FILE"
        dismiss_ha_auth_notification
    else
        printf '{"authenticated":false,"auth_url":"%s"}\n' "$auth_url" > "$AUTH_INFO_FILE"
        notify_ha_auth_required "$auth_url"
    fi
}

# Verify active session validity
if /usr/bin/agy-auth.sh check_token; then
    bashio::log.info "Authentication verified: valid session active."
    /usr/bin/agy-auth.sh reset_verifier || true
    update_auth_status true
else
    bashio::log.warning "No valid authentication found (missing, invalid, or expired)."
    rm -f "$TOKEN_FILE"

    auth_url="$(/usr/bin/agy-auth.sh generate_url)"
    update_auth_status false "$auth_url"

    echo -e "\n\033[1;33m=======================================================================\033[0m"
    echo -e "\033[1;37m ZERO-G ANMELDUNG: Google-Konto verbinden\033[0m"
    echo -e "\033[1;33m=======================================================================\033[0m"
    echo -e "Bitte öffne folgenden Link in deinem Browser, um Antigravity zu autorisieren:\n"
    echo -e "\033[1;34m${auth_url}\033[0m\n"

    echo -e "Anleitung:"
    echo -e " 1. Öffne den Link oben im Browser und bestätige die Berechtigung."
    echo -e " 2. Kopiere den Autorisierungscode (beginnt mit '4/...') oder die Weiterleitungs-URL."
    echo -e " 3. Trage ihn in Home Assistant ein unter:"
    echo -e "    Einstellungen -> Add-ons -> Zero-G -> Konfiguration -> 'auth_token'"
    echo -e " 4. Klicke auf SPEICHERN und starte das Add-on neu."
    echo -e "\033[1;33m=======================================================================\033[0m\n"
fi

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
    if [[ -n "${AGY_PID:-}" ]]; then
        kill -TERM "$AGY_PID" 2>/dev/null || true
    fi
    if [[ -n "${NGINX_PID:-}" ]]; then
        kill -TERM "$NGINX_PID" 2>/dev/null || true
    fi
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

cd "$WORKSPACE_DIR"

if ! /usr/bin/agy-auth.sh check_token; then
    bashio::log.warning "No valid authentication found. Add-on will idle until an authorization code is provided in the configuration."
    while true; do
        sleep 3600 &
        wait $! || true
    done
fi

bashio::log.info "Launching Antigravity (port ${HUB_PORT}, name '${RC_NAME}')..."

while true; do
    "$AGY_BIN" --remote-control \
               --hub-port "$HUB_PORT" \
               --remote-control-name "$RC_NAME" </dev/null &
    AGY_PID=$!

    # `wait` returns immediately when a trapped signal arrives, letting
    # the cleanup handler fire without waiting for agy to exit on its own.
    wait "$AGY_PID" || true
    AGY_PID=""

    # Check if agy exited due to an authentication error
    if ! /usr/bin/agy-auth.sh check_token; then
        bashio::log.warning "Antigravity exited because authentication credentials are no longer valid."
        rm -f "$TOKEN_FILE"
        auth_url="$(/usr/bin/agy-auth.sh generate_url)"
        update_auth_status false "$auth_url"
        bashio::log.info "Please visit this URL to re-authenticate: ${auth_url}"
        while true; do
            sleep 3600 &
            wait $! || true
        done
    fi

    # If we reach here, agy exited unexpectedly. Restart after a delay
    bashio::log.warning "Antigravity exited. Restarting in 5 s..."
    sleep 5 &
    wait $! || true   # interruptible sleep
done
