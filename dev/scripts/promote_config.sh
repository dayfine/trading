#!/usr/bin/env bash
# promote_config.sh — promote a tuned config to dayfine/trading-parameters
#
# Usage:
#   promote_config.sh <label> <config_sexp> [<bo_output_dir> [<tuner_spec> [<walk_forward_spec>]]]
#
# Example:
#   promote_config.sh 2026-05-21-bayesian-v3-winner \
#     dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-parallel4/best.sexp \
#     dev/experiments/bayesian-production-sweep-2026-05-18/output-v3-parallel4 \
#     dev/experiments/bayesian-production-sweep-2026-05-18/spec_prod_v3.sexp \
#     dev/experiments/bayesian-production-sweep-2026-05-18/walk_forward_v2_baseline.sexp
#
# Positional args 3-5 are optional; if omitted, the corresponding rows in
# provenance.md are written as "(not supplied)".
#
# What it does:
#   1. Validates inputs (label format, file existence, parameters repo clone).
#   2. Creates configs/<label>/ in the trading-parameters repo with:
#      - config.sexp        (copied from <config_sexp>)
#      - validation.sexp    (cross-scenario validation results, see below)
#      - provenance.md      (auto-generated with commit SHA + scenario metrics)
#      - bo_output/         (symlink or copy of BO output dir, if provided)
#   3. Runs cross-scenario validation (P1 of tuning-methodology-redesign-2026-05-22):
#      - Applies the candidate config's overrides on top of each reference
#        scenario's cell-E baseline and runs the resulting scratch scenario via
#        scenario_runner.exe.
#      - Reads actual.sexp metrics from each run.
#      - Compares Sharpe to the cell-E baseline; refuses promotion if any
#        scenario regresses by more than PROMOTE_SHARPE_REGRESSION_THRESHOLD
#        (default 0.10 absolute Sharpe units).
#      - Writes structured per-scenario metrics + cell-E reference + delta
#        into configs/<label>/validation.sexp.
#   4. Updates live/current.sexp symlink to point at the new config.
#   5. Regenerates _metadata/catalog.sexp from configs/*/provenance.md.
#   6. Commits in the trading-parameters repo with format:
#      `promote: <label> — trading@<sha>`
#
# Environment:
#   TRADING_PARAMS_DIR
#       Path to the trading-parameters clone.
#       Default: ~/Projects/trading-parameters
#
#   PROMOTE_SHARPE_REGRESSION_THRESHOLD
#       Maximum allowed Sharpe regression vs cell-E baseline on any scenario,
#       in absolute Sharpe units. Default 0.10 (i.e. a candidate may not score
#       0.10 lower Sharpe than cell-E on any panel scenario).
#
#   PROMOTE_MAXDD_INCREASE_THRESHOLD
#       Maximum allowed MaxDD increase vs cell-E baseline on any scenario, in
#       absolute percentage points. Default 5.0 (i.e. a candidate whose MaxDD
#       exceeds cell-E by more than 5pp on any panel scenario is refused).
#       Per Option E (dev/plans/bayesian-production-sweep-2026-05-18.md §6).
#
#   PROMOTE_TRADES_RATIO_MAX
#       Maximum allowed ratio between candidate and baseline total_trades on
#       any scenario (in either direction). Default 2.0 (i.e. a candidate that
#       trades more than 2x or less than 0.5x of cell-E is refused).
#       Catches strategies that trade radically differently from baseline.
#
#   PROMOTE_SKIP_VALIDATION
#       If set to "1", skip cross-scenario validation entirely. Useful for
#       smoke-testing the promote machinery in environments that lack the
#       per-symbol bars corpus (e.g. GHA). Validation.sexp records the skip.
#
#   PROMOTE_VALIDATION_PARALLEL
#       Number of scenarios to run in parallel. Default 2 (the panel size).
#
# Exits non-zero on:
#   - missing required argument
#   - label already exists in configs/
#   - source config.sexp not found
#   - trading-parameters repo not a git checkout
#   - cross-scenario validation gate failure (refuses promotion; cleans up
#     target_dir; does NOT touch live/current.sexp or commit)
#   - any sub-command failure (set -euo pipefail)

