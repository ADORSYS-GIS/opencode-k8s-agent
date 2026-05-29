#!/bin/bash
set -euo pipefail
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

echo "[Reporter] Starting..."

REPORT_FILE="/tmp/report.txt"

# ============================================================
# OpenCode Configuration
# ============================================================

# Generate final config from template — envsubst replaces
# OAUTH2_* and OPENCODE_* placeholders with their env values.
# OpenCode looks for opencode.json in the current working directory.
envsubst < /config/opencode.json > opencode.json

# Debug: Show the generated config (with client secret masked)
echo "[Config] Generated opencode.json:"
sed 's/"clientSecret": ".*"/"clientSecret": "[REDACTED]"/' opencode.json

# Diagnostic: Check for tools
echo "[Reporter] Verifying environment..."
which kubectl || echo "[Reporter] Warning: kubectl not found in PATH"
[ -f /usr/local/bin/kubernetes-mcp-server ] || echo "[Reporter] Warning: MCP server binary not found"

# Test MCP server
echo "[Reporter] Testing kubernetes-mcp-server..."
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
