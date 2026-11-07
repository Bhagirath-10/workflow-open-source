# Shared by explore/signup.sh and explore/sample-data.sh (app exploration workflow): reading the
# screen (uiautomator), tapping buttons by their text, typing into fields under their label.
# The caller sets PKG, OUT, NOTES, HERE, TAG (prefix of notes and screenshots) and N=0.
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
shot() { N=$((N + 1)); timeout 15 adb exec-out screencap -p > "$OUT/$(printf '%s-%04d' "$TAG" "$N")-$1.png"; }
# Typed like a person (owner, 4 Nov: "like a real human"): letter by letter with small random pauses
# (long texts in short pieces), not pasted in one go.
human_type() {
  local t=$1 i c
  if [ ${#t} -gt 40 ]; then adb shell input text "$(printf '%s' "$t" | sed 's/ /%s/g')"; return; fi
  for (( i = 0; i < ${#t}; i++ )); do
    c=${t:i:1}; [ "$c" = " " ] && c="%s"
    if [ "$c" = "'" ]; then adb shell input text "\\'"; else adb shell input text "'$c'"; fi   # quoted for the phone's shell
    sleep 0.$(( RANDOM % 4 + 1 ))
  done
}
# Back hides the keyboard only if one is showing: on phones where none appears (Android 13/14 with
# MindTheGapps, runs 113/114/118) Back left the sign-up form and closed the app.
hide_kb() {
  # The keyboard is open when the screen dump shows the keyboard app's own items (Gboard / AOSP
  # keyboard, e.g. its suggestion strip). Only then is Back pressed: Back without a keyboard closed
  # Alakh Joli's sign-up form (runs 138/139/148), and a missed keyboard hid the next field (169/179/183/184).
  local kb=no sdk
  dump; grep -qE 'package="com\.(google\.android|android)\.inputmethod' "$OUT/ui.xml" && kb=yes
  sdk=$(timeout 10 adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')
  if [ "$kb" = no ] && [ "${sdk:-30}" -lt 33 ] 2>/dev/null; then
    timeout 10 adb shell dumpsys input_method 2>/dev/null | grep -qiE "mInputShown=true|mImeWindowVis=[23]|mIsInputViewShown=true" && kb=yes
  fi
  [ "$kb" = yes ] && { adb shell input keyevent KEYCODE_BACK; sleep 1; }
  return 0
}
# tap <regex> <what>: the lowest clickable thing with that text (the button, not a title); a person
# looks for a moment before tapping, and taps a few pixels off the exact centre.
tap() {
  local xy; dump; xy=$(ui click "$1") || { say "  $TAG: no \"$2\" on the screen: $(ui texts | cut -c1-300)"; return 1; }
  sleep $(( RANDOM % 2 + 1 )); set -- "$1" "$2" ${xy% *} ${xy#* }
  say "  $TAG: tap $2 ($xy)"; adb shell input tap $(( $3 + RANDOM % 9 - 4 )) $(( $4 + RANDOM % 9 - 4 )); sleep 4
}
# fill <label regex> <text> <what>: types into the field under that label (scrolls up to 3 times)
fill() {
  local xy i
  for i in 0 1 2 3; do
    dump && xy=$(ui fieldbelow "$1") && break
    adb shell input keyevent 111; adb shell input swipe 540 1300 540 500 400; sleep 1   # keyboard away, scroll up
  done
  [ -n "${xy:-}" ] || { say "  $TAG: no field \"$3\": $(ui texts | cut -c1-300)"; return 1; }
  adb shell input tap $xy; sleep 1
  human_type "$2"; sleep 1
  hide_kb   # hide the keyboard, so the fields under it can be seen
  say "  $TAG: typed $3"; sleep 1
}
launch() {
  local act; act=$(adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PKG" 2>/dev/null | tr -d '\r' | tail -1)
  timeout 30 adb shell am start -n "$act" >/dev/null 2>&1; sleep 8
}
# Guard on every tap: if a full-screen ad is on top at that moment, the tap is NOT sent (it would
# land on the ad); the ad is closed without a tap instead.
adb() {
  if [ "${1:-} ${2:-} ${3:-}" = "shell input tap" ] && timeout 10 adb shell dumpsys activity activities 2>/dev/null \
       | grep -m1 -E "mResumedActivity|topResumedActivity|ResumedActivity:" | grep -q AdActivity; then
    say "  ${TAG:-explore}: a full-screen ad was on screen: tap skipped, ad closed without a tap"
    close_ad_notap; return 0
  fi
  command adb "$@"
}
# A full-screen ad is closed WITHOUT ANY TAP on the screen (owner's AdMob safety): even a tap on
# "Continue to app" opened the Play Store once (run 140, ChatGPT install ad, 6 Nov). Back, up to 3
# times; if the ad is still there, the app is closed (like swiping it away) and opened again.
close_ad_notap() {
  local i top
  for i in 1 2 3; do
    adb shell input keyevent KEYCODE_BACK; sleep 2
    top=$(timeout 15 adb shell dumpsys activity activities 2>/dev/null | grep -m1 -E "mResumedActivity|topResumedActivity|ResumedActivity:")
    echo "$top" | grep -q AdActivity || return 0
  done
  say "  ${TAG:-explore}: the ad did not close with Back: app closed and opened again (no tap on the ad)"
  # Safety (6 Nov, Expense Tracker): if an app's ads cannot be closed without a tap, closing and
  # reopening it shows a new ad each time. After 5 such closes the session ends, so no ad loop.
  local n; n=$(( $(cat "$OUT/.forced-closes" 2>/dev/null || echo 0) + 1 )); echo $n > "$OUT/.forced-closes"
  if [ "$n" -gt 5 ]; then
    say "STOP: this app's ads do not close with Back ($n times): session ended so that no more ads are loaded"
    echo "STOPPED: ads do not close with Back; session ended after $n forced closes" >> "$OUT/summary.txt"
    adb shell am force-stop "$PKG"; exit 4
  fi
  adb shell am force-stop "$PKG"; sleep 2
  local act; act=$(adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PKG" 2>/dev/null | tr -d '\r' | tail -1)
  timeout 30 adb shell am start -n "$act" >/dev/null 2>&1; sleep 6
}
# Startup ad (AdMob full screen): closed without a tap (close_ad_notap).
skip_ad() {
  local i
  for i in 1 2 3; do
    timeout 15 adb shell dumpsys activity activities 2>/dev/null | grep -m1 -E "mResumedActivity|topResumedActivity|ResumedActivity:" | grep -q AdActivity || return 0
    # The ad closes with its "Continue to app" / Close button (Back does nothing on it)
    dump
    # every startup ad is noted too (ad analysis): its words and a screenshot
    echo "$(TZ=Asia/Kolkata date '+%I:%M:%S %p'),$TAG,$(ui texts | cut -c1-200 | tr ',' ' ')" >> "$OUT/startup-ads.csv"; shot "startup-ad"
    say "  $TAG: startup ad, closed without touching it (Back, else the app closed)"; close_ad_notap
    sleep 1
  done
}
# After closing an ad: if a store or browser came up instead of the app, the ad was opened by mistake.
# Noted (AD-CLICK in notes and ad-clicks.txt) and closed with Back, so it is never left open.
ad_click_check() {
  local top i
  for i in 1 2 3; do
    top=$(timeout 15 adb shell dumpsys activity activities 2>/dev/null | grep -m1 -E "mResumedActivity|topResumedActivity|ResumedActivity:" | grep -oE '[a-zA-Z0-9_.]+/[^ }]+')
    case "$top" in
      com.android.vending/*|com.android.chrome/*|*browser*|*webview*)
        [ "$i" = 1 ] && { say "  ${TAG:-explore}: AD-CLICK: $top came up after closing an ad ($1); closed with Back"; echo "$(TZ=Asia/Kolkata date '+%I:%M:%S %p'),$1,$top" >> "$OUT/ad-clicks.txt"; }
        adb shell input keyevent KEYCODE_BACK; sleep 2;;
      *) return 0;;
    esac
  done
}
