#!/bin/sh
# total-return-26y-2026-10-06 launcher. Usage: PREREG=<sha> sh launch.sh
set -eu
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main; SHA=$(git rev-parse --short=9 origin/main)
WTREL=.claude/worktrees/sweep-tr26
[ -d $WTREL ] || git worktree add --detach $WTREL $SHA
for k in dividend_crediting cash_yield_fee_bp; do
  git -C $WTREL grep -q "$k" -- trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml || { echo "ABORT: $k not in $SHA"; exit 1; }
done
# Dividend crediting reads <TRADING_DATA_DIR>/<shard>/<SYM>/dividends.csv; the chain runs with
# TRADING_DATA_DIR=<run tree>/trading/test_data, which holds bars for only ~3.3k symbols (prices come from the
# snapshot warehouse). Stage every fetched dividends.csv (EODHD, #3158 fetch of 2026-10-06) into the run tree's
# test_data. Untracked files only: the chain's dirty check (--untracked-files=no) still passes, and both arms
# see the same tree, so the pairing is unaffected. The null arm never reads them (dividend_crediting false).
rsync -a -m --include='*/' --include='dividends.csv' --exclude='*' data/ $WTREL/trading/test_data/
echo "staged $(find $WTREL/trading/test_data -name dividends.csv | wc -l | tr -d ' ') dividends.csv files"
rm -rf /tmp/tr26-run/specs; mkdir -p /tmp/tr26-run/specs
PREREG=${PREREG:?set PREREG to the pre-registration commit sha}
for a in tr0-26 tr1-26; do
  git show $PREREG:dev/experiments/total-return-26y-2026-10-06/specs/$a.sexp > /tmp/tr26-run/specs/$a.sexp
done
git show $PREREG:dev/experiments/total-return-26y-2026-10-06/results/chain-tr26.sh > /tmp/tr26-run/chain-tr26.sh
toks=""; for s in 0 1 2; do toks="$toks tr0-26:$s tr1-26:$s:tr0-26"; done
echo "SHA=$SHA tokens: $toks"
nohup env BUILD=1 PREFLIGHT=1 CELL_TIMEOUT=36000 EXPECT_HEAD=$(git -C $WTREL rev-parse --short HEAD) WTREL=$WTREL \
  sh /tmp/tr26-run/chain-tr26.sh T $toks > /tmp/tr26-run/launch-T.log 2>&1 &
echo "launched pid $!"
