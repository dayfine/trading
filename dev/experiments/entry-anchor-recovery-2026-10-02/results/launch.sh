#!/bin/sh
# entry-anchor-recovery-2026-10-02 launcher, phase 1 (5r + 5d). Usage: PREREG=<sha> sh launch.sh
set -eu
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main; SHA=$(git rev-parse --short=9 origin/main)
WTREL=.claude/worktrees/sweep-anchor
[ -d $WTREL ] || git worktree add --detach $WTREL $SHA
git -C $WTREL grep -q entry_anchor_local_range_weeks -- trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml || { echo "ABORT: knob not in $SHA"; exit 1; }
rm -rf /tmp/anchor-run/specs; mkdir -p /tmp/anchor-run/specs
# Specs come from the pre-registration commit (PREREG, pushed before launch), not from the run tree or the
# parent working copy, so neither main moving nor a parent jj op can change them.
PREREG=${PREREG:?set PREREG to the pre-registration commit sha}
for a in ia0 ia4 ia13 ia26; do for w in 5d 5r; do
  git show $PREREG:dev/experiments/entry-anchor-recovery-2026-10-02/specs/$a-$w.sexp > /tmp/anchor-run/specs/$a-$w.sexp
done; done
git show $PREREG:dev/experiments/entry-anchor-recovery-2026-10-02/results/chain-anchor.sh > /tmp/anchor-run/chain-anchor.sh
# 5d (the recovery window) first, every salt, then 5r.
toks=""
for w in 5d 5r; do for s in 0 1 2; do
  toks="$toks ia0-$w:$s ia4-$w:$s:ia0-$w ia13-$w:$s:ia0-$w ia26-$w:$s:ia0-$w"
done; done
echo "SHA=$SHA tokens: $toks"
nohup env BUILD=1 PREFLIGHT=1 CELL_TIMEOUT=7200 EXPECT_HEAD=$(git -C $WTREL rev-parse --short HEAD) WTREL=$WTREL \
  sh /tmp/anchor-run/chain-anchor.sh A $toks > /tmp/anchor-run/launch-A.log 2>&1 &
echo "launched pid $!"
