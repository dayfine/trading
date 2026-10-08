#!/bin/sh
# rebaseline-v12-2026-10-08 launcher. Usage: PREREG=<sha> sh launch.sh   (after the v12 warehouse build's verify phase passed)
# Copy of ../../total-return-26y-2026-10-06/results/launch.sh with the run tree, arms and paths moved; also stages
# splits.csv (split_dividend_guard reads the vendor split file next to dividends.csv, #3181).
set -eu
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main; SHA=$(git rev-parse --short=9 origin/main)
WTREL=.claude/worktrees/sweep-rb12
# A pre-existing run tree must sit at origin/main; never reuse a stale one (its HEAD would pass EXPECT_HEAD).
if [ -d $WTREL ]; then
  [ "$(git -C $WTREL rev-parse --short=9 HEAD)" = "$SHA" ] || { echo "ABORT: $WTREL is not at origin/main $SHA; remove it first"; exit 1; }
else git worktree add --detach $WTREL $SHA; fi
for k in split_dividend_guard dividend_crediting cash_yield_fee_bp; do
  git -C $WTREL grep -q "$k" -- trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml || { echo "ABORT: $k not in $SHA"; exit 1; }
done
# The v12 build must have finished and verified: the LAST verify after the LAST abort (a resumed build may log an
# earlier ABORT). Its manifest count pins the chain.
BL=/tmp/pit-v12-work/build.log
last_ok=$(grep -n 'VERIFY DONE' $BL | tail -1 | cut -d: -f1); last_ab=$(grep -n 'ABORT' $BL | tail -1 | cut -d: -f1)
[ -n "$last_ok" ] && [ "$last_ok" -gt "${last_ab:-0}" ] || { echo "ABORT: v12 build not verified after its last abort (see $BL)"; exit 1; }
WH=/tmp/snap_top3000_pit_v12pit
EXPECT_WH=$(docker exec trading-1-dev sh -c "grep -c '(symbol ' $WH/manifest.sexp")
echo "v12 warehouse entries=$EXPECT_WH"
# Lists vs warehouse, fail-closed (#3188 review R5): verify passes before the twin alias delta is applied to the
# lists, so the run tree's lists must already carry it. Every symbol in the run's schedule (top-3000 1999..2025)
# must be in the manifest, except MEL (excluded in superset). Otherwise a dropped twin leg reads as "no bar".
L=$WTREL/trading/test_data/backtest_scenarios/pit-v12/composition
for f in $L/top-3000-1999.sexp $L/top-3000-20*.sexp; do grep -o '(symbol [^)]*)' "$f"; done \
  | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u > /tmp/rb12-lists-union.txt
docker exec trading-1-dev grep -o '((symbol [^)]*)' $WH/manifest.sexp | sed 's/((symbol //; s/)$//' | LC_ALL=C sort -u > /tmp/rb12-manifest.txt
LC_ALL=C comm -23 /tmp/rb12-lists-union.txt /tmp/rb12-manifest.txt | grep -v -x -F MEL > /tmp/rb12-absent.txt || true
[ ! -s /tmp/rb12-absent.txt ] || { echo "ABORT: $(wc -l < /tmp/rb12-absent.txt | tr -d ' ') list symbols not in the v12 manifest (e.g. $(head -5 /tmp/rb12-absent.txt | tr '\n' ' ')): apply the alias delta to the lists and merge it first"; exit 1; }
echo "lists md5 (run tree $SHA): $(cat $L/top-3000-*.sexp | md5 -q)  union=$(wc -l < /tmp/rb12-lists-union.txt | tr -d ' ') absent=0 (MEL excepted)"
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
