#!/usr/bin/env bash
# summarize.sh — emit a one-line summary of a scenario run dir.
# Usage: summarize.sh <run-dir>
#
# Adapted from dev/experiments/stage3-force-exit-impact-2026-05-06/summarize.sh
# to also count the laggard_rotation exit_trigger added in PR #909.
set -eu

d="${1:?usage: summarize.sh <run-dir>}"
if [ ! -f "$d/actual.sexp" ]; then
  echo "no actual.sexp in $d" >&2
  exit 1
fi

# Extract numeric fields from actual.sexp (one big sexp record).
get() {
  grep -oE "$1 [-]?[0-9]+(\.[0-9]+)?" "$d/actual.sexp" | head -1 | awk '{print $2}'
}

ret=$(get total_return_pct)
trd=$(get total_trades)
win=$(get win_rate)
shr=$(get sharpe_ratio)
mdd=$(get max_drawdown_pct)
hold=$(get avg_holding_days)

# Count exit reasons in trades.csv (column 13).
count_exit() {
  awk -F',' -v reason="$1" 'NR>1 && $13==reason' "$d/trades.csv" | wc -l | tr -d ' '
}
sl=$(count_exit stop_loss)
fe=$(count_exit stage3_force_exit)
lr=$(count_exit laggard_rotation)
tp=$(count_exit take_profit)
sr=$(count_exit signal_reversal)
te=$(count_exit time_expired)
up=$(count_exit underperforming)
rb=$(count_exit rebalancing)
ep=$(count_exit end_of_period)
flp=$(count_exit force_liquidation_position)
flf=$(count_exit force_liquidation_portfolio)

printf "name=%s ret=%s trd=%s win=%s shr=%s mdd=%s hold=%s | sl=%s s3=%s lr=%s tp=%s sr=%s te=%s up=%s rb=%s ep=%s flp=%s flf=%s\n" \
  "$(basename "$d")" "$ret" "$trd" "$win" "$shr" "$mdd" "$hold" \
  "$sl" "$fe" "$lr" "$tp" "$sr" "$te" "$up" "$rb" "$ep" "$flp" "$flf"
