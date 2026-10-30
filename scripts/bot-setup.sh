#!/usr/bin/env bash
# Gives 4bTech Game (app.gameauto.phone) every permission it needs and signs it in.
# Needs a booted Android on adb with the app installed, and FOUR_BTECH_GAME_EMAIL /
# FOUR_BTECH_GAME_PASSWORD in the environment (never printed; removed from the UI dumps).
#
#   bot-setup.sh <out-dir>
set -uo pipefail
OUT=$1; PKG=app.gameauto.phone; N=10
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"; NOTES="$OUT/notes.txt"
say() { echo "$*" | tee -a "$NOTES"; }
shot() { adb exec-out screencap -p > "$OUT/$N-$1.png"; N=$((N + 1)); }
dump() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1; adb shell cat /sdcard/ui.xml | tr -d '\r' > "$OUT/ui.xml"; }
find() { python3 -I "$HERE/ui.py" "$OUT/ui.xml" "$@" 2>/dev/null; }
tap() { local xy; xy=$(find "$@") || return 1; adb shell input tap $xy; sleep 2; }
# `input text` goes through the device shell: spaces become %s, shell characters are escaped.
type_secret() {
  local esc
  esc=$(python3 -I -c 'import re,sys; s=sys.argv[1].replace(" ", "%s"); print(re.sub(r"([\\()<>|;&*~\"'"'"'`$#!?\[\]{}^])", r"\\\1", s))' "$1")
  adb shell input text "$esc"
}

say "## 4bTech Game: permissions and sign-in"

# 1. Permissions, granted directly (same result as switching each one on in Settings).
grant() {
  adb shell settings put secure enabled_accessibility_services "$PKG/$PKG.BotService"
  adb shell settings put secure accessibility_enabled 1
  adb shell appops set "$PKG" PROJECT_MEDIA allow             # screen capture without the "Start recording?" prompt
  adb shell appops set "$PKG" REQUEST_INSTALL_PACKAGES allow  # install unknown apps
  adb shell appops set "$PKG" SYSTEM_ALERT_WINDOW allow       # draw over other apps
  adb shell appops set "$PKG" RUN_IN_BACKGROUND allow
  adb shell dumpsys deviceidle whitelist "+$PKG" >/dev/null   # no battery optimisation
}
grant
acc=$(adb shell settings get secure enabled_accessibility_services | tr -d '\r')
say "PASS accessibility service on: $acc"
say "  appops: $(adb shell appops get "$PKG" | tr -d '\r' | grep -E 'PROJECT_MEDIA|REQUEST_INSTALL_PACKAGES|SYSTEM_ALERT_WINDOW' | tr '\n' ' ')"
say "  battery optimisation off: $(adb shell dumpsys deviceidle whitelist | tr -d '\r' | grep -c "$PKG") entry"
adb shell am start -W -a android.settings.ACCESSIBILITY_SETTINGS >/dev/null 2>&1; sleep 3; shot accessibility-settings
adb shell input keyevent KEYCODE_HOME

# 2. Open the app and sign in.
[ -n "${FOUR_BTECH_GAME_EMAIL:-}" ] && [ -n "${FOUR_BTECH_GAME_PASSWORD:-}" ] || { say "FAIL sign-in: secrets FOUR_BTECH_GAME_EMAIL / FOUR_BTECH_GAME_PASSWORD are not set"; exit 1; }
version() { adb shell dumpsys package "$PKG" | tr -d '\r' | grep -m1 versionName | sed 's/ *versionName=//'; }
open_app() { adb shell am force-stop "$PKG"; adb shell am start -W -n "$PKG/.MainActivity" >/dev/null 2>&1; sleep 8; }
open_app
# The app insists on its newest version ("Please update"): let it update itself, then open it again.
V0=$(version)
for i in $(seq 1 8); do
  dump; top=$(find top)
  if [ "$top" = com.android.packageinstaller ] || [ "$top" = com.google.android.packageinstaller ]; then
    shot installer-$i
    tap text "INSTALL|Install|UPDATE|Update|DONE|Done|OPEN|Open" || adb shell input keyevent KEYCODE_BACK; sleep 15
  elif find text "Please update" >/dev/null; then
    shot please-update-$i
    tap text "Update|UPDATE"; sleep 20
  else
    break
  fi
  [ "$(version)" != "$V0" ] && { say "PASS app updated itself: $V0 -> $(version)"; V0=$(version); grant; open_app; }
