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
for ime in $(adb shell ime list -s | tr -d '\r'); do
  adb shell ime disable "$ime" >/dev/null
  adb shell pm disable-user --user 0 "${ime%%/*}" >/dev/null 2>&1   # the keyboard app itself
done
say "  keyboards left: $(adb shell ime list -s | tr -d '\r' | tr '\n' ' ')"
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
SPACE=$(echo "$IMP" | grep -oE 'spaces=[0-9]+' | cut -d= -f2)
if [ -n "$SPACE" ]; then
  DN="blackbox/data/user/$SPACE/$GUEST"
  M=$(rs "cat $DN/files/marker.txt"); P=$(rs "cat $DN/shared_prefs/login.xml")
  say "  imported copy (space $SPACE): marker='$M' prefs='$P'"
  if [ "$M" = hello-4bspace ] && echo "$P" | grep -q '>me<'; then say "PASS export -> import moved the data"; else say "FAIL data not in the imported copy"; RC=1; fi
else
  say "FAIL import made no copy"; RC=1
fi
# Several copies in ONE file: copies 2 and 3 get their own markers, go out together, come back together.
for sp in 1 2; do rs "mkdir -p blackbox/data/user/$sp/$GUEST/files && echo marker-$sp > blackbox/data/user/$sp/$GUEST/files/marker.txt"; done
cmd export --es pkg "$GUEST" --es spaces "1,2" --es pw "$PW" --es file two.4bspace
wait_log "export (OK|FAIL)" 120; say "  $(last_log 'export (OK|FAIL)')"
cmd import --es pw "$PW" --es file two.4bspace
wait_log "import (OK|FAIL)" 120; IMP2=$(last_log 'import (OK|FAIL)'); say "  $IMP2"
S2=$(echo "$IMP2" | grep -oE 'spaces=[0-9,]+' | cut -d= -f2)
GOT=""; for sp in ${S2//,/ }; do GOT+="$(rs "cat blackbox/data/user/$sp/$GUEST/files/marker.txt") "; done
say "  imported copies $S2: $GOT"
if echo "$IMP2" | grep -q "count=2" && [ "$GOT" = "marker-1 marker-2 " ]; then say "PASS two copies in one file came back with their own data"; else say "FAIL bundle import"; RC=1; fi
# Speed: about 50 MB like a game's data (750 x 20 kB random, 750 x 20 kB text, 20 x 1 MB packs) in copy 4.
D3="blackbox/data/user/3/$GUEST/files/client"
rs "mkdir -p $D3/a $D3/b && cd $D3 && for i in \$(seq 1 750); do head -c 20000 /dev/urandom > a/r\$i.bin; done && yes 4bTech-Space-content-line | head -c 20000 > t && for i in \$(seq 1 750); do cp t b/t\$i.json; done && rm t && for i in \$(seq 1 20); do head -c 1048576 /dev/urandom > big\$i.pak; done"
say "  copy 4 data: $(rs "du -sk blackbox/data/user/3/$GUEST" | cut -f1) kB, $(rs "find blackbox/data/user/3/$GUEST -type f | wc -l") files"
cmd export --es pkg "$GUEST" --ei space 3 --es pw "$PW" --es file speed.4bspace
wait_log "export (OK|FAIL)" 240; SE=$(last_log 'export (OK|FAIL)'); say "  $SE"
cmd import --es pw "$PW" --es file speed.4bspace
wait_log "import (OK|FAIL)" 240; SI=$(last_log 'import (OK|FAIL)'); say "  $SI"
SS=$(echo "$SI" | grep -oE 'spaces=[0-9]+' | cut -d= -f2)
say "  imported copy: $(rs "find blackbox/data/user/$SS/$GUEST -type f | wc -l") files, $(rs "du -sk blackbox/data/user/$SS/$GUEST" | cut -f1) kB"
say "SPEED 50 MB: export $(echo "$SE" | grep -oE 'ms=[0-9]+' | cut -d= -f2) ms, import $(echo "$SI" | grep -oE 'ms=[0-9]+' | cut -d= -f2) ms"
NF=$(rs "find blackbox/data/user/${SS:-none}/$GUEST -type f | wc -l")
SUM_A=$(rs "cd blackbox/data/user/3/$GUEST/files/client && cat a/r1.bin a/r750.bin b/t1.json big20.pak | md5sum")
SUM_B=$(rs "cd blackbox/data/user/${SS:-none}/$GUEST/files/client && cat a/r1.bin a/r750.bin b/t1.json big20.pak | md5sum")
if echo "$SI" | grep -q "import OK" && [ "$NF" -ge 1520 ] && [ "$SUM_A" = "$SUM_B" ]; then say "PASS 50 MB export -> import: all $NF files, contents identical"; else say "FAIL 50 MB import (files=$NF)"; RC=1; fi
cmd delete --es pkg "$GUEST" --ei space 3; wait_log "delete (OK|FAIL)" 60
[ -n "$SS" ] && { cmd delete --es pkg "$GUEST" --ei space "$SS"; wait_log "delete (OK|FAIL)" 60; }
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
tap "Choose file"; shot export-save-picker 3
# Android's save screen: Save; the export runs in a dialog in the middle and says when done.
if tap "SAVE|Save"; then
  shot export-running 0; sleep 8; shot export-done 0
  tap "OK"
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
# The exported file is the most recent one: pick it (long-press marks it, Select confirms),
# first with a wrong password (the big "Wrong password" answer), then with the right one.
pick_export() {
  local xy
  dump; xy=$(python3 -I - "$OUT/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter("node"):
    if n.get("text", "").endswith(".4bspace"):
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", n.get("bounds"))); print((x1 + x2) // 2, (y1 + y2) // 2); break
PY
)
  [ -n "$xy" ] || return 1
  adb shell input swipe $xy $xy 900; sleep 2
  dump; [ "$(find top)" = "$APP" ] || tap "SELECT|Select|OPEN|Open"
  sleep 2; dump; [ "$(find top)" = "$APP" ]
}
for attempt in wrong right; do
  dump; xy=$(find text "Import") && adb shell input tap $xy; sleep 3
  [ $attempt = wrong ] && shot import-picker 0
  if pick_export; then
    [ $attempt = wrong ] && shot import-password 0
    dump; xy=$(find edit 0) && { adb shell input tap $xy; sleep 1; adb shell input text "$([ $attempt = wrong ] && echo wrong-pass-123 || echo "$PW")"; }
    tap "Import"; sleep 8; shot import-$attempt 0
    tap "OK"
  else
    say "  (could not pick the exported file in the picker)"; adb shell input keyevent KEYCODE_BACK; sleep 2
  fi
done
# Settings without Clone engine, Share app, Save log; the bin on the Hidden tab.
# The Import result dialogs, as a user sees them: a wrong password, then the right one.
open_app
cmd importui --es pw "wrong-pass-123" --es file two.4bspace; sleep 6; shot import-wrong-password 0
tap "OK"
cmd importui --es pw "$PW" --es file two.4bspace; sleep 1; shot import-running 0; sleep 8; shot import-done 0
tap "OK"
adb shell am force-stop $APP; adb shell am start -W -n $APP/.MainActivity --es route settings >/dev/null 2>&1; shot settings 3
cmd remove --es pkg "$GUEST" --ei space 3; wait_log "remove OK" 20
adb shell am force-stop $APP; adb shell am start -W -n $APP/.MainActivity --es route hidden >/dev/null 2>&1; shot hidden-bin 3
# Long-press the first clone: the small menu next to it.
open_app
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
