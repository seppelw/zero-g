#!/usr/bin/env bash
set -euo pipefail

: "${DATA_DIR:=/data}"
: "${GEMINI_DIR:=${DATA_DIR}/.gemini}"
: "${VERIFIER_FILE:=${GEMINI_DIR}/pkce_verifier.txt}"
: "${TOKEN_FILE:=${GEMINI_DIR}/jetski-standalone-oauth-token}"
: "${LAST_CODE_FILE:=${GEMINI_DIR}/last_exchanged_code.txt}"
: "${AGY_BIN:=${DATA_DIR}/bin/agy}"

mkdir -p "$GEMINI_DIR"

PART1="1071006060591"
PART2="tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
CLIENT_ID="${PART1}-${PART2}"
REDIRECT_URI="https://antigravity.google/oauth-callback"
SCOPES="https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/cclog https://www.googleapis.com/auth/experimentsandconfigs https://www.googleapis.com/auth/aicode"

get_client_secrets() {
    local secrets=""
    if [[ -f "$AGY_BIN" ]]; then
        secrets=$(grep -a -o 'GOCSPX-[a-zA-Z0-9_-]\{28\}' "$AGY_BIN" | head -n 2 || true)
    fi
    if [[ -z "$secrets" ]]; then
        local candidate
        for candidate in "$(command -v agy 2>/dev/null || true)" "/root/.local/bin/agy" "/usr/local/bin/agy"; do
            if [[ -n "$candidate" ]] && [[ -f "$candidate" ]]; then
                secrets=$(grep -a -o 'GOCSPX-[a-zA-Z0-9_-]\{28\}' "$candidate" | head -n 2 || true)
                if [[ -n "$secrets" ]]; then
                    break
                fi
            fi
        done
    fi
    printf '%s\n' "$secrets"
}

sanitize_code() {
    local raw="$1"
    raw=$(printf '%s' "$raw" | tr -d '\r\n[:space:]')
    # If the user pasted the full redirect URL (e.g., https://antigravity.google/oauth-callback?code=4/...&state=zero-g)
    local re='[?&]code=([^&]+)'
    if [[ "$raw" =~ $re ]]; then
        raw="${BASH_REMATCH[1]}"
    fi
    # If code is URL-encoded (%2F instead of /)
    if [[ "$raw" == *"%"* ]]; then
        raw=$(printf '%b' "${raw//%/\\x}")
    fi
    printf '%s' "$raw"
}

action="${1:-}"

if [[ "$action" == "generate_url" ]]; then
    # Reuse existing verifier if present so restarts do not invalidate pending login attempts
    if [[ -s "$VERIFIER_FILE" ]]; then
        code_verifier=$(cat "$VERIFIER_FILE")
    else
        code_verifier=$(openssl rand -base64 32 | tr -d '=' | tr '+/' '-_')
        echo "$code_verifier" > "$VERIFIER_FILE"
        chmod 600 "$VERIFIER_FILE"
    fi
    
    code_challenge=$(printf %s "$code_verifier" | openssl dgst -sha256 -binary | base64 | tr -d '=' | tr '+/' '-_')
    scopes_url_encoded=$(echo "$SCOPES" | sed 's/ /+/g' | sed 's/:/%3A/g' | sed 's/\//%2F/g')
    redirect_encoded=$(echo "$REDIRECT_URI" | sed 's/:/%3A/g' | sed 's/\//%2F/g')
    
    url="https://accounts.google.com/o/oauth2/auth?access_type=offline&client_id=${CLIENT_ID}&code_challenge=${code_challenge}&code_challenge_method=S256&prompt=consent&redirect_uri=${redirect_encoded}&response_type=code&scope=${scopes_url_encoded}&state=zero-g"
    echo "$url"

