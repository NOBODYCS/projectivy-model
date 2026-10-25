#!/usr/bin/env bash
# RESTORE EVERYTHING: re-enables all packages ever disabled by this project.
# Also reverts settings tweaks recorded in applied-settings.log.
set -euo pipefail
source "$(dirname "$0")/common.sh"

echo "Restoring packages..."
sort -u "$REPO_ROOT/applied.log" 2>/dev/null | awk '$2=="disable"{print $3}' | while read -r pkg; do
  echo "enabling $pkg"
  adb_cmd shell pm enable "$pkg" || echo "WARN: enable failed for $pkg" >&2
done

if [[ -f "$REPO_ROOT/applied-settings.log" ]]; then
  echo "Restoring settings..."
  while read -r ns key value; do
    [[ "$ns" == "#" || -z "$ns" ]] && continue
    echo "settings put $ns $key $value"
    adb_cmd shell settings put "$ns" "$key" "$value"
  done < "$REPO_ROOT/applied-settings.log"
fi

echo "Stock behavior restored (package state + settings)."
echo "Launcher: to return to stock launcher, re-enable it first, then Settings -> Home app."
