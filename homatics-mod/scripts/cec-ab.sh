#!/usr/bin/env bash
# CEC dual-client hypothesis test — Phase 8.
#
# Hypothesis (inventory/rea-cec.md verdict 1): com.sei.hdmi.services
# (SeiHdmiCecService) opens a SECOND CEC HAL client alongside the AOSP
# HdmiControlService; both fight for the single callback slot in hdmicecd,
# and the arbitration state decides whether broadcast frames reach the
# wire (state-dependent NACK observed for days, 50 s good window once).
#
# Removing the second client should make broadcast TX deterministic.
# This script stages that removal as a TIME-BOXED, fully-logged,
# fully-revertible A/B test. The user runs each stage and does the
# manual checks; every disable is mirrored to restore.sh + applied.log
# by apply.sh/revert-batch.sh semantics (reused here via pm enable).
#
# PROTECTED-LIST EXCEPTION: com.sei.hdmi.services is protected (remote-key
# interception mSeiHdmiCecManager, CEC/audio persist keys). This test is
# the ONE justified exception: the package itself is the prime suspect
# for the CEC bug, and the disable is temporary + auto-revertible.
# Remote-key handling may break while disabled — that is an expected,
# observable outcome, not a regression to panic about.
#
# usage: cec-ab.sh <stage1|stage1-revert|stage2|stage2-revert|report>
set -euo pipefail
source "$(dirname "$0")/common.sh"
require_device

PKG="com.sei.hdmi.services"
SVC="$PKG/com.sei.hdmi.services.SeiHdmiCecService"
LOG="$REPO_ROOT/applied.log"
RUN_DIR="$(timestamped)-cec-ab"
mkdir -p "$RUN_DIR"

capture() {  # capture <label>
  local label="$1"
  echo "--- capture: $label ---"
  adb_cmd shell dumpsys hdmi_control > "$RUN_DIR/$label-dumpsys.txt" 2>&1 || true
  adb_cmd shell "logcat -d | grep -Ei 'cec|hdmi' | tail -80" > "$RUN_DIR/$label-logcat.txt" 2>&1 || true
  adb_cmd shell dumpsys package "$PKG" > "$RUN_DIR/$label-pkg.txt" 2>&1 || true
}

broadcast_probe() {  # force a broadcast via the framework: re-init makes the
  # stack send <Active Source>/<Report Physical Address>/<Device Vendor Id>
  # broadcasts; then read the fresh history.
  local t0 t1
  t0=$(date +%s)
  adb_cmd shell settings put global hdmi_control_enabled 0
  sleep 2
  adb_cmd shell settings put global hdmi_control_enabled 1
  sleep 8
  t1=$(date +%s)
  adb_cmd shell dumpsys hdmi_control | tr -d '\r' | \
    grep -E 'sendMessage|Failed to send|errorCode|initiated' | tail -40
}

