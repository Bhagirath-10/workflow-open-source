#!/usr/bin/env bash
# 4bTech Space (debug build): Export / Import proof on the phone, then screenshots of the
# multi-select screens. Needs a booted Android on adb.
#
#   space-select-tour.sh <space-debug.apk> <guest-app.apk> <out-dir>
#
# Proof: copy 1 of the guest app gets a marker file and a preferences file, is exported to an
# encrypted file and imported again; the new copy must hold both. A wrong password must be
# refused without making a copy.
set -uo pipefail
APP_APK=$1; GUEST_APK=$2; OUT=$3
APP=com.fourbtech.space; PW="ci-pass-1234"; N=1; RC=0
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"; NOTES="$OUT/notes.txt"; : > "$NOTES"
say() { echo "$*" | tee -a "$NOTES"; }
shot() { sleep "${2:-2}"; adb exec-out screencap -p > "$OUT/$(printf %02d $N)-$1.png"; N=$((N + 1)); }
cmd() { adb logcat -c; adb shell am broadcast -a $APP.debug.COMMAND -p $APP --es cmd "$@" >/dev/null; }
wait_log() { local i; for ((i = 0; i < ${2:-60}; i += 2)); do adb logcat -d -s MultiSpaceE2E:V | grep -qE "$1" && return 0; sleep 2; done; return 1; }
last_log() { adb logcat -d -s MultiSpaceE2E:V | grep -E "$1" | tail -1 | sed 's/.*MultiSpaceE2E: //'; }
rs() { adb shell run-as $APP sh -c "'$1'" 2>/dev/null | tr -d '\r'; }
dump() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb shell cat /sdcard/ui.xml | tr -d '\r' > "$OUT/ui.xml"; }
find() { python3 -I "$HERE/ui.py" "$OUT/ui.xml" "$@" 2>/dev/null; }
tap() { local xy; dump; xy=$(find text "$1") || { say "  (not on screen: $1)"; return 1; }; adb shell input tap $xy; sleep 2; }
open_app() { adb shell am force-stop $APP; adb shell am start -W -n $APP/.MainActivity >/dev/null 2>&1; sleep 4; }

say "device: Android $(adb shell getprop ro.build.version.release | tr -d '\r')"
adb install -r -g "$APP_APK" >/dev/null || { say "FAIL app install"; exit 1; }
BEFORE=$(adb shell pm list packages -3 | tr -d '\r' | sort)
adb install -r -g "$GUEST_APK" >/dev/null || { say "FAIL guest install"; exit 1; }
GUEST=$(comm -13 <(echo "$BEFORE") <(adb shell pm list packages -3 | tr -d '\r' | sort) | head -1 | sed 's/^package://')
say "guest app: $GUEST"
adb shell input keyevent KEYCODE_WAKEUP; adb shell wm dismiss-keyguard
# No on-screen keyboard: typing works without it and dialogs do not move under the taps.
for ime in $(adb shell ime list -s | tr -d '\r'); do adb shell ime disable "$ime" >/dev/null; done
open_app

cmd clone --es pkg "$GUEST" --ei count 4
wait_log "clone (OK|FAIL) $GUEST space=3|clone FAIL" 120 || { say "FAIL clones not made"; exit 1; }
say "PASS 4 copies of $GUEST"

