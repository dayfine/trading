#!/bin/sh
# Prepare trimmed bar data for CI golden runs.
#
# Reads the SP500 universe from trading/test_data/backtest_scenarios/universes/sp500.sexp,
# finds each symbol's full OHLCV CSV under /data/ (or TRADING_DATA_DIR), filters to
# rows with date >= CUTOFF_DATE, and writes to trading/test_data/<first>/<last>/<symbol>/.
#
# The resulting files mirror the production /data/ layout so TRADING_DATA_DIR can point
# at trading/test_data/ in CI and the scenario_runner picks them up normally.
#
# Usage:
#   dev/scripts/prepare_ci_data.sh [--universe <path>] [--cutoff <YYYY-MM-DD>] [--dry-run]
#
# Defaults:
#   --universe  trading/test_data/backtest_scenarios/universes/sp500.sexp
#   --cutoff    2009-01-01   (covers 5y + 15y scenarios with 30-week MA lookback)
#   --dry-run   false
#
# Source data dir:
#   Reads from DATA_DIR (env var); falls back to /workspaces/trading-1/data (dev container).
#
# Output:
#   trading/test_data/<first>/<last>/<symbol>/data.csv        (date-filtered rows)
#   trading/test_data/<first>/<last>/<symbol>/data.metadata.sexp  (copied as-is)
#   dev/notes/prepare-ci-data-<date>.log
#
# Idempotent: existing output files are overwritten. Run again after EODHD refresh.
#
# Designed to run locally (not in GHA). After running, commit the output files.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---- defaults ----
UNIVERSE_PATH="${REPO_ROOT}/trading/test_data/backtest_scenarios/universes/sp500.sexp"
CUTOFF_DATE="2009-01-01"
DRY_RUN=0
DATA_DIR="${DATA_DIR:-${TRADING_DATA_DIR:-/workspaces/trading-1/data}}"
OUTPUT_DIR="${REPO_ROOT}/trading/test_data"

# ---- arg parsing ----
while [ "$#" -gt 0 ]; do
  case "$1" in
    --universe) UNIVERSE_PATH="$2"; shift 2 ;;
    --cutoff)   CUTOFF_DATE="$2";   shift 2 ;;
    --dry-run)  DRY_RUN=1;           shift   ;;
    --data-dir) DATA_DIR="$2";       shift 2 ;;
    --output)   OUTPUT_DIR="$2";     shift 2 ;;
    *) printf 'Unknown arg: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# ---- validate ----
if [ ! -f "$UNIVERSE_PATH" ]; then
  printf 'FAIL: universe file not found: %s\n' "$UNIVERSE_PATH" >&2
  exit 1
fi
if [ ! -d "$DATA_DIR" ]; then
  printf 'FAIL: DATA_DIR not found: %s\n' "$DATA_DIR" >&2
  printf 'Set DATA_DIR or TRADING_DATA_DIR to the directory containing bar CSVs.\n' >&2
  exit 1
fi

printf 'prepare_ci_data.sh\n'
printf '  Universe  : %s\n' "$UNIVERSE_PATH"
printf '  Cutoff    : %s\n' "$CUTOFF_DATE"
printf '  Data dir  : %s\n' "$DATA_DIR"
printf '  Output dir: %s\n' "$OUTPUT_DIR"
printf '  Dry run   : %s\n\n' "$DRY_RUN"

# ---- extract symbols from universe sexp ----
# Sexp format: (Pinned ( ((symbol AAPL) (sector "...")) ... ))
# grep for 'symbol XXXX' and strip the prefix.
SYMBOLS="$(grep -o 'symbol [A-Z0-9-]*' "$UNIVERSE_PATH" | sed 's/symbol //')"
TOTAL="$(printf '%s\n' "$SYMBOLS" | grep -c .)"
printf 'Universe: %d symbols\n\n' "$TOTAL"

FOUND=0
MISSING=0
WRITTEN=0
SKIPPED_EMPTY=0