case "${1:-}" in

  stage1)
    # STAGE 1 — component-only disable (least invasive; may be rejected).
    echo "Stage 1: disabling ONLY the SeiHdmiCecService component."
    echo "If the vendor protects component state, expect a SecurityException"
    echo "(same as com.nes.seilivetv) — then go straight to stage 2."
    if adb_cmd shell pm disable "$SVC" 2>&1 | tee "$RUN_DIR/stage1-pm.txt"; then
      echo "$(date -Is) disable-component $SVC" >> "$LOG"
      echo "adb shell pm enable '$SVC'" >> "$REPO_ROOT/scripts/restore.sh"
      echo "-> logged + mirrored to restore.sh"
    else
      echo "Component disable REJECTED — proceeding needs stage 2 (full package)."
      exit 3
    fi
    capture stage1-post
    echo ""
    echo "=== MANUAL CHECKS NOW (2 minutes) ==="
    echo "1. Remote: do HOME/BACK/OK/dpad keys still work?"
    echo "2. Run:    bash scripts/cec-ab.sh probe"
    echo "   Then look for: broadcast sends ACK (no 'Failed to send',"
    echo "   no errorCode=1|3 on 8F:/0F: frames) in the printed history."
    echo "3. TV input switch: wake box from standby — does the TV switch to it?"
    echo "If keys broke AND broadcasts still NACK: stage1-revert, then stage 2."
    ;;

  stage1-revert)
    echo "Reverting stage 1 (component enable)."
    adb_cmd shell pm enable "$SVC" 2>&1 | tee "$RUN_DIR/stage1-revert.txt" || true
    echo "$(date -Is) revert-enable-component $SVC" >> "$LOG"
    capture stage1-reverted
    echo "Component re-enabled. Verify remote keys work again."
    ;;

  stage2)
    # STAGE 2 — full package disable (disable-user, kit-standard).
    echo "Stage 2: disabling the WHOLE package (pm disable-user --user 0)."
    echo "Remote keys may STOP working while disabled — expected, revertible."
    read -r -p "Type 'yes' to proceed: " ok
    [[ "$ok" == "yes" ]] || { echo "aborted"; exit 1; }
    adb_cmd shell pm disable-user --user 0 "$PKG"
    if adb_cmd shell pm list packages -d | tr -d '\r' | grep -x "package:$PKG" > /dev/null; then
      echo "$(date -Is) disable $PKG (CEC-AB test, PROTECTED-LIST EXCEPTION, revert ASAP)" >> "$LOG"
      echo "adb shell pm enable '$PKG'" >> "$REPO_ROOT/scripts/restore.sh"
      echo "-> logged + mirrored to restore.sh"
    else
      echo "ERROR: $PKG did not show as disabled" >&2; exit 1
    fi
    capture stage2-post
    echo ""
    echo "=== MANUAL CHECKS NOW (5 minutes) ==="
    echo "1. Remote: HOME/BACK/OK/dpad — if dead, use the box's physical"
    echo "   button or adb input keyevent to navigate. This is expected;"
    echo "   the key path runs through this package (mSeiHdmiCecManager)."
    echo "2. bash scripts/cec-ab.sh probe  — are broadcasts ACKed now?"
    echo "3. Standby/wake cycle: does the TV turn OFF with the box and"
    echo "   switch INPUT on wake? Repeat 2-3 times (state-dependence test)."
    echo "4. If broadcasts ACK consistently across cycles: ROOT CAUSE PROVEN."
    echo "   Decision time: keep disabled (accept key-path risk) or revert"
    echo "   and go vendor/HA route. Do NOT leave it disabled undecided."
    echo "5. Any regression: bash scripts/cec-ab.sh stage2-revert"
    ;;

  stage2-revert)
    echo "Reverting stage 2 (package enable = full restore)."
    adb_cmd shell pm enable "$PKG"
    echo "$(date -Is) revert-enable $PKG" >> "$LOG"
    capture stage2-reverted
    echo "Package re-enabled. Verify remote keys + CEC behavior, then run:"
    echo "  bash scripts/cec-ab.sh probe   # expect NACK again (hypothesis confirmed)"
    ;;

  probe)
    # Forces framework broadcasts via a net-zero CEC re-init and prints
    # fresh send history. Use before AND after each stage.
    echo "Probing broadcast TX (net-zero re-init, ~15 s)..."
    broadcast_probe | tee "$RUN_DIR/probe-$(date +%H%M%S).txt"
    echo ""
    echo "Read the output: 8F:82/8F:84/8F:87 frames with no 'Failed to send'"
    echo "/ errorCode=1|3 => broadcasts healthy. Note: the re-init itself is"
    echo "net-zero (0->1 toggle restored immediately)."
    ;;

  report)
    echo "=== CEC A/B test state ==="
    echo "disabled packages (grep $PKG):"
    adb_cmd shell pm list packages -d | tr -d '\r' | grep "$PKG" || echo "  (not disabled)"
    echo ""
    echo "component state:"
    adb_cmd shell dumpsys package "$PKG" | tr -d '\r' | grep -A2 "SeiHdmiCecService" | head -8 || true
    echo ""
    echo "run captures in: $RUN_DIR (relative to repo root: device/runs/...)"
    ls -la "$RUN_DIR" | tail -n +2 || true
    ;;

  *)
    cat <<EOF
usage: cec-ab.sh <command>
  stage1          disable ONLY the SeiHdmiCecService component (may be rejected)
  stage1-revert   re-enable the component
  stage2          disable the whole package (PROTECTED-LIST EXCEPTION, confirm)
  stage2-revert   re-enable the package (full restore)
  probe           net-zero CEC re-init + fresh broadcast-TX history print
  report          current state of the A/B test
Run order: probe (baseline NACK) -> stage1 -> checks -> probe -> [stage2] ->
checks + standby cycles -> decision -> stageX-revert (or keep + document).
EOF
    exit 1
    ;;
esac
