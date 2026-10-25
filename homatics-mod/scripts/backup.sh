#!/usr/bin/env bash
# Backup: package state + settings + Projectivy backup file.
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device
DIR="$REPO_ROOT/device/backups/$(date +%F-%H%M%S)"
mkdir -p "$DIR"

adb_cmd shell pm list packages          | tr -d '\r' > "$DIR/packages-all.txt"
adb_cmd shell pm list packages -d       | tr -d '\r' > "$DIR/packages-disabled.txt"
adb_cmd shell settings list global      | tr -d '\r' > "$DIR/settings-global.txt"
adb_cmd shell settings list secure      | tr -d '\r' > "$DIR/settings-secure.txt"
adb_cmd shell settings list system      | tr -d '\r' > "$DIR/settings-system.txt"
adb_cmd shell dumpsys package           | tr -d '\r' > "$DIR/dumpsys-package.txt"

# Projectivy backup file (Projectivy Settings -> General -> Backup, if exported to /sdcard)
adb_cmd shell "ls /sdcard/Download/ 2>/dev/null | grep -i -E 'projectivy|backup' || true" | tr -d '\r' | while read -r f; do
  adb_cmd pull "/sdcard/Download/$f" "$DIR/" >/dev/null 2>&1 || true
done

echo "Backup complete: $DIR"
