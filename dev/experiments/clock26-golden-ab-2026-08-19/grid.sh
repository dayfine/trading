#!/bin/sh
# Clock-26 regime grid — a PRE-REGISTERED directional test, not a fishing sweep.
#
# Hypothesis (from the sp500-2019-2023 golden A/B, -38.42pp): the clock is an
# EXPOSURE-REDUCTION dial. It pays when the exposure it removes would have
# fired into a crash, and costs when that exposure would have compounded.
#
#   PREDICT clock=26 > clock=0 on bull-crash-2015-2020     (2018 selloff + COVID)
#   PREDICT clock=26 < clock=0 on covid-recovery-2020-2024 (recovery bull)
#
# Both arms arm the SAME StopLimit stack (the clock is inert under Market
# entries, which fill immediately and never rest) and pin the clock explicitly,
# so the shipped default cannot leak in. Only entry_order_max_rest_weeks differs.
#
# Arming StopLimit means these cells no longer match their golden bands, so the
# usual "control reproduces the band" self-check is unavailable. The `baseline`
# arm below runs ONE cell untouched purely to confirm the environment still
# reproduces that cell's band (i.e. TRADING_DATA_DIR + data coverage are sane).
set -u
W=/workspaces/trading-1/.claude/worktrees/golden-clock26
LOG=/tmp/clock-grid.log
SRC=$W/trading/test_data/backtest_scenarios/goldens-broad
STAGE=/tmp/clockgrid

exec 9>/tmp/clock-grid.lock
flock -n 9 || { echo "another clock-grid is running" >>$LOG; exit 1; }

echo "[$(date '+%m-%d %H:%M')] START HEAD=$(cd $W && git rev-parse --short HEAD)" >>$LOG
cd $W/trading || exit 1
eval $(opam env)
export TRADING_DATA_DIR=$W/trading/test_data

dune build trading/backtest/scenarios/scenario_runner.exe >>$LOG 2>&1
echo "[$(date '+%m-%d %H:%M')] build rc=$?" >>$LOG

run_dir() {  # $1=label $2=dir
  echo "[$(date '+%m-%d %H:%M')] === $1" >>$LOG
  dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
    --dir "$2" --parallel 1 \
    --fixtures-root $W/trading/test_data/backtest_scenarios >>$LOG 2>&1
  echo "[$(date '+%m-%d %H:%M')] $1 rc=$?" >>$LOG
}

# Environment check: one cell, completely untouched, must reproduce its band.
d=$STAGE/bull-crash-2015-2020-baseline
mkdir -p "$d"; cp $SRC/bull-crash-2015-2020.sexp "$d/"
run_dir "bull-crash-2015-2020 BASELINE (band check)" "$d"

for cell in bull-crash-2015-2020 covid-recovery-2020-2024; do
  for clock in 0 26; do
    d=$STAGE/$cell-clock$clock
    mkdir -p "$d"
    perl -0pe "s/\(config_overrides\n  \(/(config_overrides\n  (\n   ((enable_sim_entry_stoplimit true))\n   ((sim_entry_trigger_at_suggested true))\n   ((entry_anchor_local_range_weeks 4))\n   ((entry_extension_max_pct 2.0))\n   ((freeze_entry_at_first_breakout true))\n   ((entry_order_max_rest_weeks $clock))\n   /" \
      "$SRC/$cell.sexp" > "$d/$cell.sexp"
    run_dir "$cell clock=$clock" "$d"
  done
done
echo "[$(date '+%m-%d %H:%M')] GRID DONE" >>$LOG
