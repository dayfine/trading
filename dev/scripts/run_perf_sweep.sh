#!/usr/bin/env bash
# Parameter-sweep extension to the C2 perf harness.
#
# Where run_perf_hypothesis.sh runs ONE scenario × ONE override under both
# loader strategies (a single-knob A/B), this script runs a 2D matrix of
# (universe_size N) × (run length T) under both Legacy and Tiered. The output
# is a Markdown report giving the (N, T, strategy) RSS + wall-time surface
# from which the slope of the Tiered/Legacy gap can be read off.
#
# Sweep design (8 cells × 2 strategies = 16 runs):
#   N-sweep at T=1y    : N=100, 300, 500, 1000
#   T-sweep at N=300   : T=3m,  6m,  1y,  3y
#   Worst-corner check : N=1000, T=3y
#
# Usage:
#   dev/scripts/run_perf_sweep.sh <sweep-id>
#
# Example:
#   dev/scripts/run_perf_sweep.sh 2026-04-25
#
# Outputs (under dev/experiments/perf/sweep-<sweep-id>/):
#   <N>-<T>/<strategy>.peak_rss_kb     integer kB from /usr/bin/time -f '%M'
#   <N>-<T>/<strategy>.trace.sexp      per-phase metrics from --trace
#   <N>-<T>/<strategy>.memtrace.ctf    Memtrace allocation trace
#   <N>-<T>/<strategy>.log             stdout+stderr from the run
#   <N>-<T>/<strategy>.error           present iff the run errored (timeout/OOM/...)
#   report.md                          aggregate matrix + complexity tables
#
# Hard constraints driving the design:
#   - Skip-on-resume: each cell checks for a non-empty <strategy>.peak_rss_kb
#     and skips if present. The full sweep is hours; if it dies mid-way (OOM
#     on the 1000×3y corner is plausible), re-running picks up where it left
#     off without re-running the cells that already produced output.
#   - Per-cell timeout: 1200s (20 min) hard cap so a stuck cell doesn't hang
#     the whole sweep. On timeout the script writes <strategy>.error and
#     proceeds to the next cell rather than aborting — partial sweeps are
#     more useful than no sweep at all.
#   - Identical override keys for both strategies in a cell. Only --loader-
#     strategy differs. Same parity stance as run_perf_hypothesis.sh.
#
# Notes:
#   - Uses bash because the cell list (and per-cell field unpacking) is
#     cleaner with arrays + here-strings. Run-time bash-isms only; no array
#     operations the POSIX-sh check would flag (the script has a #!/usr/bin/
#     env bash shebang and is therefore excluded from the dash linter scan
#     by trading/devtools/checks/posix_sh_check.sh).
#   - Designed to be invoked from the host (outside the devcontainer);
#     `dune exec` is run from inside the trading/ workspace so the standard
#     workspace resolution applies.
#   - DOES NOT run dune build for you. Build the binary first:
#       (cd trading && dune build trading/backtest/bin/backtest_runner.exe)
#     The script issues a single dune build at startup as a convenience, but
#     prefer pre-building for reproducible wall-clock numbers across cells.

set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s <sweep-id>\n' "$0" >&2
  exit 2
fi

SWEEP_ID="$1"

# Reject ids that would escape the experiments/perf/ directory.
case "$SWEEP_ID" in
  */* | ..* | "")
    printf 'FAIL: sweep-id must be a single non-empty path component (got: %q)\n' \
      "$SWEEP_ID" >&2
    exit 2
    ;;
esac

# Resolve repo root + dune workspace. Script lives at
# <repo-root>/dev/scripts/run_perf_sweep.sh — climb two levels.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DUNE_ROOT="$REPO_ROOT/trading"

if [ ! -f "$DUNE_ROOT/dune-workspace" ]; then
  printf 'FAIL: dune workspace not found at %s/dune-workspace\n' "$DUNE_ROOT" >&2
  exit 1
fi

OUT_BASE="$REPO_ROOT/dev/experiments/perf/sweep-${SWEEP_ID}"
mkdir -p "$OUT_BASE"

SCENARIO_DIR="$REPO_ROOT/trading/test_data/backtest_scenarios/perf-sweep"

# Probe for GNU /usr/bin/time. The shell builtin `time` has no -f / -o flags;
# we need the GNU binary specifically. macOS hosts don't have it — those
# cells will write "UNAVAILABLE" to peak_rss_kb (matching the convention
# from run_perf_hypothesis.sh) and the aggregator skips those cells.
if [ -x /usr/bin/time ]; then
  HAVE_GNU_TIME=1
else
  HAVE_GNU_TIME=0
fi

# Cell list. Each row: "N T_label scenario_basename".
# 8-cell design — see header comment for sweep design rationale.
CELLS=(
  "100  1y bull-1y.sexp"
  "300  1y bull-1y.sexp"
  "500  1y bull-1y.sexp"
  "1000 1y bull-1y.sexp"
  "300  3m bull-3m.sexp"
  "300  6m bull-6m.sexp"
  "300  3y bull-3y.sexp"
  "1000 3y bull-3y.sexp"
)

# Extract start_date/end_date from a scenario sexp. Mirrors the extraction
# in run_perf_hypothesis.sh / tiered_loader_ab_compare.sh.
_scenario_start() {
  grep -E '\(start_date[[:space:]]' "$1" \
    | head -1 \
    | sed -E 's/.*\(start_date[[:space:]]+([0-9-]+).*/\1/'
}

