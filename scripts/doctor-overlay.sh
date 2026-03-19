#!/usr/bin/env bash
set -euo pipefail

SOCKET="/tmp/claude-overlay-$(id -u).sock"

echo "[doctor] socket path: $SOCKET"
if [[ -S "$SOCKET" ]]; then
  echo "[doctor] socket file: present"
else
  echo "[doctor] socket file: missing"
fi

echo "[doctor] checking server listener..."
if nc -U "$SOCKET" </dev/null >/dev/null 2>&1; then
  echo "[doctor] listener: reachable"
else
  echo "[doctor] listener: not reachable"
fi

echo "[doctor] hook dry-run..."
set +e
RESULT=$(echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo doctor"}}' | node /Users/patel/ClaudeCodeExtensions/hooks/claude-overlay-hook.js 2>&1)
CODE=$?
set -e

echo "$RESULT"
echo "[doctor] hook exit code: $CODE"

if [[ $CODE -ne 0 ]]; then
  cat <<TXT
[doctor] fix:
1) cd /Users/patel/ClaudeCodeExtensions/scripts && ./start-overlay-stack.sh
2) retry: ./test-permission-request.sh
TXT
fi
