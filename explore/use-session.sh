#!/usr/bin/env bash
# Uses an app like a real person for <minutes>, on its real screens (taps and typing, nothing
# through its server or database): the owner asked for this (3 Nov) for the expense tracker.
# Adds expenses and income, edits and deletes entries, adds wallets and budgets, looks at
# Home, Analytics and Transactions. Every action is screenshotted (use-NNNN-*.png) and logged
# with the time in notes.txt; problems are logged as PROBLEM and the session goes on.
# Ads: every full-screen ad is watched until it ends or offers its close button, screenshotted
# and counted (ads.csv); banners are counted per screen. Ads are never tapped (only their close).
# Ad analysis (owner, 4 Nov: "main focus is ads, which type and how many, used like a normal
# human"): the session also does what the app's own code shows ads after (opening the app again
# after a while, Edit Profile, a wallet / budget / saving goal made, edited and deleted), waits for
# the ad like a person would, and keeps the phone's ad log (ads-logcat.txt: every ad the app asked
# for, loaded or failed to get) for the report (ads-summary.txt).
#
#   use-session.sh <package> <out-dir> <minutes>
set -uo pipefail
PKG=$1; OUT=$2; MIN=${3:-120}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"; NOTES="$OUT/notes.txt"; N=0; TAG=use
. "$HERE/lib.sh"
ts() { TZ=Asia/Kolkata date '+%I:%M:%S %p'; }
log() { say "[$(ts)] $*"; }
problem() { PROBLEMS=$((PROBLEMS + 1)); log "PROBLEM: $*"; shot "problem"; }
ADS=0; BANNERS=0; PROBLEMS=0; ADDED=0; EDITED=0; DELETED=0; WALLETS=0; BUDGETS=0
echo "time,type,screen,seconds,advertiser/text" > "$OUT/ads.csv"

