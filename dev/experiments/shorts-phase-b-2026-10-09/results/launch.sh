#!/bin/sh
# shorts-phase-b-2026-10-09 launcher. Usage (one lane at a time; the container runs one long chain):
#   lane A (v0, salts 0/1/2; can launch now):
#     mkdir -p /tmp/spb-run && PREREG=<sha> sh launch.sh A 2>&1 | tee /tmp/spb-run/launch-A-pre.log
#   lane B (v1, only after #3218 has merged and v1-26.sexp's field names were confirmed against the merged .mli):
#     mkdir -p /tmp/spb-run && PREREG=<sha> sh launch.sh B 2>&1 | tee /tmp/spb-run/launch-B-pre.log
# PREREG = the commit holding the specs and chain to run (the pre-registration commit, or the later commit that
# confirmed the #3218 names; the README Log records which).
# Copy of ../../rebaseline-v12-2026-10-08/results/launch.sh with the run tree, arms and paths moved. Differences:
# the warehouse count is pinned to the finished v12 build's 9,236 entries (the build log may be gone by now), the
# config-knob presence check covers the short fixes (and the #3218 names in lane B), and lane B sets REPLAY_REF so
# the chain checks build identity against lane A before pairing (chain-spb.sh, README §Validity gates).
set -eu
LANE=${1:?usage: launch.sh A|B}
REPO=/Users/difan/Projects/trading-1; cd $REPO
git fetch -q origin main; SHA=$(git rev-parse --short=9 origin/main)
WTREL=.claude/worktrees/sweep-spb-$LANE
# A pre-existing run tree must sit at origin/main; never reuse a stale one (its HEAD would pass EXPECT_HEAD).
if [ -d $WTREL ]; then
  [ "$(git -C $WTREL rev-parse --short=9 HEAD)" = "$SHA" ] || { echo "ABORT: $WTREL is not at origin/main $SHA; remove it first"; exit 1; }
else git worktree add --detach $WTREL $SHA; fi
CFG=trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml
for k in split_dividend_guard dividend_crediting cash_yield_fee_bp short_min_price_on_order_price share_class_gate_covers_shorts; do
  git -C $WTREL grep -q "$k" -- $CFG || { echo "ABORT: $k not in $SHA $CFG"; exit 1; }
done
git -C $WTREL grep -q tightened_can_ratchet -- trading/trading/weinstein/stops/lib/stop_types.ml || { echo "ABORT: tightened_can_ratchet not in $SHA"; exit 1; }
git -C $WTREL grep -q short_maintenance_finra -- trading/trading/portfolio/lib/margin_config.ml || { echo "ABORT: short_maintenance_finra not in $SHA"; exit 1; }
case $LANE in
  A) ARMS="v0-26"; toks="v0-26:0 v0-26:1 v0-26:2"; ART=/tmp/sweeps/shorts-phase-b; REPLAY_REF="" ;;
  B) ARMS="v0-26 v1-26"; ART=/tmp/sweeps/shorts-phase-b-v1; REPLAY_REF=/tmp/sweeps/shorts-phase-b
     toks="v0-26:0 v1-26:0:v0-26 v0-26:1 v1-26:1:v0-26 v0-26:2 v1-26:2:v0-26"
     # The two #3218 fields, as named in v1-26.sexp, must exist in the run tree (names were proposed, not merged,
     # at pre-registration). A mismatch is fixed in the spec by a pre-launch commit, never here.
     # Checked as: every top-level override key of v1-26 that v0-26 does not have.
     PREREG_B=${PREREG:?set PREREG}; S=dev/experiments/shorts-phase-b-2026-10-09/specs
     git show $PREREG_B:$S/v0-26.sexp | grep -oE '^ *\(\([a-z_]+' | sed 's/^ *((//' | LC_ALL=C sort -u > /tmp/spb-keys-v0.txt
     git show $PREREG_B:$S/v1-26.sexp | grep -oE '^ *\(\([a-z_]+' | sed 's/^ *((//' | LC_ALL=C sort -u > /tmp/spb-keys-v1.txt
     newk=$(LC_ALL=C comm -13 /tmp/spb-keys-v0.txt /tmp/spb-keys-v1.txt)
     [ "$(echo "$newk" | grep -c .)" = 2 ] || { echo "ABORT: expected exactly 2 v1-only override keys, got: $newk"; exit 1; }
     for k in $newk; do
       git -C $WTREL grep -q "$k" -- $CFG || { echo "ABORT: v1 field $k is not in $SHA $CFG: confirm the #3218 names and amend v1-26.sexp first"; exit 1; }
     done
     docker exec trading-1-dev test -s $REPLAY_REF/v0-26-s0-v12-actual.sexp || echo "NOTE: no lane-A v0 s0 artefact at $REPLAY_REF; every v0 salt re-runs in lane B" ;;
  *) echo "ABORT: lane must be A or B"; exit 1 ;;
