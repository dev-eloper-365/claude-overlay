#!/usr/bin/env bash
set -euo pipefail

cat <<'TXT'
Phase 1 PoC startup (run each in a separate terminal):

1) IPC server
   cd ipc-server && npm start

2) Native macOS overlay
   ./scripts/run-macos-overlay.sh

3) Simulate a Claude hook permission request
   ./scripts/test-permission-request.sh

Controls in native overlay:
  Enter/Space   approve
  Esc/Backspace deny
TXT
