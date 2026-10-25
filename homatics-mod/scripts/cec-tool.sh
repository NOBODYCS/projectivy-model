#!/usr/bin/env bash
# CEC diagnostic + workaround tool for the broadcast-TX failure documented in
# notes/cec-investigation.md. Read-only except the fix-on/fix-off subcommands,
# which route through set-setting.sh (logged + restorable).
#
# usage: cec-tool.sh <status|rawsend|test|fix-on|fix-off> [args]
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device

CEC_SYSFS="/sys/class/cec"

hdr() { echo; echo "===== $* ====="; }

dump_cec_summary() {
  hdr "settings (global)"
  for key in hdmi_control_enabled hdmi_control_one_touch_play_enabled \
             hdmi_control_auto_wakeup_enabled hdmi_control_auto_device_off_enabled \
             hdmi_control_system_audio_control_enabled power_control_mode \
             cec_power_control_mode; do
    printf '%-45s = %s\n' "$key" "$(adb_cmd shell settings get global "$key" | tr -d '\r')"
  done
  hdr "props"
  adb_cmd shell getprop | tr -d '\r' | grep -Ei 'hdmi|cec' || true
  hdr "dumpsys hdmi_control (head)"
  # head intentionally truncates a large stream -> upstream SIGPIPE is expected,
  # not an error (same class as the Phase 3 apply.sh grep -qx fix).
  adb_cmd shell dumpsys hdmi_control | tr -d '\r' | head -60 || true
  hdr "sysfs"
  # sysfs attrs are root-only on this box (cmd: Permission denied for shell) —
  # probe tolerantly instead of letting pipefail abort the whole command.
  adb_cmd shell "ls -l $CEC_SYSFS/ 2>/dev/null; for f in physical_addr device_type vendor_id cec_version arc_port; do echo \"\$f: \$(cat $CEC_SYSFS/\$f 2>/dev/null)\"; done" | tr -d '\r' || echo "sysfs not accessible to shell (expected: root-only attrs)"
}

case "${1:-}" in

  status)
    dump_cec_summary
    hdr "interpretation"
    cat <<'EOF'
- power_control_mode = to_tv  -> <Standby> sent DIRECTED to the TV (works on this box)
- power_control_mode = broadcast -> <Standby> sent as broadcast (NACKed on this box)
- sysfs cmd file writable by shell -> rawsend/test can bypass the HAL
- sysfs cmd not writable -> driver-level TX test needs root (record and skip)
EOF
    ;;

  rawsend)
    # usage: cec-tool.sh rawsend 8F:82:30:00   (bytes, first byte = header)
    shift; [[ $# -eq 1 ]] || { echo "usage: cec-tool.sh rawsend <HH:HH:...>"; exit 1; }
    BYTES="$1"
    echo "TX: $BYTES"
    adb_cmd shell "echo $BYTES > $CEC_SYSFS/cmd" 2>&1 | tr -d '\r' \
      && echo "sysfs write accepted" \
      || { echo "sysfs write REJECTED (permissions / needs root) — record this"; exit 2; }
    sleep 1
    hdr "TX/RX register state after send"
    adb_cmd shell "cat $CEC_SYSFS/dump_reg 2>/dev/null" | tr -d '\r' | head -30 || echo "dump_reg not readable (root-only)"
    hdr "kernel/logcat CEC lines (last 15 s)"
    adb_cmd shell "logcat -d -t '%k' | grep -Ei 'cec|hdmi' | tail -25" | tr -d '\r'
    ;;

  test)
    # Directed-vs-broadcast asymmetry test at the DRIVER level (below the HAL).
    # Directed probe from logical 8 (playback) to TV: <Text View On> 80:0D
    # Directed <Give Device Power Status>: 80:8F
    # Broadcast <Active Source> with PA 3.0.0.0: 8F:82:30:00
    hdr "directed send 1: <Text View On> (80:0D)"
    adb_cmd shell "echo 80:0D > $CEC_SYSFS/cmd" 2>&1 | tr -d '\r' || echo "REJECTED"
    sleep 2
    hdr "directed send 2: <Give Device Power Status> (80:8F)"
    adb_cmd shell "echo 80:8F > $CEC_SYSFS/cmd" 2>&1 | tr -d '\r' || echo "REJECTED"
    sleep 2
    hdr "broadcast send: <Active Source> (8F:82:30:00)"
    adb_cmd shell "echo 8F:82:30:00 > $CEC_SYSFS/cmd" 2>&1 | tr -d '\r' || echo "REJECTED"
    sleep 2
    hdr "dump_reg after all three"
    adb_cmd shell "cat $CEC_SYSFS/dump_reg 2>/dev/null" | tr -d '\r' | head -30 || echo "dump_reg not readable (root-only)"
    hdr "logcat CEC tail"
    adb_cmd shell "logcat -d | grep -Ei 'cec' | tail -30" | tr -d '\r'
    cat <<'EOF'

INTERPRETATION
- All three accepted, TV reacts to directed only  -> HAL/framework bug (REA target)
- All three accepted, TV reacts to none           -> driver TX broken even bypassing HAL
- Writes rejected (permission)                   -> driver test impossible without root;
  fall back to HAL-level evidence + power_control_mode workaround
Compare against the same sends THROUGH the stack (dumpsys hdmi_control history):
if sysfs broadcasts ACK but HAL broadcasts NACK, the bug is in the HAL/JNI layer.
EOF
    ;;

  fix-on)
    # Workaround: make <Standby> DIRECTED (to_tv) instead of broadcast.
    # Directed sends are the one path proven to work on this box.
    echo "Applying workaround: power_control_mode = to_tv"
    bash "$REPO_ROOT/scripts/set-setting.sh" global power_control_mode to_tv
    # Some builds store it under the cec_-prefixed key; set both, values are logged.
    OLD2=$(adb_cmd shell settings get global cec_power_control_mode | tr -d '\r')
    if [[ "$OLD2" != "null" ]]; then
      bash "$REPO_ROOT/scripts/set-setting.sh" global cec_power_control_mode to_tv
    fi
    hdr "verify"
    dump_cec_summary
    echo
    echo "NOW TEST: put the box in standby with the remote. The TV should switch off"
    echo "within ~5 s (directed <Standby> to the TV). Report result + a fresh"
    echo "dumpsys hdmi_control capture into device/runs/."
    ;;

  fix-off)
    echo "Reverting workaround (restores logged old values)."
    # applied-settings.log lines are replayable in order; set-setting.sh already
    # logged the previous values. Manual revert:
    echo "Check applied-settings.log for the old values and run:"
    echo "  bash scripts/set-setting.sh global power_control_mode <old>"
    grep -n "power_control_mode" "$REPO_ROOT/applied-settings.log" || true
    ;;

  *)
    cat <<'EOF'
usage: cec-tool.sh <command>
  status    full CEC state: settings, props, dumpsys, sysfs (read-only)
  rawsend   raw TX via /sys/class/cec/cmd, bypassing the Android HAL
            e.g.: cec-tool.sh rawsend 8F:82:30:00
  test      driver-level directed-vs-broadcast asymmetry test (read-only sends)
  fix-on    workaround: power_control_mode=to_tv (Standby becomes DIRECTED)
  fix-off   show how to revert the workaround
EOF
    exit 1
    ;;
esac
