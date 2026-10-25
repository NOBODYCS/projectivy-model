#!/usr/bin/env bash
# Apply debloat batch: apply.sh <pkg1> [pkg2 ...] (3-5 packages max per run)
# Disables each, logs, mirrors to restore.sh, verifies it took.
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device
RESTORE="$REPO_ROOT/scripts/restore.sh"

if [[ $# -lt 1 ]]; then echo "usage: apply.sh <pkg> [pkg ...]"; exit 1; fi
if [[ $# -gt 5 ]]; then echo "max 5 per batch (plan discipline)"; exit 1; fi

for pkg in "$@"; do
  if ! adb_cmd shell pm list packages | tr -d '\r' | grep -x "package:$pkg" > /dev/null; then
    echo "SKIP: $pkg not installed (check spelling against packages-all.txt!)"; continue
  fi
  echo "disabling $pkg"
  adb_cmd shell pm disable-user --user 0 "$pkg"
  if adb_cmd shell pm list packages -d | tr -d '\r' | grep -x "package:$pkg" > /dev/null; then
    log_apply "disable" "$pkg"
    echo "adb shell pm enable '$pkg'" >> "$RESTORE"
    echo "  -> logged + mirrored to restore.sh"
  else
    echo "ERROR: $pkg did NOT show as disabled — investigate before continuing" >&2
    exit 1
  fi
done

echo ""
echo "=== RUN THE CHECKLIST NOW (checklists/per-batch.md) ==="
echo "Any regression: bash scripts/revert-batch.sh $*"
