#!/bin/sh
# Hypothesis-test harness for backtest performance comparisons.
#
# Workstream C2 of dev/plans/backtest-perf-2026-04-24.md. Wraps a single
# scenario into a Legacy-vs-Tiered A/B with optional `--override` flags,
# then captures peak RSS (`/usr/bin/time -f '%M'`) + per-phase timing
# (`backtest_runner.exe --trace`) and emits a regenerable comparative
# report.
#
# This is the formalization of the manual workflow used to ship #524 and
# #531 — instead of hand-rolling the docker exec, hand-greping the
# stderr, and hand-writing the Markdown table, every hypothesis test is
# now a one-liner whose output directory becomes the experiment's
# permanent record.
#
# Usage:
#   dev/scripts/run_perf_hypothesis.sh <hypothesis-id> <scenario-path> [<override-sexp>]
#
# Example:
#   dev/scripts/run_perf_hypothesis.sh H1 \
#     trading/test_data/backtest_scenarios/goldens-small/bull-crash-2015-2020.sexp \
#     '((bar_history_max_lookback_days (365)))'
#
# Inputs:
#   hypothesis-id   Free-form short identifier (e.g. H1, H1-replay,
#                   bar-history-trim). Becomes the output directory name
#                   under dev/experiments/perf/.
#   scenario-path   Path to a Scenario.t sexp (relative to repo root or
#                   absolute). Only the [period] sub-block is consumed —
#                   start_date and end_date drive the runner CLI args.
#                   Other fields (universe_path, expected, config_overrides)
#                   are ignored: the override sexp passed on the command
#                   line is the only knob the harness toggles, so two
#                   strategies see the same exact config except for the
#                   `--loader-strategy` flag.
#   override-sexp   Optional. A partial config sexp passed to both runs
#                   via `--override`. When omitted, both runs use the
#                   default config — useful for an unfiltered Legacy-vs-
#                   Tiered baseline measurement.
#
# Outputs (under dev/experiments/perf/<hypothesis-id>/):
#   legacy.log               full stdout+stderr from the Legacy run
#   legacy.peak_rss_kb       integer kB from /usr/bin/time -f '%M', or
#                            "UNAVAILABLE" if /usr/bin/time is missing
#   legacy.trace.sexp        per-phase metrics from --trace
#   tiered.{log,peak_rss_kb,trace.sexp}
#                            same for the Tiered run
#   report.md                auto-generated comparative table
#   repro.sh                 single-shot regeneration command
#
# Hard constraints:
#   - POSIX sh only (linted by trading/devtools/checks/posix_sh_check.sh)
#   - Both runs use the same overrides + scenario; only --loader-strategy
#     differs. This is the parity-test stance: any RSS or wall-clock
#     delta we observe is attributable to the loader strategy under the
#     given override.
#   - Failure of EITHER run aborts (exit 1) before report generation —
#     a partial report is more dangerous than a missing one.

set -eu

_die() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

_usage() {
  cat <<USAGE >&2
Usage: dev/scripts/run_perf_hypothesis.sh <hypothesis-id> <scenario-path> [<override-sexp>]

Runs one scenario under both Legacy and Tiered loader strategies (with
identical overrides) and emits a comparative perf report.

See header comments for output layout.
USAGE
  exit 2
}

# -----------------------------------------------------------------------------
# Arg parsing
# -----------------------------------------------------------------------------

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  _usage
fi

HYPOTHESIS_ID="$1"
SCENARIO_PATH_INPUT="$2"
OVERRIDE_SEXP="${3:-}"