set -euo pipefail

# Source extract_metrics helpers used by the cross-scenario validation step.
# shellcheck disable=SC1091
. "$(dirname "$0")/lib/extract_metrics.sh"

# ---------------------------------------------------------------------------
# Args + validation
# ---------------------------------------------------------------------------

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <label> <config_sexp> [<bo_output_dir> [<tuner_spec> [<walk_forward_spec>]]]" >&2
  exit 1
fi

label="$1"
config_sexp="$2"
bo_output_dir="${3:-}"
tuner_spec="${4:-}"
walk_forward_spec="${5:-}"

# Label format: YYYY-MM-DD-<slug>. Forbid path-traversal characters.
if ! echo "$label" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-zA-Z0-9._-]+$'; then
  echo "Error: label must match 'YYYY-MM-DD-<slug>' (got: $label)" >&2
  exit 1
fi

if [ ! -f "$config_sexp" ]; then
  echo "Error: config sexp not found: $config_sexp" >&2
  exit 1
fi

if [ -n "$bo_output_dir" ] && [ ! -d "$bo_output_dir" ]; then
  echo "Error: bo_output_dir not found: $bo_output_dir" >&2
  exit 1
fi

if [ -n "$tuner_spec" ] && [ ! -f "$tuner_spec" ]; then
  echo "Error: tuner_spec not found: $tuner_spec" >&2
  exit 1
fi

if [ -n "$walk_forward_spec" ] && [ ! -f "$walk_forward_spec" ]; then
  echo "Error: walk_forward_spec not found: $walk_forward_spec" >&2
  exit 1
fi

TRADING_PARAMS_DIR="${TRADING_PARAMS_DIR:-$HOME/Projects/trading-parameters}"

if [ ! -d "$TRADING_PARAMS_DIR/.git" ]; then
  echo "Error: trading-parameters repo not found at $TRADING_PARAMS_DIR" >&2
  echo "Hint: clone with 'gh repo clone dayfine/trading-parameters $TRADING_PARAMS_DIR'" >&2
  exit 1
fi

target_dir="$TRADING_PARAMS_DIR/configs/$label"
if [ -e "$target_dir" ]; then
  echo "Error: configs/$label already exists; pick a new label or remove existing" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Capture provenance metadata
# ---------------------------------------------------------------------------

# We use the trading repo at the script's location to capture commit SHA.
trading_repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
trading_sha="$(cd "$trading_repo_root" && git rev-parse HEAD)"
trading_short_sha="$(cd "$trading_repo_root" && git rev-parse --short HEAD)"

# If the trading repo working copy has MODIFICATIONS to tracked files, refuse.
# The captured SHA must exist in the local clone for consumers to reproduce.
#
# We use `--diff-filter=M` to filter to Modifications only (excluding Added /
# Deleted / Renamed) — both `git diff` and `git diff-index` treat intent-to-add
# markers (set by jj-colocated workflows on untracked files when git status is
# invoked) as Added entries, even though those files aren't modifications of
# tracked content. The `M`-only filter excludes intent-to-add (which shows up
# as `A`) but still catches real worktree-vs-HEAD modifications of tracked
# files — which is what actually affects SHA reproducibility.
#
# (PR #1257 first attempted `git diff` vs `git diff-index` — qc-behavioral
# correctly noted the two are equivalent for intent-to-add markers in modern
# git. This second iteration uses the diff-filter approach instead.)
if ! (cd "$trading_repo_root" && git diff --diff-filter=M --quiet HEAD --); then
  echo "Error: trading repo working copy has uncommitted modifications to tracked files" >&2
  echo "Hint: commit + push your changes, or use git stash, before promoting" >&2
  exit 1
