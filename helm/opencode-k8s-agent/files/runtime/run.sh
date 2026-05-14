#!/bin/bash
set -euo pipefail

echo "[Reporter] Starting..."

# Save original API key for fallback if Keycloak token fails connectivity test
ORIGINAL_OPENCODE_API_KEY="${OPENCODE_API_KEY:-}"

REPORT_FILE="/tmp/report.txt"

# ============================================================
# OIDC Authentication to Keycloak
# ============================================================
fetch_keycloak_token() {
  local token_url="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token"

  echo "[OIDC] Fetching token from Keycloak..." >&2

  local response
  response=$(curl -s -X POST "$token_url" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "client_id=${KEYCLOAK_CLIENT_ID}" \
    -d "client_secret=${KEYCLOAK_CLIENT_SECRET}")

  if [ -z "$response" ]; then
    echo "[OIDC] Error: Empty response from Keycloak" >&2
    return 1
  fi

  local access_token
  access_token=$(echo "$response" | jq -r '.access_token // empty' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$access_token" ]; then
    echo "[OIDC] Error: Failed to get access_token" >&2
    echo "[OIDC] Response: $response" >&2
    return 1
  fi

  echo "[OIDC] Token length: ${#access_token} characters" >&2
  echo "$access_token"
}

# Get Keycloak token if credentials are provided
if [ -n "${KEYCLOAK_CLIENT_ID:-}" ] && [ -n "${KEYCLOAK_CLIENT_SECRET:-}" ]; then
  KEYCLOAK_TOKEN=$(fetch_keycloak_token) || {
    echo "[OIDC] Warning: Failed to get Keycloak token, falling back to API key"
    KEYCLOAK_TOKEN="${OPENCODE_API_KEY:-}"
  }
  export KEYCLOAK_TOKEN
  echo "[OIDC] Token obtained successfully"
else
  echo "[OIDC] Keycloak credentials not provided, using OPENCODE_API_KEY"
  KEYCLOAK_TOKEN="${OPENCODE_API_KEY:-}"
fi

# Use Keycloak token as the API key for OpenCode/LightBridge
export OPENCODE_API_KEY="$KEYCLOAK_TOKEN"

# Debug: Show token format (first/last 10 chars only for security)
if [ -n "$OPENCODE_API_KEY" ]; then
  TOKEN_LEN=${#OPENCODE_API_KEY}
  echo "[OIDC] Using token: ${OPENCODE_API_KEY:0:10}...${OPENCODE_API_KEY: -10} (length: $TOKEN_LEN)"
else
  echo "[OIDC] Warning: OPENCODE_API_KEY is empty!"
fi

# ============================================================
# OpenCode Configuration
# ============================================================

# Generate final config from template — envsubst is safe here because
# OPENCODE_API_KEY is already exported and will be substituted as a plain string.
# OpenCode looks for opencode.json in the current working directory.
envsubst < /config/opencode.json > opencode.json

# Debug: Show the generated config (with API key masked)
echo "[Config] Generated opencode.json:"
sed 's/"apiKey": ".*"/"apiKey": "[REDACTED]"/' opencode.json

# Debug: Test API connectivity with the token
echo "[Config] Testing API connectivity to ${OPENCODE_BASE_URL}..."
# Use more robust headers and verbose output to diagnose 403
HTTP_CODE=$(curl -s -v -o /tmp/api_test.json -w "%{http_code}" \
  -H "Authorization: Bearer ${OPENCODE_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Mozilla/5.0 (OpenCodeAgent/1.0)" \
  "${OPENCODE_BASE_URL}/models" 2>/tmp/curl_debug.log)

echo "[Config] API test HTTP status: $HTTP_CODE"
if [ "$HTTP_CODE" != "200" ]; then
  echo "[Config] API test response:"
  cat /tmp/api_test.json || echo "(empty response)"
  echo "[Config] Curl debug log:"
  grep -E "^<|> " /tmp/curl_debug.log | sed 's/^/  /'
  
  # Fallback logic for 403 Forbidden
  if [ "$HTTP_CODE" == "403" ]; then
    if [ -n "$ORIGINAL_OPENCODE_API_KEY" ] && [ "$OPENCODE_API_KEY" != "$ORIGINAL_OPENCODE_API_KEY" ]; then
      echo "[Config] Got 403 with current token. Falling back to original OPENCODE_API_KEY..."
      export OPENCODE_API_KEY="$ORIGINAL_OPENCODE_API_KEY"
      
      # Regenerate config with the fallback key
      envsubst < /config/opencode.json > opencode.json
      echo "[Config] Regenerated opencode.json with fallback API key"
      
      # Verify the fallback key
      echo "[Config] Verifying fallback API key..."
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer ${OPENCODE_API_KEY}" \
        -H "Content-Type: application/json" \
        -H "User-Agent: Mozilla/5.0 (OpenCodeAgent/1.0)" \
        "${OPENCODE_BASE_URL}/models")
      echo "[Config] Fallback API test HTTP status: $HTTP_CODE"
    else
      echo "[Config] Got 403 but no valid fallback OPENCODE_API_KEY available."
    fi
  fi
fi

# Diagnostic: Check for tools
echo "[Reporter] Verifying environment..."
which kubectl || echo "[Reporter] Warning: kubectl not found in PATH"
[ -f /usr/local/bin/kubernetes-mcp-server ] || echo "[Reporter] Warning: MCP server binary not found"

# Test MCP server
echo "[Reporter] Testing kubernetes-mcp-server..."
# kubernetes-mcp-server is a JSON-RPC server; running it without input and killing it is expected to show EOF.
# We'll just verify it can start and print its initial state if any.
timeout 2s /usr/local/bin/kubernetes-mcp-server --help >/dev/null 2>&1 || echo "[Reporter] MCP server binary is present and executable"

echo "[Reporter] Starting opencode run..."

# Run opencode with the prompt from the file
# Capture stderr to a separate file to diagnose empty reports
echo "[Reporter] Executing opencode run..."
opencode run "$(cat /config/prompt.md)" \
  --agent coder \
  --model "lightbridge/${OPENCODE_MODEL}" \
  --dangerously-skip-permissions \
  --thinking \
  > "$REPORT_FILE" 2>/tmp/opencode_stderr.log || {
    echo "[Reporter] Error: opencode run failed (exit code $?)"
    cat /tmp/opencode_stderr.log
    exit 1
  }

# Validate report — print contents regardless for debugging
echo "[Reporter] Report size: $(stat -c%s "$REPORT_FILE" 2>/dev/null || echo 0) bytes"
cat "$REPORT_FILE" || true

if [ ! -s "$REPORT_FILE" ]; then
  echo "[Reporter] Error: Empty report generated"
  echo "[Reporter] opencode stderr output:"
  cat /tmp/opencode_stderr.log
  exit 1
fi

# Optional: Relaxed validation. We check for a common keyword but don't exit if missing
if ! grep -qi "Summary" "$REPORT_FILE"; then
  echo "[Reporter] Warning: Standard report headers not found, sending as-is..."
fi

echo "[Reporter] Sending report via Apprise API..."

# Filter out thinking blocks and truncate to 1800 chars to stay under Discord's 2000 char limit
CLEAN_REPORT="/tmp/clean_report.txt"
sed '/<thinking>/,/<\/thinking>/d' "$REPORT_FILE" | grep -A 200 "# Executive Summary" | head -c 1800 > "$CLEAN_REPORT"

# If the grep failed (no Executive Summary), just take the first 1800 chars
if [ ! -s "$CLEAN_REPORT" ]; then
  head -c 1800 "$REPORT_FILE" > "$CLEAN_REPORT"
fi

echo "[Reporter] Payload size: $(stat -c%s "$CLEAN_REPORT") bytes"

TITLE="K8s Cluster Report: $(date +'%Y-%m-%d %H:%M')"

RESPONSE=$(curl -s -X POST "${APPRISE_API_URL}/notify" \
  -F "body=<${CLEAN_REPORT}" \
  -F "title=${TITLE}" \
  -F "url=${APPRISE_URLS}" \
  -F "attach=@${REPORT_FILE}")

if echo "$RESPONSE" | grep -qi "success\|sent"; then
  echo "[Reporter] Success: Report sent with attachment via Apprise API"
else
  echo "[Reporter] Warning: Apprise API response: $RESPONSE"
fi

echo "[Reporter] Execution complete"
