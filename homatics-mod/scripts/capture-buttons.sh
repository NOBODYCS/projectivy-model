#!/usr/bin/env bash
# Capture what every remote button does: press buttons when prompted.
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device
WINDOW="${CAPTURE_WINDOW:-6}"
OUT="$REPO_ROOT/device/button-inventory.txt"
: > "$OUT"
while true; do
  read -rp "Button name (or 'done'): " name
  [[ "$name" == "done" ]] && break
  echo "=== $name ===" >> "$OUT"
  adb_cmd shell getevent -l < /dev/null >> "$OUT" 2>&1 &
  sleep "$WINDOW"
  pkill -f "getevent -l" 2>/dev/null || true
  wait 2>/dev/null || true
  adb_cmd shell "logcat -d -s WindowManager:* InputReader:* InputDispatcher:* | tail -40" < /dev/null >> "$OUT" 2>&1 || true
  echo "captured: $name"
done
echo "Full map in $OUT — feed to REA for intent analysis."
