#!/usr/bin/env bash
# Uses an app like a real person for <minutes>, on its real screens (taps and typing, nothing
# through its server or database): the owner asked for this (3 Nov) for the expense tracker.
# Adds expenses and income, edits and deletes entries, adds wallets and budgets, looks at
# Home, Analytics and Transactions. Every action is screenshotted (use-NNNN-*.png) and logged
# with the time in notes.txt; problems are logged as PROBLEM and the session goes on.
# Ads: every full-screen ad is watched until it ends or offers its close button, screenshotted
# and counted (ads.csv); banners are counted per screen. Ads are never tapped (only their close).
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

top() { timeout 15 adb shell dumpsys activity activities 2>/dev/null | grep -m1 mResumedActivity | grep -oE '[a-zA-Z0-9_.]+/[^ }]+'; }
# A full-screen ad on top: watch it to the end, screenshot, count, then its close button (never the ad).
watch_ad() {
  local where=$1 t0 t txt kind
  top | grep -q AdActivity || return 1
  t0=$(date +%s); ADS=$((ADS + 1)); sleep 2; dump
  txt=$(ui texts | cut -c1-160 | tr ',' ' ')
  kind="full-screen"; echo "$txt" | grep -qiE "reward" && kind="rewarded"
  echo "$txt" | grep -qiE "video|sec|seconds|skip in" && kind="$kind video"
  shot "ad-$ADS"
  for t in $(seq 1 30); do                          # up to ~60 s: wait for the end or a close button
    top | grep -q AdActivity || break
    dump
    if ui click "Close|Close ad|Skip|Skip ad|Skip video|Continue to app|X|×" >/dev/null && [ $(( $(date +%s) - t0 )) -ge 6 ]; then
      xy=$(ui click "Close|Close ad|Skip|Skip ad|Skip video|Continue to app|X|×"); adb shell input tap $xy; sleep 2; break
    fi
    sleep 2
  done
  top | grep -q AdActivity && { adb shell input keyevent KEYCODE_BACK; sleep 2; }
  echo "$(ts),$kind,$where,$(( $(date +%s) - t0 )),$txt" >> "$OUT/ads.csv"
  log "AD #$ADS ($kind) on \"$where\", watched $(( $(date +%s) - t0 )) s: $txt"
  return 0
}
banners() {   # ad views on the current screen (AdMob banners)
  dump; local b; b=$(grep -oE 'resource-id="[^"]*(adView|ad_view|banner|native_ad)[^"]*"|text="(Ad|Advertisement|Sponsored)"' "$OUT/ui.xml" | wc -l)
  [ "$b" -gt 0 ] && { BANNERS=$((BANNERS + b)); log "banner ad(s) on \"$1\": $b"; }
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
pick() {  # pick <dropdown regex> <item regex>
  tap "$1" "$1" >/dev/null || return 1
  tap "$2" "$2" >/dev/null && return 0
  adb shell input swipe 540 1600 540 800 400; sleep 1
  tap "$2" "$2" >/dev/null
}

CATS_EXP=("Food & Dining:Tea and snacks:40" "Food & Dining:Lunch with team:320" "Travel & Transport:Petrol:500" "Travel & Transport:Auto rickshaw:80"
          "Shopping:Groceries:1250" "Bills & Utilities:Electricity bill:1840" "Bills & Utilities:Mobile recharge:299" "Health:Medicines:460"
          "Entertainment:Movie tickets:600" "Education:Books:750" "Clothing:T-shirt:899" "Phone:Earphones:1299" "Social:Gift for friend:1000")
CATS_INC=("Salary:30000" "Freelance project:8500" "Interest:420" "Cashback:150")

add_txn() {   # add_txn Expense|Income <category> <note> <amount>
  local type=$1 cat=$2 note=$3 amt=$4
  go Home
  ensure_app "add"; dump
  xy=$(ui click "\\+|Add Transaction") || xy="540 1980"
  adb shell input tap $xy; sleep 3
  tap "$type|Add $type" "$type" >/dev/null || { problem "no $type choice after +"; adb shell input keyevent KEYCODE_BACK; return 1; }
  if [ "$type" = Expense ]; then
    pick "Select Category" "$cat" || { problem "category $cat not found"; }
  else
    pick "Select Category|Select Source|Category" "$cat|Salary|Other|Income" || true
  fi
  fill "Amount.*" "$amt" "amount" || { problem "no amount field"; adb shell input keyevent KEYCODE_BACK; return 1; }
  pick "Select Wallet" "Cash Wallet|HDFC Bank|.*Wallet.*" || problem "no wallet to pick"
  fill "Note.*" "$note" "note" || true
  shot "add-$type-filled"
  tap "Save" "Save" >/dev/null
  sleep 3; dump
  if ui texts | grep -qE "Please select|is required|Please enter"; then
    problem "$type not saved: $(ui texts | grep -oE 'Please [a-z ]+\.?|[A-Za-z ]+ is required' | head -2 | tr '\n' ' ')"
    adb shell input keyevent KEYCODE_BACK; sleep 2; return 1
  fi
  ADDED=$((ADDED + 1)); log "added $type: $cat, $note, $amt"; shot "after-add-$type"
  watch_ad "after saving"
}
open_first_txn() {
  go Transaction; dump
  xy=$(ui targets | grep -vE "Home|Wallet|Analytics|Transaction|Filter|Search|\\[EditText\\]" | grep -E "₹|\\$|[0-9]" | head -1 | cut -f1)
  [ -n "$xy" ] || { log "no entry to open"; return 1; }
  adb shell input tap $xy; sleep 3; shot "entry-opened"; dump
  log "opened an entry: $(ui texts | cut -c1-200)"
}
edit_txn() {
  open_first_txn || return 1
  tap "Edit|Edit Transaction|Update" "Edit" >/dev/null || { dump; xy=$(ui targets | grep -iE "edit" | head -1 | cut -f1); [ -n "$xy" ] && adb shell input tap $xy && sleep 3; }
  dump; ui fieldbelow "Amount.*" >/dev/null || { problem "no Edit on the entry screen"; adb shell input keyevent KEYCODE_BACK; return 1; }
  xy=$(ui fieldbelow "Amount.*"); adb shell input tap $xy; sleep 1
  adb shell input keyevent KEYCODE_MOVE_END; for _ in $(seq 1 8); do adb shell input keyevent KEYCODE_DEL; done
  new=$(( (RANDOM % 90 + 10) * 10 )); adb shell input text "$new"; adb shell input keyevent KEYCODE_BACK; sleep 1
  shot "edit-filled"
  tap "Save|Update|Save Changes" "Save" >/dev/null && { EDITED=$((EDITED + 1)); log "edited an entry: amount now $new"; shot "after-edit"; }
}
delete_txn() {
  open_first_txn || return 1
  dump; xy=$(python3 -I "$HERE/ui_nodes.py" "$OUT/ui.xml" click "Delete|Delete Transaction|Remove" 2>/dev/null) || \
    xy=$(grep -oE 'content-desc="[^"]*([Dd]elete|[Tt]rash)[^"]*"[^>]*bounds="[^"]*"' "$OUT/ui.xml" | head -1 | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]' | tr -d '[]' | tr ',' ' ' | awk '{print int(($1+$3)/2), int(($2+$4)/2)}')
  [ -n "$xy" ] || { problem "no Delete on the entry screen"; adb shell input keyevent KEYCODE_BACK; return 1; }
  adb shell input tap $xy; sleep 2; shot "delete-ask"
  tap "Delete|Yes|Confirm|OK" "confirm delete" >/dev/null && { DELETED=$((DELETED + 1)); log "deleted an entry"; shot "after-delete"; }
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
  tap "Add Budget" "Add Budget" >/dev/null || return 1
  fill "Budget Name.*" "$1" "budget name"; fill "Budget Amount.*" "$2" "budget amount"
  if tap "Select Wallet|Wallet" "wallets" >/dev/null; then tap "Select All|Cash Wallet" "wallets" >/dev/null; tap "Done" "Done" >/dev/null; fi
  pick "Select Category" "$3" >/dev/null
  shot "budget-filled"
  adb shell input swipe 540 1600 540 600 400; sleep 1
  tap "Create Budget|Save Budget|Save|Add Budget|Create" "save budget" >/dev/null && { BUDGETS=$((BUDGETS + 1)); log "added budget $1 ($2, $3)"; shot "after-budget"; return 0; }
  problem "budget $1 not saved"; adb shell input keyevent KEYCODE_BACK
}
look_around() {
  go Home; shot "home"
  go Analytics; shot "analytics"; tap "Income" "Income tab" >/dev/null && shot "analytics-income"; tap "Expenses" "Expenses tab" >/dev/null
  go Transaction; shot "transactions"
  go Wallet; shot "wallets"
}

log "## session: $MIN minutes of real use of $PKG on its screens"
launch; skip_ad
dump; ui click "Confirm" >/dev/null && { tap "Live Mode" "Live Mode"; tap "Confirm" "Confirm"; }
add_wallet "Cash Wallet" 5000; add_wallet "HDFC Bank" 25000; add_wallet "Paytm Wallet" 1200
add_txn Income "Salary" "Salary" 30000
end=$(( $(date +%s) + MIN * 60 )); round=0; ie=0; ii=0
while [ "$(date +%s)" -lt "$end" ]; do
  round=$((round + 1)); log "-- round $round"
  e=${CATS_EXP[$((ie % ${#CATS_EXP[@]}))]}; ie=$((ie + 1))
  add_txn Expense "${e%%:*}" "$(echo "$e" | cut -d: -f2)" "${e##*:}"
  e=${CATS_EXP[$((ie % ${#CATS_EXP[@]}))]}; ie=$((ie + 1))
  add_txn Expense "${e%%:*}" "$(echo "$e" | cut -d: -f2)" "${e##*:}"
  [ $((round % 3)) = 0 ] && { i=${CATS_INC[$((ii % ${#CATS_INC[@]}))]}; ii=$((ii + 1)); add_txn Income "${i%%:*}" "${i%%:*}" "${i##*:}"; }
  [ $((round % 2)) = 0 ] && edit_txn
  [ $((round % 4)) = 0 ] && delete_txn
  [ $round = 3 ] && add_budget "Monthly Food" 3000 "Food & Dining"
  [ $round = 6 ] && add_budget "Travel" 2000 "Travel & Transport"
  [ $round = 8 ] && add_wallet "Savings Account" 50000
  look_around
  log "so far: added $ADDED, edited $EDITED, deleted $DELETED, wallets $WALLETS, budgets $BUDGETS, full-screen ads $ADS, banners $BANNERS, problems $PROBLEMS"
done
go Home; shot "home-final"; go Analytics; shot "analytics-final"; go Transaction; shot "transactions-final"
{
  echo "## session summary ($MIN minutes, $round rounds)"
  echo "entries added: $ADDED, edited: $EDITED, deleted: $DELETED, wallets added: $WALLETS, budgets added: $BUDGETS"
  echo "full-screen ads watched: $ADS (see ads.csv), banner ads seen: $BANNERS, problems: $PROBLEMS"
} | tee -a "$NOTES" > "$OUT/summary.txt"
