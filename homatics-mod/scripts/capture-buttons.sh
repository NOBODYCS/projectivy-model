#!/usr/bin/env bash
# Capture what every remote button does: press buttons when prompted.
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device
OUT="$REPO_ROOT/device/button-inventory.txt"
: > "$OUT"
while true; do
  read -rp "Button name (or 'done'): " name
  [[ "$name" == "done" ]] && break
  echo "=== $name ===" >> "$OUT"
  timeout 6 adb_cmd shell getevent -l >> "$OUT" 2>&1 || true
  timeout 6 adb_cmd shell "logcat -d -s WindowManager:* InputReader:* InputDispatcher:* | tail -40" >> "$OUT" 2>&1 || true
  echo "captured: $name"
done
echo "Full map in $OUT — feed to REA for intent analysis."
