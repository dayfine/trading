#!/bin/sh
# Populate trading/test_data/ with the EODHD bar fixtures (#3676).
#
# The 650 `trading/test_data/<A-Z>/**/data.csv` bar files (and their
# `data.metadata.sexp`), and the 10 `trading/test_data/split_corpus/<case>/bars.csv`,
# are not tracked in this public repo (EODHD terms: no
# redistribution). They live in the private repo dayfine/trading-results at the
# same paths, pinned by the commit named in dev/test_bars.pin. Tests, goldens
# and perf scripts read them from trading/test_data/ (TRADING_DATA_DIR), so run
# this once per checkout before `dune runtest` or any backtest.
#
# Source, first match wins:
#   1. $TRADING_RESULTS_DIR            an existing trading-results checkout
#   2. $HOME/Projects/trading-results  the usual local sibling checkout
#   3. network: git fetch of the pinned commit using $TRADING_RESULTS_TOKEN
#      (CI passes the TRADING_RESULTS_READ_TOKEN secret here, falling back to
#      BOT_GITHUB_TOKEN while that read-only secret is unset; fork PRs get no secrets)
# Sources 1-2 extract the pinned commit with `git archive` when it is present in
# that checkout (git -C <dir> pull to get it), else copy its working tree and
# warn. The fallback leaves .bars-pin unset so
# the next run re-extracts once the pin is present. Pin bumps: edit dev/test_bars.pin to the new trading-results commit.
#
# After extraction, every file named in trading/test_data/test-bars.md5 (it ships
# with the bars; "<md5>  <path under trading/test_data>" lines) must match, else
# exit 1. Only the working-tree fallback tolerates a missing manifest (WARN).
#
# Usage: sh dev/scripts/fetch_test_bars.sh [--force]
#   Idempotent: skipped when trading/test_data/.bars-pin already names the pin.
# Exit: 0 populated; 1 no usable source, or a bar fails its md5 (message says what to do).

set -eu

HERE=$(cd "$(dirname "$0")/../.." && pwd)
DEST="$HERE/trading/test_data"
MARK="$DEST/.bars-pin"
PINNED=1   # 0 when the working-tree fallback copied unpinned content
PIN=$(sed -n 's/^\([0-9a-f]\{40\}\)[[:space:]]*$/\1/p' "$HERE/dev/test_bars.pin" | head -n 1)
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

die() { echo "FAIL: fetch_test_bars: $*" >&2; exit 1; }

# md5 of file $1: md5sum (GNU, recent macOS) or BSD md5.
md5_of() {
  if command -v md5sum >/dev/null 2>&1; then md5sum "$1" | cut -d' ' -f1; else md5 -q "$1"; fi
}

# Check every "<md5>  <path>" line of manifest $1 against the file under $DEST.
verify_md5() {
  bad=0
  while read -r sum path; do
    [ -n "$sum" ] || continue
    if [ ! -f "$DEST/$path" ]; then
      echo "  missing: $path" >&2; bad=$((bad + 1))
    elif [ "$(md5_of "$DEST/$path")" != "$sum" ]; then
      echo "  md5 mismatch: $path" >&2; bad=$((bad + 1))
    fi
  done <"$1"
  [ "$bad" -eq 0 ] || die "$bad bar file(s) do not match $1"
  echo "fetch_test_bars: $(wc -l <"$1" | tr -d ' ') files match test-bars.md5"
}

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
    PINNED=0
    [ -d "$SRC/trading/test_data" ] || die "$SRC has no trading/test_data"
    (cd "$SRC" && tar -c trading/test_data) | tar -x -C "$HERE"
  fi
else
  [ -n "${TRADING_RESULTS_TOKEN:-}" ] || die "no bar source. The EODHD bar fixtures are private (dayfine/trading-results).
  Local: git clone git@github.com:dayfine/trading-results.git ~/Projects/trading-results, then rerun.
  CI: TRADING_RESULTS_TOKEN is empty (TRADING_RESULTS_READ_TOKEN and BOT_GITHUB_TOKEN unset). Fork PRs get no secrets, so their tests cannot run
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

SUMS="$DEST/test-bars.md5"
if [ -f "$SUMS" ]; then
  verify_md5 "$SUMS"
elif [ "$PINNED" = 1 ]; then
  die "no test-bars.md5 in trading-results@$PIN (pin predates the manifest?)"
else
  echo "WARN: no test-bars.md5 in $SRC; bars not verified" >&2
fi

n=$(find "$DEST" -name data.csv | wc -l | tr -d ' ')
[ "$n" -gt 0 ] || die "extraction produced no data.csv under $DEST"
if [ "$PINNED" = 1 ]; then echo "$PIN" >"$MARK"; else rm -f "$MARK"; fi
echo "fetch_test_bars: $n bar files in $DEST at $PIN"
