# REA pass: vendor CEC stack (Phase 7 — CEC broadcast-TX bug)

Goal: find the vendor bug that makes every broadcast CEC send fail
(NACK / "Failed to send … errorCode=1|3") while directed sends work.
Context and full evidence: `notes/cec-investigation.md`.

Setup: see `notes/rea-setup.md` (REA 6.8.0, jadx-headless-mcp JAR,
`REA_JADX_MCP_JAR` exported). Run from the kit root.

## What to inspect, in priority order

1. `pull/com.sei.hdmi.services/` — the vendor CEC manager that intercepts every
   key (`mSeiHdmiCecManager`). Highest-value target: any JNI bridge to the
   Amlogic CEC HAL (`/dev/cec`, `aocec`) and any TX-path filtering.
2. `pull/com.droidlogic.tv.settings/` — vendor settings slices; find which
   storage backend the box uses for `power_control_mode` (global setting key
   vs `cec_config.xml` shared prefs vs system property) and which values the
   UI accepts.
3. `pull/com.droidlogic.overlay/` — RRO carrying `cecPowerControlMode` and
   one-touch-play config; extract the default values and storage keys.
4. Any pulled `com.droidlogic.*` package containing `HdmiCec*` classes
   (`grep -rl "cec" pull/*/` on the extracted APKs).

## Commands

```bash
export REA_JADX_MCP_JAR=~/.local/share/rea/android/jadx-headless-mcp-0.7.1-all.jar
npx rea-agents@6.8.0 inspect-android-package pull/com.sei.hdmi.services/base.apk
npx rea-agents@6.8.0 inspect-android-package pull/com.droidlogic.tv.settings/base.apk
npx rea-agents@6.8.0 inspect-android-package pull/com.droidlogic.overlay/base.apk
```

## Questions per package (feed to REA)

1. Which classes call into the CEC HAL (`nativeSendCecCommand`,
   `/dev/cec` ioctl, `aocec`)? Trace the TX path: framework callback → JNI →
   driver. Where could a broadcast destination (0xF) be dropped or rewritten?
2. Does the code distinguish broadcast (destination 0xF) from directed
   sends anywhere — branching, retry logic, address validation?
3. Which settings keys does it read/write for CEC behavior
   (`power_control_mode`, `hdmi_control_*`, `persist.sys.hdmi.*`)? List exact
   key names, storage (global/secure/property/shared pref) and accepted values.
4. Any retry/errorCode mapping — what does errorCode=1|3 correspond to in the
   vendor code (driver constants: 1 = NACK, 3 = busy)?
5. Verdict per finding: vendor bug candidate / config-only workaround /
   not relevant, each with the evidence line (file + method).

## Ground truth for cross-checking

- AOSP reference: `HdmiControlManager.POWER_CONTROL_MODE_TV = "to_tv"` sends
  `<Standby>` DIRECTED to the TV instead of broadcast. On this box directed
  sends always work — that is the `cec-tool.sh fix-on` workaround.
- The box's CEC device type includes audio_system (`ro.hdmi.device_type=[5,4]`),
  which registers a second local device; check whether the vendor code
  mis-routes broadcasts between the playback and audio-system local devices.

## Output

Write findings to `inventory/rea-cec.md` with the same evidence discipline as
`inventory/inventory.md`. If a concrete vendor bug is found, quote the
decompiled evidence and note whether an OTA-fixed class version would resolve
it (compare with any newer firmware's APK if available).
