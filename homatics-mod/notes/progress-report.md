# Homatics Box R 4K Plus mod kit — progress report (2026-10-25)

Device: Homatics Box R 4K Plus (ro.product.device: YYJ), Android 14
Host: adb 192.168.60.253:5555 (wireless debugging), REA CLI rea-agents@6.8.0

## Phase 0 — baseline (COMPLETE)

- Baseline run: `device/runs/2026-10-25-143813` — all 15 dumps + screenshot +
  bugreport.zip captured.
- Idle snapshot: 366 processes; Total RAM 3,497,520K (~3.34 GB), Free RAM
  1,613,396K; packages 150 total / 138 system / 12 user / 1 disabled (stock).
- Manual measurements (recorded in `notes/baseline-metrics.md`):
  power-on → home < 30 s (both runs), launcher cold start < 2 s.
- Wake test: box **remains pingable in standby** — Home Assistant power-on
  integration looks viable (see `notes/homeassistant.md`).
- Bug fixed: `scripts/baseline.sh` invoked bare `device_config` (help text
  only). Changed to `device_config list`; recaptured 1,524 flags.

## Phase 1 — inventory (COMPLETE)

### REA analysis pass (COMPLETE)

- 61/61 pulled APKs inspected via REA inspect-android-package (jadx
  headless 0.7.1, REA_JADX_MCP_JAR exported); raw evidence + strings
  extraction (URLs, hardware keywords, persist.* keys) in
  `inventory/rea-json/`.
- 2 /vendor-unreadable packages analyzed from baseline dumpsys instead
  (both protected).
- `inventory/inventory.md` written: verdict summary table + 61
  per-package findings (boot receivers, services, telemetry endpoints,
  persist keys, hardware-gating perms, verdict with evidence) + button
  cross-analysis + Phase 2 handoff notes.
- Verdict distribution: 12 safe-to-disable, 13 watchlist, 36 protected,
  2 keep. Voice: com.google.android.katniss. Launcher set moves in
  Phase 3.

### Mute/volume retest (15 s window)

- `scripts/capture-buttons.sh` now takes `CAPTURE_WINDOW` (seconds,
  default 6).
- Result: mute/volume STILL produce no getevent events with 15 s windows
  and repeated presses — confirmed they bypass the Linux input layer.
  WindowManager logcat shows injected vendor keycodes (mute: 5122; a
  keyCode=4 burst during the volume window, attribution partly ambiguous
  due to tail-40 overlap). Mute also launched
  com.android.tv.settings/.sei.TC.TcTBtnDefinitionActivity.
- Working hypothesis (documented in inventory.md): BLE-GATT to
  com.nes.blerc → injected InputEvents. blerc and the key-interception
  chain are protected.

### APK pull (COMPLETE — 61/63)

- `lists/pull-targets.txt` populated with 63 packages taken verbatim from
  baseline `packages-system.txt`: matches of `homatics|sei|amlogic` + all
  `com.google.android.*` + (user-approved addition) all `com.nes.*` and
  `com.droidlogic.*` vendor packages.
- Pulled into `pull/` (877 MB): 61 of 63 complete.
- Not pullable (shell user denied read on /vendor, no root):
  `com.droidlogic.tvinput` (/vendor/app/DroidLogicTvInput/…) and
  `com.google.android.networkstack.tethering.google`
  (/vendor/overlay/GoogleTetheringOverlay.apk). Both will be analyzed from
  baseline `dumpsys-package.txt` instead.
- Bug fixed: `scripts/inventory.sh` — `adb shell` inside the `while read`
  loop slurped the loop's stdin, so only the first package was pulled.
  Added `< /dev/null` to the in-loop `adb shell` / `adb pull` calls.

### REA tooling (SET UP, analysis pass PENDING)

- `npx rea-agents@6.8.0` works (`inspect-android-package`, `pull-adb-package`,
  etc.).
- jadx-headless-mcp 0.7.1 JAR downloaded to
  `~/.local/share/rea/android/jadx-headless-mcp-0.7.1-all.jar`,
  SHA-256 verified against the pin in `notes/rea-setup.md`
  (6e5eacf5…573ff75 OK). Export `REA_JADX_MCP_JAR` to that path before
  running inspections.
- Remaining: run `inspect-android-package` per pulled APK (boot
  receivers/services, telemetry endpoints, settings keys + hardware gating,
  verdict) and write `inventory/inventory.md`.

### Remote button capture (COMPLETE — 11 buttons, one anomaly)

