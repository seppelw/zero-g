#!/usr/bin/env bash
set -euo pipefail

CLIENT_ID="1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
REDIRECT_URI="https://antigravity.google/oauth-callback"
SCOPES="https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/cclog https://www.googleapis.com/auth/experimentsandconfigs https://www.googleapis.com/auth/aicode"

DATA_DIR="/data"
GEMINI_DIR="${DATA_DIR}/.gemini"
VERIFIER_FILE="${GEMINI_DIR}/pkce_verifier.txt"
TOKEN_FILE="${GEMINI_DIR}/jetski-standalone-oauth-token"

action="${1:-}"

if [[ "$action" == "generate_url" ]]; then
    # Generate PKCE verifier and challenge
    code_verifier=$(openssl rand -base64 32 | tr -d '=' | tr '+/' '-_')
    code_challenge=$(printf %s "$code_verifier" | openssl dgst -sha256 -binary | base64 | tr -d '=' | tr '+/' '-_')
    
    echo "$code_verifier" > "$VERIFIER_FILE"
    chmod 600 "$VERIFIER_FILE"
    
    scopes_url_encoded=$(echo "$SCOPES" | sed 's/ /+/g' | sed 's/:/%3A/g' | sed 's/\//%2F/g')
    redirect_encoded=$(echo "$REDIRECT_URI" | sed 's/:/%3A/g' | sed 's/\//%2F/g')
    
    url="https://accounts.google.com/o/oauth2/auth?access_type=offline&client_id=${CLIENT_ID}&code_challenge=${code_challenge}&code_challenge_method=S256&prompt=consent&redirect_uri=${redirect_encoded}&response_type=code&scope=${scopes_url_encoded}&state=zero-g"
    
    echo "$url"

elif [[ "$action" == "exchange" ]]; then
    auth_code="$2"
    if [[ ! -f "$VERIFIER_FILE" ]]; then
        echo "Error: No PKCE verifier found. You must generate a new URL first." >&2
        exit 1
    fi
    code_verifier=$(cat "$VERIFIER_FILE")
    
    response=$(curl -s -X POST https://oauth2.googleapis.com/token \
      -d "client_id=${CLIENT_ID}" \
      -d "grant_type=authorization_code" \
      -d "redirect_uri=${REDIRECT_URI}" \
      -d "code=${auth_code}" \
      -d "code_verifier=${code_verifier}")
      
    if echo "$response" | grep -q '"access_token"'; then
        # Wrap it in the "token" object expected by Go
        wrapped="{\"token\": $response}"
        echo "$wrapped" > "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        rm -f "$VERIFIER_FILE"
        echo "Success"
    else
        echo "Error during exchange: $response" >&2
        exit 1
    fi
else
    echo "Usage: $0 [generate_url | exchange <code>]"
    exit 1
fi
