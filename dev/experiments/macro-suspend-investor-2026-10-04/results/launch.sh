#!/bin/sh
# macro-suspend-investor-2026-10-04 launcher (5d + 5r, salts 0-2). Usage: PREREG=<sha> sh launch.sh
set -eu
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main; SHA=$(git rev-parse --short=9 origin/main)
WTREL=.claude/worktrees/sweep-msusp
[ -d $WTREL ] || git worktree add --detach $WTREL $SHA
git -C $WTREL grep -q entry_ticket_macro_suspend -- trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml || { echo "ABORT: knob not in $SHA"; exit 1; }
rm -rf /tmp/msusp-run/specs; mkdir -p /tmp/msusp-run/specs
# Specs come from the pre-registration commit (PREREG, pushed before launch), not from the run tree or the
# parent working copy, so neither main moving nor a parent jj op can change them.
PREREG=${PREREG:?set PREREG to the pre-registration commit sha}
for a in ms0 msB; do for w in 5d 5r; do
  git show $PREREG:dev/experiments/macro-suspend-investor-2026-10-04/specs/$a-$w.sexp > /tmp/msusp-run/specs/$a-$w.sexp
done; done
git show $PREREG:dev/experiments/macro-suspend-investor-2026-10-04/results/chain-msusp.sh > /tmp/msusp-run/chain-msusp.sh
# 5d (the recovery window) first, every salt, then 5r.
toks=""
for w in 5d 5r; do for s in 0 1 2; do
  toks="$toks ms0-$w:$s msB-$w:$s:ms0-$w"
done; done
echo "SHA=$SHA tokens: $toks"
nohup env BUILD=1 PREFLIGHT=1 CELL_TIMEOUT=7200 EXPECT_HEAD=$(git -C $WTREL rev-parse --short HEAD) WTREL=$WTREL \
  sh /tmp/msusp-run/chain-msusp.sh M $toks > /tmp/msusp-run/launch-M.log 2>&1 &
echo "launched pid $!"