Captured to `device/button-inventory.txt` via `scripts/capture-buttons.sh`
(6-second getevent window per button + logcat tail; run in two passes and
merged — the script truncates its output on start, so pass 1 was backed up
and concatenated). Source device for all captured keys: `/dev/input/event10`
("B21 Keyboard", the BT remote).

| Button    | Linux keycode            | Notes                                        |
|-----------|--------------------------|----------------------------------------------|
| power     | KEY_POWER                | Short press toggles standby; SLEEP/WAKE WindowManager transitions logged |
| home      | KEY_HOMEPAGE             |                                              |
| back      | KEY_BACK                 |                                              |
| ok/center | KEY_SELECT               |                                              |
| netflix   | KEY_UNKNOWN (vendor scan)| Hotkey intent handled above the input layer (see below) |
| youtube   | KEY_UNKNOWN (vendor scan)| Same                                         |
| prime     | KEY_KBDILLUMUP          | Vendor-remapped scancode (Prime Video hotkey), same mapping pattern as the KEY_UNKNOWN hotkeys |
| apps      | KEY_KBDILLUMDOWN       | Vendor-remapped scancode (app-list hotkey)   |
| mute      | — nothing in getevent  | See anomaly below                            |
| volume_up | — nothing in getevent    | See anomaly below                            |
| volume_down | — nothing in getevent  | See anomaly below                            |

Findings from the logs:

- Every key press passes through `WindowManager: interceptKeyTq
  mSeiHdmiCecManager begin !` — the SEI HDMI/CEC manager
  (`com.sei.hdmi.services`) intercepts all key handling. Strong evidence it
  is protected (hardware gating).
- Netflix/YouTube hotkeys emit `KEY_UNKNOWN` scancodes on event10, and Prime
  Video / Apps emit remapped `KEY_KBDILLUMUP` / `KEY_KBDILLUMDOWN` scancodes;
  the app-launch mapping must happen in a vendor keylayout or
  `com.nes.tvglobalkeyhandler`. Feed to REA in the analysis pass.
- Anomaly: mute and both volume buttons produced no getevent events and no
  fresh logcat activity (the logcat tails in those sections are identical
  leftovers from the previous BACK capture — `logcat -d | tail -40` overlaps).
  Likely those buttons are consumed below the Android input layer (IR →
  audio HAL) or the presses fell outside the recording windows. Needs a
  retest with a longer window if volume-key behavior matters later.

### Script bugs fixed during this phase

1. `scripts/inventory.sh` — adb stdin slurp broke the pull loop (fixed).
2. `scripts/capture-buttons.sh` — three stacked bugs, all fixed:
   - `timeout 6 adb_cmd …` cannot invoke a shell function (nothing captured);
   - backgrounding the `adb_cmd` function orphaned the adb child on kill,
     so streams kept appending (duplicated/bleeding events);
   - `adb shell getevent` slurped the script stdin, eating the next button
     name. Now: stdin `< /dev/null` on all in-loop adb calls, window closed
     via `pkill -f "getevent -l"`, then `wait`.

## Phase 3 — launcher + UX (COMPLETE, 2026-10-25)

- Projectivy 4.72 installed from official repo (github.com/spocky/miproja1,
  release asset SHA-256 verified against GitHub's digest; package
  com.spocky.projengmenu). First launch + onboarding verified
  (device/projectivy-first-launch.png).
- Default home: `cmd package set-home-activity` and `cmd role
  add-role-holder` both failed silently; HOME role granted via the on-screen
  picker (user action, permissioncontroller DefaultAppActivity). Verified:
  `cmd role get-role-holders android.app.role.HOME` → com.spocky.projengmenu.
- VENDOR HOME HIJACK FOUND: even with the role granted, pressing HOME
  launched the stock tvlauncher. Logcat evidence: vendor
  PhoneWindowManager.handleHomeShortcuts (not AOSP) + a START of
  tvlauncher/.MainActivity with extras from uid 0, plus
  com.nes.skywayclient's SkywayHomeReceiver listening for homekey.
  Fix: disable the stock launcher — HOME then falls through to the role
  holder. Confirmed working.
- Launcher batch (all via apply.sh, HOME→Projectivy verified after each,
  no crashes): disabled com.google.android.tvlauncher,
  com.nes.leanbacklauncher.partnercustomizer, com.nes.recents.
  com.google.android.tvrecommendations MOVED to watchlist.txt per user
  decision (Continue Watching row wanted; re-evaluate after one week of
  Projectivy use) — re-enabled via revert-batch.sh.
- Animation scales set to 0.5 (window/transition/animator; old value 1.0
  logged in applied-settings.log) via set-setting.sh.
