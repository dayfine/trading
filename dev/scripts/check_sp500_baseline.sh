#!/usr/bin/env bash
# check_sp500_baseline.sh — regression-check sp500-2019-2023 metrics against
# the pinned post-revert baseline this partial-revert PR (#828 strategy
# bar_reader, closes #843) establishes.
#
# Why this is local-only: the goldens-sp500 fixture references ~500 per-symbol
# CSV files under data/<X>/<Y>/<SYMBOL>/data.csv. That corpus is gitignored
# (licensing, ~hundreds of MB). GHA runners cannot run this — same constraint
# as the tier-4 release gate (see dev/notes/tier4-release-gate-checklist-
# 2026-04-28.md §"Why local-only").
#
# Usage:
#   dev/scripts/check_sp500_baseline.sh
#     [--out-dir <path>]      Where the scenario_runner writes per-scenario
#                             output (default: a fresh dev/backtest/sp500-
#                             baseline-<UTC-timestamp>/ directory)
#     [--repo-root <path>]    Repo root containing trading/ + data/
#                             (default: /workspaces/trading-1, the in-container
#                             path; pass the host path when running outside)
#     [--quiet]               Print only the final PASS/FAIL line
#
# Pinned baseline (post-partial-revert on the 503-symbol sp500.sexp universe,
# measured 2026-05-04 against commit landing the partial revert; the scenario
# fixture's tagged baseline of 60.86%/86 was on the older 491-symbol universe
# pre-#807 universe refresh). With the 503-symbol universe + partial revert:
#
#   total_return_pct  53.36  ±2.0pp   (broken state on 503: 40.3 — outside)
#   total_trades      73     ±5      (broken state on 503: 93 — outside)
#   sharpe_ratio      0.52   ±0.05   (broken state on 503: 0.45 — outside)
#   max_drawdown_pct  32.52  ±1.5pp  (broken state on 503: 29.6 — outside)
#   win_rate          21.92  ±2.0pp  (broken state on 503: 19.3 — borderline)
#
# Tolerances are picked to (a) absorb float epsilon, (b) catch the specific
# regression that triggered #843 (broken state values are all OUT of every
# tolerance range simultaneously), (c) NOT mask future legitimate behavior
# changes that move metrics meaningfully. Re-pin via PR if a deliberate
# strategy change shifts these — do not bump tolerances to absorb regressions
# (mirror of goldens-sp500 fixture's pinning rule).
#
# These tolerances are TIGHTER than the goldens-sp500 fixture's (expected ...)
# ranges, which absorb the ±2w start-date fuzz IQR. Both gates should hold
# post-fix; this script catches regressions inside the fixture's slack.
#
# Output:
#   sp500-baseline: total_return_pct=<actual> trades=<actual> ...
#   sp500-baseline: PASS / FAIL (<reason>)
#
# Exit codes:
#   0  every metric within its tolerance
#   1  one or more metrics outside tolerance
#   2  setup error (build failed, scenario_runner not found, actual.sexp
#      missing, etc.)
#
# Reference:
#   - dev/notes/parity-bisect-2026-05-04.md  (bisect history)
#   - dev/plans/parity-revert-pr828-strategy-bar-reader-2026-05-04.md (plan)
#   - trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp
#     (canonical fixture; see header comment for the baseline rationale)

set -euo pipefail

# Pinned tolerances. Centralised here so a re-pin updates one place. Keep the
# strictest tolerance the gate passes under — slack just to absorb float
# epsilon, NOT to mask new behaviour drift (per goldens-sp500 fixture's
# "don't bump these to absorb regressions"). Values measured on the
# 503-symbol sp500.sexp universe with the partial revert applied.
readonly BASELINE_RETURN=53.36
readonly RETURN_TOLERANCE=2.0
readonly BASELINE_TRADES=73
readonly TRADES_TOLERANCE=5
readonly BASELINE_SHARPE=0.52
readonly SHARPE_TOLERANCE=0.05
readonly BASELINE_MAXDD=32.52
readonly MAXDD_TOLERANCE=1.5
readonly BASELINE_WIN_RATE=21.92
readonly WIN_RATE_TOLERANCE=2.0

repo_root="/workspaces/trading-1"
out_dir=""
quiet=false

while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root)  repo_root="$2"; shift 2 ;;
    --out-dir)    out_dir="$2";   shift 2 ;;
    --quiet)      quiet=true;     shift ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "[sp500-baseline] unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

cd "$repo_root"

if [ ! -d "trading/test_data/backtest_scenarios/goldens-sp500" ]; then
  echo "[sp500-baseline] fixture dir missing: trading/test_data/backtest_scenarios/goldens-sp500" >&2
  echo "[sp500-baseline]   (running from --repo-root '$repo_root')" >&2
  exit 2
fi

if [ ! -d "data" ]; then
  echo "[sp500-baseline] data/ dir missing in $repo_root — corpus not present" >&2
  echo "[sp500-baseline]   (per-symbol CSVs under data/<X>/<Y>/<SYMBOL>/data.csv are gitignored)" >&2
  exit 2
fi

# Build the runner. Skip rebuild if it's already present and newer than the
# touched lib files; dune already does this incrementally so we just invoke it.
runner_exe="trading/_build/default/trading/backtest/scenarios/scenario_runner.exe"
$quiet || echo "[sp500-baseline] building scenario_runner..."
( cd trading && dune build trading/backtest/scenarios/scenario_runner.exe ) \
  >/dev/null 2>&1 || {
  echo "[sp500-baseline] dune build scenario_runner.exe failed" >&2
  exit 2
}
if [ ! -x "$runner_exe" ]; then
  echo "[sp500-baseline] runner exe missing post-build: $runner_exe" >&2
  exit 2
