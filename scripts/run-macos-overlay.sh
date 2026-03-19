#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../overlay-macos"
swift run overlay-macos
