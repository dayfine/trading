#!/bin/sh
# Tiered-loader A/B comparison script.
#
# Runs a single backtest under both Loader_strategy.Legacy and
# Loader_strategy.Tiered for the same date range, then diffs the resulting
# output directories.
#
# Usage:
#   dev/scripts/tiered_loader_ab_compare.sh <scenario.sexp> <out_dir>
#
# Inputs:
#   scenario.sexp  Absolute path to a scenario file under
#                  trading/test_data/backtest_scenarios/ (or a freestanding
#                  sexp with the same shape). Only the [period] and [name]
#                  fields are consumed here — the other fields (expected
#                  ranges, universe_path, config_overrides) are ignored.
#                  The script assumes the broad-universe default (full
#                  data/sectors.csv), matching goldens-broad/*.sexp.
#   out_dir        Destination directory (created if missing). The script
#                  writes:
#                    <out_dir>/legacy/    full backtest output tree
#                    <out_dir>/tiered/    full backtest output tree
#                    <out_dir>/diff.txt   human-readable comparison summary
#                    <out_dir>/*.log      stdout/stderr from each run
#
# Exit status:
#   0 — runs completed and trade-count matches across strategies. A
#       portfolio-value drift above the warn threshold still exits 0 but
#       emits a GitHub Actions workflow annotation (::warning::) so the
#       nightly workflow surfaces the drift without failing the job.
#   1 — hard parity violation: trade-count diff != 0, either run failed to
#       produce trades.csv, or required tooling is missing. See also plan
#       dev/plans/backtest-tiered-loader-2026-04-19.md §Resolutions #1.
#
# Parity contract (plan §Resolutions #1):
#   Hard gate : trade-count diff == 0.
#   Warn gate : |legacy_pv - tiered_pv| <= max($1.00, 0.001% of legacy_pv).
#
# Scenarios (plan §Resolutions #2): nominally the 3 broad goldens under
# trading/test_data/backtest_scenarios/goldens-broad/ —
# bull-crash-2015-2020.sexp, covid-recovery-2020-2024.sexp, and
# six-year-2018-2023.sexp. Any scenario with a valid [(period ...)] block
# works; the comparison is scenario-agnostic.
#
# POSIX sh only. Covered by the devtools/checks posix_sh_check.sh linter.

set -eu

_die() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

_usage() {
  cat <<USAGE >&2
Usage: dev/scripts/tiered_loader_ab_compare.sh <scenario.sexp> <out_dir>

Runs one scenario under both Legacy and Tiered loader strategies and writes
a comparison summary. See header comments for the parity contract.
USAGE
  exit 2
}

# -----------------------------------------------------------------------------
# Arg parsing
# -----------------------------------------------------------------------------

if [ "$#" -ne 2 ]; then
  _usage
fi

SCENARIO_SEXP="$1"
OUT_DIR="$2"

[ -f "$SCENARIO_SEXP" ] || _die "scenario sexp not found: $SCENARIO_SEXP"

# Resolve repo root so dune exec runs from the dune workspace root. The
# script lives at <repo-root>/dev/scripts/tiered_loader_ab_compare.sh;
# climb two levels.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DUNE_ROOT="$REPO_ROOT/trading"

[ -f "$DUNE_ROOT/dune-workspace" ] \
  || _die "dune workspace not found at $DUNE_ROOT/dune-workspace"

mkdir -p "$OUT_DIR"
OUT_DIR_ABS="$(cd "$OUT_DIR" && pwd)"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# Extract the [name] field from a scenario sexp. First data-bearing line is
# conventionally '((name "foo") ...)' (or '((name foo) ...)').
_scenario_name() {
  sexp_path="$1"
  grep -E '^[[:space:]]*\(\(name ' "$sexp_path" \
    | head -1 \
    | sed -E 's/^[[:space:]]*\(\(name[[:space:]]+"?([^")]+)"?.*$/\1/'
}

# Extract the [start_date] from the scenario's [period] sexp.
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

