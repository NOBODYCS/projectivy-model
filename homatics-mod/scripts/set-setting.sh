#!/usr/bin/env bash
# Set a device setting with automatic restore-logging.
# usage: set-setting.sh <global|secure|system> <key> <value>
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device
[[ $# -eq 3 ]] || { echo "usage: set-setting.sh <global|secure|system> <key> <value>"; exit 1; }
NS="$1" KEY="$2" VALUE="$3"
OLD=$(adb_cmd shell settings get "$NS" "$KEY" | tr -d '\r')
if [[ "$OLD" == "null" ]]; then
  echo "# $NS $KEY (had no value, delete with: settings delete $NS $KEY)" >> "$REPO_ROOT/applied-settings.log"
else
  echo "$NS $KEY $OLD" >> "$REPO_ROOT/applied-settings.log"
fi
adb_cmd shell settings put "$NS" "$KEY" "$VALUE"
echo "set $NS/$KEY = $VALUE (was: $OLD). Restore line logged."
