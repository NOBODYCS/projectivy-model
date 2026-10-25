#!/usr/bin/env bash
# Revert the batch just applied (no guessing the culprit).
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device
for pkg in "$@"; do
  echo "enabling $pkg"
  adb_cmd shell pm enable "$pkg"
  log_apply "revert-enable" "$pkg"
done
echo "Batch reverted. Move culprit to lists/watchlist.txt with a note after re-testing."