top() { timeout 15 adb shell dumpsys activity activities 2>/dev/null | grep -m1 -E "mResumedActivity|topResumedActivity|ResumedActivity:" | grep -oE '[a-zA-Z0-9_.]+/[^ }]+'; }
# The phone's ad log for the whole session: Google Mobile Ads ("Ads") and the app's own messages.
timeout 10 adb logcat -c 2>/dev/null
( exec timeout $(( MIN * 60 + 1500 )) adb logcat -v time Ads:V flutter:V AndroidRuntime:E ActivityManager:W DEBUG:F '*:S' > "$OUT/ads-logcat.txt" 2>/dev/null ) &
LOGCAT=$!; trap 'kill $LOGCAT 2>/dev/null' EXIT
REOPENS=0; PROFILE=0; WCYCLE=0; BCYCLE=0; GCYCLE=0
pause() { sleep $(( RANDOM % ($2 - $1 + 1) + $1 )); }       # a person's pause: pause <min s> <max s>
wait_ad() {   # wait_ad <where> [seconds]: an ad may come a few seconds after the action, as for a person
  local i; for i in $(seq 1 $(( ${2:-10} / 2 ))); do watch_ad "$1" && return 0; sleep 2; done; return 1
}
reopen() {    # reopen cold|warm: leave the app and come back later, as people do
  REOPENS=$((REOPENS + 1))
  if [ "$1" = cold ]; then
    log "user closes the app (swiped away) and opens it again later"; adb shell am force-stop "$PKG"; pause 30 90
  else
    log "user goes to the phone's home screen and comes back later"; adb shell input keyevent KEYCODE_HOME; pause 60 150
  fi
  local act; act=$(adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PKG" 2>/dev/null | tr -d '\r' | tail -1)
  timeout 30 adb shell am start -n "$act" >/dev/null 2>&1; sleep 3
  wait_ad "app opened again ($1)" 16 || log "  no ad when the app opened again ($1)"
  shot "reopen-$1"
}
# A full-screen ad on top: watch it to the end, screenshot, count, then its close button (never the ad).
watch_ad() {
  local where=$1 t0 t txt kind
  top | grep -q AdActivity || return 1
  t0=$(date +%s); ADS=$((ADS + 1)); sleep 2; dump
  txt=$(ui texts | cut -c1-160 | tr ',' ' ')
  kind="full-screen"; echo "$txt" | grep -qiE "reward" && kind="rewarded"
  echo "$txt" | grep -qiE "video|sec|seconds|skip in" && kind="$kind video"
  shot "ad-$ADS"; local act; act=$(top)
  # Watched to the end as a person would (owner, 4 Nov: "view the whole ads"): never Skip; its Close
  # or "Continue to app" only once the ad is over (no countdown left) or after 30 s; at most 2 minutes.
  for t in $(seq 1 60); do
    top | grep -q AdActivity || break
    [ "$t" = 4 ] || [ "$t" = 10 ] || [ "$t" = 20 ] && shot "ad-$ADS-$(( $(date +%s) - t0 ))s"
    dump; local el=$(( $(date +%s) - t0 )) now; now=$(ui texts | cut -c1-200)
    echo "$now" | grep -qiE "video|reward" && kind=${kind%% video}" video"
    if ui adclose >/dev/null; then
      if ! echo "$now" | grep -qiE "[0-9]+ ?(s|sec|seconds)\b|reward in|skip in" || [ "$el" -ge 30 ]; then
        xy=$(ui adclose); adb shell input tap $xy; sleep 2; break
      fi
    fi
    sleep 2
  done
  top | grep -q AdActivity && { adb shell input keyevent KEYCODE_BACK; sleep 2; }
  ad_click_check "AD #$ADS $where"
  echo "$(ts),$kind,$where,$(( $(date +%s) - t0 )),$txt [$act]" >> "$OUT/ads.csv"
  log "AD #$ADS ($kind) on \"$where\", watched $(( $(date +%s) - t0 )) s: $txt"
  return 0
}
banners() {   # ad views on the current screen (AdMob banners)
  dump; local b; b=$(grep -oE 'resource-id="[^"]*(adView|ad_view|banner|native_ad)[^"]*"|text="(Ad|Advertisement|Sponsored)"|class="android.webkit.WebView"' "$OUT/ui.xml" | wc -l)
  [ "$b" -gt 0 ] && { BANNERS=$((BANNERS + b)); log "banner ad(s) on \"$1\": $b"; shot "banner"
    echo "$(ts),banner,$1,0,$(python3 -I - "$OUT/ui.xml" <<'PY2'
import sys, xml.etree.ElementTree as ET
out = []
def walk(n, inad):
    inad = inad or n.get("class") == "android.webkit.WebView"
    t = (n.get("text") or n.get("content-desc") or "").strip()
    if inad and t: out.append(t)
    for c in n: walk(c, inad)
walk(ET.parse(sys.argv[1]).getroot(), False)
print(" ".join(out)[:160].replace(",", " "))
PY2
)" >> "$OUT/ads.csv"; }
  return 0     # no banner is not a failure (a_tab stopped every round on it: run 43 read nothing)
}
ensure_app() {    # the app on screen (ads watched first); reopened when it is gone
  local i
  for i in 1 2 3; do
    watch_ad "${1:-?}" && continue
    top | grep -q "^$PKG/" && return 0
    problem "the app is not on screen (on $(top)): reopening it"
    launch; skip_ad
  done
  top | grep -q "^$PKG/"
}
go() {  # bottom tab: Home, Wallet, Analytics, Transaction
  ensure_app "$1"; tap "$1" "$1 tab" >/dev/null || { adb shell input keyevent KEYCODE_BACK; sleep 2; tap "$1" "$1 tab" >/dev/null; }
  sleep 2; watch_ad "$1"; banners "$1"
}
pick() {  # pick <label regex> <item regex>: tap the box under the label (where a person taps), then the item
  local xy x y i
  dump
  if xy=$(ui textat "Select ${1#Select }"); then :                 # the box's own words, when the app shows them
  elif xy=$(ui textat "$1"); then x=${xy% *}; y=${xy#* }; xy="$((x + 260)) $((y + 118))"   # the box under the label
  else log "  no \"$1\" on the screen"; return 1; fi
  adb shell input tap $xy; sleep 3
  for i in 0 1 2; do
    dump
    if xy=$(ui textat "$2"); then adb shell input tap $xy; sleep 2; log "  picked $2"
      dump; ui textat "Done" >/dev/null && { adb shell input tap $(ui textat "Done"); sleep 2; }   # multi-select lists
      return 0; fi
    adb shell input swipe 540 1700 540 1000 400; sleep 1        # the list may need scrolling
  done
  log "  \"$2\" not in the list: $(ui texts | cut -c1-200)"; shot "list"
  dump; ui textat "Add Expense|Add Income|Add Budget" >/dev/null || { adb shell input keyevent KEYCODE_BACK; sleep 2; }   # close the list, stay in the form
  return 1
}

CATS_EXP=("Food & Dining:Tea and snacks:40" "Food & Dining:Lunch with team:320" "Travel & Transport:Petrol:500" "Travel & Transport:Auto rickshaw:80"
          "Shopping:Groceries:1250" "Bills & Utilities:Electricity bill:1840" "Bills & Utilities:Mobile recharge:299" "Health:Medicines:460"
          "Entertainment:Movie tickets:600" "Education:Books:750" "Clothing:T-shirt:899" "Phone:Earphones:1299" "Social:Gift for friend:1000")
CATS_INC=("Salary:30000" "Freelance project:8500" "Interest:420" "Cashback:150")

add_txn() {   # add_txn Expense|Income <category> <note> <amount>
  local type=$1 cat=$2 note=$3 amt=$4
  go Home
  ensure_app "add"; dump
  # The round + sits in the bottom bar, 80 px above the tab names: found from the "Home" tab, since
  # its place changes with the screen height (a fixed 540,1980 missed it on 2460-high phones, run 51).
  local hy; hy=$(ui textat "Home" | cut -d' ' -f2)
  xy=$(ui click "\\+|Add Transaction") || xy="540 $(( ${hy:-2060} - 80 ))"
  adb shell input tap $xy; sleep 3; dump
  # The choice opens low on the screen (y 1700-1850 in good runs); Home's own Income/Expense labels are
  # at the top (y ~940): only a choice in the lower half is taken (run 51 tapped Home's label instead).
  local cy; cy=$(ui allat "$type|Add $type" | awk '$2 > 1200' | tail -1)
  [ -n "$cy" ] || { problem "no $type choice after + (tapped $xy): $(ui texts | cut -c1-120)"; adb shell input keyevent KEYCODE_BACK; return 1; }
  sleep 1; adb shell input tap $cy; sleep 3; log "  chose $type ($cy)"
  if [ "$type" = Expense ]; then
    pick "Category" "$cat" || problem "category $cat not picked"
  else
    pick "Category" "$cat" || pick "Category" "Salary|Part-Time|Investment" || problem "income category not picked"
  fi
  fill "Amount.*" "$amt" "amount" || { problem "no amount field"; adb shell input keyevent KEYCODE_BACK; return 1; }
  W=("Cash Wallet" "HDFC Bank" "Cash Wallet" "Paytm Wallet"); wal=${W[$((RANDOM % 4))]}
  pick "Wallet" "$wal" || pick "Wallet" "Cash Wallet|HDFC Bank|Paytm Wallet" || problem "no wallet to pick"
  fill "Note.*" "$note" "note" || true
  shot "add-$type-filled"
  tap "Save" "Save" >/dev/null
  sleep 3; dump
  if ui texts | grep -q "Insufficient Wallet Balance"; then     # more than the wallet holds: go on, as a user would
    log "  app: Insufficient Wallet Balance ($wal), tapping Proceed Anyway"; shot "insufficient-balance"
    xy=$(ui textat "Proceed Anyway|Proceed|Continue") || xy="742 1497"     # the red "Proceed Anyway" button
    adb shell input tap $xy; sleep 3; dump
  fi
  if ui texts | grep -qE "Please select|is required|Please enter"; then
    problem "$type not saved: $(ui texts | grep -oE 'Please [a-z ]+\.?|[A-Za-z ]+ is required' | head -2 | tr '\n' ' ')"
    adb shell input keyevent KEYCODE_BACK; sleep 2; return 1
  fi
  ADDED=$((ADDED + 1)); log "added $type: $cat, $note, $amt, ${wal:-}"
  # Expense Tracker 3.1.0 shows an ad after each income/expense saved (showIncomeExpenseAd): waited for.
  wait_ad "after saving $type" 10; shot "after-add-$type"
}
open_first_txn() {   # opens an entry from the Transactions list (a random one of the first rows)
  go Transaction; dump
  local rows n xy
  # a row is read as one item: "<category> <wallet> $ 40.00 <date>" (or the amount alone)
  rows=$(ui allat '.*[$₹] ?[0-9][0-9,]*(\.[0-9]{2})?.*' | awk '$2 > 350 && $2 < 1950')
  n=$(echo "$rows" | grep -c . || true)
  [ "$n" -gt 0 ] || { log "no entry to open"; return 1; }
  xy=$(echo "$rows" | sed -n "$(( RANDOM % (n < 4 ? n : 4) + 1 ))p")
  adb shell input tap 300 "${xy#* }"; sleep 3; shot "entry-opened"; dump
  log "opened an entry: $(ui texts | cut -c1-200)"
}
menu_item() {   # menu_item <Edit|Delete>: the ⋮ ("Show menu") of Transaction Detail, then the item
  local xy
  dump; xy=$(ui textat "Show menu|More options|More") || xy="1016 140"
  adb shell input tap $xy; sleep 2; dump; shot "menu"
  xy=$(ui textat "$1.*") || { log "  menu: $(ui texts | cut -c1-150)"; return 1; }
  adb shell input tap $xy; sleep 3
}
edit_txn() {
  open_first_txn || return 1
  menu_item "Edit" || { problem "no Edit in the entry's menu"; adb shell input keyevent KEYCODE_BACK; sleep 1; adb shell input keyevent KEYCODE_BACK; return 1; }
  dump; ui fieldbelow "Amount.*" >/dev/null || { problem "no Edit on the entry screen"; adb shell input keyevent KEYCODE_BACK; return 1; }
  xy=$(ui fieldbelow "Amount.*"); adb shell input tap $xy; sleep 1
  adb shell input keyevent KEYCODE_MOVE_END; for _ in $(seq 1 8); do adb shell input keyevent KEYCODE_DEL; done
  new=$(( (RANDOM % 90 + 10) * 10 )); adb shell input text "$new"; adb shell input keyevent KEYCODE_BACK; sleep 1
  shot "edit-filled"
  tap "Save|Update|Save Changes" "Save" >/dev/null || return 1
  dump
  if ui texts | grep -q "Insufficient Wallet Balance"; then     # the new amount is more than the wallet holds
    log "  app: Insufficient Wallet Balance on edit, tapping Proceed Anyway"
    xy=$(ui textat "Proceed Anyway|Proceed|Continue") || xy="742 1497"; adb shell input tap $xy; sleep 3
  fi
  EDITED=$((EDITED + 1)); log "edited an entry: amount now $new"; shot "after-edit"
}
delete_txn() {
  open_first_txn || return 1
  local what; what=$(ui texts | cut -d'|' -f3-6)
  menu_item "Delete" || { problem "no Delete in the entry's menu"; adb shell input keyevent KEYCODE_BACK; sleep 1; adb shell input keyevent KEYCODE_BACK; return 1; }
  shot "delete-ask"; dump
  xy=$(ui textat "Delete|Yes|Confirm|OK|Yes, Delete") && adb shell input tap $xy && sleep 3
  DELETED=$((DELETED + 1)); log "deleted an entry:$what"; shot "after-delete"
}
add_wallet() {   # add_wallet <name> <balance>
  go Wallet
  tap "Add Wallet|Add New Wallet|\\+ Add Wallet|New Wallet" "Add Wallet" >/dev/null || { dump; xy=$(ui click "\\+") && adb shell input tap $xy && sleep 3; }
  fill "Wallet Name.*" "$1" "wallet name" && fill "Initial [Bb]alance.*" "$2" "initial balance" &&
    tap "Create Wallet|Save" "Create Wallet" >/dev/null && { WALLETS=$((WALLETS + 1)); log "added wallet $1 ($2)"; shot "after-wallet"; return 0; }
  problem "wallet $1 not added"; adb shell input keyevent KEYCODE_BACK
}
add_budget() {   # add_budget <name> <amount> <category>
  go Home
  local i; for i in 1 2 3; do dump; ui textat "Add Budget" >/dev/null && break; adb shell input swipe 540 1600 540 900 400; sleep 1; done
  tap "Add Budget|\+ Add Budget" "Add Budget" >/dev/null || { problem "no Add Budget on Home"; return 1; }
  fill "Budget Name.*" "$1" "budget name"; fill "Budget Amount.*" "$2" "budget amount"
  dump; xy=$(ui textat "Select Wallet|Select Wallets") && { adb shell input tap $xy; sleep 2; dump; xy=$(ui textat "Cash Wallet") && adb shell input tap $xy; sleep 1; tap "Done" "Done" >/dev/null; }
  pick "Category" "$3" >/dev/null
  shot "budget-filled"
  adb shell input swipe 540 1600 540 600 400; sleep 1
  tap "Create Budget|Save Budget|Save|Add Budget|Create" "save budget" >/dev/null && { BUDGETS=$((BUDGETS + 1)); log "added budget $1 ($2, $3)"; shot "after-budget"; return 0; }
  problem "budget $1 not saved"; adb shell input keyevent KEYCODE_BACK
}
# ---------- Expense Tracker: the actions its code shows ads after (admob_service.dart:
# showEditProfileAd, showWalletCreate/Edit/DeleteAd, showBudgetAdd/Edit/DeleteAd,
# showSavingGoalCreate/DeleteAd, showSplashAd) ----------
screen_log() { dump; log "  screen $1: $(ui texts | cut -c1-220)"; shot "$1"; }
profile() {   # Home › "Hello, <name>" opens the Profile
  go Home; dump
  # "Hello, <name>" is not marked clickable (tap found nothing, runs 45/47): tapped where its text is
  local xy; xy=$(ui textat "Hello,.*") || xy=$(ui textat "Here's your financial overview") || { problem "no Profile (Hello, ...) on Home"; return 1; }
  adb shell input tap $xy; sleep 3
  wait_ad "Profile" 6; screen_log "profile"
}
edit_profile() {
  profile || return 1
  tap "Edit Profile|Edit|Expense Tester" "Edit Profile" >/dev/null || { problem "no Edit Profile on the Profile"; go Home; return 1; }
  PROFILE=$((PROFILE + 1)); wait_ad "Edit Profile" 12; screen_log "edit-profile"
  if dump && ui click "Save|Update|Save Changes|Update Profile" >/dev/null; then
    fill "Phone.*|Mobile.*" "9409005692" "phone" >/dev/null 2>&1
    tap "Save|Update|Save Changes|Update Profile" "Save profile" >/dev/null; wait_ad "Edit Profile saved" 12; screen_log "after-edit-profile"
  fi
  adb shell input keyevent KEYCODE_BACK; sleep 2; go Home
}
open_named() {   # open_named <tab> <name>: tap that item (scrolling to find it)
  local i xy
  [ "$1" = Profile ] || go "$1"
  for i in 0 1 2 3; do dump; xy=$(ui textat "$2") && break; adb shell input swipe 540 1600 540 1000 400; sleep 1; done
  [ -n "${xy:-}" ] || { log "  no \"$2\" on $1: $(ui texts | cut -c1-200)"; return 1; }
  adb shell input tap $xy; sleep 3; screen_log "opened-$(echo "$2" | tr ' ' '-')"
}
do_action() {   # do_action <Edit|Delete>: the item's own button, else its ⋮ menu
  local xy; dump
  if xy=$(ui textat "$1|$1 .*|.*$1"); then adb shell input tap $xy; sleep 3; else menu_item "$1" || return 1; fi
  if [ "$1" = Delete ]; then dump; xy=$(ui textat "Delete|Yes|Confirm|OK|Yes, Delete") && { adb shell input tap $xy; sleep 3; }; fi
  return 0
}
change_amount() {   # change_amount <label regex> <new amount>
  local xy; dump; xy=$(ui fieldbelow "$1") || return 1
  adb shell input tap $xy; sleep 1; adb shell input keyevent KEYCODE_MOVE_END
  for _ in $(seq 1 10); do adb shell input keyevent KEYCODE_DEL; done
  adb shell input text "$2"; adb shell input keyevent KEYCODE_BACK; sleep 1
}
wallet_cycle() {   # a wallet made, edited, deleted (a trip wallet)
  local w="Trip Wallet $1"; WCYCLE=$((WCYCLE + 1))
  add_wallet "$w" 3000 && wait_ad "wallet created" 12
  open_named Wallet "$w" || return 1; wait_ad "wallet opened" 6
  if do_action Edit; then
    change_amount "Initial [Bb]alance.*|Balance.*|Amount.*" 3500 && tap "Save|Update|Update Wallet|Save Changes" "save wallet" >/dev/null &&
      { log "edited wallet $w"; wait_ad "wallet edited" 12; screen_log "after-wallet-edit"; }
  else problem "no Edit for wallet $w"; adb shell input keyevent KEYCODE_BACK; sleep 2; fi
  open_named Wallet "$w" || return 1
  do_action Delete && { log "deleted wallet $w"; wait_ad "wallet deleted" 12; screen_log "after-wallet-delete"; } || { problem "no Delete for wallet $w"; adb shell input keyevent KEYCODE_BACK; }
}
budget_cycle() {   # a budget made, edited, deleted
  local b="Weekend Fun $1"; BCYCLE=$((BCYCLE + 1))
  add_budget "$b" 1500 "Entertainment" && wait_ad "budget created" 12
  open_named Home "$b" || return 1; wait_ad "budget opened" 6
  if do_action Edit; then
    change_amount "Budget Amount.*" 1800 && { adb shell input swipe 540 1600 540 600 400; sleep 1; } &&
      tap "Update Budget|Save Budget|Save|Update" "save budget" >/dev/null && { log "edited budget $b"; wait_ad "budget edited" 12; screen_log "after-budget-edit"; }
  else problem "no Edit for budget $b"; adb shell input keyevent KEYCODE_BACK; sleep 2; fi
  open_named Home "$b" || return 1
  do_action Delete && { log "deleted budget $b"; wait_ad "budget deleted" 12; screen_log "after-budget-delete"; } || { problem "no Delete for budget $b"; adb shell input keyevent KEYCODE_BACK; }
}
goal_cycle() {    # Profile › Saving Goal: a goal made, then deleted
  local g="New Phone $1"; GCYCLE=$((GCYCLE + 1))
  profile || return 1
  tap "Saving Goal" "Saving Goal" >/dev/null || { problem "no Saving Goal on the Profile"; return 1; }
  wait_ad "Saving Goal" 6; screen_log "saving-goals"
  tap "Add Goal|Create Goal|Add Saving Goal|New Goal|Add New Goal|Create New Goal|\\+|Add" "Add goal" >/dev/null || { dump; xy=$(ui click "\\+") && adb shell input tap $xy && sleep 3; }
  screen_log "goal-form"
  fill "Goal Name.*|Goal Title.*|Name.*|Title.*" "$g" "goal name" || { problem "no goal form"; adb shell input keyevent KEYCODE_BACK; return 1; }
  fill "Target Amount.*|Target.*|Goal Amount.*|Amount.*" "20000" "target amount"
  dump; ui textat "Select Wallet|Wallet" >/dev/null && pick "Wallet" "Cash Wallet" >/dev/null
  adb shell input swipe 540 1600 540 600 400; sleep 1; screen_log "goal-filled"
  tap "Create Goal|Save Goal|Add Goal|Create|Save" "save goal" >/dev/null && { log "added saving goal $g"; wait_ad "saving goal created" 12; screen_log "after-goal"; }
  open_named Profile "$g" || return 1
  do_action Delete && { log "deleted saving goal $g"; wait_ad "saving goal deleted" 12; screen_log "after-goal-delete"; } || { problem "no Delete for goal $g"; adb shell input keyevent KEYCODE_BACK; }
  adb shell input keyevent KEYCODE_BACK; sleep 2
}
ads_summary() {   # the ad report of this session (ads-summary.txt)
  {
    echo "## ads in this session ($PKG, $MIN minutes)"
    echo "full-screen ads watched: $ADS, banner ads seen: $BANNERS, app opened again: $REOPENS times"
    echo "startup ads during sign-up/first start: $( [ -f "$OUT/startup-ads.csv" ] && wc -l < "$OUT/startup-ads.csv" || echo 0)"
    echo "-- full-screen ads by where they came:"; awk -F, 'NR>1 && $2!="banner"{print "   " $3 " (" $2 ")"}' "$OUT/ads.csv" | sort | uniq -c | sort -rn
    echo "-- banners by screen:"; awk -F, 'NR>1 && $2=="banner"{print "   " $3}' "$OUT/ads.csv" | sort | uniq -c | sort -rn
    echo "-- the phone's ad log (ads-logcat.txt):"
    echo "   ad requests (Ads): $(grep -c 'Ads.*\(request\|Requesting\)' "$OUT/ads-logcat.txt" 2>/dev/null)"
    echo "   failed to load (no ad given): $(grep -ciE 'failed to load|onAdFailedToLoad|No fill' "$OUT/ads-logcat.txt" 2>/dev/null)"
    echo "   error codes: $(grep -oE 'failed to load *: *[0-9]+|[Ee]rror code:? *[0-9]+|code: *[0-9]+' "$OUT/ads-logcat.txt" 2>/dev/null | sort | uniq -c | tr '\n' ';')"
    echo "   app's own ad messages:"; grep -E 'flutter' "$OUT/ads-logcat.txt" 2>/dev/null | grep -iE 'ad|admob' | sed -E 's/^[0-9-]+ [0-9:.]+ //' | cut -c1-160 | sort | uniq -c | sort -rn | head -25
  } > "$OUT/ads-summary.txt" 2>/dev/null
  cat "$OUT/ads-summary.txt" >> "$NOTES"
}
look_around() {
  go Home; shot "home"
  go Analytics; shot "analytics"; tap "Income" "Income tab" >/dev/null && shot "analytics-income"; tap "Expenses" "Expenses tab" >/dev/null
  go Transaction; shot "transactions"
  go Wallet; shot "wallets"
}

# ---------- Alakh Joli: a devotee using the app (reading bhajans, saints, types, the tabs) ----------
READ=0; SAINTS=0; TYPES=0; TABS=0
SAINT_NAMES=("ગંગાસતી" "ચારણ કવિ શ્રી ભગુભાઈ" "દેવાયત પંડિત" "નરસિંહ મહેતા" "પ્રેમાનંદ સ્વામી" "મીરાબાઈ" "લીરલ' બાઈ" "દયાનંદ સરસ્વતી")
TYPE_NAMES=("આત્મજ્ઞાન ભજન" "કૃષ્ણ ભક્તિ ભજન" "ભક્તિ ભજન" "ભજન-આરતી" "યોગ ભજન" "રામ ભક્તિ ભજન" "લોક ભજન" "શિવ ભક્તિ ભજન" "ઉપદેશ ભજન" "પ્રાર્થના")
a_login() {  # the app logged the test account out (run 56): log in again with it (never with Google)
  dump; ui texts | grep -q "લૉગિન કરો" || return 0
  local em pw; em=$(sed -n 's/^email: //p' "$OUT/account.txt" 2>/dev/null); pw=$(sed -n 's/^password: //p' "$OUT/account.txt" 2>/dev/null)
  [ -n "$em" ] || { problem "logged out and no account.txt"; return 1; }
  log "the app logged the test account out: logging in again ($em)"; shot "logged-out"
  fill "ઈમેલ.*|Email.*" "$em" "email" && fill "પાસવર્ડ.*|Password.*" "$pw" "password" && tap "લૉગિન કરો" "login" >/dev/null
  sleep 5; wait_ad "after login" 8; shot "after-login"
}
a_tab() {   # a bottom tab: ઘર સાખી AI રિફર નોટેશન
  ensure_app "$1"; a_login; dump; local xy
  xy=$(ui textat "$1") || { adb shell input keyevent KEYCODE_BACK; sleep 2; dump; xy=$(ui textat "$1"); } || { problem "no tab $1"; return 1; }
  adb shell input tap $xy; sleep 3; watch_ad "$1"; banners "$1"
}
a_back() { adb shell input keyevent KEYCODE_BACK; sleep 2; }
a_open() {  # a_open <text regex> <what>: tap that text (scrolling a little to find it)
  local xy i
  for i in 0 1 2; do dump; xy=$(ui textat "$1") && break; adb shell input swipe 540 1600 540 1000 400; sleep 1; done
  [ -n "${xy:-}" ] || { log "  no \"$2\" on the screen"; return 1; }
  adb shell input tap $xy; sleep 3; wait_ad "$2" 6
  return 0     # no ad is not a failure (run 52: saints and types were never opened because of it)
}
a_read_one() {  # on a list of bhajans: open one, read it (scroll slowly), come back
  dump
  local rows n xy title
  rows=$(ui targets | grep -vE "ઘર|સાખી|^.*\bAI\b|રિફર|નોટેશન|મેનુ|Menu|શોધો|\[ImageView\]|\[Button\]|\[EditText\]")
  n=$(echo "$rows" | grep -c . || true)
  [ "$n" -gt 0 ] || { log "  no bhajan in this list: $(ui texts | cut -c1-120)"; shot "empty-list"; return 1; }
  pick=$(echo "$rows" | sed -n "$(( RANDOM % n + 1 ))p"); xy=$(echo "$pick" | cut -f1); title=$(echo "$pick" | cut -f2)
  adb shell input tap $xy; sleep 3; watch_ad "bhajan"
  dump; log "  reading: $title ($(ui texts | cut -c1-80))"; shot "bhajan"
  local k; for k in 1 2 3; do sleep $(( RANDOM % 15 + 10 )); adb shell input swipe 540 1600 540 900 600; done   # reading, scrolling down
  READ=$((READ + 1)); a_back
}
a_saint() {
  a_tab "ઘર" || return 1
  a_open "બધા જુઓ" "all saints" || return 1                      # the first "see all" is the saints
  local s=${SAINT_NAMES[$((RANDOM % ${#SAINT_NAMES[@]}))]}
  a_open "$s" "$s" || { a_back; return 1; }
  SAINTS=$((SAINTS + 1)); dump; log "saint: $s: $(ui texts | cut -c1-150)"; shot "saint"
  a_read_one; a_back; a_back
}
a_type() {
  a_tab "ઘર" || return 1
  local t=${TYPE_NAMES[$((RANDOM % ${#TYPE_NAMES[@]}))]}
  a_open "$t" "$t" || { dump; xy=$(ui allat "બધા જુઓ" | sed -n 2p) && adb shell input tap $xy && sleep 3 && a_open "$t" "$t"; } || return 1
  TYPES=$((TYPES + 1)); dump; log "type: $t: $(ui texts | cut -c1-150)"; shot "type"
  a_read_one; a_back
}
a_new() {   # the newly added bhajans on Home
  a_tab "ઘર" || return 1
  adb shell input swipe 540 1600 540 800 500; sleep 2
  dump; xy=$(ui allat "બધા જુઓ" | tail -1) && { adb shell input tap $xy; sleep 3; shot "new-bhajans"; a_read_one; a_back; }
}
a_tabs() {  # the other tabs and the menu, as a user looks around
  local t; for t in "સાખી" "AI" "રિફર" "નોટેશન"; do a_tab "$t" && { TABS=$((TABS + 1)); dump; log "tab $t: $(ui texts | cut -c1-150)"; shot "tab"; }; done
  a_tab "ઘર"; a_open "મેનુ" "menu" && { shot "menu"; a_open "પ્રોફાઇલ" "profile" && { shot "profile"; a_back; }; a_open "મેનુ" "menu"; a_open "વિશેષ વિડિયો" "special videos" && { shot "special-videos"; a_back; }; }
}
alakh_main() {
  log "## session: $MIN minutes of real use of $PKG (a devotee reading bhajans)"
  launch; wait_ad "app start" 12
  end=$(( $(date +%s) + MIN * 60 )); round=0
  while [ "$(date +%s)" -lt "$end" ]; do
    round=$((round + 1)); log "-- round $round"
    a_saint; a_type
    [ $((round % 2)) = 0 ] && a_new
    [ $((round % 3)) = 0 ] && a_tabs
    if [ $((round % 3)) = 0 ]; then reopen cold; else reopen warm; fi     # leave the app and come back (app open ads)
    pause 20 60
    log "so far: bhajans read $READ, saints opened $SAINTS, types opened $TYPES, tabs looked at $TABS, full-screen ads $ADS, banners $BANNERS, problems $PROBLEMS"
  done
  a_tab "ઘર"; shot "home-final"
  {
    echo "## session summary ($MIN minutes, $round rounds)"
    echo "bhajans read: $READ, saints opened: $SAINTS, bhajan types opened: $TYPES, tabs looked at: $TABS"
    echo "full-screen ads watched: $ADS (see ads.csv), banner ads seen: $BANNERS, app opened again: $REOPENS, problems: $PROBLEMS"
  } | tee -a "$NOTES" > "$OUT/summary.txt"
  ads_summary
}
if [ "$PKG" = com.mechodal.alakhjoli ]; then alakh_main; exit 0; fi

log "## session: $MIN minutes of real use of $PKG on its screens"
launch; wait_ad "app start" 12
dump; ui click "Confirm" >/dev/null && { tap "Live Mode" "Live Mode"; tap "Confirm" "Confirm"; }
add_wallet "Cash Wallet" 5000; add_wallet "HDFC Bank" 25000; add_wallet "Paytm Wallet" 1200
add_txn Income "Salary" "Salary" 30000
end=$(( $(date +%s) + MIN * 60 )); round=0; ie=0; ii=0
while [ "$(date +%s)" -lt "$end" ]; do
  round=$((round + 1)); log "-- round $round"
  e=${CATS_EXP[$((ie % ${#CATS_EXP[@]}))]}; ie=$((ie + 1))
  add_txn Expense "${e%%:*}" "$(echo "$e" | cut -d: -f2)" "${e##*:}"
  [ $((round % 3)) = 0 ] && { i=${CATS_INC[$((ii % ${#CATS_INC[@]}))]}; ii=$((ii + 1)); add_txn Income "${i%%:*}" "${i%%:*}" "${i##*:}"; }
  case $((round % 4)) in                       # one of the actions the app shows ads after
    1) edit_profile;; 2) wallet_cycle $round;; 3) budget_cycle $round;; 0) goal_cycle $round;;
  esac
  [ $((round % 2)) = 0 ] && edit_txn
  [ $((round % 5)) = 0 ] && delete_txn
  look_around
  if [ $((round % 3)) = 0 ]; then reopen cold; else reopen warm; fi     # leave the app and come back (app open ads)
  pause 20 60
  log "so far: added $ADDED, edited $EDITED, deleted $DELETED, profile $PROFILE, wallet/budget/goal cycles $WCYCLE/$BCYCLE/$GCYCLE, reopened $REOPENS, full-screen ads $ADS, banners $BANNERS, problems $PROBLEMS"
done
go Home; shot "home-final"; go Analytics; shot "analytics-final"; go Transaction; shot "transactions-final"
{
  echo "## session summary ($MIN minutes, $round rounds)"
  echo "entries added: $ADDED, edited: $EDITED, deleted: $DELETED, wallets added: $WALLETS, budgets added: $BUDGETS"
  echo "edit profile: $PROFILE, wallet / budget / saving goal made-edited-deleted: $WCYCLE / $BCYCLE / $GCYCLE, app opened again: $REOPENS"
  echo "full-screen ads watched: $ADS (see ads.csv), banner ads seen: $BANNERS, problems: $PROBLEMS"
} | tee -a "$NOTES" > "$OUT/summary.txt"
ads_summary
