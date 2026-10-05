#!/bin/sh
# short-only-liveness-2026-10-04 launcher (5d, salt 0, one pair). Usage: PREREG=<sha> sh launch.sh
set -eu
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main; SHA=$(git rev-parse --short=9 origin/main)
WTREL=.claude/worktrees/sweep-shortonly
[ -d $WTREL ] || git worktree add --detach $WTREL $SHA
git -C $WTREL grep -q enable_slow_grind_short_gate -- trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml || { echo "ABORT: knob not in $SHA"; exit 1; }
rm -rf /tmp/shortonly-run/specs; mkdir -p /tmp/shortonly-run/specs
# Specs come from the pre-registration commit (PREREG, pushed before launch), not from the run tree or the
# parent working copy, so neither main moving nor a parent jj op can change them.
PREREG=${PREREG:?set PREREG to the pre-registration commit sha}
for a in soT soTs; do
  git show $PREREG:dev/experiments/short-only-liveness-2026-10-04/specs/$a-5d.sexp > /tmp/shortonly-run/specs/$a-5d.sexp
done
git show $PREREG:dev/experiments/short-only-liveness-2026-10-04/results/chain-shortonly.sh > /tmp/shortonly-run/chain-shortonly.sh
toks="soT-5d:0 soTs-5d:0:soT-5d"
echo "SHA=$SHA tokens: $toks"
nohup env BUILD=1 PREFLIGHT=1 CELL_TIMEOUT=5400 EXPECT_HEAD=$(git -C $WTREL rev-parse --short HEAD) WTREL=$WTREL \
  sh /tmp/shortonly-run/chain-shortonly.sh S $toks > /tmp/shortonly-run/launch-S.log 2>&1 &
echo "launched pid $!"