done
dump
[ "$(find top)" = "$PKG" ] || { say "FAIL still not in the app (top: $(find top))"; shot stuck; exit 1; }
say "  app version $(version)"
shot app-open
activity() { adb shell dumpsys activity activities | tr -d '\r' | grep -m1 mResumedActivity | grep -oE '[^ /]+/[^ }]+' | tail -1; }
keyboard_down() { sleep 1; }  # no on-screen keyboard (turned off below), so nothing covers the form
fill() {  # fill <id> <value>: types into the field with that id (screen is dumped again first)
  local xy; dump; xy=$(find id "$1") || { say "  no field $1"; return 1; }
  adb shell input tap $xy; sleep 1; type_secret "$2"; keyboard_down
}
# Signed in = some screen of the app other than the sign-in screen is in front.
signed_in() { local a; a=$(activity); case "$a" in "$PKG"/*) [[ "$a" != *AuthActivity* ]];; *) return 1;; esac; }
# Typing needs no on-screen keyboard; without it the whole form stays visible.
for ime in $(adb shell ime list -s | tr -d '\r'); do adb shell ime disable "$ime" >/dev/null; done

# The account lives on the phone only, so a new phone has none: register it first.
# (No screenshots while the email is on screen: these results are public.)
dump; tap id modeRegister; dump; shot register-form
fill name "${FOUR_BTECH_GAME_NAME:-Bhautik}"
fill email "$FOUR_BTECH_GAME_EMAIL"
[ -n "${FOUR_BTECH_GAME_MOBILE:-}" ] && fill mobile "$FOUR_BTECH_GAME_MOBILE"
fill password "$FOUR_BTECH_GAME_PASSWORD"
fill confirm "$FOUR_BTECH_GAME_PASSWORD"
dump
# Tick "I agree": tap the left end of the row so the Terms/Privacy links are not hit.
python3 -I - "$OUT/ui.xml" <<'PY' > "$OUT/agree.txt"
import re, sys, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter("node"):
    if n.get("resource-id", "").endswith(":id/agree"):
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", n.get("bounds")))
        print(x1 + (y2 - y1) // 2, (y1 + y2) // 2, n.get("checked")); break
PY
read -r ax ay checked < "$OUT/agree.txt"; rm -f "$OUT/agree.txt"
[ -n "${ax:-}" ] && [ "$checked" != true ] && { adb shell input tap $ax $ay; sleep 1; }
dump; tap id authGo; sleep 8; dump
err=$(find idtext authError)
if signed_in; then
  say "PASS registered and signed in ($(activity))"
else
  say "  register: ${err:-no message}; trying sign-in"
  # Already registered on this phone (or the app wants a sign-in after registering): sign in.
  dump; tap id modeSignIn
  fill email "$FOUR_BTECH_GAME_EMAIL"; fill password "$FOUR_BTECH_GAME_PASSWORD"
  dump; tap id authGo; sleep 8; dump
  if signed_in; then say "PASS signed in ($(activity))"
  else
    # No screenshot here: the form shows the email.
    say "FAIL sign-in: $(find idtext authError) (screen: $(activity))"
    adb shell input keyevent KEYCODE_HOME; sleep 1; shot after-fail-home; exit 1
  fi
fi
shot signed-in
sleep 10; dump; shot signed-in-later
cp "$OUT/ui.xml" "$OUT/ui-last.xml"
exit 0
