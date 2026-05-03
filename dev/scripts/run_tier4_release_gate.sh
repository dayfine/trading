#!/bin/sh
# Tier-4 release-gate SCALE runner for N=5000 / N=10000 cells.
#
# Distinct from `dev/scripts/perf_tier4_release_gate.sh`, which runs the
# established N=1000 release-gate cells (`bull-crash-2015-2020`,
# `covid-recovery-2020-2024`, `decade-2014-2023`, `six-year-2018-2023`)
# tagged `;; perf-tier: 4`. This script discovers and runs the SCALE
# variants tagged `;; perf-tier: 4-scale`:
#   - tier4-N5000-5y   (5y × N=5000)
#   - tier4-N5000-10y  (10y × N=5000)
#   - tier4-N10000-5y  (5y × N=10000)
#
# Why a separate sub-tier:
#   1. The N=1000 cells fit 8 GB under CSV mode and have pinned baselines.
#      They run today via `perf_tier4_release_gate.sh` at every release cut.
#   2. The N=5000 / N=10000 cells require snapshot-mode runtime (default
#      since #802 / Phase F.2) + a pre-built snapshot corpus that is still
#      being assembled (ops-data agent in flight on the 15y sp500 fetch).
#      Tagging them with a distinct sub-tier keeps them OFF the standard
#      tier-4 runner until both prereqs land.
#
# Snapshot-mode is mandatory: CSV-mode upper bound (RSS ≈ 67 + 3.94·N +
# 0.19·N·(T-1)) projects 24-47 GB peak for these cells, well beyond any
# single runner. Snapshot mode (Phase E §F3 cache-bounded RSS ~50-200 MB)
# is what makes them feasible on the user's 8 GB local box. The runner
# below sets `--snapshot-mode` explicitly to be future-proof against the
# F.2 default ever flipping back.
#
# This script is SCAFFOLDING — the actual gate run is local-only on the
# user's box once the 5000-symbol snapshot corpus is built. Until then
# `--dry-run` is the expected invocation: it prints the discovered cells
# + planned commands without executing them.
#
# Exit status:
#   0 if every tier-4-scale scenario completes within budget (or --dry-run)
#   1 if any scenario exits non-zero, errors, or times out
#   2 if invocation is malformed or no cells are discovered
#
# Usage:
#   dev/scripts/run_tier4_release_gate.sh                       -- run all
#   dev/scripts/run_tier4_release_gate.sh --dry-run             -- print plan, no exec
#   PERF_TIER4_SCALE_TIMEOUT=14400 dev/scripts/run_tier4_release_gate.sh
#
# Output artefacts under dev/perf/tier4-scale-<timestamp>/:
#   <scenario-name>.log        scenario_runner stdout/stderr
#   <scenario-name>.peak_rss   integer kB from /usr/bin/time -f '%M'
#   <scenario-name>.wall_sec   seconds (real time) — best-effort
#   <scenario-name>.error      present iff the run errored / timed out
#   summary.txt                aggregate table written at the end
#
# References:
#   dev/notes/tier4-release-gate-checklist-2026-04-28.md
#   dev/notes/panels-rss-matrix-post-engine-pool-2026-04-28.md
#   dev/plans/snapshot-engine-phase-f-2026-05-03.md
#   dev/plans/daily-snapshot-streaming-2026-04-27.md

set -e

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    --help|-h)
      sed -n '2,55p' "$0"
      exit 0 ;;
    *)
      printf 'FAIL: unknown argument: %s\n' "$arg" >&2
      printf 'See `%s --help`.\n' "$0" >&2
      exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCENARIO_ROOT="${REPO_ROOT}/trading/test_data/backtest_scenarios"
RUN_IN_ENV="${REPO_ROOT}/dev/lib/run-in-env.sh"

# Default per-cell timeout: 12 h. The largest cell (N=10000 × 5y) is
# expected to be screener-bound, not memory-bound, under snapshot mode.
# Override via env var.
TIMEOUT="${PERF_TIER4_SCALE_TIMEOUT:-43200}"

# Snapshot-mode default-flip landed in #802 (Phase F.2). We pass the flag
# explicitly so this script remains correct if a future change reverts the
# default. Override via env var if you need to test a specific snapshot
# directory; otherwise auto-build is used.
SNAPSHOT_DIR="${PERF_TIER4_SCALE_SNAPSHOT_DIR:-}"

# Aggressive major-GC + smaller minor heap. Same rationale as the N=1000
# tier-4 runner. Override via PERF_TIER4_SCALE_OCAMLRUNPARAM=...; pass
# empty to use the OCaml defaults.
export OCAMLRUNPARAM="${PERF_TIER4_SCALE_OCAMLRUNPARAM:-o=60,s=512k}"

if [ "$DRY_RUN" = "0" ] && [ ! -x "$RUN_IN_ENV" ]; then
  printf 'FAIL: %s not found / not executable\n' "$RUN_IN_ENV" >&2
  exit 1