# Run backtest_runner and parse its "Output written to: <path>/" stderr to
# locate the timestamped output directory. scenario_runner creates a fresh
# directory per run so this is race-free as long as the two invocations are
# at least 1 second apart (enforced by the wall-clock gap between two full
# backtest runs).
#
# Peak RSS capture: when GNU time (/usr/bin/time) is available, wraps the
# dune exec and writes the run's maximum resident set size to
# $log_path.peak_rss_kb (integer, kilobytes). When absent, writes the string
# "UNAVAILABLE" instead — the comparison path treats that like any other
# missing value and emits an annotation without failing the job. We probe
# /usr/bin/time once at module load (see _have_gnu_time below) to avoid
# per-run fork overhead.
_run_backtest() {
  strategy="$1"
  log_path="$2"
  peak_rss_path="$log_path.peak_rss_kb"
  set +e
  if [ "$_HAVE_GNU_TIME" = "1" ]; then
    (
      cd "$DUNE_ROOT"
      /usr/bin/time -o "$peak_rss_path" -f '%M' \
        dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
          "$START_DATE" "$END_DATE" --loader-strategy "$strategy"
    ) >"$log_path.stdout" 2>"$log_path.stderr"
  else
    (
      cd "$DUNE_ROOT"
      dune exec --no-build -- trading/backtest/bin/backtest_runner.exe \
        "$START_DATE" "$END_DATE" --loader-strategy "$strategy"
    ) >"$log_path.stdout" 2>"$log_path.stderr"
    printf 'UNAVAILABLE\n' >"$peak_rss_path"
  fi
  rc=$?
  set -e
  cat "$log_path.stdout" >"$log_path"
  printf -- '----- stderr -----\n' >>"$log_path"
  cat "$log_path.stderr" >>"$log_path"
  if [ "$rc" -ne 0 ]; then
    _die "backtest_runner ($strategy) exited $rc — see $log_path"
  fi
  # Match "Output written to: <path>/" on stderr; the trailing slash is
  # emitted by the runner. Strip it for easier downstream handling.
  output_dir=$(grep -E '^Output written to: ' "$log_path.stderr" \
    | head -1 \
    | sed -E 's/^Output written to: (.+)\/?$/\1/' \
    | sed -E 's/\/$//')
  if [ -z "$output_dir" ] || [ ! -d "$output_dir" ]; then
    _die "could not locate backtest_runner output dir (log: $log_path)"
  fi
  printf '%s\n' "$output_dir"
}

# Peak-RSS tooling probe. /usr/bin/time -f '%M' is a GNU-time extension; the
# shell builtin `time` has no -f / -o flags. We require the binary at the
# canonical path — probing $(command -v time) would pick up the builtin.
if [ -x /usr/bin/time ]; then
  _HAVE_GNU_TIME=1
else
  _HAVE_GNU_TIME=0
fi

# Count data rows (excluding header) in trades.csv. Returns [MISSING] if
# the file is absent.
_trade_count() {
  csv_path="$1"
  if [ ! -f "$csv_path" ]; then
    printf 'MISSING\n'
    return
  fi
  # wc -l counts newlines; subtract 1 for the header.
  total=$(wc -l < "$csv_path")
  printf '%d\n' "$((total - 1))"
}

# Extract final_portfolio_value from summary.sexp.
_final_portfolio_value() {
  sexp_path="$1"
  if [ ! -f "$sexp_path" ]; then
    printf 'MISSING\n'
    return
  fi
  grep -E '\(final_portfolio_value[[:space:]]' "$sexp_path" \
    | head -1 \
    | sed -E 's/.*\(final_portfolio_value[[:space:]]+([0-9.+-eE]+).*/\1/'
}

# Absolute-value delta of two decimal numbers. Uses awk for portability
# (POSIX `bc` is not in the devcontainer image; awk always is).
_abs_delta() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    d = a - b
    if (d < 0) d = -d
    printf "%.4f\n", d
  }'
}

# Compute the portfolio-value warn threshold per plan §Resolutions #1:
# max($1.00, 0.001% of legacy_pv).
_pv_warn_threshold() {
  awk -v pv="$1" 'BEGIN {
    t = pv * 0.00001
    if (t < 1.0) t = 1.0
    printf "%.4f\n", t
  }'
}

# Returns 0 (true) iff a > b (both floats).
_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit (a > b) ? 0 : 1 }'
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

