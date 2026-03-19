#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOCKET="/tmp/claude-overlay-$(id -u).sock"

"$SCRIPT_DIR/stop-overlay-stack.sh" >/dev/null 2>&1 || true

# Remove stale socket if no process is listening.
if [[ -S "$SOCKET" ]]; then
  if ! nc -U "$SOCKET" </dev/null >/dev/null 2>&1; then
    rm -f "$SOCKET"
  fi
fi

cd "$REPO_ROOT/ipc-server"
npm start &
SERVER_PID=$!

sleep 0.7

cd "$REPO_ROOT"
./scripts/run-macos-overlay.sh &
OVERLAY_PID=$!

cat <<TXT
Overlay stack started.
- IPC server PID: $SERVER_PID
- Overlay PID: $OVERLAY_PID

To test:
  cd "$REPO_ROOT/scripts" && ./test-permission-request.sh

To stop:
  kill $OVERLAY_PID $SERVER_PID
TXT
