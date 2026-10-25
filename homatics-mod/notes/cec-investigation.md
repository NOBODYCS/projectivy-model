# CEC investigation — 2026-10-25

Pre-existing issue (broken "way before modding"). Not caused by, and not
fixable within, the debloat kit (CEC = vendor kernel/HAL territory,
com.sei.hdmi.services is protected). Net-zero device changes: one
hdmi_control_enabled 0→1 toggle during Test 2 (net effect zero; both
log lines removed from applied-settings.log). Dumps saved in
device/runs/2026-10-25-164542-batch-google2/ (hdmi-control-dump.txt,
hdmi-control-no-soundbar.txt, hdmi-control-reinit.txt).

## Setup (decoded from dumpsys hdmi_control, run 2026-10-25-164542-batch-google2)

| Device | Logical | Type | Physical | Name / vendor |
|--------|---------|------|----------|---------------|
| Box    | 0x08    | 4 (playback) | 0x3000 (TV HDMI3) | "LG C3" (user-set device name), vendor 0x1CA410 |
| Soundbar (Samsung HW-T5) | 0x05 | 5 (audio system) | 0x2000 (TV HDMI2/eARC) | HW-T5 Series, vendor 0x0000F0 |
| TV (LG C3) | 0x00 | 0 | 0xFFFF UNKNOWN | "TV", vendor 0xFFFFFF UNKNOWN |

Note: the box's own CEC name is "LG C3" — deliberately set by the user.
Do not confuse the box record with the TV record.

## Evidence (4-minute message history, 337-line dump)

1. ALL box broadcast sends failed — 51/51 NACK or driver error
   ("Failed to send … errorCode=1|3", ResendCecCommandAction retries):
   <Active Source> 8F:82:30:00, <Report Physical Address> 8F:84:30:00:04,
   <Device Vendor Id> 8F:87:…, <Standby> 8F:36.
2. Directed messages both ways WORK: box→TV <Text View On>/<Menu Status>/
   <Give Device Power Status> ACKed; TV→box <Give Physical Address> and
   <Report Power Status> received.
3. Consequence loop: TV polls box (08:83) every 14 s; box's answer is a
   broadcast that always fails → TV never learns the box's physical
   address → infinite re-poll (seen continuously 16:49–16:52+).
4. Box never learned the TV either: 0 TV broadcasts (0F:) received in the
   window (TV's <Report Physical Address> reply is broadcast 0F:84) →
   TV record stays 0xFFFF / vendor unknown.
5. Soundbar floods the bus: 103 broadcasts in ~4 min (<Device Vendor Id>
   5F:87:00:00:F0, <Set System Audio Mode> 5F:72:01, up to 10/s bursts).
   Box RX of 5F broadcasts works fine.
6. One-touch-play therefore HALF-works: <Text View On> (directed) reaches
   the TV, <Active Source> (broadcast) never does → TV does not switch
   input/wake from the box. <Standby> broadcast also fails → TV does not
   turn off with the box. Both are broadcast-only messages.
7. Soundbar feature-aborts <Set Audio Volume Level> (58:00:73) — cosmetic,
   volume-level sync unsupported.
8. HDMI TX driver errors at the standby transition:
   HDMITX_HDCP_AUTH_FAILURE, "audio chn msk must larger than 0" — vendor
   hdmitx driver noise during sleep/wake.
9. Props: ro.hdmi.device_type=[5,4] (box registers as audio_system AND
   playback — contends with the real soundbar for audio-system role);
   ro.hdmi.cec.source.playback_device_action_on_routing_control=
   wake_up_and_send_active_source.

## Symptoms (confirmed by user)

TV does not switch to the box on power-up; TV does not turn off with box
standby; power on/off flaky. All three match broadcast-path failures
(<Active Source>, <Standby>); the flaky/partial successes are the
surviving directed <Text View On>.

## Hypotheses (pre-test)

A. Box's CEC broadcast TX path is broken at the Amlogic/DroidLogic HAL /
   driver level (NACK for every broadcast while directed TX/RX works —
   an electrical fault cannot produce this asymmetry).
B. Soundbar bus flood (known Samsung HW-T behavior) causes bus
   contention that kills broadcast ACK.
C. Marginal HDMI cable/port CEC level.

## Test results (2026-10-25)

Test 1 — soundbar removed from bus (HDMI unplugged 17:00:07, dump
hdmi-control-no-soundbar.txt): with only the TV on the bus, 17:00:16 →
17:02:22, every box broadcast still NACKed/FAILed (9+ attempts) while TV
polls (08:83) and directed sends continued to work. **B ruled out.**

Test 2 — full CEC stack re-init (hdmi_control_enabled 0 → 1 via
set-setting.sh, dump hdmi-control-reinit.txt): address re-allocation and
full discovery ran at 17:04:12 (onAddressAllocated, Active Source +
Report Physical Address + Device Vendor Id broadcasts, Set Osd Name /
Give Device Vendor Id / Give Device Power Status directed sends).
Result identical: all broadcasts NACK, all directed sends ACK,
including <Set Osd Name> to the TV. **Not a stuck driver state.**
The 0→1 toggle netted to zero, so both lines were removed from
applied-settings.log (replaying them would have left CEC disabled).

## Conclusion

**Root cause: the box's own vendor CEC stack (Amlogic/DroidLogic/SEI)
cannot send broadcast messages** — they all fail at the driver/HAL level
with NACK or "Failed to send … errorCode=1|3". Every broadcast-only CEC
feature is therefore dead from the box side: one-touch-play input
switching (<Active Source>), TV-off-on-standby (<Standby>), and the
box's <Report Physical Address> that the TV needs to register it (hence
the TV's endless 14 s re-poll). Directed messages work both ways, so
<Report Power Status>, <Text View On> and system-audio messaging with
the soundbar survive.

Not caused by the debloat kit (CEC settings byte-identical to baseline;
com.sei.hdmi.services protected; symptom predates modding).

Remaining untested: HDMI port/cable (hypothesis C) — box on HDMI4 with a
new physical address. Low expectation: an electrical fault cannot explain
the directed-vs-broadcast asymmetry, but it is the only variable left.

## Remedies (realistic)

1. Vendor OTA / Homatics firmware update — the only real fix; the bug is
   in the vendor CEC HAL/kernel path. Re-test with this note's method
   after any OTA (Phase 6 durability re-verification).
   STATUS 2026-10-25: box is ALREADY on the latest released firmware,
   14.8.8963 (build UKG3.250803.001, 2026-05-22) — per r/Homatics this
   is the current rollout version for the Box R 4K Plus; no newer build
   exists in public channels. The box's own OTA check (skywayclient
   FirmwareCheckService) errors with otaCheckError/deviceNotOnline
   (Skyway hotel-platform DMS not provisioning retail boxes); no fix to
   wait for yet. Community reports confirm CEC problems persist on this
   firmware (same B21 remote), with a workaround of pairing the remote
   directly with the TV.