fi

promotion_date="$(date '+%Y-%m-%d %H:%M:%S %Z')"

# ---------------------------------------------------------------------------
# Stage files in target_dir
# ---------------------------------------------------------------------------

mkdir -p "$target_dir"
cp "$config_sexp" "$target_dir/config.sexp"

if [ -n "$bo_output_dir" ]; then
  mkdir -p "$target_dir/bo_output"
  # Copy bo_log.csv, best.sexp, convergence.md, oos_report.md (the artefacts;
  # skip bo_checkpoint.sexp which is internal state).
  for f in bo_log.csv best.sexp convergence.md oos_report.md; do
    if [ -f "$bo_output_dir/$f" ]; then
      cp "$bo_output_dir/$f" "$target_dir/bo_output/$f"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Cross-scenario validation (P1 of tuning-methodology-redesign-2026-05-22)
# ---------------------------------------------------------------------------
#
# Per scenario in the reference panel, compose a scratch scenario sexp that
# merges the candidate's overrides onto the base scenario's cell-E overrides,
# run it via scenario_runner.exe, and read actual.sexp to extract metrics.
# Then compute deltas vs the hardcoded cell-E baseline and apply the
# regression gate.
#
# Cell-E baseline reference values (hardcoded; provenance documented below).
# These are the canonical cell-E (max_position_pct_long=0.14, exposure=0.70,
# min_cash=0.30, stage3 h=1, laggard h=2) full-window results on each panel
# scenario, as measured at the time the scenario was last re-pinned:
#
# Source: scenario sexp file headers, both checked-in at HEAD:
#   - trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp
#     §"Measured 2026-05-13 (full Cell E, 16.3y window, post-#1052..#1054)"
#   - trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp
#     §"Measured 2026-05-12 (Cell E, post-#1052 force-liq fix + #1053 schema)"

PROMOTE_SHARPE_REGRESSION_THRESHOLD="${PROMOTE_SHARPE_REGRESSION_THRESHOLD:-0.10}"
PROMOTE_MAXDD_INCREASE_THRESHOLD="${PROMOTE_MAXDD_INCREASE_THRESHOLD:-5.0}"
PROMOTE_TRADES_RATIO_MAX="${PROMOTE_TRADES_RATIO_MAX:-2.0}"
PROMOTE_SKIP_VALIDATION="${PROMOTE_SKIP_VALIDATION:-0}"
PROMOTE_VALIDATION_PARALLEL="${PROMOTE_VALIDATION_PARALLEL:-2}"

# Panel: (scenario_name | base_scenario_sexp_path | cell_e_sharpe | cell_e_return | cell_e_max_dd | cell_e_trades)
# When the panel grows (P7 broad-universe / French-49 / Shiller), append rows
# here. Each row is a single space-separated record. cell_e_trades pinned from
# the scenario sexp headers; re-pin whenever the scenario is re-measured.
read -r -d '' PROMOTE_VALIDATION_PANEL << 'EOF' || true
sp500-2010-2026 trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp 0.78 341.69 18.36 806
sp500-2019-2023 trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp 0.56 50.66 21.56 264
EOF

validation_sexp="$target_dir/validation.sexp"
# Place validation_dir under the repo bind-mount so docker (running
# scenario_runner.exe) can see the composed scratch scenarios. Host TMPDIR
# (/var/folders/... on macOS) is NOT bind-mounted into trading-1-dev.
mkdir -p "$trading_repo_root/dev/_tmp"
validation_dir="$(mktemp -d "$trading_repo_root/dev/_tmp/promote-validation-XXXXXX")"
trap 'rm -rf "$validation_dir"' EXIT

# Build validation.sexp incrementally as scenarios complete; the final form
# is assembled at the end so promotion can fail mid-flight without leaving a
# partial validation.sexp staged.
declare -a validation_rows
declare -a gate_failures

