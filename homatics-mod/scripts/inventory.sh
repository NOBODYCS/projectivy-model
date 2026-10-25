#!/usr/bin/env bash
# Phase 1: pull every system APK for REA analysis.
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device
PULL="$REPO_ROOT/pull"
mkdir -p "$PULL"

adb_cmd shell pm list packages -s | sed 's/package://' | tr -d '\r' | sort > "$PULL/system-package-names.txt"

while read -r pkg; do
  echo "pulling $pkg"
  mkdir -p "$PULL/$pkg"
  # pull all split/base apks
  adb_cmd shell pm path "$pkg" < /dev/null | sed 's/package://' | tr -d '\r' | while read -r apkpath; do
    adb_cmd pull "$apkpath" "$PULL/$pkg/" >/dev/null 2>&1 < /dev/null || echo "WARN: failed $apkpath" >&2
  done
done < <(cat "$REPO_ROOT/lists/pull-targets.txt" 2>/dev/null || echo "$PULL/system-package-names.txt")

echo "Done. Next: REA analysis per APK (see notes/rea-workflow.md)."
