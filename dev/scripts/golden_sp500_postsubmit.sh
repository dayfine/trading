#!/bin/sh
# SP500 golden postsubmit runner.
#
# Discovers all scenarios tagged `;; perf-tier: 3` under
# trading/test_data/backtest_scenarios/goldens-sp500/, runs each via the
# scenario_runner binary with a per-scenario timeout, and prints a compact
# wall-time + peak-RSS table.
#
# Mirrors dev/scripts/perf_tier3_weekly.sh — same discovery + output layout,
# same OCAMLRUNPARAM tuning, same scratch-dir staging trick. Differences:
#   - scans goldens-sp500/ only (not goldens-small/broad/perf-sweep/smoke)
#   - per-cell timeout default is 5400s = 90 min
#   - artefact dir is dev/perf/golden-sp500-postsubmit-<timestamp>/
#   - env var override is GOLDEN_SP500_TIMEOUT / GOLDEN_SP500_OCAMLRUNPARAM
#
# Exit status:
#   0 if every scenario completes within budget with PASS verdict
#   1 if any scenario exits non-zero, errors, or times out
#
# Usage:
#   dev/scripts/golden_sp500_postsubmit.sh                        -- run all
#   GOLDEN_SP500_TIMEOUT=3600 dev/scripts/golden_sp500_postsubmit.sh
#
# Designed to run inside GHA where TRADING_IN_CONTAINER=1 and
# TRADING_DATA_DIR=${{ github.workspace }}/trading/test_data.
#
# Prerequisite: bar data for SP500 symbols must be present under
# trading/test_data/. Run dev/scripts/prepare_ci_data.sh locally and
# commit the output before using this workflow. See
# dev/notes/ci-golden-runs-design-2026-05-06.md for the full design.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCENARIO_ROOT="${REPO_ROOT}/trading/test_data/backtest_scenarios"
RUN_IN_ENV="${REPO_ROOT}/dev/lib/run-in-env.sh"
TIMEOUT="${GOLDEN_SP500_TIMEOUT:-5400}"

# Same GC tuning as perf_tier3_weekly.sh — keeps peak RSS ~25-37% lower
# for runs with low allocation rates.
# dev/notes/panels-rss-matrix-post602-gc-tuned-2026-04-26.md
export OCAMLRUNPARAM="${GOLDEN_SP500_OCAMLRUNPARAM:-o=60,s=512k}"

if [ ! -x "$RUN_IN_ENV" ]; then
  printf 'FAIL: %s not found / not executable\n' "$RUN_IN_ENV" >&2
  exit 1
fi

if [ ! -d "$SCENARIO_ROOT" ]; then
  printf 'FAIL: scenario root not found: %s\n' "$SCENARIO_ROOT" >&2
  exit 1
fi

# Probe for GNU /usr/bin/time (available on GHA ubuntu-latest, not on macOS).
if [ -x /usr/bin/time ]; then
  HAVE_GNU_TIME=1
else
  HAVE_GNU_TIME=0
fi

TS="$(date -u +%Y-%m-%dT%H%M%SZ)"
OUT_DIR="${REPO_ROOT}/dev/perf/golden-sp500-postsubmit-${TS}"
mkdir -p "$OUT_DIR"

printf 'SP500 golden postsubmit run.\n'
printf '  Scenario root    : %s\n' "$SCENARIO_ROOT"
printf '  Output dir       : %s\n' "$OUT_DIR"
printf '  Per-cell timeout : %ss\n' "$TIMEOUT"
printf '  GNU /usr/bin/time: %s\n\n' "$HAVE_GNU_TIME"