for sym in $SYMBOLS; do
  first="${sym%${sym#?}}"  # first char: ${sym:0:1} in bash; posix: remove all but first
  last="${sym#"${sym%?}"}" # last char:  ${sym: -1}  in bash; posix: remove all but last

  src_dir="${DATA_DIR}/${first}/${last}/${sym}"
  src_csv="${src_dir}/data.csv"
  src_meta="${src_dir}/data.metadata.sexp"
  dst_dir="${OUTPUT_DIR}/${first}/${last}/${sym}"
  dst_csv="${dst_dir}/data.csv"
  dst_meta="${dst_dir}/data.metadata.sexp"

  if [ ! -f "$src_csv" ]; then
    printf 'MISSING: %s (no data.csv at %s)\n' "$sym" "$src_csv"
    MISSING=$((MISSING + 1))
    continue
  fi

  FOUND=$((FOUND + 1))

  # Filter rows: keep header + rows where date >= CUTOFF_DATE.
  # The CSV header is "date,open,high,low,close,adjusted_close,volume".
  # We rely on lexicographic ordering of ISO dates (YYYY-MM-DD).
  HEADER="$(head -1 "$src_csv")"
  FILTERED_LINES="$(grep -c "^${CUTOFF_DATE%????}\|^2[0-9]\{3\}-" "$src_csv" 2>/dev/null || true)"

  # Actually filter: keep header + rows where date field >= CUTOFF_DATE.
  # Use awk-free approach: grep for date patterns >= cutoff.
  # Strategy: extract cutoff year; keep all rows from that year onward by year prefix,
  # then discard rows from cutoff year that fall before cutoff month-day.
  CUTOFF_YEAR="${CUTOFF_DATE%%-*}"  # e.g. "2009"
  CUTOFF_MMDD="${CUTOFF_DATE#*-}"   # e.g. "01-01"

  if [ "$DRY_RUN" = "1" ]; then
    printf 'DRY-RUN: would write %s -> %s (cutoff %s)\n' "$sym" "$dst_csv" "$CUTOFF_DATE"
    WRITTEN=$((WRITTEN + 1))
    continue
  fi

  mkdir -p "$dst_dir"

  # Write header + filtered rows.
  # Filter: keep rows where the date field (first field, no quotes) >= CUTOFF_DATE.
  # Shell-portable approach: use grep with year ranges + a final sed pass for the
  # boundary year. Since data is sorted ascending, we:
  # 1. Skip all rows where year < CUTOFF_YEAR (those before 2009)
  # 2. For rows in CUTOFF_YEAR, skip those where date < CUTOFF_DATE
  # Use grep line-by-line; sed for the boundary year is not available without awk.
  # Instead: pipe through grep -v for pre-cutoff date patterns is fragile.
  # Simplest correct approach: use a while-read loop in sh.
  {
    printf '%s\n' "$HEADER"
    while IFS= read -r line; do
      # Skip header line (already written)
      case "$line" in
        date,*) continue ;;
      esac
      # Extract date field (first field before comma)
      row_date="${line%%,*}"
      # Lexicographic comparison works for ISO dates
      if [ "$row_date" \> "$CUTOFF_DATE" ] || [ "$row_date" = "$CUTOFF_DATE" ]; then
        printf '%s\n' "$line"
      fi
    done < "$src_csv"
  } > "$dst_csv"

  # Copy metadata if present
  if [ -f "$src_meta" ]; then
    cp "$src_meta" "$dst_meta"
  fi

  # Verify the output is non-empty (more than just the header)
  line_count="$(wc -l < "$dst_csv")"
  if [ "$line_count" -le 1 ]; then
    printf 'WARN: %s produced empty output after filtering (cutoff=%s)\n' "$sym" "$CUTOFF_DATE"
    SKIPPED_EMPTY=$((SKIPPED_EMPTY + 1))
  else
    WRITTEN=$((WRITTEN + 1))
  fi
done

printf '\n'
printf 'Done.\n'
printf '  Found   : %d\n' "$FOUND"
printf '  Missing : %d\n' "$MISSING"
printf '  Written : %d\n' "$WRITTEN"
printf '  Empty   : %d\n' "$SKIPPED_EMPTY"

if [ "$MISSING" -gt 0 ]; then
  printf '\nWARN: %d symbols had no source data.\n' "$MISSING"
fi
if [ "$DRY_RUN" = "1" ]; then
  printf '\nDry run complete — no files written.\n'
  printf 'Remove --dry-run to write output to %s\n' "$OUTPUT_DIR"
fi
