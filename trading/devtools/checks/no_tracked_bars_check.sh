#!/bin/sh
# Fails when an EODHD bar fixture is tracked in git again (#3676).
#
# `trading/test_data/<A-Z>/**/data.csv` and `data.metadata.sexp` live in the
# private dayfine/trading-results repo (EODHD terms: no redistribution) and are
# fetched by dev/scripts/fetch_test_bars.sh. Reads live git state via repo_root(),
# so the dune rule needs (universe).
#
# Output: OK line, or FAIL listing offenders (exit 1).

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"

FOUND=$(git -C "$REPO_ROOT" ls-files -- 'trading/test_data/*/data.csv' 'trading/test_data/*/data.metadata.sexp' |
  grep -E '^trading/test_data/[A-Z]/.*/data(\.metadata\.sexp|\.csv)$' || true)

if [ -n "$FOUND" ]; then
  echo "FAIL: no-tracked-bars check -- EODHD bar fixtures are tracked:"
  echo "$FOUND" | head -20 | sed 's/^/  /'
  echo "Fix: git rm them; they live in dayfine/trading-results (dev/scripts/fetch_test_bars.sh)."
  exit 1
fi
echo "OK: no-tracked-bars check -- no trading/test_data bar fixtures tracked."
