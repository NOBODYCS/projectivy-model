#!/usr/bin/env bash
# RESTORE EVERYTHING: re-enables all packages ever disabled by this project.
# Also reverts settings tweaks recorded in applied-settings.log.
set -euo pipefail
source "$(dirname "$0")/common.sh"

echo "Restoring packages..."
sort -u "$REPO_ROOT/applied.log" 2>/dev/null | awk '$2=="disable"{print $3}' | while read -r pkg; do
  echo "enabling $pkg"
  adb_cmd shell pm enable "$pkg" || echo "WARN: enable failed for $pkg" >&2
done

if [[ -f "$REPO_ROOT/applied-settings.log" ]]; then
  echo "Restoring settings..."
  while read -r ns key value; do
    [[ "$ns" == "#" || -z "$ns" ]] && continue
    echo "settings put $ns $key $value"
    adb_cmd shell settings put "$ns" "$key" "$value"
  done < "$REPO_ROOT/applied-settings.log"
fi

echo "Stock behavior restored (package state + settings)."
echo "Launcher: to return to stock launcher, re-enable it first, then Settings -> Home app."
adb shell pm enable 'com.google.android.tvlauncher'
adb shell pm enable 'com.google.android.tvrecommendations'
adb shell pm enable 'com.nes.leanbacklauncher.partnercustomizer'
adb shell pm enable 'com.nes.recents'
adb shell pm enable 'com.nes.remoteota.one'
adb shell pm enable 'com.nes.remoteota.two'
adb shell pm enable 'com.nes.remoteota.six'
adb shell pm enable 'com.nes.dvb.playtest'
adb shell pm enable 'com.nes.bugreportsender'
adb shell pm enable 'android.autoinstalls.config.sei'
adb shell pm enable 'com.android.tv.feedbackconsent'
adb shell pm enable 'com.google.android.backdrop'
adb shell pm enable 'com.google.android.feedback'
adb shell pm enable 'com.google.android.onetimeinitializer'
adb shell pm enable 'com.google.android.play.games'
adb shell pm enable 'com.google.android.syncadapters.calendar'
adb shell pm enable 'com.google.android.katniss'
