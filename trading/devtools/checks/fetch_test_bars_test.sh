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
#   6. test-bars.md5 with a wrong sum at the pin: exit 1 naming the file, no marker
#   7. pin with no test-bars.md5: exit 1, no marker

set -u
. "$(dirname "$0")/_check_lib.sh"
SCRIPT="$(repo_root)/dev/scripts/fetch_test_bars.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fails=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fails=$((fails + 1)); }

# Fake trading-results with one bar file. Three commits: no manifest
# (PIN_NOMAN), a manifest with a wrong md5 (PIN_BAD), then the good manifest
# (PIN, also the working tree).
SRC="$T/results"
SRC_TD="$SRC/trading/test_data"
mkdir -p "$SRC_TD/A/L/AAPL" "$T/home"
echo 'date,close
2020-01-01,1' >"$SRC_TD/A/L/AAPL/data.csv"
git init -q "$SRC"
commit_src() { git -C "$SRC" add -A && git -C "$SRC" -c user.name=t -c user.email=t@t commit -q -m "$1" && git -C "$SRC" rev-parse HEAD; }
PIN_NOMAN=$(commit_src bars)
echo '00000000000000000000000000000000  A/L/AAPL/data.csv' >"$SRC_TD/test-bars.md5"
PIN_BAD=$(commit_src bad-manifest)
(cd "$SRC_TD" && md5sum A/L/AAPL/data.csv >test-bars.md5)
PIN=$(commit_src manifest)

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
{ [ $rc -eq 0 ] && [ -f "$W/trading/test_data/A/L/AAPL/data.csv" ] && [ "$(cat "$W/trading/test_data/.bars-pin")" = "$PIN" ] &&
  echo "$out" | grep -q '1 files match test-bars.md5'; } &&
  ok "local extraction + md5 check + marker" || bad "local extraction: rc=$rc $out"

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

# md5 manifest: a wrong sum and a missing manifest both exit 1 and leave no marker.
W4="$T/w4"; mk_tree "$W4" "$PIN_BAD"
out=$(run "$W4" TRADING_RESULTS_DIR="$SRC"); rc=$?
{ [ $rc -eq 1 ] && echo "$out" | grep -q 'md5 mismatch: A/L/AAPL/data.csv' && [ ! -f "$W4/trading/test_data/.bars-pin" ]; } &&
  ok "md5 mismatch exits 1" || bad "md5 mismatch: rc=$rc $out"
W5="$T/w5"; mk_tree "$W5" "$PIN_NOMAN"
out=$(run "$W5" TRADING_RESULTS_DIR="$SRC"); rc=$?
{ [ $rc -eq 1 ] && echo "$out" | grep -q 'no test-bars.md5' && [ ! -f "$W5/trading/test_data/.bars-pin" ]; } &&
  ok "missing manifest at the pin exits 1" || bad "missing manifest: rc=$rc $out"

[ "$fails" -eq 0 ] || { echo "FAIL: fetch_test_bars_test: $fails case(s)"; exit 1; }
echo "OK: fetch_test_bars_test"
