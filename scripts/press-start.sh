#!/usr/bin/env bash
# Presses Start in 4bTech Game on every phone (after pool-join.sh put them in one pool), then
# takes screenshots right after and a while later. Screen texts go to <out-dir>/notes.txt.
#
#   press-start.sh <out-dir> <adb-serial-1> [<adb-serial-2> ...]
set -uo pipefail
OUT=$1; shift
PHONES=("$@"); PKG=app.gameauto.phone
HERE=$(cd "$(dirname "$0")" && pwd)
NOTES="$OUT/notes.txt"; mkdir -p "$OUT"
trap 'rm -f "$OUT/ui.xml" "$OUT"/screen.png*' EXIT
say() { echo "$*" | tee -a "$NOTES"; }
a() { adb -s "$S" "$@"; }
shot() { a exec-out screencap -p > "$OUT/phone$P-$1.png"; }
dump() {
  local i
  for i in 1 2 3; do
    a shell rm -f /sdcard/ui.xml
    a shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    a shell cat /sdcard/ui.xml 2>/dev/null | tr -d '\r' > "$OUT/ui.xml"
    grep -q '<hierarchy' "$OUT/ui.xml" && return 0
    sleep 2
  done
  return 1
}
find() { python3 -I "$HERE/ui.py" "$OUT/ui.xml" "$@" 2>/dev/null; }
screen_text() {
  a exec-out screencap -p > "$OUT/screen.png"
  python3 -I "$HERE/ocr.py" "$OUT/screen.png" text 2>/dev/null | tr '\n' '|' | cut -c1-600
}

RC=0
for i in "${!PHONES[@]}"; do
  S=${PHONES[$i]}; P=$((i + 1))
  say "## phone $P ($S): Start"
  a shell input keyevent KEYCODE_WAKEUP
  a shell am start -W -n "$PKG/.MainActivity" >/dev/null 2>&1; sleep 3
  shot 1-before-start
  # Start: the big button of the bar at the bottom (668,1840 on the 1080x2280 screen; its white
  # text on orange is not read by OCR, and uiautomator often cannot read the home screen).
  if dump && xy=$(find text "Start"); then :; else xy="668 1840"; fi
  say "  tap: Start ($xy)"; a shell input tap $xy; sleep 8
  say "  screen: $(screen_text)"; shot 2-after-start
done

# A while later: what every phone is doing.
sleep 60
for i in "${!PHONES[@]}"; do
  S=${PHONES[$i]}; P=$((i + 1))
  top=$(a shell dumpsys activity activities 2>/dev/null | grep -m1 mResumedActivity | tr -d '\r' | sed 's/^ *//')
  say "## phone $P 1 minute after Start: $top"
  say "  screen: $(screen_text)"; shot 3-1min
done
say "DONE Start pressed on ${#PHONES[@]} phones"
exit $RC