_scenario_end() {
  grep -E '\(end_date[[:space:]]' "$1" \
    | head -1 \
    | sed -E 's/.*\(end_date[[:space:]]+([0-9-]+).*/\1/'
}

# Pre-build the binary so per-cell wall-clock numbers don't include build
# time. Even with --no-build below, the FIRST `dune exec --no-build` call
# would fail without a prior build; bake that in here.
printf 'Pre-building backtest_runner.exe...\n'
(cd "$DUNE_ROOT" && dune build trading/backtest/bin/backtest_runner.exe)

# Run a single (N, T_label, strategy) cell. Skips if the peak_rss_kb output
# already exists and is non-empty (skip-on-resume). On timeout/OOM/non-zero
# exit, writes <strategy>.error and returns 0 so the sweep continues.
_run_cell() {
  local n="$1"
  local t_label="$2"
  local scenario_path="$3"
  local strategy="$4"
  local cell_dir="$5"

  local out_prefix="$cell_dir/$strategy"
  local log_path="${out_prefix}.log"
  local peak_rss_path="${out_prefix}.peak_rss_kb"
  local trace_path="${out_prefix}.trace.sexp"
  local memtrace_path="${out_prefix}.memtrace.ctf"
  local error_path="${out_prefix}.error"

  if [ -s "$peak_rss_path" ] && [ ! -f "$error_path" ]; then
    printf '[skip] N=%-4s T=%-2s %s (already done)\n' "$n" "$t_label" "$strategy"
    return 0
  fi

  # Clear any prior partial-error marker before retrying.
  rm -f "$error_path"

  printf '[run]  N=%-4s T=%-2s %s\n' "$n" "$t_label" "$strategy"

  local start_date end_date
  start_date=$(_scenario_start "$scenario_path")
  end_date=$(_scenario_end "$scenario_path")

  if [ -z "$start_date" ] || [ -z "$end_date" ]; then
    printf 'parse-error: could not extract dates from %s\n' "$scenario_path" \
      >"$error_path"
    return 0
  fi

  # Build the override sexp on the fly so the cap is the only knob varying
  # per cell. universe_cap is the single-knob lever — see weinstein_strategy.mli.
  local override_sexp
  override_sexp="((universe_cap (${n})))"

  set +e
  if [ "$HAVE_GNU_TIME" = "1" ]; then
    (
      cd "$DUNE_ROOT"
      /usr/bin/time -o "$peak_rss_path" -f '%M' \
        timeout 1200 \
        dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
          "$start_date" "$end_date" \
          --loader-strategy "$strategy" \
          --override "$override_sexp" \
          --trace "$trace_path" \
          --memtrace "$memtrace_path"
    ) >"$log_path" 2>&1
  else
    (
      cd "$DUNE_ROOT"
      timeout 1200 \
        dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
          "$start_date" "$end_date" \
          --loader-strategy "$strategy" \
          --override "$override_sexp" \
          --trace "$trace_path" \
          --memtrace "$memtrace_path"
    ) >"$log_path" 2>&1
    printf 'UNAVAILABLE\n' >"$peak_rss_path"
  fi
  local rc=$?
  set -e

  if [ "$rc" -ne 0 ]; then
    printf 'exit=%s — see %s\n' "$rc" "$log_path" >"$error_path"
    # Wipe the peak_rss file too — /usr/bin/time may have left a partial line
    # (e.g. on timeout it can record %M of the killed process, which is
    # technically valid but easy to misread as a successful run).
    if [ "$HAVE_GNU_TIME" = "1" ]; then
      printf 'UNAVAILABLE\n' >"$peak_rss_path"
    fi
    return 0
  fi

  if [ ! -f "$trace_path" ]; then
    printf 'trace.sexp not produced — see %s\n' "$log_path" >"$error_path"
  fi
}

# -----------------------------------------------------------------------------
# Main sweep loop
# -----------------------------------------------------------------------------

printf 'Sweep id : %s\n' "$SWEEP_ID"
printf 'Out base : %s\n' "$OUT_BASE"
printf 'Cells    : %s\n' "${#CELLS[@]}"
printf 'GNU time : %s\n' "$HAVE_GNU_TIME"
printf '\n'

for cell in "${CELLS[@]}"; do
  # POSIX-style field unpacking via `read -r` — works under bash.
  read -r N T_LABEL SCENARIO_BASENAME <<<"$cell"
  CELL_DIR="$OUT_BASE/${N}-${T_LABEL}"
  mkdir -p "$CELL_DIR"
  SCENARIO_PATH="$SCENARIO_DIR/$SCENARIO_BASENAME"
  if [ ! -f "$SCENARIO_PATH" ]; then
    printf 'FAIL: scenario not found: %s\n' "$SCENARIO_PATH" >&2
    exit 1
  fi
  for STRATEGY in legacy tiered; do
    _run_cell "$N" "$T_LABEL" "$SCENARIO_PATH" "$STRATEGY" "$CELL_DIR"
  done
done

# -----------------------------------------------------------------------------
# Generate aggregate report.
# -----------------------------------------------------------------------------

REPORT_PATH="$OUT_BASE/report.md"
python3 "$SCRIPT_DIR/perf_sweep_report.py" \
  --sweep-dir "$OUT_BASE" \
  --sweep-id "$SWEEP_ID" \
  >"$REPORT_PATH"

printf '\nDone. Sweep report: %s\n' "$REPORT_PATH"