if [ "$PROMOTE_SKIP_VALIDATION" = "1" ]; then
  echo "=== Cross-scenario validation SKIPPED (PROMOTE_SKIP_VALIDATION=1) ==="
  validation_rows+=("((status skipped) (reason \"PROMOTE_SKIP_VALIDATION=1 at promote time\"))")
else
  echo "=== Cross-scenario validation ==="
  echo "Sharpe regression threshold: $PROMOTE_SHARPE_REGRESSION_THRESHOLD (absolute units)"
  echo "Parallel: $PROMOTE_VALIDATION_PARALLEL"

  scratch_scenarios_dir="$validation_dir/scenarios"
  mkdir -p "$scratch_scenarios_dir"

  # Compose scratch scenarios for every panel row.
  while IFS=' ' read -r scenario_name base_path _ _ _ _; do
    [ -z "$scenario_name" ] && continue
    full_base_path="$trading_repo_root/$base_path"
    if [ ! -f "$full_base_path" ]; then
      echo "Error: panel scenario base file not found: $full_base_path" >&2
      rm -rf "$target_dir"
      exit 1
    fi
    scratch_path="$scratch_scenarios_dir/scratch-$scenario_name.sexp"
    if ! compose_scratch_scenario \
        "$full_base_path" "$config_sexp" \
        "scratch-$scenario_name" "$scratch_path"; then
      echo "Error: failed to compose scratch scenario for $scenario_name" >&2
      rm -rf "$target_dir"
      exit 1
    fi
    echo "Composed scratch scenario: $scratch_path"
  done <<< "$PROMOTE_VALIDATION_PANEL"

  # Build scenario_runner.exe via docker (idempotent if already built).
  # This repo's OCaml toolchain lives in the trading-1-dev container; the
  # host opam switch is intentionally minimal and missing libraries like
  # core_unix.
  echo "Building scenario_runner.exe (inside docker)..."
  docker exec "${PROMOTE_DOCKER_CONTAINER:-trading-1-dev}" bash -c \
    'cd /workspaces/trading-1/trading && eval $(opam env) && dune build trading/backtest/scenarios/scenario_runner.exe' \
    >/dev/null 2>&1 || {
      echo "Error: dune build scenario_runner.exe failed inside docker" >&2
      rm -rf "$target_dir"
      exit 1
    }
  scenario_runner_exe="$trading_repo_root/trading/_build/default/trading/backtest/scenarios/scenario_runner.exe"

  if [ ! -x "$scenario_runner_exe" ]; then
    echo "Error: scenario_runner.exe missing post-build: $scenario_runner_exe" >&2
    rm -rf "$target_dir"
    exit 1
  fi

  # Run all scratch scenarios via docker (same toolchain as the build). We
  # tolerate non-zero exit because the runner's PASS/FAIL gate compares
  # against pinned cell-E ranges that the candidate may legitimately exceed
  # (in either direction). The validation gate below reads actual.sexp
  # directly.
  runner_log="$validation_dir/runner.log"
  # Capture the pre-run state of dev/backtest/scenarios-* so we can identify
  # the runner's new output dir even when other backtests created dirs before.
  pre_run_marker="$validation_dir/pre_run_marker"
  touch "$pre_run_marker"
  echo "Running scratch scenarios (this may take 15-60 min per scenario)..."
  # Translate host paths to docker-visible paths (the bind-mount maps
  # /Users/difan/Projects/trading-1 → /workspaces/trading-1).
  docker_repo_root="/workspaces/trading-1"
  docker_scratch_dir="${scratch_scenarios_dir/$trading_repo_root/$docker_repo_root}"
  docker_runner_exe="${scenario_runner_exe/$trading_repo_root/$docker_repo_root}"
  set +e
  docker exec "${PROMOTE_DOCKER_CONTAINER:-trading-1-dev}" bash -c "
    cd $docker_repo_root/trading && eval \$(opam env) &&
    $docker_runner_exe \\
      --dir $docker_scratch_dir \\
      --fixtures-root $docker_repo_root/trading/test_data/backtest_scenarios \\
      --parallel $PROMOTE_VALIDATION_PARALLEL \\
      --no-emit-all-eligible" \
    > "$runner_log" 2>&1
  runner_exit=$?
  set -e
  echo "scenario_runner exited $runner_exit (non-zero is allowed; gate reads actual.sexp directly)"

  # Locate the scenario_runner output root. The runner makes a fresh
  # dev/backtest/scenarios-<timestamp>/ dir per invocation; pick the newest
  # one created after our pre-run marker.
  runner_output_root=$(find "$trading_repo_root/dev/backtest" \
    -maxdepth 1 -mindepth 1 -type d -name 'scenarios-*' \
    -newer "$pre_run_marker" 2>/dev/null \
    | head -1)
  if [ -z "$runner_output_root" ] || [ ! -d "$runner_output_root" ]; then
    echo "Error: cannot find scenario_runner output root under dev/backtest/ (no scenarios-* dir newer than $pre_run_marker)" >&2
    tail -20 "$runner_log" >&2
    rm -rf "$target_dir"
    exit 1
  fi
  echo "scenario_runner output root: $runner_output_root"

  # Extract metrics + apply gate per scenario.
  while IFS=' ' read -r scenario_name base_path cell_e_sharpe cell_e_return cell_e_max_dd cell_e_trades; do
    [ -z "$scenario_name" ] && continue
    actual_sexp="$runner_output_root/scratch-$scenario_name/actual.sexp"
    if [ ! -f "$actual_sexp" ]; then
      echo "Error: actual.sexp missing for $scenario_name: $actual_sexp" >&2
      tail -20 "$runner_log" >&2
      rm -rf "$target_dir"
      exit 1
    fi

    actual_sharpe=$(extract_metric "$actual_sexp" sharpe_ratio)
    actual_return=$(extract_metric "$actual_sexp" total_return_pct)
    actual_max_dd=$(extract_metric "$actual_sexp" max_drawdown_pct)
    actual_trades=$(extract_metric "$actual_sexp" total_trades)
    actual_win_rate=$(extract_metric "$actual_sexp" win_rate)

    if [ -z "$actual_sharpe" ]; then
      echo "Error: failed to extract sharpe_ratio from $actual_sexp" >&2
      cat "$actual_sexp" >&2
      rm -rf "$target_dir"
      exit 1
    fi

    sharpe_delta=$(signed_delta "$actual_sharpe" "$cell_e_sharpe")
    return_delta=$(signed_delta "$actual_return" "$cell_e_return")
    max_dd_delta=$(signed_delta "$actual_max_dd" "$cell_e_max_dd")
    trades_delta=$(signed_delta "$actual_trades" "$cell_e_trades")

    # Gates (Option E, per dev/plans/bayesian-production-sweep-2026-05-18.md §6):
    #  - Sharpe regression ≤ threshold (higher-is-better)
    #  - MaxDD increase ≤ threshold (lower-is-better; swap regresses_by_more_than args)
    #  - total_trades within ratio (catches strategies that trade radically differently)
    verdict="pass"
    if regresses_by_more_than \
        "$actual_sharpe" "$cell_e_sharpe" \
        "$PROMOTE_SHARPE_REGRESSION_THRESHOLD"; then
      verdict="fail"
      gate_failures+=("$scenario_name: sharpe $actual_sharpe vs cell-E $cell_e_sharpe (delta $sharpe_delta) regresses > $PROMOTE_SHARPE_REGRESSION_THRESHOLD")
    fi
    if regresses_by_more_than \
        "$cell_e_max_dd" "$actual_max_dd" \
        "$PROMOTE_MAXDD_INCREASE_THRESHOLD"; then
      verdict="fail"
      gate_failures+=("$scenario_name: max_drawdown_pct $actual_max_dd vs cell-E $cell_e_max_dd (delta $max_dd_delta) increases > $PROMOTE_MAXDD_INCREASE_THRESHOLD pp")
    fi
    if trades_out_of_ratio \
        "$actual_trades" "$cell_e_trades" \
        "$PROMOTE_TRADES_RATIO_MAX"; then
      verdict="fail"
      gate_failures+=("$scenario_name: total_trades $actual_trades vs cell-E $cell_e_trades (delta $trades_delta) outside ratio ${PROMOTE_TRADES_RATIO_MAX}x")
    fi

    echo "  $scenario_name: sharpe=$actual_sharpe (cell-E $cell_e_sharpe, delta $sharpe_delta) max_dd=$actual_max_dd (cell-E $cell_e_max_dd, delta $max_dd_delta) trades=$actual_trades (cell-E $cell_e_trades, delta $trades_delta) verdict=$verdict"

    validation_rows+=("((scenario $scenario_name)
   (verdict $verdict)
   (cell_e_baseline ((sharpe $cell_e_sharpe) (total_return_pct $cell_e_return) (max_drawdown_pct $cell_e_max_dd) (total_trades $cell_e_trades)))
   (candidate ((sharpe $actual_sharpe) (total_return_pct $actual_return) (max_drawdown_pct $actual_max_dd) (total_trades $actual_trades) (win_rate $actual_win_rate)))
   (delta ((sharpe $sharpe_delta) (total_return_pct $return_delta) (max_drawdown_pct $max_dd_delta) (total_trades $trades_delta))))")
  done <<< "$PROMOTE_VALIDATION_PANEL"
