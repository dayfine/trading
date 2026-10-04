#!/bin/sh
# shorts-liveness-2026-10-03 launcher (5d, salt 0, one pair). Usage: PREREG=<sha> sh launch.sh
set -eu
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main; SHA=$(git rev-parse --short=9 origin/main)
WTREL=.claude/worktrees/sweep-shorts
[ -d $WTREL ] || git worktree add --detach $WTREL $SHA
git -C $WTREL grep -q enable_slow_grind_short_gate -- trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml || { echo "ABORT: knob not in $SHA"; exit 1; }
rm -rf /tmp/shorts-run/specs; mkdir -p /tmp/shorts-run/specs
# Specs come from the pre-registration commit (PREREG, pushed before launch), not from the run tree or the
# parent working copy, so neither main moving nor a parent jj op can change them.
PREREG=${PREREG:?set PREREG to the pre-registration commit sha}
for a in sh0 shB; do
  git show $PREREG:dev/experiments/shorts-liveness-2026-10-03/specs/$a-5d.sexp > /tmp/shorts-run/specs/$a-5d.sexp
done
git show $PREREG:dev/experiments/shorts-liveness-2026-10-03/results/chain-shorts.sh > /tmp/shorts-run/chain-shorts.sh
toks="sh0-5d:0 shB-5d:0:sh0-5d"
echo "SHA=$SHA tokens: $toks"
nohup env BUILD=1 PREFLIGHT=1 CELL_TIMEOUT=5400 EXPECT_HEAD=$(git -C $WTREL rev-parse --short HEAD) WTREL=$WTREL \
  sh /tmp/shorts-run/chain-shorts.sh S $toks > /tmp/shorts-run/launch-S.log 2>&1 &
echo "launched pid $!"
