#!/bin/sh
# Linter: file length check for all lib .ml files in the trading codebase.
#
# Two-tier limit:
#
#   Normal files:         fail if > 300 lines.
#   Declared-large files: a file may opt in by including the marker
#                           (* @large-module: <reason> *)
#                         on any line. These are allowed up to 500 lines,
#                         but declared-large files must stay <= 11% of all
#                         checked files.
#
# This lets genuinely large modules exist without gaming the 300-line norm.
# If too many files declare themselves large the check fails, preventing
# mass opt-out from the soft limit.

set -e

. "$(dirname "$0")/_check_lib.sh"

TRADING_DIR="$(trading_dir)"
SOFT_LIMIT=300
HARD_LIMIT=500
MAX_LARGE_PCT=11

VIOLATIONS=""
TOTAL=0
LARGE_COUNT=0

for ml_file in $(find "$TRADING_DIR" -path "*/lib/*.ml" \
    -not -path "*/_build/*" \
    -not -path "*/.formatted/*" \
    -not -name "*.pp.ml"); do
  TOTAL=$((TOTAL + 1))
  line_count=$(wc -l < "$ml_file")

  if grep -q "@large-module" "$ml_file"; then
    LARGE_COUNT=$((LARGE_COUNT + 1))
    if [ "$line_count" -gt "$HARD_LIMIT" ]; then
      VIOLATIONS="${VIOLATIONS}${ml_file}: ${line_count} lines (declared-large hard limit: ${HARD_LIMIT})\n"
    fi
  else
    if [ "$line_count" -gt "$SOFT_LIMIT" ]; then
      VIOLATIONS="${VIOLATIONS}${ml_file}: ${line_count} lines (limit: ${SOFT_LIMIT})\n"
    fi
  fi
done

# Fail if declared-large files exceed MAX_LARGE_PCT% of total.
# Uses integer arithmetic: LARGE * 100 > TOTAL * MAX_LARGE_PCT.
if [ "$TOTAL" -gt 0 ] && [ $((LARGE_COUNT * 100)) -gt $((TOTAL * MAX_LARGE_PCT)) ]; then
  VIOLATIONS="${VIOLATIONS}Too many declared-large files: ${LARGE_COUNT}/${TOTAL} exceeds ${MAX_LARGE_PCT}% cap.\n"
  VIOLATIONS="${VIOLATIONS}  Split modules instead of opting out of the ${SOFT_LIMIT}-line limit.\n"
fi

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: file length linter:"
  printf '%b' "$VIOLATIONS"
  echo ""
  echo "Normal files: <= ${SOFT_LIMIT} lines. To exceed, add to the file:"
  echo "  (* @large-module: <reason> *)"
  echo "Declared-large files: <= ${HARD_LIMIT} lines, capped at ${MAX_LARGE_PCT}% of all files."
  exit 1
fi

echo "OK: all lib/*.ml files within limits (${LARGE_COUNT} declared-large of ${TOTAL} total)."
