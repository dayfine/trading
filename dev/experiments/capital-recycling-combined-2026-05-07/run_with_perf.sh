#!/bin/sh
# run_with_perf.sh — re-run Cells A-E with wall + peak RSS capture.
#
# Q3 from dev/notes/next-session-priorities-2026-05-08.md: the original
# experiment captured trading outcomes (actual.sexp, trades.csv) but NOT
# runtime. This script wraps each cell with /usr/bin/time -f '%M' to capture
# peak RSS, plus wall-clock delta from epoch timestamps.
#
# Designed to run inside the dev container (or CI image). Uses run-in-env.sh.
#
# Usage: dev/experiments/capital-recycling-combined-2026-05-07/run_with_perf.sh
#
# Output: dev/experiments/capital-recycling-combined-2026-05-07/perf-<TS>/
#   - <cell>.log     scenario_runner stdout/stderr
#   - <cell>.peak_rss   peak RSS in KB
#   - <cell>.wall_sec   wall-clock seconds
#   - summary.txt      one-line table

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
RUN_IN_ENV="${REPO_ROOT}/dev/lib/run-in-env.sh"
SCENARIO_ROOT="${REPO_ROOT}/trading/test_data/backtest_scenarios"
EXP_SCENARIOS="${SCRIPT_DIR}/scenarios"
TIMEOUT="${PERF_TIMEOUT:-1800}"

export OCAMLRUNPARAM="${PERF_OCAMLRUNPARAM:-o=60,s=512k}"

if [ -x /usr/bin/time ]; then
  HAVE_GNU_TIME=1
else
  HAVE_GNU_TIME=0
fi

TS="$(date -u +%Y-%m-%dT%H%M%SZ)"
OUT_DIR="${SCRIPT_DIR}/perf-${TS}"
mkdir -p "$OUT_DIR"

printf 'Cell A-E perf measurement (Q3).\n'
printf '  Scenarios dir : %s\n' "$EXP_SCENARIOS"
printf '  Output dir    : %s\n' "$OUT_DIR"
printf '  Timeout       : %ss\n' "$TIMEOUT"
printf '  GNU time      : %s\n\n' "$HAVE_GNU_TIME"

# Pre-build so per-cell wall doesn't include build overhead.
"$RUN_IN_ENV" dune build trading/backtest/scenarios/scenario_runner.exe \
  >"${OUT_DIR}/_prebuild.log" 2>&1 || true

TABLE_ROWS=""

for sexp in "$EXP_SCENARIOS"/*.sexp; do
  [ -f "$sexp" ] || continue
  base="$(basename "$sexp" .sexp)"
  log="${OUT_DIR}/${base}.log"
  rss="${OUT_DIR}/${base}.peak_rss"
  wall="${OUT_DIR}/${base}.wall_sec"

  stage="${OUT_DIR}/_stage_${base}"
  mkdir -p "$stage"
  cp "$sexp" "$stage/"

  printf '[run]  %s\n' "$base"
  start=$(date +%s)
  rc=0
  if [ "$HAVE_GNU_TIME" = "1" ]; then
    /usr/bin/time -o "$rss" -f '%M' \
      timeout "$TIMEOUT" \
      "$RUN_IN_ENV" \
        dune exec --no-build \
          trading/backtest/scenarios/scenario_runner.exe -- \
          --dir "$stage" --parallel 1 \
          --fixtures-root "$SCENARIO_ROOT" \
        >"$log" 2>&1 || rc=$?
  else
    timeout "$TIMEOUT" \
      "$RUN_IN_ENV" \
        dune exec --no-build \
          trading/backtest/scenarios/scenario_runner.exe -- \
          --dir "$stage" --parallel 1 \
          --fixtures-root "$SCENARIO_ROOT" \
        >"$log" 2>&1 || rc=$?
    printf 'UNAVAILABLE\n' >"$rss"
  fi
  end=$(date +%s)
  wall_sec=$((end - start))
  printf '%s\n' "$wall_sec" >"$wall"

  rss_value="?"
  [ -f "$rss" ] && rss_value=$(tr -d '\n' <"$rss")

  if [ "$rc" -ne 0 ]; then
    TABLE_ROWS="${TABLE_ROWS}FAIL  ${base}  ${wall_sec}s  ${rss_value}kB
"
  else
    TABLE_ROWS="${TABLE_ROWS}PASS  ${base}  ${wall_sec}s  ${rss_value}kB
"
  fi

  rm -rf "$stage"
done

SUMMARY="${OUT_DIR}/summary.txt"
{
  printf 'Cells A-E perf measurement (%s)\n\n' "$TS"
  printf '%-6s  %-40s  %-8s  %s\n' "STATUS" "SCENARIO" "WALL" "PEAK_RSS"
  printf '%s\n' "--------------------------------------------------------------------------"
  printf '%b' "$TABLE_ROWS" | while IFS= read -r row; do
    s1="${row%% *}"; rest="${row#* }"
    s2="${rest%% *}"; rest="${rest#* }"
    s3="${rest%% *}"; s4="${rest#* }"
    printf '%-6s  %-40s  %-8s  %s\n' "$s1" "$s2" "$s3" "$s4"
  done
} >"$SUMMARY"

cat "$SUMMARY"
