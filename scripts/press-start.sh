#!/usr/bin/env bash
# Presses Start in 4bTech Game on every phone (after pool-join.sh put them in one pool), then
# takes screenshots right after and a while later, then 4bTech Space's home screen (the clones). Screen texts go to <out-dir>/notes.txt.
#
#   press-start.sh <out-dir> <adb-serial-1> [<adb-serial-2> ...]
set -uo pipefail
OUT=$1; shift
PHONES=("$@"); PKG=app.gameauto.phone
HERE=$(cd "$(dirname "$0")" && pwd)
NOTES="$OUT/notes.txt"; mkdir -p "$OUT"
trap 'rm -f "$OUT"/screen.png*' EXIT
say() { echo "$*" | tee -a "$NOTES"; }
a() { adb -s "$S" "$@"; }
shot() { a exec-out screencap -p > "$OUT/phone$P-$1.png"; }
screen_text() {
  a exec-out screencap -p > "$OUT/screen.png"
  python3 -I "$HERE/ocr.py" "$OUT/screen.png" text 2>/dev/null | tr '\n' '|' | cut -c1-600
}

# Pop-ups that stop the game: Android's "Viewing full screen ... GOT IT" (marked as already seen)
# and permission questions from the game (it runs inside 4bTech Space: every permission 4bTech
# Space asks for is given ahead of time).
no_popups() {
  a shell settings put secure immersive_mode_confirmations confirmed
  local p
  for p in $(a shell dumpsys package com.fourbtech.space 2>/dev/null | tr -d '\r' \
             | sed -n '/requested permissions:/,/install permissions:/p' | grep -o 'android\.permission\.[A-Z_]*' | sort -u); do
    a shell pm grant com.fourbtech.space "$p" >/dev/null 2>&1 || true
  done
}
# Taps GOT IT / Allow when one is on screen (read from the screenshot).
tap_popup() {
  local xy
  a exec-out screencap -p > "$OUT/screen.png"
  xy=$(python3 -I "$HERE/ocr.py" "$OUT/screen.png" find "GOT IT|Got it|While using the app|Only this time|ALLOW|Allow" 2>/dev/null) || return 1
  say "  phone $P: pop-up, tapping it ($xy): $(python3 -I "$HERE/ocr.py" "$OUT/screen.png" text 2>/dev/null | tr '\n' '|' | cut -c1-200)"
  shot "popup-$(date +%H%M%S)"; a shell input tap $xy; sleep 2
}

RC=0
for i in "${!PHONES[@]}"; do S=${PHONES[$i]}; P=$((i + 1)); no_popups; done
for i in "${!PHONES[@]}"; do
  S=${PHONES[$i]}; P=$((i + 1))
  say "## phone $P ($S): Start"
  a shell input keyevent KEYCODE_WAKEUP
  # Screen permission back on (uiautomator dumps in the earlier steps can switch it off; the app
  # then says "Setup needed" and Start is greyed out). No uiautomator from here on: OCR only.
  a shell settings put secure enabled_accessibility_services "$PKG/$PKG.BotService"
  a shell settings put secure accessibility_enabled 1
  a shell am start -W -n "$PKG/.MainActivity" >/dev/null 2>&1; sleep 5
  before=$(screen_text); say "  before: $before"; shot 1-before-start
  case "$before" in *"Setup needed"*) say "  WARN phone $P still says Setup needed: Start may be greyed out"; RC=1;; esac
  # Start: the big button of the bar at the bottom (668,1840 on the 1080x2280 screen; its white
  # text on orange is not read by OCR).
  xy="668 1840"
  say "  tap: Start ($xy)"; a shell input tap $xy; sleep 8
  say "  screen: $(screen_text)"; shot 2-after-start
done

# The first 5 minutes after Start: close a pop-up on any phone (every phone checked about every
# 15 seconds), and a screenshot of every phone each minute.
start_t=$(date +%s); m=1
while [ $(( $(date +%s) - start_t )) -lt 300 ]; do
  if [ $(( $(date +%s) - start_t )) -ge $(( m * 60 )) ]; then
    for i in "${!PHONES[@]}"; do S=${PHONES[$i]}; P=$((i + 1)); shot "3-min$m"; done; m=$((m + 1))
  fi
  for i in "${!PHONES[@]}"; do S=${PHONES[$i]}; P=$((i + 1)); tap_popup || true; done
  sleep 5
done
# What every phone is doing now.
for i in "${!PHONES[@]}"; do
  S=${PHONES[$i]}; P=$((i + 1))
  top=$(a shell dumpsys activity activities 2>/dev/null | grep -m1 mResumedActivity | tr -d '\r' | sed 's/^ *//')
  say "## phone $P 5 minutes after Start: $top"
  say "  screen: $(screen_text)"; shot 3-5min
done
# Then 4bTech Space's home screen on every phone: the clones 4bTech Game made after Start.
for i in "${!PHONES[@]}"; do
  S=${PHONES[$i]}; P=$((i + 1))
  a shell am start -W -n com.fourbtech.space/.MainActivity >/dev/null 2>&1; sleep 5
  say "## phone $P: 4bTech Space home after Start: $(screen_text)"; shot 4-space-clones
done
say "DONE Start pressed on ${#PHONES[@]} phones"
exit $RC