# Reject ids that would escape the experiments/perf/ directory or pollute
# tools that consume the dirname (e.g. shell completion of report.md).
case "$HYPOTHESIS_ID" in
  */* | ..* | "")
    _die "hypothesis-id must be a single non-empty path component (got: '$HYPOTHESIS_ID')"
    ;;
esac

# Resolve repo root + dune workspace. The script lives at
# <repo-root>/dev/scripts/run_perf_hypothesis.sh — climb two levels.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DUNE_ROOT="$REPO_ROOT/trading"

[ -f "$DUNE_ROOT/dune-workspace" ] \
  || _die "dune workspace not found at $DUNE_ROOT/dune-workspace"

# Accept either an absolute path or one relative to the repo root.
if [ -f "$SCENARIO_PATH_INPUT" ]; then
  SCENARIO_PATH="$(cd "$(dirname "$SCENARIO_PATH_INPUT")" && pwd)/$(basename "$SCENARIO_PATH_INPUT")"
elif [ -f "$REPO_ROOT/$SCENARIO_PATH_INPUT" ]; then
  SCENARIO_PATH="$REPO_ROOT/$SCENARIO_PATH_INPUT"
else
  _die "scenario sexp not found: $SCENARIO_PATH_INPUT"
fi

OUT_DIR="$REPO_ROOT/dev/experiments/perf/$HYPOTHESIS_ID"
mkdir -p "$OUT_DIR"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# Extract the [start_date] from the scenario's [period] sexp. Mirrors the
# tiered_loader_ab_compare.sh extraction pattern so identical scenarios
# produce identical date arguments.
_scenario_start() {
  sexp_path="$1"
  grep -E '\(start_date[[:space:]]' "$sexp_path" \
    | head -1 \
    | sed -E 's/.*\(start_date[[:space:]]+([0-9-]+).*/\1/'
}

# Extract the [end_date] from the scenario's [period] sexp.
_scenario_end() {
  sexp_path="$1"
  grep -E '\(end_date[[:space:]]' "$sexp_path" \
    | head -1 \
    | sed -E 's/.*\(end_date[[:space:]]+([0-9-]+).*/\1/'
}

# Probe for GNU time. /usr/bin/time -f '%M' is a GNU-time extension; the
# shell builtin `time` has no -f / -o flags. Probe the canonical path so
# we don't mistake the builtin for the GNU binary.
if [ -x /usr/bin/time ]; then
  _HAVE_GNU_TIME=1
else
  _HAVE_GNU_TIME=0
fi

