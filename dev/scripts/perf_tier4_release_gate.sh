#!/bin/sh
# Tier-4 perf release-gate runner.
#
# Discovers all scenarios with `;; perf-tier: 4` under
# trading/test_data/backtest_scenarios/{goldens-small,goldens-broad,perf-sweep,smoke}/,
# runs each via the scenario_runner binary with a per-scenario timeout
# (default 28800s = 8 hours, per dev/plans/perf-scenario-catalog-2026-04-25.md
# tier 4 budget), and prints a compact wall-time + peak-RSS table.
#
# Mirrors dev/scripts/perf_tier3_weekly.sh — same discovery + output layout,
# same OCAMLRUNPARAM tuning, same scratch-dir staging trick. Differences:
#   - tier filter is `perf-tier: 4`
#   - per-cell timeout default is 28800s (vs 7200s for tier 3)
#   - artefact dir is dev/perf/tier4-release-gate-<timestamp>/
#   - env var override is PERF_TIER4_TIMEOUT / PERF_TIER4_OCAMLRUNPARAM
#
# Designed to run on-demand at release-cut time, not on a recurring schedule —
# tier-4 is the heaviest tier (≤8 h per cell, decade-long at N=1000). Local-only:
# GHA cannot satisfy `Full_sector_map` data load. See
# dev/notes/tier4-release-gate-checklist-2026-04-28.md for the cut procedure.
#
# Exit status:
#   0 if every tier-4 scenario completes within budget
#   1 if any scenario exits non-zero, errors, or times out
#
# Usage:
#   dev/scripts/perf_tier4_release_gate.sh                          -- run all tier-4 cells
#   PERF_TIER4_TIMEOUT=14400 dev/scripts/perf_tier4_release_gate.sh -- bump per-cell timeout
#
# Designed to run inside the trading-1-dev container or under GHA where
# TRADING_IN_CONTAINER=1; uses dev/lib/run-in-env.sh to wrap dune exec.
#
# Output artefacts under dev/perf/tier4-release-gate-<timestamp>/:
#   <scenario-name>.log        scenario_runner stdout/stderr
#   <scenario-name>.peak_rss   integer kB from /usr/bin/time -f '%M'
#   <scenario-name>.wall_sec   seconds (real time) — best-effort
#   <scenario-name>.error      present iff the run errored / timed out
#   summary.txt                aggregate table written at the end

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCENARIO_ROOT="${REPO_ROOT}/trading/test_data/backtest_scenarios"
RUN_IN_ENV="${REPO_ROOT}/dev/lib/run-in-env.sh"
TIMEOUT="${PERF_TIER4_TIMEOUT:-28800}"

# Aggressive major-GC + smaller minor heap. Same rationale as tier-1/tier-2/tier-3
# (dev/notes/panels-rss-matrix-post602-gc-tuned-2026-04-26.md): without this,
# the GC steady-state high-water mark inflates peak RSS by ~25-37% for runs
# with low allocation rates. Override via PERF_TIER4_OCAMLRUNPARAM=... if a
# specific scenario needs a different heap shape; pass empty to use the OCaml
# defaults.
export OCAMLRUNPARAM="${PERF_TIER4_OCAMLRUNPARAM:-o=60,s=512k}"

if [ ! -x "$RUN_IN_ENV" ]; then
  printf 'FAIL: %s not found / not executable\n' "$RUN_IN_ENV" >&2
  exit 1
fi

if [ ! -d "$SCENARIO_ROOT" ]; then
  printf 'FAIL: scenario root not found: %s\n' "$SCENARIO_ROOT" >&2
  exit 1
fi

# Probe for GNU /usr/bin/time. The shell builtin has no -f / -o; we need
# the GNU binary for peak-RSS reporting. macOS hosts won't have it.
if [ -x /usr/bin/time ]; then
  HAVE_GNU_TIME=1
else
  HAVE_GNU_TIME=0
fi