# Discover tier-3 SP500 golden scenarios.
SP500_PATHS=""
for sub in goldens-sp500 goldens-sp500-historical; do
  dir="${SCENARIO_ROOT}/${sub}"
  [ -d "$dir" ] || continue
  for sexp in "$dir"/*.sexp; do
    [ -f "$sexp" ] || continue
    if grep -q '^;; perf-tier: 3' "$sexp"; then
      SP500_PATHS="${SP500_PATHS}${sexp}
"
    fi
  done
done

if [ -z "$SP500_PATHS" ]; then
  printf 'WARNING: no scenarios found with [;; perf-tier: 3] in goldens-sp500/ -- nothing to do.\n'
  exit 0
fi

PASS_COUNT=0
FAIL_COUNT=0
TABLE_ROWS=""

_run_one() {
  scenario_path="$1"
  base_name="$(basename "$scenario_path" .sexp)"
  log_path="${OUT_DIR}/${base_name}.log"
  rss_path="${OUT_DIR}/${base_name}.peak_rss"
  wall_path="${OUT_DIR}/${base_name}.wall_sec"
  error_path="${OUT_DIR}/${base_name}.error"

  # Stage into a scratch dir so scenario_runner --dir picks up exactly one cell.
  stage_dir="${OUT_DIR}/_stage_${base_name}"
  mkdir -p "$stage_dir"
  cp "$scenario_path" "$stage_dir/"

  printf '[run]  %s\n' "$base_name"

  start_epoch=$(date +%s)
  rc=0
  if [ "$HAVE_GNU_TIME" = "1" ]; then
    /usr/bin/time -o "$rss_path" -f '%M' \
      timeout "$TIMEOUT" \
      "$RUN_IN_ENV" \
        dune exec --no-build \
          trading/backtest/scenarios/scenario_runner.exe -- \
          --dir "$stage_dir" --parallel 1 \
          --fixtures-root "$SCENARIO_ROOT" \
        >"$log_path" 2>&1 || rc=$?
  else
    timeout "$TIMEOUT" \
      "$RUN_IN_ENV" \
        dune exec --no-build \
          trading/backtest/scenarios/scenario_runner.exe -- \
          --dir "$stage_dir" --parallel 1 \
          --fixtures-root "$SCENARIO_ROOT" \
        >"$log_path" 2>&1 || rc=$?
    printf 'UNAVAILABLE\n' >"$rss_path"
  fi
  end_epoch=$(date +%s)
  wall_sec=$((end_epoch - start_epoch))
  printf '%s\n' "$wall_sec" >"$wall_path"

  rss_value="?"
  if [ -f "$rss_path" ]; then
    rss_value=$(tr -d '\n' <"$rss_path")
  fi

  if [ "$rc" -ne 0 ]; then
    printf 'exit=%s — see %s\n' "$rc" "$log_path" >"$error_path"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TABLE_ROWS="${TABLE_ROWS}FAIL  ${base_name}  ${wall_sec}s  ${rss_value}kB
"
  else
    PASS_COUNT=$((PASS_COUNT + 1))
    TABLE_ROWS="${TABLE_ROWS}PASS  ${base_name}  ${wall_sec}s  ${rss_value}kB
"
  fi

  rm -rf "$stage_dir"
}

# Pre-build so per-cell wall times don't include build overhead.
"$RUN_IN_ENV" dune build trading/backtest/scenarios/scenario_runner.exe \
  >"${OUT_DIR}/_prebuild.log" 2>&1 || true

OLD_IFS="$IFS"
IFS='
'
for path in $SP500_PATHS; do
  IFS="$OLD_IFS"
  _run_one "$path"
  IFS='
'
done
IFS="$OLD_IFS"

SUMMARY="${OUT_DIR}/summary.txt"
{
  printf 'SP500 golden postsubmit summary (%s)\n' "$TS"
  printf '  passed: %d\n' "$PASS_COUNT"
  printf '  failed: %d\n' "$FAIL_COUNT"
  printf '\n'
  printf '%-6s  %-40s  %-8s  %s\n' "STATUS" "SCENARIO" "WALL" "PEAK_RSS"
  printf '%s\n' "--------------------------------------------------------------------------"
  # Print TABLE_ROWS with alignment; avoid awk (posix sh) — use printf column hack
  printf '%b' "$TABLE_ROWS" | while IFS= read -r row; do
    s1="${row%% *}"; rest="${row#* }"
    s2="${rest%% *}"; rest="${rest#* }"
    s3="${rest%% *}"; s4="${rest#* }"
    printf '%-6s  %-40s  %-8s  %s\n' "$s1" "$s2" "$s3" "$s4"
  done
} >"$SUMMARY"

cat "$SUMMARY"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
