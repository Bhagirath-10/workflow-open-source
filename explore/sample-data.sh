#!/usr/bin/env bash
# Puts sample data into an app after explore/signup.sh made its test account, so explore.sh sees
# the screens that are empty without data (app exploration workflow; the owner asked for it, 3 Nov).
# Only made-up amounts on the test account; best effort: a step that cannot be done is noted and
# the next one is tried. Every step is screenshotted (data-NN-*.png).
#
#   sample-data.sh <package> <out-dir>
set -uo pipefail
PKG=$1; OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"; NOTES="$OUT/notes.txt"; N=0; TAG=data
. "$HERE/lib.sh"

# One screen's texts into the notes (to learn the forms the explorer cannot fill).
look() { dump; say "  data: screen \"$1\": $(ui texts | cut -c1-500)"; shot "$1"; }
home() { tap "Home" "Home" >/dev/null 2>&1 || { adb shell input keyevent KEYCODE_BACK; sleep 2; }; }

case "$PKG" in
  com.expensetracker.renine)
    say "## data: sample wallets, an expense, an income and a budget for the test account"
    launch; skip_ad
    dump; ui click "Confirm" >/dev/null && { tap "Live Mode" "Live Mode (cloud sync)"; tap "Confirm" "Confirm"; }
    # Two wallets
    for w in "Cash Wallet:5000" "HDFC Bank:25000"; do
      tap "Wallet" "Wallet tab" && tap "Add Wallet|Add New Wallet|\\+ Add Wallet" "Add Wallet" || continue
      fill "Wallet Name.*" "${w%%:*}" "wallet name" && fill "Initial [Bb]alance.*" "${w##*:}" "initial balance" &&
        tap "Create Wallet" "Create Wallet"
      look "wallet-${w%%:*}"
    done
    # An expense and an income through the big + button
    for t in "Expense:250:Tea and snacks" "Income:30000:Salary"; do
      home
      dump; xy=$(ui click "\\+|Add|Add Transaction") || xy="540 1980"     # the round + in the bottom bar
      say "  data: tap + ($xy)"; adb shell input tap $xy; sleep 3
      look "add-${t%%:*}-form"
      tap "${t%%:*}" "${t%%:*} type" >/dev/null 2>&1
      t2=${t#*:}
      fill "Amount.*|Enter [Aa]mount.*|₹.*" "${t2%%:*}" "amount" &&
      { fill "Note.*|Description.*|Title.*|Remark.*" "${t2#*:}" "note" || true; }
      dump; ui click "Select Wallet|Wallet" >/dev/null && { tap "Select Wallet|Wallet" "wallet choice"; tap "Cash Wallet" "Cash Wallet"; }
      dump; ui click "Select Category|Category" >/dev/null && { tap "Select Category|Category" "category choice"; dump; xy=$(ui targets | sed -n 2p | cut -f1); [ -n "$xy" ] && { say "  data: first category ($xy)"; adb shell input tap $xy; sleep 2; }; }
      look "add-${t%%:*}-filled"
      tap "Save|Add|Add Expense|Add Income|Add Transaction|Done|Submit" "save" && look "after-${t%%:*}"
    done
    # A monthly budget
    home
    if tap "Add Budget" "Add Budget"; then
      fill "Budget Name.*" "Monthly Food" "budget name" && fill "Budget Amount.*" "3000" "budget amount"
      tap "Select Wallet" "wallet choice" && tap "Cash Wallet" "Cash Wallet"
      tap "Select Category" "category choice" && { dump; xy=$(ui targets | sed -n 2p | cut -f1); [ -n "$xy" ] && adb shell input tap $xy; sleep 2; }
      look "budget-filled"
      tap "Create Budget|Save|Add Budget|Save Budget|Create" "save budget" && look "after-budget"
    fi
    home; look "home-with-data"
    say "data: done"
    ;;
  *) say "data: no sample data steps for $PKG";;
esac