# Run a single backtest under the given loader strategy. Captures peak
# RSS (when /usr/bin/time is present) and per-phase trace metrics.
#
# When OVERRIDE_SEXP is non-empty, the override flag is supplied to BOTH
# runs identically — the harness is a single-knob A/B over loader
# strategy, NOT a sweep over override values. (Sweeps belong in a
# wrapper that calls this script multiple times.)
#
# POSIX sh has no arrays; we conditionally include the flag-pair.
_run_backtest() {
  strategy="$1"
  out_prefix="$2"
  log_path="${out_prefix}.log"
  peak_rss_path="${out_prefix}.peak_rss_kb"
  trace_path="${out_prefix}.trace.sexp"

  set +e
  if [ -n "$OVERRIDE_SEXP" ] && [ "$_HAVE_GNU_TIME" = "1" ]; then
    (
      cd "$DUNE_ROOT"
      /usr/bin/time -o "$peak_rss_path" -f '%M' \
        dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
          "$START_DATE" "$END_DATE" \
          --loader-strategy "$strategy" \
          --trace "$trace_path" \
          --override "$OVERRIDE_SEXP"
    ) >"$log_path" 2>&1
  elif [ -n "$OVERRIDE_SEXP" ]; then
    (
      cd "$DUNE_ROOT"
      dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
        "$START_DATE" "$END_DATE" \
        --loader-strategy "$strategy" \
        --trace "$trace_path" \
        --override "$OVERRIDE_SEXP"
    ) >"$log_path" 2>&1
    printf 'UNAVAILABLE\n' >"$peak_rss_path"
  elif [ "$_HAVE_GNU_TIME" = "1" ]; then
    (
      cd "$DUNE_ROOT"
      /usr/bin/time -o "$peak_rss_path" -f '%M' \
        dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
          "$START_DATE" "$END_DATE" \
          --loader-strategy "$strategy" \
          --trace "$trace_path"
    ) >"$log_path" 2>&1
  else
    (
      cd "$DUNE_ROOT"
      dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
        "$START_DATE" "$END_DATE" \
        --loader-strategy "$strategy" \
        --trace "$trace_path"
    ) >"$log_path" 2>&1
    printf 'UNAVAILABLE\n' >"$peak_rss_path"
  fi
  rc=$?
  set -e

  if [ "$rc" -ne 0 ]; then
    _die "backtest_runner ($strategy) exited $rc — see $log_path"
  fi

  [ -f "$trace_path" ] \
    || _die "trace sexp not produced for $strategy run — see $log_path"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

START_DATE=$(_scenario_start "$SCENARIO_PATH")
END_DATE=$(_scenario_end "$SCENARIO_PATH")

[ -n "$START_DATE" ] \
  || _die "could not extract start_date from $SCENARIO_PATH"
[ -n "$END_DATE" ] \
  || _die "could not extract end_date from $SCENARIO_PATH"

printf 'Hypothesis : %s\n' "$HYPOTHESIS_ID"
printf 'Scenario   : %s\n' "$SCENARIO_PATH"
printf 'Dates      : %s .. %s\n' "$START_DATE" "$END_DATE"
printf 'Override   : %s\n' "${OVERRIDE_SEXP:-(none)}"
printf 'Out dir    : %s\n' "$OUT_DIR"

# Build binaries up front so the two backtest invocations run back-to-back
# without dune-rebuild interleaving (otherwise the second run's wall-clock
# numbers would include build time).
printf 'Building backtest_runner.exe...\n'
(cd "$DUNE_ROOT" && dune build trading/backtest/bin/backtest_runner.exe) \
  || _die "dune build failed"

printf 'Running Legacy...\n'
_run_backtest legacy "$OUT_DIR/legacy"

printf 'Running Tiered...\n'
_run_backtest tiered "$OUT_DIR/tiered"

# -----------------------------------------------------------------------------
# Generate repro.sh — single source of truth for re-running the experiment.
# -----------------------------------------------------------------------------

REPRO_PATH="$OUT_DIR/repro.sh"
{
  printf '#!/bin/sh\n'
  printf '# Auto-generated by dev/scripts/run_perf_hypothesis.sh on %s.\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '# Hypothesis : %s\n' "$HYPOTHESIS_ID"
  printf '# Scenario   : %s\n' "$SCENARIO_PATH"
  printf '# Override   : %s\n' "${OVERRIDE_SEXP:-(none)}"
  printf 'set -eu\n'
  printf 'cd "$(dirname "$0")/../../.."\n'
  if [ -n "$OVERRIDE_SEXP" ]; then
    # Single-quote the override sexp; sexps don't contain single quotes
    # in any of our hypothesis catalog entries, but if a future override
    # ever does, the user gets a regen failure instead of a silent
    # mis-quote — which is the conservative behavior.
    case "$OVERRIDE_SEXP" in
      *"'"*) _die "override sexp contains a single quote — refusing to emit unsafe repro.sh: $OVERRIDE_SEXP" ;;
    esac
    printf "exec dev/scripts/run_perf_hypothesis.sh '%s' '%s' '%s'\n" \
      "$HYPOTHESIS_ID" "$SCENARIO_PATH" "$OVERRIDE_SEXP"
  else
    printf "exec dev/scripts/run_perf_hypothesis.sh '%s' '%s'\n" \
      "$HYPOTHESIS_ID" "$SCENARIO_PATH"
  fi
} >"$REPRO_PATH"
chmod +x "$REPRO_PATH"

# -----------------------------------------------------------------------------
# Generate report.md via the Python helper.
# -----------------------------------------------------------------------------

REPORT_PATH="$OUT_DIR/report.md"
python3 "$SCRIPT_DIR/perf_hypothesis_report.py" \
  --out-dir "$OUT_DIR" \
  --hypothesis-id "$HYPOTHESIS_ID" \
  --scenario "$SCENARIO_PATH" \
  --start-date "$START_DATE" \
  --end-date "$END_DATE" \
  --override "$OVERRIDE_SEXP" \
  >"$REPORT_PATH"

printf 'Done. Report: %s\n' "$REPORT_PATH"
