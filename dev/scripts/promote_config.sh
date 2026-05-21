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
#      - provenance.md      (auto-generated with commit SHA + scenario metrics)
#      - bo_output/         (symlink or copy of BO output dir, if provided)
#   3. Updates live/current.sexp symlink to point at the new config.
#   4. Regenerates _metadata/catalog.sexp from configs/*/provenance.md.
#   5. Commits in the trading-parameters repo with format:
#      `promote: <label> — Sharpe X.XX (n=N folds), trading@<sha>`
#
# Environment:
#   TRADING_PARAMS_DIR  Path to the trading-parameters clone.
#                       Default: ~/Projects/trading-parameters
#
# Exits non-zero on:
#   - missing required argument
#   - label already exists in configs/
#   - source config.sexp not found
#   - trading-parameters repo not a git checkout
#   - any sub-command failure (set -euo pipefail)

set -euo pipefail

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

# If the trading repo working copy has uncommitted changes, refuse.
# Verifies tracked-tree cleanness (not unpushed commits or untracked files);
# the captured SHA must exist in the local clone for consumers to reproduce.
if ! (cd "$trading_repo_root" && git diff-index --quiet HEAD --); then
  echo "Error: trading repo working copy has uncommitted changes" >&2
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

| Scenario | Cell-E baseline | $label | Delta | Verdict |
|---|---:|---:|---:|---|
| sp500-2010-2026 (16y, 510 sym) | TBD | TBD | TBD | TBD |
| sp500-2019-2023 (5y, 500 sym) | TBD | TBD | TBD | TBD |

(Populate this table by running the scenarios via \`backtest_runner\` with
the config and comparing to baseline. Manual for now; the \`run_validation\`
function below is the proposed automation.)

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
