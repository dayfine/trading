#!/bin/sh
# Populate trading/test_data/ with the EODHD bar fixtures (#3676).
#
# The 650 `trading/test_data/<A-Z>/**/data.csv` bar files (and their
# `data.metadata.sexp`) are not tracked in this public repo (EODHD terms: no
# redistribution). They live in the private repo dayfine/trading-results at the
# same paths, pinned by the commit named in dev/test_bars.pin. Tests, goldens
# and perf scripts read them from trading/test_data/ (TRADING_DATA_DIR), so run
# this once per checkout before `dune runtest` or any backtest.
#
# Source, first match wins:
#   1. $TRADING_RESULTS_DIR            an existing trading-results checkout
#   2. $HOME/Projects/trading-results  the usual local sibling checkout
#   3. network: git fetch of the pinned commit using $TRADING_RESULTS_TOKEN
#      (CI passes the BOT_GITHUB_TOKEN secret here; fork PRs get no secrets)
# Sources 1-2 extract the pinned commit with `git archive` when it is present in
# that checkout (git -C <dir> pull to get it), else copy its working tree and
# warn. Pin bumps: edit dev/test_bars.pin to the new trading-results commit.
#
# Usage: sh dev/scripts/fetch_test_bars.sh [--force]
#   Idempotent: skipped when trading/test_data/.bars-pin already names the pin.
# Exit: 0 populated; 1 no usable source (message says what to do).

set -eu

HERE=$(cd "$(dirname "$0")/../.." && pwd)
DEST="$HERE/trading/test_data"
MARK="$DEST/.bars-pin"
PIN=$(sed -n 's/^\([0-9a-f]\{40\}\)[[:space:]]*$/\1/p' "$HERE/dev/test_bars.pin" | head -n 1)
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

die() { echo "FAIL: fetch_test_bars: $*" >&2; exit 1; }

[ -n "$PIN" ] || die "dev/test_bars.pin has no 40-hex commit"
if [ "$FORCE" = 0 ] && [ -f "$MARK" ] && [ "$(cat "$MARK")" = "$PIN" ]; then
  echo "fetch_test_bars: bars already at $PIN"
  exit 0
fi

SRC="${TRADING_RESULTS_DIR:-}"
[ -z "$SRC" ] && [ -d "$HOME/Projects/trading-results/.git" ] && SRC="$HOME/Projects/trading-results"

if [ -n "$SRC" ]; then
  echo "fetch_test_bars: using local checkout $SRC"
  if git -C "$SRC" cat-file -e "$PIN^{commit}" 2>/dev/null; then
    git -C "$SRC" archive "$PIN" trading/test_data | tar -x -C "$HERE"
  else
    echo "WARN: pin $PIN not in $SRC (run: git -C $SRC pull); copying its working tree" >&2
    [ -d "$SRC/trading/test_data" ] || die "$SRC has no trading/test_data"
    (cd "$SRC" && tar -c trading/test_data) | tar -x -C "$HERE"
  fi
else
  [ -n "${TRADING_RESULTS_TOKEN:-}" ] || die "no bar source. The EODHD bar fixtures are private (dayfine/trading-results).
  Local: git clone git@github.com:dayfine/trading-results.git ~/Projects/trading-results, then rerun.
  CI: the BOT_GITHUB_TOKEN secret is empty. Fork PRs get no secrets, so their tests cannot run
  here: push the branch to dayfine/trading instead."
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  AUTH=$(printf 'x-access-token:%s' "$TRADING_RESULTS_TOKEN" | base64 | tr -d '[:space:]')  # GNU base64 wraps at 76 columns
  git init -q "$TMP/r"
  git -C "$TMP/r" -c "http.extraheader=Authorization: Basic $AUTH" \
    fetch -q --depth 1 https://github.com/dayfine/trading-results.git "$PIN" ||
    die "cannot fetch trading-results@$PIN with the token (no read access to the private repo, or pin not pushed)"
  git -C "$TMP/r" archive FETCH_HEAD trading/test_data | tar -x -C "$HERE"
fi

n=$(find "$DEST" -name data.csv | wc -l | tr -d ' ')
[ "$n" -gt 0 ] || die "extraction produced no data.csv under $DEST"
echo "$PIN" >"$MARK"
echo "fetch_test_bars: $n bar files in $DEST at $PIN"
