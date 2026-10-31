#!/usr/bin/env bash
# Puts 2 or 3 phones (same Wi-Fi) in one 4bTech Game pool, after full-cycle.sh has finished Setup:
#   every phone:  open 4bTech Game, scroll down a little, PLAY › select the last tab "Pool"
#   first phone:  tap "New pool code" and read the pool code from the screen
#   other phones: enter that code and join
# Screens uiautomator cannot read are read from the screenshot (scripts/ocr.py, Tesseract).
# Start is never pressed. Screenshots and screen texts go to <out-dir> (notes.txt).
#
#   pool-join.sh <out-dir> <adb-serial-1> <adb-serial-2> [<adb-serial-3> ...]
#
# POOL_CODE=<code> skips reading it from the first phone's screen.
set -uo pipefail
OUT=$1; shift
PHONES=("$@"); PKG=app.gameauto.phone
HERE=$(cd "$(dirname "$0")" && pwd)
NOTES="$OUT/notes.txt"; mkdir -p "$OUT"
[ "${#PHONES[@]}" -ge 2 ] || { echo "usage: pool-join.sh <out-dir> <serial-1> <serial-2> [<serial-3> ...]"; exit 2; }

say() { echo "$*" | tee -a "$NOTES"; }
a() { adb -s "$S" "$@"; }                          # adb on the current phone ($S)
shot() { a exec-out screencap -p > "$OUT/phone$P-$1.png"; }
dump() {
  local i
  for i in 1 2 3 4 5; do
    a shell rm -f /sdcard/ui.xml
    a shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    a shell cat /sdcard/ui.xml 2>/dev/null | tr -d '\r' > "$OUT/ui.xml"
    grep -q '<hierarchy' "$OUT/ui.xml" && return 0
    sleep 2
  done
  echo '<hierarchy/>' > "$OUT/ui.xml"; return 1
}
find() { python3 -I "$HERE/ui.py" "$OUT/ui.xml" "$@" 2>/dev/null; }
texts() { python3 -I - "$OUT/ui.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
seen = []
for n in ET.parse(sys.argv[1]).iter("node"):
    t = (n.get("text") or n.get("content-desc") or "").strip()
    if t and t not in seen: seen.append(t)
print(" | ".join(seen)[:600])
PY
}
# tap <regex> <label>: tap the first node whose text matches; never anything named Start.
tap() {
  local xy; dump; xy=$(find text "$1") || return 1
  say "  tap: $2"; a shell input tap $xy; sleep 3
}
# Screens uiautomator cannot read (the home screen's moving parts): read the screenshot (OCR).
ocr() { a exec-out screencap -p > "$OUT/screen.png"; python3 -I "$HERE/ocr.py" "$OUT/screen.png" "$@" 2>/dev/null; }
# locate <uiautomator regex> <OCR phrase(s)>: centre "x y" from the dump, else from the screenshot.
locate() { dump && find text "$1" && return 0; ocr find "$2"; }
screen_text() { dump && texts && return 0; ocr text | tr '\n' '|' | cut -c1-600; }
# The pool code on the screen: a short word of capital letters and digits (with a digit),
# or 4-8 digits; the nodes right after a "code" label first.
read_code() { python3 -I - "$OUT/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
texts = [(n.get("text") or n.get("content-desc") or "").strip() for n in ET.parse(sys.argv[1]).iter("node")]
texts = [t for t in texts if t]
def code(t):
    t = t.replace(" ", "").replace("-", "")
    return t if re.fullmatch(r"(?=.*\d)[A-Z0-9]{4,10}", t) else None
for i, t in enumerate(texts):                      # "Pool code: AB12CD" or a label then the code
    if re.search(r"code", t, re.I):
        m = re.search(r"code\W*([A-Z0-9][A-Z0-9 -]{3,12})$", t, re.I)
        if m and code(m.group(1)): print(code(m.group(1))); sys.exit()
        for u in texts[i + 1:i + 4]:
            if code(u): print(code(u)); sys.exit()
for t in texts:
    if code(t): print(code(t)); sys.exit()
sys.exit(1)
PY
}

