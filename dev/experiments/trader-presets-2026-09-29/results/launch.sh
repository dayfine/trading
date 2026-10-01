#!/bin/sh
# #3038 trader-preset matrix launcher. Run AFTER #3052 merges. Usage: sh /tmp/trader-run/launch.sh
set -eu
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main; SHA=$(git rev-parse --short=9 origin/main)
WTREL=.claude/worktrees/sweep-trader
[ -d $WTREL ] || git worktree add --detach $WTREL $SHA
git -C $WTREL grep -q trailing_stop_ma_period -- trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli || { echo "ABORT: #3052 not in $SHA"; exit 1; }
rm -rf /tmp/trader-run/specs; mkdir -p /tmp/trader-run/specs
cp $WTREL/dev/experiments/trader-presets-2026-09-29/specs/*.sexp /tmp/trader-run/specs/
toks=""
for s in 0 1 2; do for w in 5r 5d; do
  toks="$toks tp-h-$w:$s tp-i-$w:$s:tp-h-$w tp-t1-$w:$s:tp-h-$w tp-t0-$w:$s:tp-h-$w tp-t2-$w:$s:tp-t1-$w"
done; done
echo "SHA=$SHA tokens: $toks"
nohup env BUILD=1 PREFLIGHT=1 CELL_TIMEOUT=10800 EXPECT_HEAD=$(git -C $WTREL rev-parse --short HEAD) WTREL=$WTREL \
  sh /tmp/trader-run/chain-trader.sh M $toks > /tmp/trader-run/launch-M.log 2>&1 &
echo "launched pid $!"