- Backup: scripts/backup.sh → device/backups/2026-10-25-155048.
  Projectivy in-app backup (Settings → General → Backup) NOT yet exported by
  user — re-run backup.sh after exporting to pick it up.
- Kit bugs fixed this phase:
  1. apply.sh: `grep -qx` early-exit + pipefail → SIGPIPE made every check
     fail (false "not installed" / false verify failure). Replaced with
     `grep -x ... > /dev/null` (reads whole stream).
  2. backup.sh: device-side `ls | grep` with no match exited 1 and, with
     set -e + pipefail, aborted the script after the dumps. Added `|| true`.
- Note: device/backups/ contains two partial dirs from the pre-fix failed
  runs (dumps complete, no Projectivy file) — safe to delete.

## Phase 4 — apply debloat (IN PROGRESS — 4 of 5 batches applied)

Batch history (all via apply.sh, mirrored to restore.sh):

| # | Batch | Packages | State |
|---|-------|----------|-------|
| 1 | remoteota trio | remoteota.one/two/six | APPLIED 16:15, disabled on device |
| 2 | vendor test/telemetry | dvb.playtest, bugreportsender | APPLIED 16:22, disabled on device |
| 3 | Google one-shots (5 of 7) | autoinstalls.config.sei, tv.feedbackconsent, backdrop, feedback, onetimeinitializer | APPLIED 16:23, disabled on device |
| 4 | Google one-shots (part 2) | play.games, syncadapters.calendar | APPLIED 16:46, disabled on device; automated checklist green (below) |
| 5 | voice | katniss (batch-voice.txt) | PENDING — own batch + mic-key verification |

Automated verification, batch 4 (run dir `device/runs/2026-10-25-164542-batch-google2/`):
`pm list packages -d` shows the full batch disabled; screenshots captured
(home.png, after-launch.png); `am start` Netflix (com.netflix.ninja, existing
task brought to front) and Settings OK; YouTube launched via monkey launcher
intent — real launcher activity is com.google.android.youtube.tv/…ShellActivity
(a guessed activity name failed with Error type 3; resolve via
`cmd package resolve-activity` instead of guessing); `logcat -d *:E`: 0
FATAL/ANR, 0 mentions of play.games or syncadapters; `dumpsys activity
processes`: no restart loops. MANUAL per-batch checklist NOT yet confirmed by
user for batches 1-4. Batches 1-3 also have no automated-verification run
dir recorded (predates this session).

### Firmware status (2026-10-25)

Box is on 14.8.8963 (build UKG3.250803.001, incremental 8963, dated
2026-05-22) — the latest released firmware for the Box R 4K Plus; no
pending updates. OTA check path is com.nes.skywayclient
FirmwareCheckService; it errors (otaCheckError/deviceNotOnline —
Skyway hotel DMS doesn't provision retail boxes), which is expected
and harmless while on the latest build.
CAVEAT for batch 1 (remoteota trio): those packages are the BLE-remote
firmware update path. If Homatics ships a remote firmware update
(they have recommended remote updates publicly), temporarily
re-enable com.nes.remoteota.{one,two,six}, update the remote,
re-disable. Nothing to do now.

### Findings and fixes this session

- `scripts/verify.sh` was broken: it sorted raw debloat.txt lines without
  stripping comments/inline `# …` annotations, so every comparison line
  mismatched and it always exited 1 with spurious "RE-ENABLED BY OTA"
  output. Fixed: comment lines and inline annotations stripped before
  `comm`. Now exits 0 (all 12 debloat.txt entries disabled on device).
- `com.nes.seilivetv` mystery resolved: it is the single package the vendor
  ships DISABLED at baseline (baseline packages-disabled.txt; dumpsys
  `enabled=2` = DISABLED, not the DISABLED_USER=3 that disable-user sets).
  `pm enable` is rejected (SecurityException "Shell cannot change component
  state") — vendor-protected. Never disabled by this kit, cannot be
  re-enabled from shell. Watchlist entry annotated; no action possible or
  needed. applied.log has no entry for it (the revert attempt aborted on
  the SecurityException before logging, thanks to set -e).

## Next steps

1. User confirms manual per-batch checklist for batches 1-4 (Netflix DRM
   playback mandatory every batch; reboot clean to Projectivy — not done
   since batch 1).
2. batch-voice.txt (katniss) as its own batch after that, mic-key
   verification (in-app YouTube/Netflix mic search must still work).
3. Watchlist entries need dedicated verification batches before promotion.
4. tvrecommendations re-evaluation after one week of Projectivy use.
5. Phase 5 (measure) once Phase 4 batches are user-confirmed.
