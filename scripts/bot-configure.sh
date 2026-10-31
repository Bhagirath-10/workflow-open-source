#!/usr/bin/env bash
# Finishes 4bTech Game's Setup after sign-in: screen permission and the other Allow steps,
# game = Rummy Home, cloner = 4bTech Space. Never presses Start: nothing is played.
# Every screen is screenshotted and its texts are written to notes.txt.
#
#   bot-configure.sh <out-dir>
set -uo pipefail
OUT=$1; PKG=app.gameauto.phone; N=30
HERE=$(cd "$(dirname "$0")" && pwd)
NOTES="$OUT/notes.txt"
say() { echo "$*" | tee -a "$NOTES"; }
shot() { adb exec-out screencap -p > "$OUT/$N-$1.png"; N=$((N + 1)); }
# The home screen's moving banner can make a dump fail ("could not get idle state"): retry.
dump() {
  local i
  for i in 1 2 3 4 5; do
    adb shell rm -f /sdcard/ui.xml
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    adb shell cat /sdcard/ui.xml 2>/dev/null | tr -d '\r' > "$OUT/ui.xml"
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
taps=""
# tap_once <regex> [label]: tap the first node whose text matches, at most twice per regex.
tap_once() {
  local xy; [ "$(grep -Fxc -- "$1" <<< "$taps")" -ge 2 ] && return 1
  xy=$(find text "$1") || return 1
  taps+=$'\n'"$1"; say "  tap: ${2:-$1}"; adb shell input tap $xy; sleep 3
}

say "## 4bTech Game: Setup (game Rummy Home, cloner 4bTech Space; Start is never pressed)"
adb shell am start -W -n "$PKG/.MainActivity" >/dev/null 2>&1; sleep 4; dump
xy=$(find id openSetup) || xy=$(find text "Setup|Open setup|Open Setup|Finish setup") || {
  # Screen not readable: the Setup button of the "Setup needed" card (1080x2280 screen).
  say "  home screen not readable; tapping the Setup button by position"; xy="878 1084"; }
adb shell input tap $xy; sleep 4

for step in $(seq 1 25); do
  dump; top=$(find top)
  say "  screen $step [$top]: $(texts)"
  shot "setup-$step"
  if [ "$top" != "$PKG" ]; then
    # Android's own screens: the screen-capture prompt ("Start now"), the Accessibility page
    # (4bTech Game › switch › Allow/OK), anything else is closed with Back.
    tap_once "Start now|START NOW" "Start now (screen capture)" && continue
    tap_once "Allow|ALLOW|OK|Don't optimize|DON'T OPTIMIZE" "confirm" && continue
    if find text "DOWNLOADED SERVICES|Downloaded services|Downloaded apps" >/dev/null; then
      tap_once "4bTech Game" "Accessibility: 4bTech Game" && continue
    elif find text "4bTech Game" >/dev/null && ! find text "On|ON" >/dev/null; then
      tap_once "Off|OFF|Use 4bTech Game|Use service" "Accessibility: switch 4bTech Game on" && continue
    fi
    say "  back"; adb shell input keyevent KEYCODE_BACK; sleep 2
    continue
  fi
  # The game list ("Which app is the game?") and the cloner list.
  tap_once ".*rummy.*" "game: Rummy Home" && continue
  tap_once "4bTech Space" "cloner: 4bTech Space" && continue
  # Steps that still need something, then the general buttons. Never "Start".
  tap_once "Not picked|Pick|Choose|Which app is the game\\?" "pick" && continue
  tap_once "Allow|Allow the settings|Grant|Turn on|Switch on|Enable|Open settings|Continue|Next|OK|Got it|GOT IT" && continue
  tap_once "Done|Finish|Finish setup|Save|Close" && continue
  say "  nothing left to tap on this screen"
  break
done

# The Setup screen itself says whether something is missing ("Give the last permission").
dump; setup=$(texts)
say "  accessibility services on: $(adb shell settings get secure enabled_accessibility_services | tr -d '\r')"
shot setup-final
adb shell input keyevent KEYCODE_BACK; sleep 3; shot home-after-setup
case "$setup" in
  *"Give the last permission"*|*"Not picked"*) say "FAIL Setup not finished: $setup"; exit 1;;
  *Setup*) say "PASS Setup done (game RummyHome, cloner 4bTech Space); Start not pressed";;
  *) say "FAIL could not read the Setup screen"; exit 1;;
esac
