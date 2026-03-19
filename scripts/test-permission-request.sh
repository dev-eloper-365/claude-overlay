#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[test] sending permission request..."
echo "[test] if overlay is interactive, press Enter (approve) or Esc (deny) in the overlay window."
echo "[test] timeout: ${OVERLAY_REQUEST_TIMEOUT_MS:-10000}ms"

cat <<'JSON' | OVERLAY_REQUEST_TIMEOUT_MS="${OVERLAY_REQUEST_TIMEOUT_MS:-10000}" node "$REPO_ROOT/hooks/claude-overlay-hook.js"
{
  "hook_type": "PreToolUse",
  "session_id": "session-local-dev",
  "tool_name": "Bash",
  "tool_input": {
    "command": "echo hello"
  }
}
JSON
