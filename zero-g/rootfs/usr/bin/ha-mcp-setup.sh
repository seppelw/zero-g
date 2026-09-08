#!/usr/bin/env bash
# ==============================================================================
# Zero-G Home Assistant Add-on: Home Assistant MCP Server Setup
#
# Reads add-on options from /data/options.json and writes/updates
# /data/.gemini/config/mcp_config.json, preserving any other MCP servers
# the user has configured manually.
#
# Symlink plumbing is handled by run.sh (ln -sfn /data/.gemini /root/.gemini),
# so this script operates exclusively on the canonical /data/… paths and
# never creates symlinks itself.
# ==============================================================================
set -euo pipefail

: "${CONFIG_DIR:=/data/.gemini/config}"
: "${CONFIG_FILE:=${CONFIG_DIR}/mcp_config.json}"
: "${OPTIONS_FILE:=/data/options.json}"

log() {
    local level="$1"; shift
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [MCP-SETUP] [${level}] $*"
}

# ── Ensure config directory exists ───────────────────────────────────────────
mkdir -p "$CONFIG_DIR"

# ── Bootstrap or repair mcp_config.json ──────────────────────────────────────
if [[ ! -s "$CONFIG_FILE" ]] || ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    log "INFO" "Initializing mcp_config.json"
    printf '{"mcpServers":{}}\n' > "$CONFIG_FILE"
fi

# Ensure the top-level mcpServers key exists (protects against hand-edited files
# that have valid JSON but no mcpServers key).
jq '.mcpServers //= {}' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" \
    && mv -f "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# ── Read add-on options ──────────────────────────────────────────────────────
opt() {
    # Safely read a key from options.json, returning a default if the key
    # is missing, null, or the file does not exist.
    local key="$1" default="${2:-}"
    if [[ -f "$OPTIONS_FILE" ]]; then
        local val
        val="$(jq -r --arg k "$key" 'if has($k) and (.[$k] != null) then .[$k] else empty end' "$OPTIONS_FILE")"
        if [[ -n "$val" ]] && [[ "$val" != "null" ]]; then
            printf '%s' "$val"
            return
        fi
    fi
    printf '%s' "$default"
}

HA_MCP_ENABLED="$(opt ha_mcp_enabled true)"
HA_MCP_MODE="$(opt ha_mcp_mode auto)"
HA_MCP_URL="$(opt ha_mcp_url auto)"
HA_MCP_TOKEN="$(opt ha_mcp_token "")"
HA_MCP_HIST_ENABLED="$(opt ha_mcp_history_enabled false)"
HA_MCP_HIST_URL="$(opt ha_mcp_history_url auto)"

# ── Disabled → remove HA entries and exit ────────────────────────────────────
if [[ "$HA_MCP_ENABLED" != "true" ]]; then
    log "INFO" "HA MCP disabled — removing from config."
    jq 'del(.mcpServers.homeassistant, .mcpServers.homeassistant_history)' \
        "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" \
        && mv -f "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    exit 0
fi

# ── Resolve effective URL ────────────────────────────────────────────────────
EFFECTIVE_URL="http://supervisor/core/api/mcp"
if [[ "$HA_MCP_URL" != "auto" ]] && [[ -n "$HA_MCP_URL" ]]; then
    EFFECTIVE_URL="$HA_MCP_URL"
fi

# ── Resolve effective auth token ─────────────────────────────────────────────
#    Priority: explicit token in options > SUPERVISOR_TOKEN (auto-injected by HA)
EFFECTIVE_TOKEN=""
if [[ -n "$HA_MCP_TOKEN" ]]; then
    EFFECTIVE_TOKEN="$HA_MCP_TOKEN"
elif [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
    EFFECTIVE_TOKEN="$SUPERVISOR_TOKEN"
fi

if [[ -z "$EFFECTIVE_TOKEN" ]]; then
    log "WARN" "No auth token available — HA MCP requests will likely fail."
fi

# ── Write main homeassistant MCP server ──────────────────────────────────────
log "INFO" "HA MCP: ${EFFECTIVE_URL}  (mode=${HA_MCP_MODE})"

jq --arg url "$EFFECTIVE_URL" --arg token "$EFFECTIVE_TOKEN" '
    .mcpServers.homeassistant = {
        "serverUrl": $url,
        "headers": { "Authorization": ("Bearer " + $token) }
    }
' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" \
    && mv -f "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# ── Optional history / statistics endpoint ───────────────────────────────────
if [[ "$HA_MCP_HIST_ENABLED" == "true" ]]; then
    EFFECTIVE_HIST_URL="http://supervisor/core/api/hass_mcp"
    if [[ "$HA_MCP_HIST_URL" != "auto" ]] && [[ -n "$HA_MCP_HIST_URL" ]]; then
        EFFECTIVE_HIST_URL="$HA_MCP_HIST_URL"
    fi
    log "INFO" "HA MCP History: ${EFFECTIVE_HIST_URL}"
    jq --arg url "$EFFECTIVE_HIST_URL" --arg token "$EFFECTIVE_TOKEN" '
        .mcpServers.homeassistant_history = {
            "serverUrl": $url,
            "headers": { "Authorization": ("Bearer " + $token) }
        }
    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" \
        && mv -f "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
    jq 'del(.mcpServers.homeassistant_history)' \
        "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" \
        && mv -f "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi

log "INFO" "MCP configuration complete."