elif [[ "$action" == "exchange" ]]; then
    raw_code="${2:-}"
    auth_code=$(sanitize_code "$raw_code")

    if [[ -z "$auth_code" ]]; then
        echo "Error: Empty authorization code." >&2
        exit 1
    fi

    if [[ ! -s "$VERIFIER_FILE" ]]; then
        echo "Error: No PKCE verifier found. A new authentication URL must be generated." >&2
        exit 1
    fi
    code_verifier=$(cat "$VERIFIER_FILE")
    
    secrets=$(get_client_secrets)
    SECRET1=$(echo "$secrets" | sed -n '1p')
    SECRET2=$(echo "$secrets" | sed -n '2p')
    
    response=""
    for secret in "$SECRET1" "$SECRET2"; do
        [[ -z "$secret" ]] && continue
        response=$(curl -s -X POST https://oauth2.googleapis.com/token \
          -d "client_id=${CLIENT_ID}" \
          -d "client_secret=${secret}" \
          -d "grant_type=authorization_code" \
          -d "redirect_uri=${REDIRECT_URI}" \
          -d "code=${auth_code}" \
          -d "code_verifier=${code_verifier}")
        if echo "$response" | grep -q '"access_token"'; then
            break
        fi
    done
      
    if echo "$response" | grep -q '"access_token"'; then
        expiry=$(date -u -d "+3500 seconds" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u "+%Y-%m-%dT%H:%M:%SZ")
        wrapped=$(jq -n \
            --argjson token "$response" \
            --arg expiry "$expiry" \
            '{
                "auth_method": "consumer",
                "token": ($token + {"expiry": $expiry})
            }')
        echo "$wrapped" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        echo "$raw_code" > "$LAST_CODE_FILE"
        rm -f "$VERIFIER_FILE"
        echo "Success"
    else
        echo "Error during exchange: $response" >&2
        exit 1
    fi

elif [[ "$action" == "check_token" ]]; then
    if [[ ! -s "$TOKEN_FILE" ]]; then
        exit 1
    fi

    access_token=$(jq -r '.token.access_token // empty' "$TOKEN_FILE" 2>/dev/null || true)
    refresh_token=$(jq -r '.token.refresh_token // empty' "$TOKEN_FILE" 2>/dev/null || true)

    if [[ -z "$access_token" ]] && [[ -z "$refresh_token" ]]; then
        exit 1
    fi

    # Verify access token via Google userinfo endpoint
    if [[ -n "$access_token" ]]; then
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $access_token" "https://www.googleapis.com/oauth2/v3/userinfo" --connect-timeout 5 || echo "000")
        if [[ "$http_code" == "200" ]]; then
            exit 0
        elif [[ "$http_code" == "000" ]]; then
            # Network unreachable; avoid invalidating existing token when offline
            exit 0
        fi
    fi

    # Access token expired/rejected; attempt refresh if refresh_token is present
    if [[ -n "$refresh_token" ]]; then
        secrets=$(get_client_secrets)
        SECRET1=$(echo "$secrets" | sed -n '1p')
        SECRET2=$(echo "$secrets" | sed -n '2p')
        for secret in "$SECRET1" "$SECRET2"; do
            [[ -z "$secret" ]] && continue
            refresh_res=$(curl -s -X POST https://oauth2.googleapis.com/token \
              -d "client_id=${CLIENT_ID}" \
              -d "client_secret=${secret}" \
              -d "grant_type=refresh_token" \
              -d "refresh_token=${refresh_token}")
            if echo "$refresh_res" | grep -q '"access_token"'; then
                expiry=$(date -u -d "+3500 seconds" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u "+%Y-%m-%dT%H:%M:%SZ")
                new_token=$(jq --argjson new "$refresh_res" --arg expiry "$expiry" '
                    .token.access_token = $new.access_token |
                    .token.token_type = ($new.token_type // "Bearer") |
                    .token.expiry = $expiry |
                    if $new.refresh_token then .token.refresh_token = $new.refresh_token else . end |
                    .auth_method = "consumer"
                ' "$TOKEN_FILE")
                echo "$new_token" > "$TOKEN_FILE"
                chmod 600 "$TOKEN_FILE"
                exit 0
            fi
        done
    fi

    # Token could not be validated or refreshed
    exit 1

elif [[ "$action" == "reset_verifier" ]]; then
    rm -f "$VERIFIER_FILE"
    echo "Verifier reset"

elif [[ "$action" == "sanitize" ]]; then
    sanitize_code "${2:-}"

else
    echo "Usage: $0 [generate_url | exchange <code> | check_token | reset_verifier | sanitize <code>]"
    exit 1
fi
