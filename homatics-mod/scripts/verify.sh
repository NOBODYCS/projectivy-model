#!/usr/bin/env bash
# Verify: does device disabled-state match lists/debloat.txt? Catches OTA re-enables.
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device

DEBLOAT="$REPO_ROOT/lists/debloat.txt"
[[ -f "$DEBLOAT" ]] || { echo "no debloat.txt yet"; exit 0; }

adb_cmd shell pm list packages -d | sed 's/package://' | tr -d '\r' | sort > /tmp/disabled-now.txt
# Strip comment lines and trailing "# ..." annotations before comparing.
grep -v '^[[:space:]]*#' "$DEBLOAT" | sed 's/[[:space:]]#.*//; s/[[:space:]]*$//' | grep -v '^$' | sort > /tmp/debloat-expected.txt

MISSING=$(comm -23 /tmp/debloat-expected.txt /tmp/disabled-now.txt)
if [[ -n "$MISSING" ]]; then
  echo "RE-ENABLED BY OTA or not yet applied — expected disabled but enabled:"
  echo "$MISSING"
  echo "Re-run scripts/apply.sh to re-apply."
  exit 1
else
  echo "OK: all debloat.txt entries are disabled on device."
fi