# Every phone: 4bTech Game home › scroll down a little › PLAY › "Pool" (the last tab).
select_pool() {
  say "## phone $P ($S): select Pool"
  a shell input keyevent KEYCODE_WAKEUP
  # The home screen's moving banner keeps uiautomator from reading the screen: animations off.
  local k; for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    a shell settings put global $k 0; done
  a shell am start -W -n "$PKG/.MainActivity" >/dev/null 2>&1; sleep 4
  local i xy=""
  for i in 1 2 3 4; do
    a shell input swipe 540 1700 540 1100 400; sleep 2          # scroll down a little
    xy=$( (dump && find text "Pool") || ocr findin Alone "Pool") && break
  done
  shot 1-play
  if [ -n "$xy" ]; then
    say "  tap: PLAY › Pool ($xy)"; a shell input tap $xy; sleep 3
  else
    # Not found: scrolled to the bottom, the Pool tab is at 843,1212 on the 1080x2280 screen.
    say "  Pool tab not found on the screen; scrolled to the bottom, tapping it by position"
    for i in 1 2 3; do a shell input swipe 540 1700 540 900 300; sleep 1; done
    a shell input tap 843 1212; sleep 3
  fi
  a shell input swipe 540 1700 540 1300 400; sleep 2            # bring the pool part into view
  say "  screen: $(screen_text)"; shot 2-pool
}

# First phone: "New pool code" › read the code from the code box.
show_code() {
  say "## phone $P ($S): new pool code"
  local xy e
  if xy=$(locate "New pool code|Show code|Show pool code" "New pool code|Show code"); then :
  elif e=$(ocr find "Enter code"); then
    xy="303 ${e#* }"                                 # same row as Enter code, left button
  else
    say "FAIL phone $P: no New pool code button: $(screen_text)"; shot 3-no-button; return 1
  fi
  say "  tap: New pool code ($xy)"; a shell input tap $xy; sleep 4
  local i
  for i in 1 2 3; do
    CODE=${POOL_CODE:-$( (dump && read_code) || ocr code)}
    [ -n "$CODE" ] && break; sleep 3
  done
  say "  screen: $(screen_text)"; shot 3-code
  [ -n "$CODE" ] || { say "FAIL phone $P: no pool code on the screen"; return 1; }
  say "  pool code: $CODE"
}

# Other phones: "Enter code" › type the code › Join.
join_pool() {
  say "## phone $P ($S): enter code $CODE"
  local xy
  xy=$(locate "Enter code|Enter pool code" "Enter code") || { say "FAIL phone $P: no Enter code button: $(screen_text)"; shot 3-no-button; return 1; }
  say "  tap: Enter code ($xy)"; a shell input tap $xy; sleep 3
  say "  screen: $(screen_text)"; shot 3-enter-code
  if dump && xy=$(find edit 0); then a shell input tap $xy; sleep 1; fi   # else the box has the focus already
  a shell input keyevent KEYCODE_MOVE_END; for _ in $(seq 1 12); do a shell input keyevent KEYCODE_DEL; done
  a shell input text "$CODE"; sleep 1
  shot 4-code-typed
  local ok="Join|JOIN|Join pool|Connect|CONNECT|OK|Done|Save|Use code"
  if xy=$(locate "$ok" "Join pool|Join|Connect|OK|Done|Save|Use code"); then
    say "  tap: Join ($xy)"; a shell input tap $xy
  else
    say "  no Join button found; pressing Enter"; a shell input keyevent KEYCODE_ENTER
  fi
  sleep 5; say "  screen: $(screen_text)"; shot 5-joined
}

RC=0; CODE=""
for i in "${!PHONES[@]}"; do S=${PHONES[$i]}; P=$((i + 1)); select_pool || RC=1; done
S=${PHONES[0]}; P=1
show_code || { say "FAIL no pool code: the other phones cannot join"; exit 1; }
for i in "${!PHONES[@]}"; do
  [ "$i" = 0 ] && continue
  S=${PHONES[$i]}; P=$((i + 1)); join_pool || RC=1
done

# Every phone's pool screen at the end (the first phone should list the others).
sleep 5
for i in "${!PHONES[@]}"; do
  S=${PHONES[$i]}; P=$((i + 1))
  say "## phone $P at the end: $(screen_text)"; shot 6-final
done
rm -f "$OUT/ui.xml" "$OUT"/screen.png*
[ "$RC" = 0 ] && say "PASS pool: phone 1 showed code $CODE, phones 2..${#PHONES[@]} entered it (Start not pressed)" \
              || say "FAIL pool: see the steps above"
exit $RC
