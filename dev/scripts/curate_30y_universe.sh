#!/usr/bin/env bash
# curate_30y_universe.sh — emit a 1,000-symbol sector-classified universe with
# >=30y of bar history, suitable for a long-horizon capacity backtest.
#
# Selection logic (deterministic):
#   1. Read every data/<L>/<L>/<SYM>/data.metadata.sexp; extract symbol +
#      data_start_date.
#   2. Filter to start_date <= 1996-01-01 (the cutoff for "covers the full
#      30y window 1996-2026").
#   3. Intersect with data/sectors.csv to ensure each symbol carries a GICS
#      sector classification (the runner needs sectors for sector ETFs +
#      sector concentration limits to operate).
#   4. Prefer the S&P 500 cohort first (305 symbols with >=30y data, all
#      sector-classified), then alphabetic backfill from the broader
#      sector-classified pool until 1,000 symbols are picked.
#
# Output: writes a (Pinned ((symbol X) (sector S)) ...) sexp to the path
# given as $1, or to stdout if no argument is given.
#
# Caveat: this is a CAPACITY-VALIDATION universe, not a strategy-validation
# universe. The selection is intrinsically survivorship-biased (every chosen
# symbol survived from <=1996 through 2026) — see
# dev/notes/historical-universe-membership-2026-04-30.md for details and
# dev/notes/n1000-30y-capacity-2026-04-30.md for the run output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
DATA_DIR="${TRADING_DATA_DIR:-${REPO_ROOT}/data}"
SP500_SEXP="${SP500_SEXP:-${REPO_ROOT}/trading/test_data/backtest_scenarios/universes/sp500.sexp}"
CUTOFF="${CUTOFF:-1996-01-01}"
TARGET_SIZE="${TARGET_SIZE:-1000}"
OUT="${1:-/dev/stdout}"

if [[ ! -d "${DATA_DIR}" ]]; then
  echo "ERROR: data dir not found: ${DATA_DIR}" >&2
  exit 1
fi
if [[ ! -f "${DATA_DIR}/sectors.csv" ]]; then
  echo "ERROR: sectors.csv not found at ${DATA_DIR}/sectors.csv" >&2
  exit 1
fi
if [[ ! -f "${SP500_SEXP}" ]]; then
  echo "ERROR: sp500 universe sexp not found: ${SP500_SEXP}" >&2
  exit 1
fi

TMPDIR_LOCAL="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_LOCAL}"' EXIT