fi

# Write validation.sexp.
{
  echo ";; Cross-scenario validation results for $label"
  echo ";; Generated by promote_config.sh on $promotion_date"
  echo ";; Gates: Sharpe regression ≤ $PROMOTE_SHARPE_REGRESSION_THRESHOLD,"
  echo ";;        MaxDD increase ≤ ${PROMOTE_MAXDD_INCREASE_THRESHOLD}pp,"
  echo ";;        total_trades within ${PROMOTE_TRADES_RATIO_MAX}x"
  echo "((label $label)"
  echo " (promotion_date \"$promotion_date\")"
  echo " (trading_sha $trading_short_sha)"
  echo " (sharpe_regression_threshold $PROMOTE_SHARPE_REGRESSION_THRESHOLD)"
  echo " (maxdd_increase_threshold_pp $PROMOTE_MAXDD_INCREASE_THRESHOLD)"
  echo " (trades_ratio_max $PROMOTE_TRADES_RATIO_MAX)"
  echo " (results ("
  for row in "${validation_rows[@]}"; do
    echo "  $row"
  done
  echo " )))"
} > "$validation_sexp"

# Apply the gate. On failure: clean up target_dir, refuse promotion.
if [ "${#gate_failures[@]}" -gt 0 ]; then
  echo ""
  echo "=== Cross-scenario validation FAILED ==="
  for f in "${gate_failures[@]}"; do
    echo "  - $f"
  done
  echo ""
  echo "Promotion refused. Cleaning up $target_dir."
  rm -rf "$target_dir"
  exit 1
