#!/bin/sh
# breadth-fix-rb1-2026-10-11 launcher. Usage, after #3252 merges:
#   mkdir -p /tmp/bp-run && PREREG=<sha> sh launch.sh 2>&1 | tee /tmp/bp-run/launch-pre.log
# Two pinned run trees: O = main just before #3252 (old NYSE A-D fixture, 1965 then 2017+), N = the #3252 merge
# (full fixture + interior-gap fill). The trees differ by #3252 only. Setup follows
# ../../rebaseline-v12-2026-10-08/results/launch.sh (lists vs warehouse, dividends/splits staging).
set -eu
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main
NEW=$(git log origin/main --format='%h %s' --abbrev=9 | grep -m1 '(#3252)$' | cut -d' ' -f1)
[ -n "$NEW" ] || { echo "ABORT: #3252 not merged on origin/main"; exit 1; }
OLD=$(git rev-parse --short=9 "$NEW^")
echo "old tree $OLD, new tree $NEW"
for lane in O N; do
  case $lane in O) sha=$OLD ;; N) sha=$NEW ;; esac
  wt=.claude/worktrees/sweep-bp-$lane
  if [ -d $wt ]; then
    [ "$(git -C $wt rev-parse --short=9 HEAD)" = "$sha" ] || { echo "ABORT: $wt is not at $sha; remove it first"; exit 1; }
  else git worktree add --detach $wt $sha; fi
done
# The arms must hold the fixtures this experiment is about.
nO=$(wc -l < .claude/worktrees/sweep-bp-O/trading/test_data/breadth/nyse_advn.csv | tr -d ' ')
nN=$(wc -l < .claude/worktrees/sweep-bp-N/trading/test_data/breadth/nyse_advn.csv | tr -d ' ')
echo "nyse_advn rows: O=$nO N=$nN"
[ "$nO" -lt 1000 ] && [ "$nN" -gt 13000 ] || { echo "ABORT: fixtures are not old (O) vs full (N)"; exit 1; }
# Everything except #3252's files must match between the trees: the schedule lists in particular.
L=trading/test_data/backtest_scenarios/pit-v12/composition
mO=$(cat .claude/worktrees/sweep-bp-O/$L/top-3000-1999.sexp .claude/worktrees/sweep-bp-O/$L/top-3000-20*.sexp | md5 -q)
mN=$(cat .claude/worktrees/sweep-bp-N/$L/top-3000-1999.sexp .claude/worktrees/sweep-bp-N/$L/top-3000-20*.sexp | md5 -q)
echo "lists md5 O=$mO N=$mN"; [ "$mO" = "$mN" ] || { echo "ABORT: schedule lists differ between trees"; exit 1; }
WH=/tmp/snap_top3000_pit_v12pit
EXPECT_WH=$(docker exec trading-1-dev sh -c "grep -c '(symbol ' $WH/manifest.sexp")
echo "v12 warehouse entries=$EXPECT_WH"
WT=.claude/worktrees/sweep-bp-N
for f in $WT/$L/top-3000-1999.sexp $WT/$L/top-3000-20*.sexp; do grep -o '(symbol [^)]*)' "$f"; done \
  | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u > /tmp/bp-run/lists-union.txt
docker exec trading-1-dev grep -o '((symbol [^)]*)' $WH/manifest.sexp | sed 's/((symbol //; s/)$//' | LC_ALL=C sort -u > /tmp/bp-run/manifest.txt
LC_ALL=C comm -23 /tmp/bp-run/lists-union.txt /tmp/bp-run/manifest.txt | grep -v -x -F MEL > /tmp/bp-run/absent.txt || true
[ ! -s /tmp/bp-run/absent.txt ] || { echo "ABORT: $(wc -l < /tmp/bp-run/absent.txt | tr -d ' ') list symbols not in the v12 manifest"; exit 1; }
echo "lists union=$(wc -l < /tmp/bp-run/lists-union.txt | tr -d ' ') absent=0 (MEL excepted)"
for lane in O N; do
  rsync -a -m --include='*/' --include='dividends.csv' --include='splits.csv' --exclude='*' data/ .claude/worktrees/sweep-bp-$lane/trading/test_data/
  echo "staged $lane: $(find .claude/worktrees/sweep-bp-$lane/trading/test_data -name dividends.csv | wc -l | tr -d ' ') dividends.csv"
done
PREREG=${PREREG:?set PREREG to the pre-registration commit sha}
rm -rf /tmp/bp-run/specs; mkdir -p /tmp/bp-run/specs
E=dev/experiments/breadth-fix-rb1-2026-10-11
git show $PREREG:$E/specs/rb1-26.sexp > /tmp/bp-run/specs/rb1-26.sexp
for f in chain-bp.sh driver-bp.sh; do git show $PREREG:$E/results/$f > /tmp/bp-run/$f; done
nohup env EXPECT_WH=$EXPECT_WH HEAD_O=$(git -C .claude/worktrees/sweep-bp-O rev-parse --short HEAD) \
  HEAD_N=$(git -C .claude/worktrees/sweep-bp-N rev-parse --short HEAD) sh /tmp/bp-run/driver-bp.sh > /tmp/bp-run/driver.log 2>&1 &
echo "launched driver pid $!"