2. Workaround TV power via Home Assistant: box stays pingable in standby
   (notes/baseline-metrics.md) and the LG C3 can be driven by the webOS
   integration; see notes/homeassistant.md for the existing plan.
3. The TV's 14 s re-poll of the box is harmless bus noise (one message
   pair); no action needed.

## Not touched

No settings, no package changes. All CEC settings verified identical to
baseline (cec-settings.txt): hdmi_control_enabled=1, one_touch_play=1,
auto_wakeup=1, auto_device_off=1, volume_control=1, earc_enabled=1.

## Fix plan (2026-10-25, added after root-cause confirmation)

Two parallel tracks, both runnable from this repo:

1. **Workaround now — directed <Standby>**: AOSP `power_control_mode=to_tv`
   makes the box send <Standby> DIRECTED to the TV instead of broadcast
   (HdmiControlManager.POWER_CONTROL_MODE_TV = "to_tv"). Directed sends are
   the one path proven to work on this box (evidence item 2). Apply with
   `scripts/cec-tool.sh fix-on` (logged/restorable via set-setting.sh), then
   standby the box and confirm the TV powers off. This fixes TV-off-on-standby
   only; <Active Source> (one-touch-play input switching) is broadcast-only in
   AOSP and stays broken until the vendor fix. Verify the correct storage key
   first with `scripts/cec-tool.sh status` (some builds store it as
   `cec_power_control_mode` or in cec_config.xml shared prefs).
2. **Find the vendor bug — REA pass**: `notes/rea-cec-pass.md` has the exact
   commands and questions to decompile com.sei.hdmi.services and the
   DroidLogic CEC settings/overlay packages from the existing pull/ tree.

Driver-level test (hypothesis A refinement): `scripts/cec-tool.sh test` sends
directed and broadcast frames via /sys/class/cec/cmd, BELOW the Android HAL.
- sysfs broadcast ACKs but HAL broadcast NACKs → bug is in the HAL/JNI/vendor
  framework layer (REA pass will find it).
- sysfs broadcast also NACKs → bug is in the Amlogic aocec driver itself;
  REA pass is only useful for config, and the fix must come from the vendor.
- writes rejected → no shell access to the driver; rely on HAL-level evidence.

Order of operations: `cec-tool.sh status` → `cec-tool.sh test` → `cec-tool.sh
fix-on` + user standby test → REA pass per notes/rea-cec-pass.md.
