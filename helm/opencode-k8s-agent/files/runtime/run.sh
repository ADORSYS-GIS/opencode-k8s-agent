#!/bin/bash
set -euo pipefail
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

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
  grep -E "^<|> " /tmp/curl_debug.log 2>/dev/null | sed 's/Authorization: Bearer .*/Authorization: Bearer [REDACTED]/' | sed 's/^/  /' || true
  
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
timeout 2s /usr/local/bin/kubernetes-mcp-server --help >/dev/null 2>&1 && echo "[Reporter] MCP server binary is present and executable" || true

echo "[Reporter] Starting opencode run..."
opencode mcp list || true

# Run opencode with the prompt from the file
# --thinking is intentionally omitted: with it enabled, opencode streams the model's
# entire reasoning process to stdout, polluting the report file and making the
# ---REPORT START--- delimiter unreliable. Tool calls still work without it.
# stderr is captured separately so tool call activity remains visible in pod logs.
echo "[Reporter] Executing opencode run..."
opencode run "$(cat /config/prompt.md)" \
  --agent coder \
  --model "lightbridge/${OPENCODE_MODEL}" \
  --dangerously-skip-permissions \
  > "$REPORT_FILE" 2> >(tee /tmp/opencode_stderr.log >&2) || {
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

# ============================================================
# Report Payload Preparation
# ============================================================
CLEAN_REPORT="/tmp/clean_report.txt"

# Extract everything after the unique ---REPORT START--- delimiter.
# This is anchored to a delimiter rather than a header so that "Thinking: ..."
# lines and any pre-report reasoning emitted by opencode --thinking are skipped
# regardless of their format (plain-text or XML <thinking> blocks).
if awk '/^---REPORT START---/{found=1; next} found{print}' "$REPORT_FILE" > "$CLEAN_REPORT" \
   && [ -s "$CLEAN_REPORT" ]; then
  echo "[Reporter] Report extracted via REPORT START delimiter"
else
  echo "[Reporter] Warning: REPORT START delimiter not found — prompt adherence issue. Sending raw output."
  cp "$REPORT_FILE" "$CLEAN_REPORT"
fi

# Remove any stray Thinking: lines that leaked past the delimiter
sed -i '/^Thinking:[[:space:]]*/d' "$CLEAN_REPORT"

# Smart truncation: cut at the last complete line within the Discord limit,
# then append an indicator so engineers know to check the attachment.
DISCORD_LIMIT=1850
REPORT_SIZE=$(wc -c < "$CLEAN_REPORT")

if [ "$REPORT_SIZE" -gt "$DISCORD_LIMIT" ]; then
  echo "[Reporter] Report size ${REPORT_SIZE}B exceeds Discord limit, truncating at last complete line..."
  head -c "$DISCORD_LIMIT" "$CLEAN_REPORT" | sed '$d' > "${CLEAN_REPORT}.tmp"
  printf '\n\n*[Truncated — full report in the attached file]*' >> "${CLEAN_REPORT}.tmp"
  mv "${CLEAN_REPORT}.tmp" "$CLEAN_REPORT"
fi

echo "[Reporter] Payload size: $(stat -c%s "$CLEAN_REPORT") bytes"
echo "[Reporter] First 5 lines of payload for emoji verification:"
head -n 5 "$CLEAN_REPORT"

TITLE="🚀 K8s Cluster Report: $(date +'%Y-%m-%d %H:%M')"

if [ -z "${APPRISE_URLS:-}" ]; then
  echo "[Reporter] Error: APPRISE_URLS is empty. Check your Kubernetes secrets."
  exit 1
fi

RESPONSE=$(curl -s -X POST "${APPRISE_API_URL}/notify" \
  -F "body=<${CLEAN_REPORT}" \
  -F "title=${TITLE}" \
  -F "urls=${APPRISE_URLS}" \
  -F "format=markdown" \
  -F "attach=@${REPORT_FILE}") || {
  echo "[Reporter] Error: curl failed to reach Apprise API (connection error). Report not sent."
  exit 1
}

echo "[Reporter] Apprise API response: $RESPONSE"

if echo "${RESPONSE:-}" | grep -qi "success\|sent" >/dev/null 2>&1; then
  echo "[Reporter] Success: Report sent with attachment via Apprise API"
else
  echo "[Reporter] Warning: Apprise API did not return success. Response: ${RESPONSE:-<empty>}"
fi

echo "[Reporter] Execution complete"