SCENARIO_NAME=$(_scenario_name "$SCENARIO_SEXP")
START_DATE=$(_scenario_start "$SCENARIO_SEXP")
END_DATE=$(_scenario_end "$SCENARIO_SEXP")

[ -n "$SCENARIO_NAME" ] \
  || _die "could not extract scenario name from $SCENARIO_SEXP"
[ -n "$START_DATE" ] \
  || _die "could not extract start_date from $SCENARIO_SEXP"
[ -n "$END_DATE" ] \
  || _die "could not extract end_date from $SCENARIO_SEXP"

printf 'A/B compare: scenario=%s\n' "$SCENARIO_NAME"
printf '  input      : %s\n' "$SCENARIO_SEXP"
printf '  dates      : %s .. %s\n' "$START_DATE" "$END_DATE"
printf '  out_dir    : %s\n' "$OUT_DIR_ABS"

# Build binaries up front so the two backtest invocations run back-to-back
# rather than interleaving with dune rebuild work.
printf 'Building backtest_runner.exe...\n'
(cd "$DUNE_ROOT" && dune build trading/backtest/bin/backtest_runner.exe) \
  || _die "dune build failed"

printf 'Running Legacy...\n'
LEGACY_SRC=$(_run_backtest legacy "$OUT_DIR_ABS/legacy.log")
printf 'Legacy output: %s\n' "$LEGACY_SRC"

printf 'Running Tiered...\n'
TIERED_SRC=$(_run_backtest tiered "$OUT_DIR_ABS/tiered.log")
printf 'Tiered output: %s\n' "$TIERED_SRC"

# backtest_runner writes to a timestamped dev/backtest/<ts>/ directory —
# mirror into $OUT_DIR/legacy/ and $OUT_DIR/tiered/ so the artefact layout
# is stable and easy for the workflow to upload.
LEGACY_DIR="$OUT_DIR_ABS/legacy"
TIERED_DIR="$OUT_DIR_ABS/tiered"
rm -rf "$LEGACY_DIR" "$TIERED_DIR"
cp -r "$LEGACY_SRC" "$LEGACY_DIR"
cp -r "$TIERED_SRC" "$TIERED_DIR"

# -----------------------------------------------------------------------------
# Parity comparison
# -----------------------------------------------------------------------------

LEGACY_TRADES=$(_trade_count "$LEGACY_DIR/trades.csv")
TIERED_TRADES=$(_trade_count "$TIERED_DIR/trades.csv")
LEGACY_PV=$(_final_portfolio_value "$LEGACY_DIR/summary.sexp")
TIERED_PV=$(_final_portfolio_value "$TIERED_DIR/summary.sexp")

# Peak-RSS read (written by _run_backtest via /usr/bin/time -f '%M'). When
# GNU time is unavailable the file contains "UNAVAILABLE" — treat that as a
# soft signal, no gating. Values from /usr/bin/time -f '%M' are in kilobytes.
LEGACY_RSS=$(head -1 "$OUT_DIR_ABS/legacy.log.peak_rss_kb" 2>/dev/null || echo UNAVAILABLE)
TIERED_RSS=$(head -1 "$OUT_DIR_ABS/tiered.log.peak_rss_kb" 2>/dev/null || echo UNAVAILABLE)

DIFF_FILE="$OUT_DIR_ABS/diff.txt"
{
  printf 'Scenario       : %s\n' "$SCENARIO_NAME"
  printf 'Dates          : %s .. %s\n' "$START_DATE" "$END_DATE"
  printf 'Legacy trades  : %s\n' "$LEGACY_TRADES"
  printf 'Tiered trades  : %s\n' "$TIERED_TRADES"
  printf 'Legacy final PV: %s\n' "$LEGACY_PV"
  printf 'Tiered final PV: %s\n' "$TIERED_PV"
  printf 'Legacy peak RSS: %s KB\n' "$LEGACY_RSS"
  printf 'Tiered peak RSS: %s KB\n' "$TIERED_RSS"
} | tee "$DIFF_FILE"

# Hard gate: trades.csv must exist on both sides.
if [ "$LEGACY_TRADES" = "MISSING" ] || [ "$TIERED_TRADES" = "MISSING" ]; then
  printf '::error::A/B compare %s — trades.csv missing (legacy=%s tiered=%s)\n' \
    "$SCENARIO_NAME" "$LEGACY_TRADES" "$TIERED_TRADES"
  printf 'HARD PARITY FAIL: trades.csv missing for at least one strategy\n' \
    >>"$DIFF_FILE"
  exit 1
