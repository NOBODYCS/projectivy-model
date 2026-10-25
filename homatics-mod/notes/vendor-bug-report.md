# Vendor bug report — CEC broadcast-TX failure (ready to send)

Send to: SEI Robotics (support@homatics.com; Homatics Telegram support per
homatics.com/pages/faqs) and/or Homatics support. Attach
device/runs/*-cec-verify.txt and the Phase 7 sections of
notes/cec-investigation.md as evidence.

---

**Subject:** Box R 4K Plus (firmware 14.8.8963): all broadcast CEC sends NACK
while directed sends work; SeiHdmiCecService dual HAL client suspected

**Device:** Homatics Box R 4K Plus, Android 14, firmware 14.8.8963
(build UKG3.250803.001, 2026-05-22)
**TV:** LG OLED55C35L (SimpLink on)
**Bus:** LG C3 + Samsung HW-T5 soundbar (eARC on TV HDMI2) + PS5 Pro

**Symptoms**
1. Every broadcast CEC send from the box fails (NACK / HAL FAIL):
   <Active Source>, <Report Physical Address>, <Device Vendor Id>,
   <Standby>, <Set Osd Name> when broadcast. Result: no one-touch-play
   input switching, TV does not turn off with box standby, and the TV
   re-polls the box with <Give Physical Address> every 14 s forever
   because the box's broadcast reply never reaches it.
2. Directed CEC messages work in BOTH directions (box↔TV <Text View On>,
   <Give/Report Device Power Status>; system-audio with the soundbar).
3. The failure is state-dependent: broadcasts were stuck NACK for days,
   worked for exactly ~50 s after a bus change + CEC re-init on one
   occasion, then NACK again. After a reboot the box boots directly into
   the broken state. No software sequence reproduces the good window.

**Evidence**
- 51/51 broadcast sends NACK/errorCode=1|3 over a 4-minute dumpsys
  hdmi_control history; directed sends ACK in the same window.
- Same result with the soundbar removed from the bus (single TV only),
  and after a full CEC stack re-init (hdmi_control_enabled 0→1):
  all broadcasts NACK, all directed ACK.
- errorCode 1|3 matches AIDL SendMessageResult NACK=1 / FAIL=3.
- The box's own CEC name, vendor ID and physical address are correct in
  dumpsys; RX of broadcasts from other devices works.

**Analysis (decompiled from the shipped APK, jadx/apktool)**
com.sei.hdmi.services v1.0.0.3 — SeiHdmiCecService.initConnectToHal()
(p()) — opens its own persistent AIDL IHdmiCec connection to the CEC HAL
(with HIDL cec@1.1 / cec@1.0 fallbacks), registers its own callbacks, and
re-runs the connection + re-registers callbacks on EVERY HDMI hotplug
event. This runs alongside system_server's HdmiControlService, which
connects to the same HAL. The AIDL IHdmiCec callback contract has a
single callback slot; two clients repeatedly re-registering on the same
daemon (hdmicecd) must arbitrate both the callback and the TX queue.
We believe this arbitration is where broadcast frames are dropped, and
it matches the observed state-dependent behavior.

**Request**
1. Please forward to the firmware team: check hdmicecd's multi-client
   arbitration and SeiHdmiCecService's callback re-registration on
   hotplug (com.sei.hdmi.services.SeiHdmiCecService.p() / onReceived()).
2. Can a firmware update fix this? Is a fixed build planned for the
   Box R 4K Plus?
3. If useful, we can provide full dumpsys captures, logcat logs and the
   decompiled evidence.

Device serial: [fill in from the sticker on the bottom of the box]
