#!/usr/bin/env bash
# Installs 4bTech Space, the game and 4bTech Game (in that order) on the Android on adb,
# with proof for each: its App info page and a screenshot after opening it.
#
#   install-apks.sh <apk-dir> <out-dir>     (apk-dir holds 4bTech-Space.apk, base.apk, 4B-Rummy-Home.apk)
set -uo pipefail
APK=$1; OUT=$2; RC=0; n=0
mkdir -p "$OUT"
for f in 4bTech-Space.apk base.apk 4B-Rummy-Home.apk; do
  n=$((n + 1)); name=${f%.apk}
  before=$(adb shell pm list packages -3 | tr -d '\r' | sort)
  if adb install -r -g "$APK/$f" > "$OUT/install-$name.txt" 2>&1; then
    pkg=$(comm -13 <(echo "$before") <(adb shell pm list packages -3 | tr -d '\r' | sort) | head -1 | sed 's/^package://')
    echo "PASS install $f ($pkg)" | tee -a "$OUT/notes.txt"
    if [ -n "$pkg" ]; then
      ver=$(adb shell dumpsys package "$pkg" | tr -d '\r' | grep -m1 versionName | sed 's/ *versionName=//')
      echo "  version $ver" | tee -a "$OUT/notes.txt"
      # Proof of install: the app's own App info page in Settings.
      adb shell am start -W -a android.settings.APPLICATION_DETAILS_SETTINGS -d "package:$pkg" >/dev/null 2>&1 || true
      sleep 4; adb exec-out screencap -p > "$OUT/$n-$name-1-appinfo.png"
      adb shell input keyevent KEYCODE_HOME; sleep 1
      # Open it through its launcher activity and screenshot what is on screen.
      act=$(adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$pkg" | tr -d '\r' | tail -1)
      adb logcat -c
      adb shell am start -W -n "$act" > "$OUT/launch-$name.txt" 2>&1 || true
      sleep 25
      adb exec-out screencap -p > "$OUT/$n-$name-2-open.png"
      top=$(adb shell dumpsys activity activities | tr -d '\r' | grep -m1 -E "mResumedActivity|topResumedActivity" | sed 's/^ *//')
      echo "  launch $act -> on screen: $top" | tee -a "$OUT/notes.txt"
      adb logcat -d -b crash > "$OUT/crash-$name.txt" 2>/dev/null || true
      [ -s "$OUT/crash-$name.txt" ] && echo "  CRASH log: crash-$name.txt" | tee -a "$OUT/notes.txt"
      adb shell am force-stop "$pkg"; adb shell input keyevent KEYCODE_HOME; sleep 2
    fi
  else
    RC=1; echo "FAIL install $f: $(tail -1 "$OUT/install-$name.txt")" | tee -a "$OUT/notes.txt"
  fi
done
adb exec-out screencap -p > "$OUT/9-final.png"
adb shell pm list packages -3 | tr -d '\r' > "$OUT/packages.txt"
exit $RC