fi

# Hard gate: trade-count diff == 0.
if [ "$LEGACY_TRADES" != "$TIERED_TRADES" ]; then
  printf '::error::A/B compare %s — trade-count diff: legacy=%s tiered=%s\n' \
    "$SCENARIO_NAME" "$LEGACY_TRADES" "$TIERED_TRADES"
  printf 'HARD PARITY FAIL: trade-count diff (legacy=%s tiered=%s)\n' \
    "$LEGACY_TRADES" "$TIERED_TRADES" >>"$DIFF_FILE"
  exit 1
fi

# Warn gate: portfolio-value drift above max($1.00, 0.001% of legacy_pv).
if [ "$LEGACY_PV" = "MISSING" ] || [ "$TIERED_PV" = "MISSING" ]; then
  printf '::warning::A/B compare %s — summary.sexp missing PV (legacy=%s tiered=%s)\n' \
    "$SCENARIO_NAME" "$LEGACY_PV" "$TIERED_PV"
  printf 'WARN: summary.sexp final_portfolio_value missing\n' >>"$DIFF_FILE"
  exit 0
fi

PV_DELTA=$(_abs_delta "$LEGACY_PV" "$TIERED_PV")
PV_WARN=$(_pv_warn_threshold "$LEGACY_PV")
printf 'PV delta       : $%s (warn threshold $%s)\n' "$PV_DELTA" "$PV_WARN" \
  | tee -a "$DIFF_FILE"

if _gt "$PV_DELTA" "$PV_WARN"; then
  printf '::warning::A/B compare %s — PV drift $%s exceeds warn threshold $%s (legacy=$%s tiered=$%s)\n' \
    "$SCENARIO_NAME" "$PV_DELTA" "$PV_WARN" "$LEGACY_PV" "$TIERED_PV"
  printf 'WARN: PV drift $%s > threshold $%s\n' "$PV_DELTA" "$PV_WARN" \
    >>"$DIFF_FILE"
else
  printf 'OK: PV drift within threshold\n' | tee -a "$DIFF_FILE"
fi

# Observational: peak RSS comparison. This is the whole point of Tiered —
# `Bar_history` should grow for only `full_candidate_limit + held_positions`
# symbols instead of the full universe. Not a gate: we report the delta and
# the Tiered/Legacy ratio as a `::notice::` annotation so post-merge we can
# eyeball whether the expected ~30× reduction is materializing on broad
# goldens. Gating would require calibrated thresholds per scenario, which
# we don't have yet.
if [ "$LEGACY_RSS" = "UNAVAILABLE" ] || [ "$TIERED_RSS" = "UNAVAILABLE" ]; then
  printf 'RSS            : UNAVAILABLE (/usr/bin/time not installed in container)\n' \
    | tee -a "$DIFF_FILE"
elif ! echo "$LEGACY_RSS$TIERED_RSS" | grep -qE '^[0-9]+[0-9]+$'; then
  printf 'RSS            : MALFORMED (legacy=%s tiered=%s)\n' "$LEGACY_RSS" "$TIERED_RSS" \
    | tee -a "$DIFF_FILE"
else
  # Ratio = tiered / legacy, formatted to 3 decimal places. <1.0 is a win.
  RSS_RATIO=$(awk -v t="$TIERED_RSS" -v l="$LEGACY_RSS" 'BEGIN {
    if (l == 0) { printf "n/a (legacy=0)"; exit }
    printf "%.3f", t / l
  }')
  printf 'Peak RSS ratio : %s (tiered/legacy; <1.0 is a memory win)\n' "$RSS_RATIO" \
    | tee -a "$DIFF_FILE"
  printf '::notice::A/B compare %s — peak RSS legacy=%s KB tiered=%s KB ratio=%s\n' \
    "$SCENARIO_NAME" "$LEGACY_RSS" "$TIERED_RSS" "$RSS_RATIO"
fi

printf 'OK: trade-count parity holds for %s\n' "$SCENARIO_NAME"
exit 0
