# Homatics Box R 4K Plus — Mod & Debloat Kit

Complete, self-contained kit. A CLI agent (Vibe Code or equivalent) executes it
on a PC on the same network as the box. The repo is the agent's memory: every
phase reads prior state from disk, so sessions are resumable.

## Principles (non-negotiable, enforced in scripts)

1. Disable-only: `pm disable-user --user 0`. Never `pm uninstall`, never delete files.
2. Nothing flashed. No USB Burning Tool, no recovery zips, no Magisk, no OTA sideload.
3. Protected list enforced. Widevine/DRM, SystemUI, package manager, Netflix and
   partner certification apps are never disabled.
4. Every disable is verified to have taken effect (`pm list packages -d` diff).
5. Every change is logged and mirrored to restore.sh at the moment it happens.
6. Batches of max 5, full checklist after each, whole batch reverted on regression.
7. Launcher safety order: install new → set default → only then disable stock.
8. Package names in lists must come verbatim from device dumps, never from memory.

## One-time host setup (the only manual steps)

On the PC:
```bash
sudo apt install adb openjdk-21-jre   # or: download Android platform-tools + any JDK 17+
npx rea-agents@6.8.0 setup             # or use CLI directly; see notes/rea-setup.md
```
On the box (remote + TV, human hands):
1. Settings → About → click "Build" 7× → Developer Options appears
2. Developer Options → Wireless debugging → On
3. "Pair device with pairing code" → note IP:pairing-port + 6-digit code
4. On PC: `adb pair <IP>:<pair-port>` (type code) then `adb connect <IP>:5555`
   (use the port shown on the second line of the wireless debugging screen)
5. On TV: accept prompt, check "Always allow from this computer"

## Execution playbook

Run phases in order. Each phase section below is a ready-to-type prompt for the
CLI agent. Do not skip ahead; every phase depends on the previous one's output.

### Phase 0 — baseline (read-only)
> Read scripts/baseline.sh and execute it. Then ask me to power-cycle the box
> twice and measure power-on→home time; record in notes/baseline-metrics.md.
> Then run scripts/wake-test.sh (I will press the power button on the remote).

### Phase 1 — inventory (read-only)
> Read scripts/inventory.sh and execute it to pull all system APKs into pull/.
> Then, for each APK under pull/, use REA (inspect-android-package) to answer:
> boot receivers/services, telemetry endpoints, hardware gating (HDMI/CEC/audio/
> LED/OTA), safe-to-disable assessment. Write per-package notes into
> inventory/inventory.md. Also run scripts/capture-buttons.sh (I will press
> remote buttons on request).

### Phase 2 — classification
> From inventory/inventory.md and device baseline dumps, produce lists/
> debloat.txt, watchlist.txt, protected.txt. Every debloat entry must be a
> package name that appears verbatim in the baseline packages-system.txt.
> Nothing enters debloat.txt without either community precedent or direct APK
> evidence. Voice/Assistant components go in their own batch file
> (lists/batch-voice.txt).

### Phase 3 — launcher + UX
> Install the Projectivy APK from the URL in preferences/projectivy.txt (or ask
> me for the file), verify it launches, then set it as default home
> (verify with `cmd package resolve-home` or dumpsys). Only after the new
> launcher is confirmed default: ask me to confirm home screen works, then
> disable the stock launcher packages listed in lists/launcher-stock.txt using
> scripts/apply.sh. Record animation-scale settings changes through
> scripts/set-setting.sh.

### Phase 4 — apply debloat
> Apply debloat.txt in batches of 3-5 using scripts/apply.sh, sorted so that
> each batch groups related packages. After EACH batch: run automated
> verification (screenshot, launch Netflix/YouTube via am start, logcat crash
> check, dumpsys package state), then ask me to confirm the manual checklist
> in checklists/per-batch.md. On any failure, run scripts/revert-batch.sh for
> the whole batch and move it to watchlist.

### Phase 5 — measure
> Re-run baseline captures into device/ and produce a before/after comparison
> in notes/results.md: idle RAM, process count, alarm/job counts, launcher
> screenshots. List anything still waking the box with a recommendation
> (second pass / accept).

### Phase 6 — durability
> After any OTA: re-run scripts/verify.sh, diff package lists against the
> latest backup, re-apply debloat.txt if re-enabled. Keep network debugging on
> if Home Assistant integration is planned (see notes/homeassistant.md).

## Restore

```bash
bash scripts/restore.sh    # everything back to stock behavior
```

## Layout

```
scripts/       baseline, inventory, backup, verify, apply, revert-batch,
               restore, set-setting, capture-buttons, wake-test, cec-tool
               (CEC diagnostics + power_control_mode workaround; see
               notes/cec-investigation.md and notes/rea-cec-pass.md)
device/        baseline dumps, backups, per-run captures
inventory/     per-package findings from REA
pull/          pulled APKs
lists/         debloat.txt, watchlist.txt, protected.txt, batch-voice.txt,
               launcher-stock.txt, pull-targets.txt
checklists/    per-batch.md
preferences/   projectivy.txt, ux-preferences.md
notes/         rea-setup.md, homeassistant.md, baseline-metrics.md, results.md
applied.log    timestamped disable history (auto-generated)
applied-settings.log  settings changes with old values (auto-generated)
```