fi

if [ ! -d "$SCENARIO_ROOT" ]; then
  printf 'FAIL: scenario root not found: %s\n' "$SCENARIO_ROOT" >&2
  exit 1
fi

if [ -x /usr/bin/time ]; then
  HAVE_GNU_TIME=1
else
  HAVE_GNU_TIME=0
fi

TS="$(date -u +%Y-%m-%dT%H%M%SZ)"
OUT_DIR="${REPO_ROOT}/dev/perf/tier4-scale-${TS}"
mkdir -p "$OUT_DIR"

printf 'Tier-4 release-gate SCALE run.\n'
printf '  Scenario root  : %s\n' "$SCENARIO_ROOT"
printf '  Output dir     : %s\n' "$OUT_DIR"
printf '  Per-cell timeout : %ss\n' "$TIMEOUT"
printf '  GNU /usr/bin/time : %s\n' "$HAVE_GNU_TIME"
printf '  Snapshot dir   : %s\n' "${SNAPSHOT_DIR:-<auto-build>}"
printf '  Dry run        : %s\n\n' "$DRY_RUN"

# Discover tier-4-scale scenarios under goldens-broad/.
TIER4_SCALE_PATHS=""
for sexp in "${SCENARIO_ROOT}/goldens-broad"/*.sexp; do
  [ -f "$sexp" ] || continue
  if grep -q '^;; perf-tier: 4-scale' "$sexp"; then
    TIER4_SCALE_PATHS="${TIER4_SCALE_PATHS}${sexp}
"
  fi
done

if [ -z "$TIER4_SCALE_PATHS" ]; then
  printf 'WARNING: no scenarios found with [;; perf-tier: 4-scale] -- nothing to do.\n' >&2
  exit 2
fi

PASS_COUNT=0
FAIL_COUNT=0
TABLE_ROWS=""

# Snapshot-mode flag set. Empty if SNAPSHOT_DIR is empty (then auto-build
# takes over per F.2). Otherwise pass an explicit dir.
SNAPSHOT_FLAGS="--snapshot-mode"
if [ -n "$SNAPSHOT_DIR" ]; then
  SNAPSHOT_FLAGS="--snapshot-mode --snapshot-dir $SNAPSHOT_DIR"
fi

_run_one() {
  scenario_path="$1"
  base_name="$(basename "$scenario_path" .sexp)"
  log_path="${OUT_DIR}/${base_name}.log"
  rss_path="${OUT_DIR}/${base_name}.peak_rss"
  wall_path="${OUT_DIR}/${base_name}.wall_sec"
  error_path="${OUT_DIR}/${base_name}.error"

  stage_dir="${OUT_DIR}/_stage_${base_name}"
  mkdir -p "$stage_dir"
  cp "$scenario_path" "$stage_dir/"

  cmd="dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- --dir $stage_dir --parallel 1 --fixtures-root $SCENARIO_ROOT $SNAPSHOT_FLAGS"

  if [ "$DRY_RUN" = "1" ]; then
    printf '[dry]  %s\n' "$base_name"
    printf '       cmd: %s\n' "$cmd"
    printf '       timeout: %ss  OCAMLRUNPARAM=%s\n' "$TIMEOUT" "$OCAMLRUNPARAM"
    PASS_COUNT=$((PASS_COUNT + 1))
    TABLE_ROWS="${TABLE_ROWS}DRY   ${base_name}  -          -
"
    rm -rf "$stage_dir"
    return 0
  fi

  printf '[run]  %s\n' "$base_name"

  start_epoch=$(date +%s)
  rc=0
  if [ "$HAVE_GNU_TIME" = "1" ]; then
    /usr/bin/time -o "$rss_path" -f '%M' \
      timeout "$TIMEOUT" \
      "$RUN_IN_ENV" sh -c "$cmd" \
      >"$log_path" 2>&1 || rc=$?
  else
    timeout "$TIMEOUT" \
      "$RUN_IN_ENV" sh -c "$cmd" \
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

if [ "$DRY_RUN" = "0" ]; then
  "$RUN_IN_ENV" dune build trading/backtest/scenarios/scenario_runner.exe \
    >"${OUT_DIR}/_prebuild.log" 2>&1 || true
fi

OLD_IFS="$IFS"
IFS='
'
for path in $TIER4_SCALE_PATHS; do
  IFS="$OLD_IFS"
  _run_one "$path"
  IFS='
'
done
IFS="$OLD_IFS"

SUMMARY="${OUT_DIR}/summary.txt"
{
  printf 'Tier-4 release-gate SCALE summary (%s)\n' "$TS"
  printf '  passed: %d\n' "$PASS_COUNT"
  printf '  failed: %d\n' "$FAIL_COUNT"
  printf '  dry-run: %s\n' "$DRY_RUN"
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