# ---------------------------------------------------------------------------
# 1. Extract (symbol, start_date) pairs from every metadata sexp.
# ---------------------------------------------------------------------------
find "${DATA_DIR}" -name 'data.metadata.sexp' -print0 | xargs -0 awk '
FILENAME != prev_file {
  if (prev_file != "" && sym != "" && start != "") print sym "\t" start
  prev_file = FILENAME; sym=""; start=""
}
/^\(\(symbol / { gsub(/[() ]/, "", $0); sub(/^symbol/, "", $0); sym=$0 }
/data_start_date/ { gsub(/[() ]/, "", $0); sub(/^data_start_date/, "", $0); start=$0 }
END { if (sym != "" && start != "") print sym "\t" start }
' | sort -k1,1 > "${TMPDIR_LOCAL}/symbol_starts.tsv"

# ---------------------------------------------------------------------------
# 2. Filter to start_date <= cutoff.
# ---------------------------------------------------------------------------
awk -F'\t' -v cutoff="${CUTOFF}" '$2 <= cutoff { print $1 }' \
  "${TMPDIR_LOCAL}/symbol_starts.tsv" | sort -u > "${TMPDIR_LOCAL}/all_30y.txt"

# ---------------------------------------------------------------------------
# 3. Intersect with sectors.csv (sector lookup).
# ---------------------------------------------------------------------------
tail -n +2 "${DATA_DIR}/sectors.csv" | sort -t',' -k1,1 -u \
  > "${TMPDIR_LOCAL}/sectors.csv"
awk -F',' '{ print $1 }' "${TMPDIR_LOCAL}/sectors.csv" \
  > "${TMPDIR_LOCAL}/sectors_symbols.txt"
comm -12 "${TMPDIR_LOCAL}/sectors_symbols.txt" "${TMPDIR_LOCAL}/all_30y.txt" \
  > "${TMPDIR_LOCAL}/sectors_30y.txt"

# ---------------------------------------------------------------------------
# 4. Build the SP500 cohort: every sp500.sexp symbol that's in sectors_30y.
# ---------------------------------------------------------------------------
grep '(symbol' "${SP500_SEXP}" | sed 's/.*symbol *//; s/).*//; s/ //g' \
  | sort -u > "${TMPDIR_LOCAL}/sp500.txt"
comm -12 "${TMPDIR_LOCAL}/sp500.txt" "${TMPDIR_LOCAL}/sectors_30y.txt" \
  > "${TMPDIR_LOCAL}/sp500_30y.txt"

# Backfill from non-SP500 sector-classified-30y, alphabetically.
comm -23 "${TMPDIR_LOCAL}/sectors_30y.txt" "${TMPDIR_LOCAL}/sp500_30y.txt" \
  > "${TMPDIR_LOCAL}/backfill_pool.txt"

sp500_count=$(wc -l < "${TMPDIR_LOCAL}/sp500_30y.txt")
backfill_needed=$(( TARGET_SIZE - sp500_count ))
if (( backfill_needed < 0 )); then
  backfill_needed=0
fi

backfill_pool_size=$(wc -l < "${TMPDIR_LOCAL}/backfill_pool.txt")
if (( backfill_needed > backfill_pool_size )); then
  echo "ERROR: insufficient backfill pool (have ${backfill_pool_size}, need ${backfill_needed})" >&2
  exit 1
fi

head -n "${backfill_needed}" "${TMPDIR_LOCAL}/backfill_pool.txt" \
  > "${TMPDIR_LOCAL}/backfill.txt"

cat "${TMPDIR_LOCAL}/sp500_30y.txt" "${TMPDIR_LOCAL}/backfill.txt" \
  | sort -u > "${TMPDIR_LOCAL}/universe.txt"

universe_size=$(wc -l < "${TMPDIR_LOCAL}/universe.txt")
if (( universe_size != TARGET_SIZE )); then
  echo "ERROR: post-dedup size ${universe_size} != target ${TARGET_SIZE}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 5. Emit Pinned sexp with (symbol, sector) joined from sectors.csv.
# ---------------------------------------------------------------------------
universe_size_trim=$(printf '%d' "${universe_size}")
sp500_count_trim=$(printf '%d' "${sp500_count}")
{
  echo ";; Generated by dev/scripts/curate_30y_universe.sh."
  echo ";; ${universe_size_trim} symbols, all with data_start_date <= ${CUTOFF}"
  echo ";; and sector classifications from data/sectors.csv."
  echo ";;"
  echo ";; Composition: SP500 cohort (${sp500_count_trim} symbols) + alphabetic"
  echo ";; backfill (${backfill_needed} symbols) from non-SP500 sector-30y."
  echo ";;"
  echo ";; SURVIVORSHIP BIAS WARNING: every symbol here is a 30y+ survivor."
  echo ";; Use this universe for CAPACITY VALIDATION only — strategy"
  echo ";; metrics over a 30y horizon will overstate live-tradeable returns."
  echo ";; See dev/notes/historical-universe-membership-2026-04-30.md."
  echo "(Pinned ("
  join -t',' -1 1 -2 1 \
    "${TMPDIR_LOCAL}/universe.txt" "${TMPDIR_LOCAL}/sectors.csv" \
    | awk -F',' '{ printf "  ((symbol %-7s) (sector %s))\n", $1, "\"" $2 "\"" }'
  echo "))"
} > "${OUT}"

echo "Wrote ${universe_size} symbols to ${OUT}" >&2