fi

# ---------------------------------------------------------------------------
# Write provenance.md
# ---------------------------------------------------------------------------

cat > "$target_dir/provenance.md" << EOF
# Provenance — $label

## Promotion metadata
- Promoted: $promotion_date
- Trading repo commit: \`$trading_sha\`
- Trading repo short SHA: \`$trading_short_sha\`
- Source config: \`$config_sexp\` (in trading repo at promote time)
- BO output dir: \`${bo_output_dir:-<not supplied>}\`
- Tuner spec: \`${tuner_spec:-<not supplied>}\`
- Walk-forward spec: \`${walk_forward_spec:-<not supplied>}\`

## Cross-scenario validation

Gates applied:
- Sharpe regression ≤ \`$PROMOTE_SHARPE_REGRESSION_THRESHOLD\` absolute units
- MaxDD increase ≤ \`${PROMOTE_MAXDD_INCREASE_THRESHOLD}\` percentage points
- total_trades within \`${PROMOTE_TRADES_RATIO_MAX}x\` of baseline (either direction)

See \`validation.sexp\` for full structured results.

$(if [ "$PROMOTE_SKIP_VALIDATION" = "1" ]; then
    echo "**SKIPPED** — PROMOTE_SKIP_VALIDATION=1 at promote time. validation.sexp records the skip; this config has not been verified against the panel."
  else
    echo "All panel scenarios passed every gate (Sharpe + MaxDD + trades-ratio)."
  fi)

## How to use

To run a backtest with this config:

\`\`\`sh
# After --config-path flag lands (separate PR), this becomes:
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval \$(opam env) &&
  dune exec --no-build trading/backtest/bin/backtest_runner.exe -- \
    2010-01-01 2026-04-30 \
    --config-path \$TRADING_PARAMS_DIR/configs/$label/config.sexp \
    --experiment-name $label-validation'

# In the interim, use the --override mechanism with the cells from config.sexp.
\`\`\`

## Verifying this config is current-live

\`\`\`sh
readlink \$TRADING_PARAMS_DIR/live/current.sexp
# Expected: ../configs/$label/config.sexp
\`\`\`

EOF

# ---------------------------------------------------------------------------
# Update live/current.sexp symlink
# ---------------------------------------------------------------------------

mkdir -p "$TRADING_PARAMS_DIR/live"
# In-place symlink replace via -f (not POSIX-atomic — readers can transiently
# see the symlink missing during the swap; acceptable for this single-operator
# workflow where readers are humans + scripts, not high-frequency consumers).
ln -sfn "../configs/$label/config.sexp" "$TRADING_PARAMS_DIR/live/current.sexp"

# ---------------------------------------------------------------------------
# Regenerate _metadata/catalog.sexp
# ---------------------------------------------------------------------------

mkdir -p "$TRADING_PARAMS_DIR/_metadata"
catalog="$TRADING_PARAMS_DIR/_metadata/catalog.sexp"
{
  echo ";; Auto-generated by promote_config.sh on $promotion_date"
  echo ";; Lists every promoted config in chronological order."
  echo "((promoted_configs ("
  for d in $(ls -1d "$TRADING_PARAMS_DIR/configs"/*/ 2>/dev/null | sort); do
    cfg_label="$(basename "$d")"
    echo "  ((label \"$cfg_label\") (path \"configs/$cfg_label/config.sexp\"))"
  done
  echo " ))"
  if [ -L "$TRADING_PARAMS_DIR/live/current.sexp" ]; then
    cur_target="$(readlink "$TRADING_PARAMS_DIR/live/current.sexp")"
    echo " (live_current \"$cur_target\")"
  fi
  echo ")"
} > "$catalog"

# ---------------------------------------------------------------------------
# Commit
# ---------------------------------------------------------------------------

cd "$TRADING_PARAMS_DIR"
git add "configs/$label" "live/current.sexp" "_metadata/catalog.sexp"
git commit -m "promote: $label — trading@$trading_short_sha"

echo ""
echo "=== Promotion complete ==="
echo "Label:           $label"
echo "Target dir:      $target_dir"
echo "Trading SHA:     $trading_short_sha"
echo "Live symlink:    $TRADING_PARAMS_DIR/live/current.sexp -> configs/$label/config.sexp"
echo "Commit:          $(cd "$TRADING_PARAMS_DIR" && git rev-parse --short HEAD)"
echo ""
echo "Next steps:"
echo "  1. Review the commit: cd $TRADING_PARAMS_DIR && git show HEAD"
echo "  2. Push: cd $TRADING_PARAMS_DIR && git push"
echo "  3. Populate cross-scenario validation table in provenance.md"
echo "     (run backtests via backtest_runner with --config-path)"
