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
  adb shell input keyevent KEYCODE_BACK  # hide the keyboard, so the fields under it can be seen
  say "  $TAG: typed $3"; sleep 1
}
launch() {
  local act; act=$(adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PKG" 2>/dev/null | tr -d '\r' | tail -1)
  timeout 30 adb shell am start -n "$act" >/dev/null 2>&1; sleep 8
}
# Startup ad (AdMob full screen): Back closes it.
skip_ad() {
  local i
  for i in 1 2 3; do
    timeout 15 adb shell dumpsys activity activities 2>/dev/null | grep -m1 -E "mResumedActivity|topResumedActivity|ResumedActivity:" | grep -q AdActivity || return 0
    # The ad closes with its "Continue to app" / Close button (Back does nothing on it)
    dump
    # every startup ad is noted too (ad analysis): its words and a screenshot
    echo "$(TZ=Asia/Kolkata date '+%I:%M:%S %p'),$TAG,$(ui texts | cut -c1-200 | tr ',' ' ')" >> "$OUT/startup-ads.csv"; shot "startup-ad"
    if xy=$(ui adclose); then say "  $TAG: startup ad, tap its close button ($xy)"; adb shell input tap $xy
    else say "  $TAG: startup ad, Back"; adb shell input keyevent KEYCODE_BACK; fi
    sleep 3
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
