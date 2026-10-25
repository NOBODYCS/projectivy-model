#!/usr/bin/env bash
# Shared helpers. Source from other scripts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_DIR="$REPO_ROOT/device"
LOG="$REPO_ROOT/applied.log"

BOX_IP="${BOX_IP:-}"
BOX_PORT="${BOX_PORT:-5555}"

adb_cmd() {
  if [[ -n "$BOX_IP" ]]; then
    if ! adb devices | grep -q "${BOX_IP}:${BOX_PORT}"; then
      adb connect "${BOX_IP}:${BOX_PORT}" >/dev/null 2>&1 || true
    fi
    adb -s "${BOX_IP}:${BOX_PORT}" "$@"
  else
    adb "$@"
  fi
}

require_device() {
  if ! adb_cmd get-state >/dev/null 2>&1; then
    echo "ERROR: no device. Set BOX_IP and/or run: adb connect <IP>:5555" >&2
    exit 1
  fi
}

log_apply() {  # log_apply <action> <target>
  echo "$(date -Is) $1 $2" >> "$LOG"
}

timestamped() { echo "device/runs/$(date +%F-%H%M%S)"; }
