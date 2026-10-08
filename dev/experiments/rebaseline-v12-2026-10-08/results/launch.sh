#!/bin/sh
# rebaseline-v12-2026-10-08 launcher. Usage: PREREG=<sha> sh launch.sh   (after the v12 warehouse build's verify phase passed)
# Copy of ../../total-return-26y-2026-10-06/results/launch.sh with the run tree, arms and paths moved; also stages
# splits.csv (split_dividend_guard reads the vendor split file next to dividends.csv, #3181).
set -eu
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main; SHA=$(git rev-parse --short=9 origin/main)
WTREL=.claude/worktrees/sweep-rb12
[ -d $WTREL ] || git worktree add --detach $WTREL $SHA
for k in split_dividend_guard dividend_crediting cash_yield_fee_bp; do
  git -C $WTREL grep -q "$k" -- trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml || { echo "ABORT: $k not in $SHA"; exit 1; }
done
# The v12 build must have finished and verified (build_pit_warehouse_v12.sh verify); its manifest count pins the chain.
grep -q 'VERIFY DONE' /tmp/pit-v12-work/build.log && ! grep -q 'ABORT' /tmp/pit-v12-work/build.log || { echo "ABORT: v12 build not verified (see /tmp/pit-v12-work/build.log)"; exit 1; }
EXPECT_WH=$(docker exec trading-1-dev sh -c "grep -c '(symbol ' /tmp/snap_top3000_pit_v12pit/manifest.sexp")
echo "v12 warehouse entries=$EXPECT_WH"
# Dividend crediting and the split-dividend guard read <TRADING_DATA_DIR>/<shard>/<SYM>/{dividends,splits}.csv; the chain
# runs with TRADING_DATA_DIR=<run tree>/trading/test_data. Untracked files only (the dirty check uses
# --untracked-files=no); both arms see the same tree.
rsync -a -m --include='*/' --include='dividends.csv' --include='splits.csv' --exclude='*' data/ $WTREL/trading/test_data/
echo "staged $(find $WTREL/trading/test_data -name dividends.csv | wc -l | tr -d ' ') dividends.csv, $(find $WTREL/trading/test_data -name splits.csv | wc -l | tr -d ' ') splits.csv"
rm -rf /tmp/rb12-run/specs; mkdir -p /tmp/rb12-run/specs
PREREG=${PREREG:?set PREREG to the pre-registration commit sha}
for a in rb0-26 rb1-26; do
  git show $PREREG:dev/experiments/rebaseline-v12-2026-10-08/specs/$a.sexp > /tmp/rb12-run/specs/$a.sexp
done
git show $PREREG:dev/experiments/rebaseline-v12-2026-10-08/results/chain-rb12.sh > /tmp/rb12-run/chain-rb12.sh
toks=""; for s in 0 1 2; do toks="$toks rb0-26:$s rb1-26:$s:rb0-26"; done
echo "SHA=$SHA tokens: $toks"
nohup env BUILD=1 PREFLIGHT=1 CELL_TIMEOUT=36000 EXPECT_HEAD=$(git -C $WTREL rev-parse --short HEAD) EXPECT_WH=$EXPECT_WH \
  WTREL=$WTREL sh /tmp/rb12-run/chain-rb12.sh R $toks > /tmp/rb12-run/launch-R.log 2>&1 &
echo "launched pid $!"