esac
WH=/tmp/snap_top3000_pit_v12pit; EXPECT_WH=9236
n_wh=$(docker exec trading-1-dev sh -c "grep -c '(symbol ' $WH/manifest.sexp")
[ "$n_wh" = "$EXPECT_WH" ] || { echo "ABORT: v12 warehouse has $n_wh entries, expected $EXPECT_WH (rebaseline-v12 launch-pre.log)"; exit 1; }
echo "v12 warehouse entries=$n_wh"
# Lists vs warehouse, fail-closed (#3188 review R5): every symbol in the run's schedule (top-3000 1999..2025) must be
# in the manifest, except MEL (excluded in superset). Otherwise a dropped twin leg reads as "no bar".
L=$WTREL/trading/test_data/backtest_scenarios/pit-v12/composition
for f in $L/top-3000-1999.sexp $L/top-3000-20*.sexp; do grep -o '(symbol [^)]*)' "$f"; done \
  | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u > /tmp/spb-lists-union.txt
n_files=$(ls $L/top-3000-1999.sexp $L/top-3000-20*.sexp | wc -l | tr -d " "); n_union=$(wc -l < /tmp/spb-lists-union.txt | tr -d " ")
[ "$n_files" = 27 ] && [ "$n_union" -ge 9000 ] || { echo "ABORT: schedule lists look wrong (files=$n_files, union=$n_union; expect 27 and >= 9000)"; exit 1; }
docker exec trading-1-dev grep -o '((symbol [^)]*)' $WH/manifest.sexp | sed 's/((symbol //; s/)$//' | LC_ALL=C sort -u > /tmp/spb-manifest.txt
LC_ALL=C comm -23 /tmp/spb-lists-union.txt /tmp/spb-manifest.txt | grep -v -x -F MEL > /tmp/spb-absent.txt || true
[ ! -s /tmp/spb-absent.txt ] || { echo "ABORT: $(wc -l < /tmp/spb-absent.txt | tr -d ' ') list symbols not in the v12 manifest (e.g. $(head -5 /tmp/spb-absent.txt | tr '\n' ' '))"; exit 1; }
echo "lists md5 (run tree $SHA): $(cat $L/top-3000-1999.sexp $L/top-3000-20*.sexp | md5 -q)  union=$(wc -l < /tmp/spb-lists-union.txt | tr -d ' ') absent=0 (MEL excepted)"
echo "  (rebaseline-v12 ran on lists md5 b62da7e2c4958c42a9805c89222c2d88, union 9222; a different md5 is reported in the writeup)"
# Dividend crediting (shorts PAY) and the split-dividend guard read <TRADING_DATA_DIR>/<shard>/<SYM>/{dividends,splits}.csv;
# the chain runs with TRADING_DATA_DIR=<run tree>/trading/test_data. Untracked files only (the dirty check uses
# --untracked-files=no).
rsync -a -m --include='*/' --include='dividends.csv' --include='splits.csv' --exclude='*' data/ $WTREL/trading/test_data/
echo "staged $(find $WTREL/trading/test_data -name dividends.csv | wc -l | tr -d ' ') dividends.csv, $(find $WTREL/trading/test_data -name splits.csv | wc -l | tr -d ' ') splits.csv"
# Stage inputs outside any VCS tree (sweep-hygiene.md 2026-08-20).
rm -rf /tmp/spb-run/specs; mkdir -p /tmp/spb-run/specs
PREREG=${PREREG:?set PREREG to the pre-registration commit sha}
for a in $ARMS; do
  git show $PREREG:dev/experiments/shorts-phase-b-2026-10-09/specs/$a.sexp > /tmp/spb-run/specs/$a.sexp
done
git show $PREREG:dev/experiments/shorts-phase-b-2026-10-09/results/chain-spb.sh > /tmp/spb-run/chain-spb.sh
echo "SHA=$SHA lane=$LANE tokens: $toks"
nohup env BUILD=1 PREFLIGHT=1 CELL_TIMEOUT=36000 EXPECT_HEAD=$(git -C $WTREL rev-parse --short HEAD) EXPECT_WH=$EXPECT_WH \
  WTREL=$WTREL ART=$ART REPLAY_REF=$REPLAY_REF sh /tmp/spb-run/chain-spb.sh $LANE $toks > /tmp/spb-run/launch-$LANE.log 2>&1 &
echo "launched pid $!"
