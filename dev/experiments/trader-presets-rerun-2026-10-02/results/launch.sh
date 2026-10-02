#!/bin/sh
# trader-presets-rerun-2026-10-02 launcher. Run AFTER #3067 (continuation anchor, #3056) merges.
# Usage: PREREG=<sha> sh launch.sh
set -eu
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main; SHA=$(git rev-parse --short=9 origin/main)
WTREL=.claude/worktrees/sweep-trader-rerun
[ -d $WTREL ] || git worktree add --detach $WTREL $SHA
git -C $WTREL grep -q consolidation_high -- trading/analysis/weinstein/screener/lib/screener.ml || { echo "ABORT: #3067 not in $SHA"; exit 1; }
rm -rf /tmp/trader-rerun/specs; mkdir -p /tmp/trader-rerun/specs
# Specs come from the pre-registration commit (PREREG, pushed before launch), not from the run tree or the
# parent working copy, so neither main moving nor a parent jj op can change them.
PREREG=${PREREG:?set PREREG to the pre-registration commit sha}
for f in tp-h-5r tp-h-5d tp-t1-5r tp-t1-5d tp-t2-5r tp-t2-5d tp-t0s-5r; do
  git show $PREREG:dev/experiments/trader-presets-rerun-2026-10-02/specs/$f.sexp > /tmp/trader-rerun/specs/$f.sexp
done
git show $PREREG:dev/experiments/trader-presets-rerun-2026-10-02/results/chain-trader.sh > /tmp/trader-rerun/chain-trader.sh
toks=""
for s in 0 1 2; do
  toks="$toks tp-h-5r:$s tp-t1-5r:$s:tp-h-5r tp-t2-5r:$s:tp-t1-5r tp-t0s-5r:$s:tp-h-5r"
  toks="$toks tp-h-5d:$s tp-t1-5d:$s:tp-h-5d tp-t2-5d:$s:tp-t1-5d"
done
echo "SHA=$SHA tokens: $toks"
nohup env BUILD=1 PREFLIGHT=1 CELL_TIMEOUT=10800 EXPECT_HEAD=$(git -C $WTREL rev-parse --short HEAD) WTREL=$WTREL \
  sh /tmp/trader-rerun/chain-trader.sh N $toks > /tmp/trader-rerun/launch-N.log 2>&1 &
echo "launched pid $!"