# Output dir keyed by timestamp so re-runs don't clobber each other.
TS="$(date -u +%Y-%m-%dT%H%M%SZ)"
OUT_DIR="${REPO_ROOT}/dev/perf/tier4-release-gate-${TS}"
mkdir -p "$OUT_DIR"

printf 'Tier-4 perf release-gate run.\n'
printf '  Scenario root : %s\n' "$SCENARIO_ROOT"
printf '  Output dir    : %s\n' "$OUT_DIR"
printf '  Per-cell timeout : %ss\n' "$TIMEOUT"
printf '  GNU /usr/bin/time : %s\n\n' "$HAVE_GNU_TIME"

# Discover tier-4 scenarios (full paths, sorted for determinism).
TIER4_PATHS=""
for sub in goldens-small goldens-broad perf-sweep smoke; do
  dir="${SCENARIO_ROOT}/${sub}"
  [ -d "$dir" ] || continue
  for sexp in "$dir"/*.sexp; do
    [ -f "$sexp" ] || continue
    if grep -q '^;; perf-tier: 4' "$sexp"; then
      TIER4_PATHS="${TIER4_PATHS}${sexp}
"
    fi
  done
done

if [ -z "$TIER4_PATHS" ]; then
  printf 'WARNING: no scenarios found with [;; perf-tier: 4] -- nothing to do.\n'
  exit 0
fi

PASS_COUNT=0
FAIL_COUNT=0
TABLE_ROWS=""

# Run a single scenario. Stages it into a one-element scratch dir so the
# scenario_runner --dir entry point picks up exactly one cell. Captures
# wall time + peak RSS from GNU /usr/bin/time.
_run_one() {
  scenario_path="$1"
  base_name="$(basename "$scenario_path" .sexp)"
  log_path="${OUT_DIR}/${base_name}.log"
  rss_path="${OUT_DIR}/${base_name}.peak_rss"
  wall_path="${OUT_DIR}/${base_name}.wall_sec"
  error_path="${OUT_DIR}/${base_name}.error"

  # Stage into a scratch dir; scenario_runner --dir consumes ALL .sexp in
  # the dir, so we put just this one scenario in a fresh subdir.
  stage_dir="${OUT_DIR}/_stage_${base_name}"
  mkdir -p "$stage_dir"
  cp "$scenario_path" "$stage_dir/"

  printf '[run]  %s\n' "$base_name"

  start_epoch=$(date +%s)
  rc=0
  # Pass --fixtures-root so the runner resolves the scenario's [universe_path]
  # against the original fixtures dir, not the per-cell `_stage_<name>/`
  # scratch dir. Tier-1/2/3 pass this same flag (#634).
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

  # Clean up stage dir; keep logs.
  rm -rf "$stage_dir"
}

# Pre-build the scenario_runner so per-cell wall numbers don't include build
# time. Best-effort: if the build fails, _run_one will surface it.
"$RUN_IN_ENV" dune build trading/backtest/scenarios/scenario_runner.exe \
  >"${OUT_DIR}/_prebuild.log" 2>&1 || true

# IFS-by-newline iteration — TIER4_PATHS is newline-separated.
OLD_IFS="$IFS"
IFS='
'
for path in $TIER4_PATHS; do
  IFS="$OLD_IFS"
  _run_one "$path"
  IFS='
'
done
IFS="$OLD_IFS"

SUMMARY="${OUT_DIR}/summary.txt"
{
  printf 'Tier-4 perf release-gate summary (%s)\n' "$TS"
  printf '  passed: %d\n' "$PASS_COUNT"
  printf '  failed: %d\n' "$FAIL_COUNT"
  printf '\n'
  printf '%-6s  %-32s  %-8s  %s\n' "STATUS" "SCENARIO" "WALL" "PEAK_RSS"
  printf '%s\n' "----------------------------------------------------------------------"
  printf '%b' "$TABLE_ROWS" | awk 'NF { printf "%-6s  %-32s  %-8s  %s\n", $1, $2, $3, $4 }'
} >"$SUMMARY"

cat "$SUMMARY"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
