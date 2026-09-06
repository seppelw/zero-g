#!/usr/bin/env bash
# ==============================================================================
# Antigravity Home Assistant Add-on: Home Assistant MCP Server Setup Helper
# ==============================================================================
set -euo pipefail

CONFIG_FILE="/data/.gemini/config/mcp_config.json"
OPTIONS_FILE="/data/options.json"

# Logging helper
log() {
    local level="$1"
    shift
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [MCP-SETUP] [${level}] $*"
}

mkdir -p "/data/.gemini/config"
mkdir -p "/root/.gemini/config"

# Ensure symlink from /root/.gemini/config/mcp_config.json to persistent volume
if [[ ! -L "/root/.gemini/config/mcp_config.json" ]] && [[ -f "/root/.gemini/config/mcp_config.json" ]]; then
    mv -f "/root/.gemini/config/mcp_config.json" "$CONFIG_FILE" 2>/dev/null || true
fi
ln -sf "$CONFIG_FILE" "/root/.gemini/config/mcp_config.json"

# Initialize base mcp_config.json if not present or empty
if [[ ! -s "$CONFIG_FILE" ]]; then
    echo '{"mcpServers":{}}' > "$CONFIG_FILE"
fi

# Validate existing JSON structure
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    log "WARN" "Existing mcp_config.json was invalid JSON. Reinitializing."
    echo '{"mcpServers":{}}' > "$CONFIG_FILE"
fi

# Ensure mcpServers key exists
jq '.mcpServers = (.mcpServers // {})' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Parse options from Home Assistant options.json
HA_MCP_ENABLED="true"
HA_MCP_MODE="auto"
HA_MCP_URL="auto"
HA_MCP_TOKEN=""
HA_MCP_HIST_ENABLED="false"
HA_MCP_HIST_URL="auto"

if [[ -f "$OPTIONS_FILE" ]]; then
    HA_MCP_ENABLED=$(jq -r '.ha_mcp_enabled // true' "$OPTIONS_FILE")
    HA_MCP_MODE=$(jq -r '.ha_mcp_mode // "auto"' "$OPTIONS_FILE")
    HA_MCP_URL=$(jq -r '.ha_mcp_url // "auto"' "$OPTIONS_FILE")
    HA_MCP_TOKEN=$(jq -r '.ha_mcp_token // empty' "$OPTIONS_FILE")
    HA_MCP_HIST_ENABLED=$(jq -r '.ha_mcp_history_enabled // false' "$OPTIONS_FILE")
    HA_MCP_HIST_URL=$(jq -r '.ha_mcp_history_url // "auto"' "$OPTIONS_FILE")
fi

if [[ "$HA_MCP_ENABLED" != "true" ]]; then
    log "INFO" "Home Assistant MCP server is disabled in options. Removing from config."
    jq 'del(.mcpServers.homeassistant) | del(.mcpServers.homeassistant_history)' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" \
        && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    exit 0
fi

# Resolve effective URL
EFFECTIVE_URL="http://supervisor/core/api/mcp"
if [[ -n "$HA_MCP_URL" ]] && [[ "$HA_MCP_URL" != "auto" ]] && [[ "$HA_MCP_URL" != "null" ]]; then
    EFFECTIVE_URL="$HA_MCP_URL"
fi

# Resolve effective Token
EFFECTIVE_TOKEN=""
if [[ -n "$HA_MCP_TOKEN" ]] && [[ "$HA_MCP_TOKEN" != "null" ]]; then
    EFFECTIVE_TOKEN="$HA_MCP_TOKEN"
elif [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
    EFFECTIVE_TOKEN="$SUPERVISOR_TOKEN"
fi

if [[ -z "$EFFECTIVE_TOKEN" ]]; then
    log "WARN" "Neither Supervisor Token nor Long-Lived Access Token provided. Home Assistant MCP server might reject requests."
fi

log "INFO" "Configuring Home Assistant MCP server: $EFFECTIVE_URL"

# Inject homeassistant server into mcp_config.json
jq --arg url "$EFFECTIVE_URL" --arg token "$EFFECTIVE_TOKEN" '
    .mcpServers.homeassistant = {
        "serverUrl": $url,
        "headers": {
            "Authorization": ("Bearer " + $token)
        }
    }
' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Configure optional history server if enabled
if [[ "$HA_MCP_HIST_ENABLED" == "true" ]]; then
    EFFECTIVE_HIST_URL="http://supervisor/core/api/hass_mcp"
    if [[ -n "$HA_MCP_HIST_URL" ]] && [[ "$HA_MCP_HIST_URL" != "auto" ]] && [[ "$HA_MCP_HIST_URL" != "null" ]]; then
        EFFECTIVE_HIST_URL="$HA_MCP_HIST_URL"
    fi
    log "INFO" "Configuring Home Assistant History MCP server: $EFFECTIVE_HIST_URL"
    jq --arg url "$EFFECTIVE_HIST_URL" --arg token "$EFFECTIVE_TOKEN" '
        .mcpServers.homeassistant_history = {
            "serverUrl": $url,
            "headers": {
                "Authorization": ("Bearer " + $token)
            }
        }
    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
    jq 'del(.mcpServers.homeassistant_history)' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi

log "INFO" "Home Assistant MCP configuration completed successfully."
exit 0
