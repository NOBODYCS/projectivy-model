# REA pass: vendor CEC stack — findings (Phase 7.3, 2026-10-25)

Scope per notes/rea-cec-pass.md. REA 6.8.0 (jadx-headless-mcp 0.7.1) +
apktool 3.0.3 (downloaded this session, SHA-256 verified against the
GitHub release digest: dbf930b0…f9423; launcher at
~/.local/share/rea/android/apktool.sh, REA_APKTOOL_COMMAND).

Raw evidence: inventory/rea-json/com.sei.hdmi.services.json,
com.droidlogic.overlay.json, com.droidlogic.tv.settings.json.

## Q1: TX path trace (framework callback → JNI → driver)

**com.sei.hdmi.services v1.0.0.3 (20250306) opens its OWN parallel
connection to the CEC HAL, separate from system_server's
HdmiControlService.** Decompiled `SeiHdmiCecService.p()`
(REA inspect-android-method, display alias for the HAL-connector block):

    private void p() {
        this.q = new d();  // AIDL android.hardware.tv.hdmi.cec.IHdmiCec
        this.r = new b();  // HIDL android.hardware.tv.cec@1.1::IHdmiCec
        this.s = new c();  // HIDL android.hardware.tv.cec@1.0::IHdmiCec
        if (dVar == null || !dVar.a()) {          // AIDL HAL not available?
            ... fallback chain cec@1.1, then cec@1.0 ...
        } else {
            this.t = true;                        // mHdmiCecHalAidlAvailable
            this.q.e(new g(this));                // register callback #1
            this.q.f(new h(this));                // register callback #2
            Log.d(A, "connect to cec AIDL HALs");
        }
        Log.d(A, "initConnectToHal mHdmiCecHalAidlAvailable: " + this.t + ...);
    }

Smali confirms the raw interfaces (const-string evidence):
"android.hardware.tv.cec@1.0::IHdmiCec", "@1.0::IHdmiCecCallback",
"@1.1::IHdmiCec", "@1.1::IHdmiCecCallback" plus AIDL proxies
android/hardware/tv/hdmi/cec/{e,f}.smali (IHdmiCec + callback) built
against CecMessage. `o()` = initCecSignatureData keeps the service's own
CEC identity (vendorId from the HAL, logicalAddress, displayName,
physicalAddress).

The service is persistent + boot-started (manifest: BOOT_COMPLETED
receiver, persistent service), registers an HdmiControlManager hotplug
listener, and re-runs p() on every hotplug "connected" event
(onReceived → synchronized p() + o()).

**Implication:** the box runs TWO CEC HAL clients against the single
Amlogic HAL daemon (hdmicecd → /sys fe044000.aocec): AOSP
HdmiControlService (system_server) and SeiHdmiCecService. The AIDL
IHdmiCec contract has a single callback slot — every setCallback
replaces the previous one. A second client re-registering callbacks on
hotplug can steal the RX channel from the framework, and the native
daemon must arbitrate two senders. This is the most plausible mechanism
for the observed STATE-DEPENDENT broadcast failure: whichever client
last (re)registered and the daemon's internal arbitration decides
whether broadcasts get ACKed (observed: NACK for days → ACK after bus
change + CEC re-init). Not proven to the line, but every observed
symptom (broadcast TX NACK, broadcast RX dropped by framework, sudden
recovery after re-init) fits a dual-client arbitration/callback bug in
hdmicecd.

The actual broadcast-drop/rewrite code is in hdmicecd (native daemon,
pid 518) — not in any pulled APK; not analyzable without root.

## Q2: broadcast-vs-directed branching in the SEI app

None found in com.sei.hdmi.services / droidlogic lib classes inspected.
The app is a client; no TX filtering/branching on destination 0xF.
Verdict: not relevant — the asymmetry lives below this layer.

## Q3: settings keys / storage backends

- com.droidlogic.app.HdmiCecManager (bundled in the SEI APK):
  enable*/is* flags → Settings.Global (decompiled writeValue):
      Settings.Global.putInt(context.getContentResolver(), str, z ? 1 : 0);
  Keys = hdmi_control_* family (verified on-device earlier: all live in
  Settings.Global and match the baseline cec-settings.txt).
