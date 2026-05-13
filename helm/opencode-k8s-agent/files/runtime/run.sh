#!/bin/bash
set -euo pipefail

echo "[Reporter] Starting..."

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
  access_token=$(echo "$response" | jq -r '.access_token // empty')

  if [ -z "$access_token" ]; then
    echo "[OIDC] Error: Failed to get access_token" >&2
    echo "[OIDC] Response: $response" >&2
    return 1
  fi

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

# ============================================================
# OpenCode Configuration
# ============================================================

# Copy config — all values are read via {env:VAR} at runtime, no substitution needed
cp /config/opencode.json opencode.json

# Diagnostic: Check for tools
echo "[Reporter] Verifying environment..."
which kubectl || echo "[Reporter] Warning: kubectl not found in PATH"
[ -f /usr/local/bin/kubernetes-mcp-server ] || echo "[Reporter] Warning: MCP server binary not found"

# Run opencode — response goes to stderr, stdout is empty in non-interactive mode
# permission: "allow" in opencode.json covers external_directory and all MCP tool calls
opencode run \
  --model "lightbridge/${OPENCODE_MODEL}" \
  --dangerously-skip-permissions \
  "$(cat /config/prompt.md)" \
  2>"$REPORT_FILE" >/dev/null || true

# Validate report
if [ ! -s "$REPORT_FILE" ]; then
  echo "[Reporter] Error: Empty report generated — check opencode stderr above"
  exit 1
fi

echo "[Reporter] Report generated (Size: $(stat -c%s "$REPORT_FILE") bytes)"
echo "[Reporter] Report contents:"
cat "$REPORT_FILE"

# Optional: Relaxed validation. We check for a common keyword but don't exit if missing
if ! grep -qi "Summary" "$REPORT_FILE"; then
  echo "[Reporter] Warning: Standard report headers not found, sending as-is..."
fi

echo "[Reporter] Sending report via Apprise API..."

# Filter out any thinking/reasoning blocks and truncate to 1800 chars
# to stay under Discord's 2000 char limit
CLEAN_REPORT="/tmp/clean_report.txt"
sed '/<thinking>/,/<\/thinking>/d' "$REPORT_FILE" | grep -A 200 "# Executive Summary" | head -c 1800 > "$CLEAN_REPORT"

# If the grep failed (no Executive Summary), just take the first 1800 chars
if [ ! -s "$CLEAN_REPORT" ]; then
    head -c 1800 "$REPORT_FILE" > "$CLEAN_REPORT"
fi

echo "[Reporter] Payload size: $(stat -c%s "$CLEAN_REPORT") bytes"
echo "[Reporter] Apprise URL: ${APPRISE_API_URL}/notify"
echo "[Reporter] Notification URLs: ${APPRISE_URLS}"

# Send via Apprise API with file attachment
# Apprise API expects multipart form data for file uploads
TITLE="K8s Cluster Report: $(date +'%Y-%m-%d %H:%M')"

# Use multipart form data for file attachment support
# The @ prefix tells curl to upload the file
RESPONSE=$(curl -s -X POST "${APPRISE_API_URL}/notify" \
  -F "body=<${CLEAN_REPORT}" \
  -F "title=${TITLE}" \
  -F "url=${APPRISE_URLS}" \
  -F "attach=@${REPORT_FILE}")

echo "[Reporter] Apprise response: $RESPONSE"

echo "[Reporter] Execution complete"