# --- Export / Import proof -----------------------------------------------------------------
D0="blackbox/data/user/0/$GUEST"
rs "mkdir -p $D0/files $D0/shared_prefs && echo hello-4bspace > $D0/files/marker.txt && echo \"<map><string name=\\\"user\\\">me</string></map>\" > $D0/shared_prefs/login.xml"
say "  copy 1: marker $(rs "cat $D0/files/marker.txt")"
cmd export --es pkg "$GUEST" --ei space 0 --es pw "$PW"
wait_log "export (OK|FAIL)" 120; say "  $(last_log 'export (OK|FAIL)')"
cmd import --es pw "wrong-password-1"
wait_log "import (OK|FAIL)" 120; WRONG=$(last_log 'import (OK|FAIL)'); say "  wrong password: $WRONG"
case "$WRONG" in *"FAIL Wrong password"*) say "PASS wrong password refused";; *) say "FAIL wrong password not refused"; RC=1;; esac
cmd import --es pw "$PW"
wait_log "import (OK|FAIL)" 120; IMP=$(last_log 'import (OK|FAIL)'); say "  $IMP"
SPACE=$(echo "$IMP" | grep -oE 'space=[0-9]+' | cut -d= -f2)
if [ -n "$SPACE" ]; then
  DN="blackbox/data/user/$SPACE/$GUEST"
  M=$(rs "cat $DN/files/marker.txt"); P=$(rs "cat $DN/shared_prefs/login.xml")
  say "  imported copy (space $SPACE): marker='$M' prefs='$P'"
  if [ "$M" = hello-4bspace ] && echo "$P" | grep -q '>me<'; then say "PASS export -> import moved the data"; else say "FAIL data not in the imported copy"; RC=1; fi
else
  say "FAIL import made no copy"; RC=1
fi
cmd list; wait_log "list OK" 30; say "  $(last_log 'list OK')"

# --- Multi-select screens ------------------------------------------------------------------
open_app; shot home 3
dump; xy=$(find text "Select") && { adb shell input tap $xy; } ; shot select-one
tap "Select all"; shot select-all
tap "Rename"; shot rename-dialog
# A new name for all, then numbered 1, 2, 3...
dump; xy=$(find edit 0) && { adb shell input tap $xy; adb shell input keyevent KEYCODE_MOVE_END $(printf 'KEYCODE_DEL %.0s' $(seq 1 30)); adb shell input text "Game"; }
tap "1, 2, 3…"; shot rename-numbered
tap "Save"; shot renamed 3
dump; xy=$(find text "Select") && adb shell input tap $xy; sleep 2
tap "Select all"
tap "Export"; shot export-password
for i in 0 1; do dump; xy=$(find edit $i) && { adb shell input tap $xy; sleep 1; adb shell input text "$PW"; }; done
shot export-password-filled
tap "Choose folder"; shot export-folder-picker 3
# Android's folder picker: this folder, then allow; the export runs and says so.
if tap "USE THIS FOLDER|Use this folder"; then
  shot export-allow
  tap "ALLOW|Allow"; shot export-running 1; sleep 8; shot export-done 0
else
  adb shell input keyevent KEYCODE_BACK; sleep 2
fi
dump; xy=$(find text "Select") && adb shell input tap $xy; sleep 2
tap "Delete"; shot delete-confirm
tap "Cancel"; sleep 1
tap "Clear"; shot clear-confirm
tap "Cancel"; sleep 1
adb shell input keyevent KEYCODE_BACK; sleep 2; shot selection-left
dump; xy=$(find text "Import") && { adb shell input tap $xy; shot import-picker 3; }
# The exported files are the most recent ones: open the first, give the password, import.
dump; xy=$(python3 -I - "$OUT/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter("node"):
    if n.get("text", "").endswith(".4bspace"):
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", n.get("bounds"))); print((x1 + x2) // 2, (y1 + y2) // 2); break
PY
)
if [ -n "$xy" ]; then
  adb shell input tap $xy; sleep 3; shot import-password
  dump; xy=$(find edit 0) && { adb shell input tap $xy; sleep 1; adb shell input text "$PW"; }
  tap "Import"; shot import-running 1; sleep 8; shot import-done 0
else
  say "  (no exported file in the picker)"; adb shell input keyevent KEYCODE_BACK; sleep 2
fi
# Long-press the first clone: the single menu with its new "Select" and "Export" rows.
dump; xy=$(python3 -I - "$OUT/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter("node"):
    if re.fullmatch(r"Copy \d+", n.get("text", "")):
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", n.get("bounds"))); print((x1 + x2) // 2, y1 - 60); break
PY
)
[ -n "$xy" ] && { adb shell input swipe $xy $xy 900; shot clone-menu; }
rm -f "$OUT/ui.xml"
exit $RC
