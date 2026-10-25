#!/usr/bin/env bash
# Phase 0: capture full read-only baseline. Run twice for boot-time comparison.
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device
OUT="$(timestamped)"
mkdir -p "$REPO_ROOT/$OUT"
cd "$REPO_ROOT/$OUT"

for f in getprop.txt meminfo-idle.txt processes-idle.txt alarm-dump.txt \
         jobs-dump.txt dumpsys-package.txt packages-all.txt \
         packages-system.txt packages-user.txt packages-disabled.txt \
         settings-global.txt settings-secure.txt settings-system.txt \
         cec-settings.txt feature-flags.txt; do
  case "$f" in
    getprop.txt)            CMD=(shell getprop) ;;
    meminfo-idle.txt)       CMD=(shell dumpsys meminfo) ;;
    processes-idle.txt)     CMD=(shell ps -A) ;;
    alarm-dump.txt)         CMD=(shell dumpsys alarm) ;;
    jobs-dump.txt)          CMD=(shell dumpsys jobscheduler) ;;
    dumpsys-package.txt)    CMD=(shell dumpsys package) ;;
    packages-all.txt)       CMD=(shell pm list packages) ;;
    packages-system.txt)    CMD=(shell pm list packages -s) ;;
    packages-user.txt)      CMD=(shell pm list packages -3) ;;
    packages-disabled.txt)  CMD=(shell pm list packages -d) ;;
    settings-global.txt)    CMD=(shell settings list global) ;;
    settings-secure.txt)    CMD=(shell settings list secure) ;;
    settings-system.txt)    CMD=(shell settings list system) ;;
    cec-settings.txt)      CMD=(shell "settings list global | grep -i -E 'cec|hdmi'") ;;
    feature-flags.txt)      CMD=(shell device_config) ;;
  esac
  echo "capturing $f"
  adb_cmd "${CMD[@]}" > "$f" 2>&1 || echo "WARN: $f capture failed" >&2
done

echo "capturing screenshot"
adb_cmd exec-out screencap -p > home-screen.png || echo "WARN: screenshot failed" >&2

echo "capturing bugreport (slow, ~1-2 min)"
adb_cmd bugreport bugreport.zip >/dev/null 2>&1 || echo "WARN: bugreport failed" >&2

echo "Base line captured in $OUT"
echo "Now (manually, twice): time power-on -> interactive home, and launcher cold start."
echo "Record in notes/baseline-metrics.md"
