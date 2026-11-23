#!/bin/sh
# fetch_test_bars_test.sh -- pins dev/scripts/fetch_test_bars.sh (#3701).
#
# Hermetic: a copy of the script runs in a temp tree against a throwaway git
# repo standing in for dayfine/trading-results. No network. Cases:
#   1. local checkout (TRADING_RESULTS_DIR) at the pin: extracts bars + marker
#   2. rerun: no-op ("already at")
#   3. stale marker: re-extracts
#   4. no source, no token: exit 1 with the clone message
#   5. checkout lacking the pin: WARN, bars copied, marker NOT claiming the pin;
#      after the pin appears, a plain rerun extracts it and writes the marker

set -u
. "$(dirname "$0")/_check_lib.sh"
SCRIPT="$(repo_root)/dev/scripts/fetch_test_bars.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fails=$((fails + 1)); }

# Fake trading-results with one bar file.
SRC="$T/results"
mkdir -p "$SRC/trading/test_data/A/L/AAPL" "$T/home"
echo 'date,close
2020-01-01,1' >"$SRC/trading/test_data/A/L/AAPL/data.csv"
git init -q "$SRC"
git -C "$SRC" add -A
git -C "$SRC" -c user.name=t -c user.email=t@t commit -q -m bars
PIN=$(git -C "$SRC" rev-parse HEAD)

# Fake repo tree holding a copy of the script and a pin file.
mk_tree() { # $1 = dir, $2 = pin
  mkdir -p "$1/dev/scripts" "$1/trading/test_data"
  cp "$SCRIPT" "$1/dev/scripts/fetch_test_bars.sh"
  echo "$2" >"$1/dev/test_bars.pin"
}
run() { # $1 = tree; remaining env passed through
  tree=$1; shift
  env -u TRADING_RESULTS_DIR -u TRADING_RESULTS_TOKEN HOME="$T/home" "$@" \
    sh "$tree/dev/scripts/fetch_test_bars.sh" 2>&1
}

W="$T/w1"; mk_tree "$W" "$PIN"
out=$(run "$W" TRADING_RESULTS_DIR="$SRC"); rc=$?
{ [ $rc -eq 0 ] && [ -f "$W/trading/test_data/A/L/AAPL/data.csv" ] && [ "$(cat "$W/trading/test_data/.bars-pin")" = "$PIN" ]; } &&
  ok "local extraction + marker" || bad "local extraction: rc=$rc $out"

out=$(run "$W" TRADING_RESULTS_DIR="$SRC"); rc=$?
{ [ $rc -eq 0 ] && echo "$out" | grep -q 'already at'; } && ok "rerun is a no-op" || bad "rerun: rc=$rc $out"

echo 0000000000000000000000000000000000000000 >"$W/trading/test_data/.bars-pin"
rm "$W/trading/test_data/A/L/AAPL/data.csv"
out=$(run "$W" TRADING_RESULTS_DIR="$SRC"); rc=$?
{ [ $rc -eq 0 ] && [ -f "$W/trading/test_data/A/L/AAPL/data.csv" ] && [ "$(cat "$W/trading/test_data/.bars-pin")" = "$PIN" ]; } &&
  ok "stale marker re-extracts" || bad "stale marker: rc=$rc $out"

W2="$T/w2"; mk_tree "$W2" "$PIN"
out=$(run "$W2"); rc=$?
{ [ $rc -eq 1 ] && echo "$out" | grep -q 'no bar source'; } && ok "no source exits 1 with message" || bad "no source: rc=$rc $out"

# Checkout lacking the pin: a different pin that the fake checkout does not have.
MISSING=1111111111111111111111111111111111111111
W3="$T/w3"; mk_tree "$W3" "$MISSING"
out=$(run "$W3" TRADING_RESULTS_DIR="$SRC"); rc=$?
{ [ $rc -eq 0 ] && echo "$out" | grep -q 'WARN' && [ -f "$W3/trading/test_data/A/L/AAPL/data.csv" ]; } &&
  ok "fallback warns and copies working tree" || bad "fallback: rc=$rc $out"
{ [ ! -f "$W3/trading/test_data/.bars-pin" ] || [ "$(cat "$W3/trading/test_data/.bars-pin")" != "$MISSING" ]; } &&
  ok "fallback does not mark the pin" || bad "fallback wrote the pin marker"

# Pin now present: plain rerun (no --force) must extract and mark.
echo "$PIN" >"$W3/dev/test_bars.pin"
out=$(run "$W3" TRADING_RESULTS_DIR="$SRC"); rc=$?
{ [ $rc -eq 0 ] && ! echo "$out" | grep -q 'already at' && [ "$(cat "$W3/trading/test_data/.bars-pin")" = "$PIN" ]; } &&
  ok "rerun after pin appears marks it" || bad "post-pin rerun: rc=$rc $out"

[ "$fails" -eq 0 ] || { echo "FAIL: fetch_test_bars_test: $fails case(s)"; exit 1; }
echo "OK: fetch_test_bars_test"
