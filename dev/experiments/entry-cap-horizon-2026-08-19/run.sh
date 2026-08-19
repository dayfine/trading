#!/bin/sh
# E1 horizon control (#2404): the same entry_extension_max_pct axis at
# test_days 1095 instead of 365. If tighter-is-better survives a 3x longer
# fold, the 1-year result was not a truncation artifact; if the ranking
# compresses or inverts, it was.
#
# Same tree, same base scenario, same --parallel 2 as /tmp/e1-axis.sh, so the
# only difference between the two surfaces is the fold length.
set -u
W=/workspaces/trading-1/trading
LOG=/tmp/e1-axis-3y.log
OUT=/tmp/e1-axis-3y-out
exec 9>/tmp/e1-axis-3y.lock
flock -n 9 || { echo busy >>$LOG; exit 1; }
cd $W || exit 1
eval $(opam env)
export TRADING_DATA_DIR=$W/test_data
mkdir -p $OUT
echo "[$(date '+%H:%M:%S')] START e1 3y-fold axis {1,2,5,10,15} rolling 2010-2026" >>$LOG
dune build trading/backtest/walk_forward/bin/walk_forward_runner.exe >>$LOG 2>&1
echo "[$(date '+%H:%M:%S')] build rc=$?" >>$LOG
t0=$(date +%s)
dune exec --no-build trading/backtest/walk_forward/bin/walk_forward_runner.exe -- \
  --spec $W/test_data/walk_forward/entry-extension-cap-3y-folds-2010-2026.sexp \
  --out-dir $OUT --parallel 2 \
  --fixtures-root $W/test_data/backtest_scenarios >>$LOG 2>&1
echo "[$(date '+%H:%M:%S')] RESULT rc=$? wall=$(( $(date +%s)-t0 ))s" >>$LOG
echo "[$(date '+%H:%M:%S')] E1 3Y AXIS DONE" >>$LOG
