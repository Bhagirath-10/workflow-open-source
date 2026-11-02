#!/usr/bin/env bash
# Update test for a production release of 4bTech Space: the published version is installed,
# clones are made through its own screens, then the new release APK is installed over it.
# The app must start, keep every clone (database upgrade) and still open one.
#
#   space-upgrade-test.sh <old.apk> <new.apk> <guest.apk> <out-dir>
set -uo pipefail
OLD=$1; NEW=$2; GUEST_APK=$3; OUT=$4
APP=com.fourbtech.space; N=1; RC=0
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"; NOTES="$OUT/notes.txt"; : > "$NOTES"
say() { echo "$*" | tee -a "$NOTES"; }
shot() { sleep "${2:-2}"; adb exec-out screencap -p > "$OUT/$(printf %02d $N)-$1.png"; N=$((N + 1)); }
dump() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb shell cat /sdcard/ui.xml | tr -d '\r' > "$OUT/ui.xml"; }
find() { python3 -I "$HERE/ui.py" "$OUT/ui.xml" "$@" 2>/dev/null; }
tap() { local xy; dump; xy=$(find text "$1") || { say "  (not on screen: $1)"; return 1; }; adb shell input tap $xy; sleep 3; }
open_app() { adb shell am force-stop $APP; adb shell am start -W -n $APP/.MainActivity >/dev/null 2>&1; sleep 5; }
clones() { dump; grep -oE 'text="E2E Guest-[0-9]+"' "$OUT/ui.xml" | sort -u | wc -l; }
version() { adb shell dumpsys package $APP | tr -d '\r' | grep -m1 versionName | sed 's/ *versionName=//'; }

for ime in $(adb shell ime list -s | tr -d '\r'); do adb shell ime disable "$ime" >/dev/null; adb shell pm disable-user --user 0 "${ime%%/*}" >/dev/null 2>&1; done
adb shell input keyevent KEYCODE_WAKEUP; adb shell wm dismiss-keyguard
adb install -r -g "$OLD" >/dev/null || { say "FAIL old version install"; exit 1; }
adb install -r -g "$GUEST_APK" >/dev/null || { say "FAIL guest install"; exit 1; }
say "installed: 4bTech Space $(version)"
open_app; shot old-home 3

# Two clones of the guest app through the old version's own Add clone screen.
for i in 1 2; do
  tap "Add clone"
  shot old-add-$i 2
  tap "E2E Guest" || { dump; xy=$(find text ".*Guest.*") && adb shell input tap $xy; sleep 3; }
  sleep 4; dump
  [ "$(find top)" = "$APP" ] && tap "Clone|CLONE|Create|Add|OK|Done" >/dev/null 2>&1
  sleep 3
  open_app
done
BEFORE=$(clones); shot old-with-clones 1
say "old version: $BEFORE clones on Home"
[ "$BEFORE" -ge 2 ] || { say "FAIL could not make clones in the old version"; RC=1; }

adb logcat -c
if adb install -r "$NEW" > "$OUT/update.txt" 2>&1; then say "PASS update installed over it: $(version)"; else say "FAIL update: $(tail -1 "$OUT/update.txt")"; exit 1; fi
open_app; sleep 3; shot new-home 2
AFTER=$(clones)
CRASH=$(adb logcat -d -b crash | grep -c "FATAL EXCEPTION" || true)
say "new version: $AFTER clones on Home, crashes: $CRASH"
[ "$CRASH" = 0 ] || { adb logcat -d -b crash | head -60 > "$OUT/crash.txt"; say "FAIL the app crashed (crash.txt)"; RC=1; }
[ "$AFTER" = "$BEFORE" ] && [ "$AFTER" -ge 2 ] && say "PASS every clone kept after the update" || { say "FAIL clones before $BEFORE, after $AFTER"; RC=1; }
# Open the first clone: the guest app must come to the front inside 4bTech Space.
dump; xy=$(find text "E2E Guest-1") && { adb shell input tap $xy; sleep 8; shot new-clone-open 0; }
TOP=$(adb shell dumpsys activity activities | tr -d '\r' | grep -m1 mResumedActivity)
say "  on screen after opening a clone: $TOP"
echo "$TOP" | grep -q "$APP" && say "PASS a clone opens after the update" || { say "FAIL the clone did not open"; RC=1; }
rm -f "$OUT/ui.xml"
exit $RC
