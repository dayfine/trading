#!/bin/sh
set -u
W=/workspaces/trading-1/.claude/worktrees/golden-clock26
LOG=/tmp/golden-clock26.log
G=$W/trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp
echo "[$(date '+%H:%M')] START HEAD=$(cd $W && git rev-parse --short HEAD)" >>$LOG
cd $W/trading || exit 1
eval $(opam env)
export TRADING_DATA_DIR=$W/trading/test_data
dune build trading/backtest/scenarios/scenario_runner.exe >>$LOG 2>&1
echo "[$(date '+%H:%M')] build rc=$?" >>$LOG
mkdir -p /tmp/gc26/armed /tmp/gc26/pinned0
cp $G /tmp/gc26/armed/
sed 's|((enable_sim_entry_stoplimit true))|((enable_sim_entry_stoplimit true))\n   ((entry_order_max_rest_weeks 0))|' \
  $G > /tmp/gc26/pinned0/sp500-2019-2023-armed-stoplimit.sexp
for arm in armed pinned0; do
  echo "[$(date '+%H:%M')] === arm=$arm" >>$LOG
  dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
    --dir /tmp/gc26/$arm --parallel 1 \
    --fixtures-root $W/trading/test_data/backtest_scenarios >>$LOG 2>&1
  echo "[$(date '+%H:%M')] arm=$arm rc=$?" >>$LOG
done
echo "[$(date '+%H:%M')] DONE" >>$LOG
