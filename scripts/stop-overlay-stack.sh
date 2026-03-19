#!/usr/bin/env bash
set -euo pipefail

pkill -f '/Users/patel/ClaudeCodeExtensions/ipc-server/node_modules/.bin' >/dev/null 2>&1 || true
pkill -f 'node src/index.js' >/dev/null 2>&1 || true
pkill -f 'overlay-macos' >/dev/null 2>&1 || true

SOCKET="/tmp/claude-overlay-$(id -u).sock"
rm -f "$SOCKET" >/dev/null 2>&1 || true

echo "Stopped overlay stack processes and removed stale socket (if any)."
