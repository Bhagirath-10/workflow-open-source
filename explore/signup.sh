#!/usr/bin/env bash
# Makes a new test account in an app through its own "Register" screen, so explore.sh can visit
# the screens behind the login (app exploration workflow, separate from scripts/). The owner asked
# for this (3 Nov): names that fit the app, emails on the owner's domain 4born.com, a new strong
# password every run. The account is written to <out-dir>/account.txt (results stay private).
# Stops (exit 2) when the app asks for a code sent by email or SMS: nobody can read it here.
#
#   signup.sh <package> <out-dir>
set -uo pipefail
PKG=$1; OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"; NOTES="$OUT/notes.txt"; N=0
say() { echo "$*" >> "$NOTES"; }
ui() { python3 -I "$HERE/ui_nodes.py" "$OUT/ui.xml" "$@" 2>/dev/null; }
dump() {
  local i
  for i in 1 2 3; do
    adb shell rm -f /sdcard/ui.xml
    timeout 25 adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    timeout 10 adb shell cat /sdcard/ui.xml 2>/dev/null | tr -d '\r' > "$OUT/ui.xml"
    grep -q '<hierarchy' "$OUT/ui.xml" && return 0
    sleep 1
  done
  return 1
}
shot() { N=$((N + 1)); timeout 15 adb exec-out screencap -p > "$OUT/$(printf 'signup-%02d' $N)-$1.png"; }
# tap <regex> <what>: the lowest clickable thing with that text (the button, not a title)
tap() {
  local xy; dump; xy=$(ui click "$1") || { say "  signup: no \"$2\" on the screen: $(ui texts | cut -c1-300)"; return 1; }
  say "  signup: tap $2 ($xy)"; adb shell input tap $xy; sleep 4
}
# fill <label regex> <text> <what>: types into the field under that label (scrolls up to 3 times)
fill() {
  local xy i
  for i in 0 1 2 3; do
    dump && xy=$(ui fieldbelow "$1") && break
    adb shell input swipe 540 1500 540 900 400; sleep 1
  done
  [ -n "${xy:-}" ] || { say "  signup: no field \"$3\": $(ui texts | cut -c1-300)"; return 1; }
  adb shell input tap $xy; sleep 1
  adb shell input text "$(printf '%s' "$2" | sed 's/ /%s/g')"; sleep 1
  adb shell input keyevent 111          # hide the keyboard (Escape), so the next field is visible
  say "  signup: typed $3"; sleep 1
}
launch() {
  local act; act=$(adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PKG" 2>/dev/null | tr -d '\r' | tail -1)
  timeout 30 adb shell am start -n "$act" >/dev/null 2>&1; sleep 8
}
# Startup ad (AdMob full screen): Back closes it.
skip_ad() {
  local i
  for i in 1 2 3; do
    timeout 15 adb shell dumpsys activity activities 2>/dev/null | grep -m1 mResumedActivity | grep -q AdActivity || return 0
    say "  signup: startup ad on screen, Back"; adb shell input keyevent KEYCODE_BACK; sleep 3
  done
}
asks_code() {   # the screen asks for a code (OTP) or to verify the email
  dump; ui texts | grep -qiE "\bOTP\b|verification code|verify your email|enter (the )?code|કોડ"
}

RUN=${GITHUB_RUN_NUMBER:-$(date +%s)}
PASS="Tst$(head -c 12 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 8)9@x"
case "$PKG" in
  com.mechodal.alakhjoli) NAME="Bhakti Tester"; EMAIL="bhakti.tester.$RUN@4born.com"; MOBILE=9876543210;;
  com.expensetracker.renine) NAME="Expense Tester"; EMAIL="expense.tester.$RUN@4born.com"; MOBILE=;;
  *) say "signup: no sign-up steps known for $PKG"; exit 1;;
esac
say "## signup: new test account for $PKG: $NAME, $EMAIL"

launch; skip_ad; shot start
case "$PKG" in
  com.mechodal.alakhjoli)
    tap ".*રજિસ્ટર.*|.*[Rr]egister.*" "Register (રજિસ્ટર કરો)" || exit 1
    shot register
    fill "નામ.*|Name.*" "$NAME" "name" &&
    fill "ઈમેલ.*|Email.*" "$EMAIL" "email" &&
    fill "મોબાઇલ.*|Mobile.*" "$MOBILE" "mobile number" &&
    fill "પાસવર્ડ \*|પાસવર્ડ|Password.*" "$PASS" "password" &&
    fill "તમારો પાસવર્ડ ફરીથી.*|Confirm.*|Re-?enter.*" "$PASS" "password again" || { shot form-failed; exit 1; }
    shot form-filled
    adb shell input swipe 540 1600 540 600 400; sleep 1
    tap "રજિસ્ટર કરો|Register" "the Register button" || exit 1
    ;;
  com.expensetracker.renine)
    dump; ui click "Get Started" >/dev/null && tap "Get Started" "Get Started"
    skip_ad
    tap "Create account|Create Account|Sign ?[Uu]p" "Create account" || exit 1
    shot create-account
    fill "Name.*" "$NAME" "name" &&
    fill "Email.*" "$EMAIL" "email" &&
    fill "Password.*" "$PASS" "password" || { shot form-failed; exit 1; }
    shot form-filled
    tap "Create account|Create Account|Sign ?[Uu]p|Register|Continue" "the Create account button" || exit 1
    ;;
esac
sleep 6; shot after-submit
dump; say "  signup: after the button: $(ui texts | cut -c1-400)"
if asks_code; then say "STOP signup: the app asks for a code sent to $EMAIL / $MOBILE; nobody can read it here"; exit 2; fi
printf 'app: %s\nname: %s\nemail: %s\nmobile: %s\npassword: %s\nmade: run %s, %s\n' \
  "$PKG" "$NAME" "$EMAIL" "${MOBILE:-}" "$PASS" "$RUN" "$(TZ=Asia/Kolkata date '+%d %b %Y %I:%M %p IST')" > "$OUT/account.txt"
say "signup: done (account in account.txt)"
