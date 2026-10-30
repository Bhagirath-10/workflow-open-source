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
adb shell settings put secure enabled_accessibility_services "$PKG/$PKG.BotService"
adb shell settings put secure accessibility_enabled 1
adb shell appops set "$PKG" PROJECT_MEDIA allow             # screen capture without the "Start recording?" prompt
adb shell appops set "$PKG" REQUEST_INSTALL_PACKAGES allow  # install unknown apps
adb shell appops set "$PKG" SYSTEM_ALERT_WINDOW allow       # draw over other apps
adb shell appops set "$PKG" RUN_IN_BACKGROUND allow
adb shell dumpsys deviceidle whitelist "+$PKG" >/dev/null   # no battery optimisation
acc=$(adb shell settings get secure enabled_accessibility_services | tr -d '\r')
say "PASS accessibility service on: $acc"
say "  appops: $(adb shell appops get "$PKG" | tr -d '\r' | grep -E 'PROJECT_MEDIA|REQUEST_INSTALL_PACKAGES|SYSTEM_ALERT_WINDOW' | tr '\n' ' ')"
say "  battery optimisation off: $(adb shell dumpsys deviceidle whitelist | tr -d '\r' | grep -c "$PKG") entry"
adb shell am start -W -a android.settings.ACCESSIBILITY_SETTINGS >/dev/null 2>&1; sleep 3; shot accessibility-settings
adb shell input keyevent KEYCODE_HOME

# 2. Open the app and sign in.
[ -n "${FOUR_BTECH_GAME_EMAIL:-}" ] && [ -n "${FOUR_BTECH_GAME_PASSWORD:-}" ] || { say "FAIL sign-in: secrets FOUR_BTECH_GAME_EMAIL / FOUR_BTECH_GAME_PASSWORD are not set"; exit 1; }
adb shell am force-stop "$PKG"
adb shell am start -W -n "$PKG/.MainActivity" >/dev/null 2>&1; sleep 8
# A system dialog (e.g. an install prompt) on top of the app: record it, then close it.
for i in 1 2 3; do
  dump; top=$(find top)
  [ "$top" = "$PKG" ] && break
  say "  dialog over the app from $top"; shot dialog-$i
  tap text "CANCEL|Cancel|GOT IT|Got it|OK|Allow|ALLOW" || adb shell input keyevent KEYCODE_BACK; sleep 3
done
shot app-open
tap text "Sign in|SIGN IN|Login|LOG IN|Log in" && dump
email_xy=$(find edit 0); pass_xy=$(find password)
if [ -z "$email_xy" ] || [ -z "$pass_xy" ]; then
  say "FAIL sign-in: no email/password fields on screen"; shot no-login-form; exit 1
fi
shot sign-in-form
adb shell input tap $email_xy; sleep 1; type_secret "$FOUR_BTECH_GAME_EMAIL"
adb shell input tap $pass_xy; sleep 1; type_secret "$FOUR_BTECH_GAME_PASSWORD"
adb shell input keyevent KEYCODE_BACK; sleep 1   # hide the keyboard
dump
# The submit button is the last "Sign in"-like node (the first one is the tab).
xy=$(python3 -I - "$OUT/ui.xml" <<'PY'
import re, sys, xml.etree.ElementTree as ET
hits = [n for n in ET.parse(sys.argv[1]).iter("node")
        if re.fullmatch(r"(sign ?in|log ?in|continue|submit)", (n.get("text") or n.get("content-desc") or "").strip(), re.I)]
if hits:
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", hits[-1].get("bounds"))); print((x1 + x2) // 2, (y1 + y2) // 2)
PY
)
[ -n "$xy" ] || { say "FAIL sign-in: no sign-in button"; shot no-button; exit 1; }
adb shell input tap $xy; sleep 12
dump; shot after-sign-in
if find edit 0 >/dev/null && find password >/dev/null; then
  say "FAIL sign-in: still on the sign-in screen (see after-sign-in screenshot)"; RC=1
else
  say "PASS signed in (screen after sign-in: see screenshot)"; RC=0
fi
# Second look a bit later (first screen after sign-in may be a loading screen).
sleep 10; dump; shot signed-in-later
cp "$OUT/ui.xml" "$OUT/ui-last.xml"
exit $RC
