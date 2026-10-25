# REA setup notes (host PC)

Install: `npx rea-agents@6.8.0 setup` (pin to 6.8.0, the current release at kit
creation). Vibe Code is not among setup's named clients; use Route B (CLI):

```bash
npx -y rea-agents@6.8.0 <command>
```

Key CLI commands used by this kit (see docs/cli.md, docs/adb-device-analysis.md
in https://github.com/morluto/rea):

```bash
npx rea-agents@6.8.0 inspect-adb-client
npx rea-agents@6.8.0 list-adb-devices
npx rea-agents@6.8.0 list-adb-packages <serial> --scope system
npx rea-agents@6.8.0 pull-adb-package <serial> <package> --output-directory pull/
npx rea-agents@6.8.0 inspect-android-package pull/<pkg>/base.apk
npx rea-agents@6.8.0 capture-adb-screen <serial> --output-directory device/
npx rea-agents@6.8.0 collect-adb-bugreport <serial> --output-directory device/
```

Android APK analysis requires headless JADX. REA uses a pinned
jadx-headless-mcp JAR, not a plain JADX install:

```bash
mkdir -p ~/.local/share/rea/android && cd ~/.local/share/rea/android
curl -fL -o jadx-headless-mcp-0.7.1-all.jar \
  https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar
echo '6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75  jadx-headless-mcp-0.7.1-all.jar' | sha256sum -c -
export REA_JADX_MCP_JAR="$PWD/jadx-headless-mcp-0.7.1-all.jar"
```
(SHA-256 is REA's pinned release metadata; re-verify against
morluto/rea src/android/JadxRelease.ts if the version has moved.)

Per-APK analysis questions for Phase 1 (feed to the agent):
1. Which broadcast receivers/services start at boot (BOOT_COMPLETED, LOCKED_BOOT)?
2. Which telemetry/network endpoints does it contact?
3. Does it read/write settings keys (list them) or gate hardware
   (HDMI, CEC, audio, LED, OTA, Bluetooth remote)?
4. Verdict: safe-to-disable / watchlist / protected, with evidence.
