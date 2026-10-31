#!/usr/bin/env bash
# Presses Start in 4bTech Game on every phone (after pool-join.sh put them in one pool), then
# waits until 4bTech Space has CLONES_TARGET clones on every phone (default 3, at most
# CLONES_WAIT_MIN minutes, default 60), then takes 4bTech Space's home screen (the clones). Screen texts go to <out-dir>/notes.txt.
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

# After Start nothing is touched in the apps (4bTech Game makes the clones by itself). The run waits
# until 4bTech Space has at least $CLONES_TARGET clones on every phone (each clone is an inner user
# with the game in blackbox/data/user/<N>/), at most $CLONES_WAIT_MIN minutes. Only Android's own
# pop-ups (GOT IT / Allow) are closed; a screenshot of every phone every 5 minutes.
TARGET=${CLONES_TARGET:-3}; WAIT_MIN=${CLONES_WAIT_MIN:-60}
GAME=BnrOdaB.HmkEhkT.AqlWygK.SrmOtnP
clones() {
  local d=/data/data/com.fourbtech.space/blackbox/data/user
  { a shell "ls -d $d/*/$GAME 2>/dev/null" || a shell "su 0 sh -c 'ls -d $d/*/$GAME' 2>/dev/null"; } | tr -d '\r' | grep -c "/$GAME$"
}
start_t=$(date +%s); next_shot=300; next_log=0
while :; do
  el=$(( $(date +%s) - start_t )); counts=""; done_all=1
  for i in "${!PHONES[@]}"; do
    S=${PHONES[$i]}; P=$((i + 1)); c=$(clones); counts="$counts phone$P=$c"
    [ "$c" -ge "$TARGET" ] || done_all=0
    tap_popup || true
  done
  if [ "$el" -ge "$next_log" ]; then say "  $((el / 60)) min after Start, clones:$counts"; next_log=$((next_log + 60)); fi
  if [ "$el" -ge "$next_shot" ]; then
    for i in "${!PHONES[@]}"; do S=${PHONES[$i]}; P=$((i + 1)); shot "3-min$((el / 60))"; done; next_shot=$((next_shot + 300))
  fi
  if [ "$done_all" = 1 ]; then say "PASS every phone has at least $TARGET clones ($((el / 60)) min after Start):$counts"; break; fi
  if [ "$el" -ge $((WAIT_MIN * 60)) ]; then say "FAIL not $TARGET clones on every phone after $WAIT_MIN min:$counts"; RC=1; break; fi
  sleep 10
done
# What every phone is doing now.
for i in "${!PHONES[@]}"; do
  S=${PHONES[$i]}; P=$((i + 1))
  top=$(a shell dumpsys activity activities 2>/dev/null | grep -m1 mResumedActivity | tr -d '\r' | sed 's/^ *//')
  say "## phone $P at the end: $top"
  say "  screen: $(screen_text)"; shot 3-end
done
# Then 4bTech Space's home screen on every phone: the clones 4bTech Game made after Start.
for i in "${!PHONES[@]}"; do
  S=${PHONES[$i]}; P=$((i + 1))
  a shell am start -W -n com.fourbtech.space/.MainActivity >/dev/null 2>&1; sleep 5
  say "## phone $P: 4bTech Space home after Start: $(screen_text)"; shot 4-space-clones
done
say "DONE Start pressed on ${#PHONES[@]} phones"
exit $RC