fi

# Pick / create the output directory the runner writes into.
if [ -z "$out_dir" ]; then
  ts="$(date -u +%Y-%m-%d-%H%M%S)"
  out_dir="dev/backtest/sp500-baseline-${ts}"
fi
mkdir -p "$out_dir"

# Stage the fixture into a per-call dir (the runner enumerates *.sexp in --dir
# and writes per-scenario output under dev/backtest/scenarios-<ts>/<name>/).
# We just point at the canonical fixture dir and read back actual.sexp from
# the most-recently-written scenarios-* dir — simpler than mucking with
# fixtures-root.
$quiet || echo "[sp500-baseline] running sp500-2019-2023 (this takes 30-90 minutes)..."
"$runner_exe" --dir trading/test_data/backtest_scenarios/goldens-sp500 \
  --parallel 1 \
  >"$out_dir/runner.log" 2>&1 || {
  echo "[sp500-baseline] scenario_runner exited non-zero — see $out_dir/runner.log" >&2
  tail -30 "$out_dir/runner.log" >&2
  exit 2
}

# Find the actual.sexp the runner just wrote. The runner names its output
# dir with a timestamp; pick the newest sp500-2019-2023/actual.sexp under
# dev/backtest/.
actual_sexp=$(find dev/backtest -mindepth 3 -maxdepth 4 \
  -path '*sp500-2019-2023/actual.sexp' -printf '%T@ %p\n' 2>/dev/null \
  | sort -n | tail -1 | awk '{print $2}')

if [ -z "$actual_sexp" ] || [ ! -f "$actual_sexp" ]; then
  echo "[sp500-baseline] no actual.sexp found under dev/backtest/scenarios-*/sp500-2019-2023/" >&2
  echo "[sp500-baseline]   (look in $out_dir/runner.log for runner output)" >&2
  exit 2
fi

$quiet || echo "[sp500-baseline] reading $actual_sexp"

# Extract metrics via sed. The actual.sexp shape is:
#   ((total_return_pct N) (total_trades N) (win_rate N) (sharpe_ratio N)
#    (max_drawdown_pct N) (avg_holding_days N) (open_positions_value N)
#    (unrealized_pnl N) (force_liquidations_count N))
# Each (k v) pair is whitespace-separated; the value is the second token.
extract_field() {
  local field="$1"
  sed -n "s/.*($field \\([0-9.eE+-]*\\)).*/\\1/p" "$actual_sexp" | head -1
}

actual_return=$(extract_field total_return_pct)
actual_trades=$(extract_field total_trades)
actual_sharpe=$(extract_field sharpe_ratio)
actual_maxdd=$(extract_field max_drawdown_pct)
actual_winrate=$(extract_field win_rate)

if [ -z "$actual_return" ] || [ -z "$actual_trades" ]; then
  echo "[sp500-baseline] failed to parse actual.sexp — got empty fields" >&2
  cat "$actual_sexp" >&2
  exit 2
fi

# Tolerance check. Use awk for the float math — POSIX shell can't.
within_tolerance() {
  local actual="$1" baseline="$2" tolerance="$3"
  awk -v a="$actual" -v b="$baseline" -v t="$tolerance" \
    'BEGIN { d = a - b; if (d < 0) d = -d; exit !(d <= t) }'
}

failures=()

if ! within_tolerance "$actual_return" "$BASELINE_RETURN" "$RETURN_TOLERANCE"; then
  failures+=("total_return_pct=$actual_return outside ${BASELINE_RETURN} ± ${RETURN_TOLERANCE}")
fi

# total_trades is an integer; tolerate ±TRADES_TOLERANCE.
if ! within_tolerance "${actual_trades%.*}" "$BASELINE_TRADES" "$TRADES_TOLERANCE"; then
  failures+=("total_trades=$actual_trades outside ${BASELINE_TRADES} ± ${TRADES_TOLERANCE}")
fi

if ! within_tolerance "$actual_sharpe" "$BASELINE_SHARPE" "$SHARPE_TOLERANCE"; then
  failures+=("sharpe_ratio=$actual_sharpe outside ${BASELINE_SHARPE} ± ${SHARPE_TOLERANCE}")
fi

if ! within_tolerance "$actual_maxdd" "$BASELINE_MAXDD" "$MAXDD_TOLERANCE"; then
  failures+=("max_drawdown_pct=$actual_maxdd outside ${BASELINE_MAXDD} ± ${MAXDD_TOLERANCE}")
fi

if ! within_tolerance "$actual_winrate" "$BASELINE_WIN_RATE" "$WIN_RATE_TOLERANCE"; then
  failures+=("win_rate=$actual_winrate outside ${BASELINE_WIN_RATE} ± ${WIN_RATE_TOLERANCE}")
fi

# Summary line, always printed (even with --quiet).
printf 'sp500-baseline: return=%s trades=%s win=%s sharpe=%s maxdd=%s\n' \
  "$actual_return" "$actual_trades" "$actual_winrate" "$actual_sharpe" "$actual_maxdd"

if [ "${#failures[@]}" -eq 0 ]; then
  echo "sp500-baseline: PASS"
  exit 0
fi

echo "sp500-baseline: FAIL"
for f in "${failures[@]}"; do
  echo "  - $f"
done
exit 1
