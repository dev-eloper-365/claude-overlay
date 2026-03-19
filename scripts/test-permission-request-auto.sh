#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/stop-overlay-stack.sh" >/dev/null 2>&1 || true

cd "$REPO_ROOT/ipc-server"
npm start >/tmp/claude-overlay-ipc.log 2>&1 &
SERVER_PID=$!

sleep 0.7

cd "$REPO_ROOT"
OVERLAY_AUTO_DECISION=approved ./scripts/run-macos-overlay.sh >/tmp/claude-overlay-macos.log 2>&1 &
OVERLAY_PID=$!

sleep 0.7

set +e
RESULT=$(cd "$REPO_ROOT/scripts" && OVERLAY_REQUEST_TIMEOUT_MS=5000 ./test-permission-request.sh 2>&1)
CODE=$?
set -e

echo "$RESULT"

echo "[auto-test] stopping stack..."
kill "$OVERLAY_PID" "$SERVER_PID" >/dev/null 2>&1 || true

exit $CODE
