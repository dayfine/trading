#!/bin/sh
# Fails when an EODHD bar fixture is tracked in git again (#3676).
#
# `trading/test_data/<A-Z>/**/data.csv`, `data.metadata.sexp` and
# `trading/test_data/split_corpus/<case>/bars.csv` live in the
# private dayfine/trading-results repo (EODHD terms: no redistribution) and are
# fetched by dev/scripts/fetch_test_bars.sh. Reads live git state via repo_root(),
# so the dune rule needs (universe).
#
# Output: OK line, or FAIL listing offenders (exit 1).

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"

# safe.directory: CI runs git as a user that does not own the checkout; without it
# git errors out, and a swallowed error would read as "no offenders" (QC #3701).
LS=$(git -C "$REPO_ROOT" -c safe.directory="$REPO_ROOT" ls-files -- 'trading/test_data/*/data.csv' 'trading/test_data/*/data.metadata.sexp' 'trading/test_data/split_corpus/*/bars.csv' 2>&1) && GIT_CODE=0 || GIT_CODE=$?
if [ "$GIT_CODE" -ne 0 ]; then
  echo "FAIL: no-tracked-bars check -- git ls-files failed (rc=$GIT_CODE): $LS"
  exit 1
fi
FOUND=$(printf '%s\n' "$LS" | grep -E '^trading/test_data/([A-Z]/.*/data(\.metadata\.sexp|\.csv)|split_corpus/[^/]+/bars\.csv)$' || true)

if [ -n "$FOUND" ]; then
  echo "FAIL: no-tracked-bars check -- EODHD bar fixtures are tracked:"
  echo "$FOUND" | head -20 | sed 's/^/  /'
  echo "Fix: git rm them; they live in dayfine/trading-results (dev/scripts/fetch_test_bars.sh)."
  exit 1
fi
echo "OK: no-tracked-bars check -- no trading/test_data bar fixtures tracked."