- com.droidlogic.overlay (RRO): NO CEC config at all. Its only two
  string overrides are config_defaultSupervisionProfileOwnerComponent
  and config_deviceConfiguratorPackageName (GMS). The hypothesis in
  rea-cec-pass.md ("RRO carrying cecPowerControlMode") is refuted.
- com.droidlogic.tv.settings (DroidTvSettings.apk): HdmiCecFragment/
  HdmiCecActivity/HdmiCecContentManager handle only the enable flags
  (setHdmiCecEnabled, setOneTouchPlayStatus, setVolumeControlStatus,
  setSoundbarModeStatus, setDeviceAutoPowerOffStatus, setMenuLanguage).
  **power_control_mode is NOT exposed or stored by the vendor Settings
  UI anywhere.**
- power_control_mode is owned by the AOSP framework's
  HdmiCecSettingsManager inside system_server (dumpsys "CEC settings:
  power_control_mode (string): broadcast [modifiable]"). Empirically,
  a Settings.Global write of "power_control_mode" did NOT change the
  framework-reported value even after a full CEC re-init (Phase 7.2):
  the manager caches at service start and/or reads a non-Global store.
  The key takes effect at earliest on next full reboot — unverified.

## Q4: errorCode mapping

"Failed to send <X> … with errorCode=1|3" (logcat, HDMI tag) matches
the AIDL android.hardware.tv.hdmi.cec SendMessageResult enum:
SUCCESS=0, NACK=1, BUSY=2, FAIL=3. Observed (NACK, NACK) pairs =
errorCode 1; (FAIL, NACK)/(FAIL, FAIL) = 3. So the framework is being
told by the HAL that nobody ACKed the frame (1) or the send failed
outright (3) — consistent with frames not reaching the wire while the
daemon arbitrates clients, and with directed sends succeeding.

## Q5: device_type [5,4] mis-routing

ro.hdmi.device_type=[5,4] → the framework registers local devices for
BOTH audio_system (5) and playback (4) (dumpsys: mCecLocalDevices: 5 4;
"device type from getCecLocalDeviceTypes: 4"). No mis-routing code was
found in the pulled APKs; the arbitration is in hdmicecd. Noting that
the earlier system-audio contention with a real soundbar on the bus
(HW-T5 flooding Set System Audio Mode) plus a phantom audio-system
local device is another consequence of this vendor config, but it is
not the broadcast-TX root cause.

## Verdicts

1. STRONG CANDIDATE (unproven to the line): dual CEC HAL clients
   (AOSP HdmiControlService + persistent SeiHdmiCecService, re-registering
   callbacks on hotplug) against the single-callback AIDL IHdmiCec
   contract in the Amlogic hdmicecd daemon → state-dependent broadcast
   TX NACK and broadcast RX loss. An OTA fixing hdmicecd/SeiHdmiCecService
   callback re-registration would resolve it. Vendor classes of interest:
   com.sei.hdmi.services.SeiHdmiCecService.p()/onReceived() and hdmicecd
   (native).
2. CONFIG-ONLY: power_control_mode/to_tv workaround — the vendor stack
   never reads the Settings.Global key live; effective only via the
   framework (boot-time read at best).
3. NOT RELEVANT: com.droidlogic.overlay (no CEC), Settings UI (no
   power_control_mode), HdmiCecManager enable flags (work, already
   verified on-device).

## Method notes (REA capabilities used)

inspect-android-package (manifest/components), search-android-classes,
inspect-android-class, inspect-android-method (decompiled quotes
above), decode-android-resources (apktool via REA_APKTOOL_COMMAND
launcher script — REA requires an absolute launcher path, not a
command string). `rea search` and `decompile-all` do NOT support APK
targets (native-only providers); obfuscated short-name methods
(e/f/g/h wrappers) were not resolvable via inspect-android-method, so
apktool smali grep was used for the interface-descriptor evidence.
