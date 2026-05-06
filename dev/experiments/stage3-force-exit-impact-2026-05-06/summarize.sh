#!/usr/bin/env bash
# summarize.sh — emit a one-line summary of a scenario run dir.
# Usage: summarize.sh <run-dir>
set -eu

d="${1:?usage: summarize.sh <run-dir>}"
if [ ! -f "$d/actual.sexp" ]; then
  echo "no actual.sexp in $d" >&2
  exit 1
fi

# Extract numeric fields. actual.sexp is one big sexp with float fields.
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
fe=$(awk -F',' 'NR>1 && $13=="stage3_force_exit"' "$d/trades.csv" | wc -l | tr -d ' ')
sl=$(awk -F',' 'NR>1 && $13=="stop_loss"' "$d/trades.csv" | wc -l | tr -d ' ')
tp=$(awk -F',' 'NR>1 && $13=="take_profit"' "$d/trades.csv" | wc -l | tr -d ' ')
sr=$(awk -F',' 'NR>1 && $13=="signal_reversal"' "$d/trades.csv" | wc -l | tr -d ' ')
te=$(awk -F',' 'NR>1 && $13=="time_expired"' "$d/trades.csv" | wc -l | tr -d ' ')
up=$(awk -F',' 'NR>1 && $13=="underperforming"' "$d/trades.csv" | wc -l | tr -d ' ')
rb=$(awk -F',' 'NR>1 && $13=="rebalancing"' "$d/trades.csv" | wc -l | tr -d ' ')
ep=$(awk -F',' 'NR>1 && $13=="end_of_period"' "$d/trades.csv" | wc -l | tr -d ' ')
fl_p=$(awk -F',' 'NR>1 && $13=="force_liquidation_position"' "$d/trades.csv" | wc -l | tr -d ' ')
fl_f=$(awk -F',' 'NR>1 && $13=="force_liquidation_portfolio"' "$d/trades.csv" | wc -l | tr -d ' ')

printf "name=%s ret=%s trd=%s win=%s shr=%s mdd=%s hold=%s | sl=%s s3=%s tp=%s sr=%s te=%s up=%s rb=%s ep=%s flp=%s flf=%s\n" \
  "$(basename "$d")" "$ret" "$trd" "$win" "$shr" "$mdd" "$hold" \
  "$sl" "$fe" "$tp" "$sr" "$te" "$up" "$rb" "$ep" "$fl_p" "$fl_f"
