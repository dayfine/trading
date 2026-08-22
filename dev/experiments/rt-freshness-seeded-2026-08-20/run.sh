#!/bin/sh
# F1 freshness axis, seeded: Range_top_breakout vs Ma_cross on the 26y base.
#
# WHY THIS RUN EXISTS. `entry_freshness_basis = Range_top_breakout` is the
# book's §4.7 order mechanics — screen the setup while it is still UNDER the
# range top and rest a GTC buy-stop at the anchor, rather than admitting only
# after the MA cross. Its isolated effect has NEVER been measured on a
# trustworthy binary:
#   - the 26y cell-02 number (302.68 vs core 343.90) is from the 2026-08-11
#     chain, which ran on the NONDETERMINISTIC binary and whose own duplicate
#     cell put the noise floor at ~278pp. Its results file discredits the whole
#     ranking ("maxstop50's 726.2 came back at 363.86 -- it was noise").
#   - the 2026-08-14 seeded re-run covered rt only in COMBINATION with
#     nearfloor; cell-02 alone was never re-run.
#
# WHY 6 CELLS AND NOT 2. The seeded run recorded return and trades per salt and
# nothing else, and its artifacts are gone -- so there is no null spread for
# MaxDD or Sharpe. On the 5-year deterministic testbed rt's drawdown got WORSE
# (16.98 -> 21.43) while on the unseeded 26y it got much BETTER (44.28 ->
# 32.51), so drawdown is the disputed metric and it is exactly the one with no
# measured null. Running BOTH arms at the SAME three salts yields the null
# spread and the treatment effect for every metric, in one self-contained
# design, depending on nothing unrecoverable.
#
# PAIRING. Arms share a salt, so both see the same intraday path realization;
# compare within-salt, not mean-to-mean. Core at salt 0 must reproduce
# 281.707836178685 -- that is the determinism tripwire, and a miss means the
# binary moved and nothing else in the table is interpretable.
#
# NOT BUNDLED. One axis. Adding nearfloor (the best seeded cell was
# 13-rt-nearfloor at 568.10) would make the result unattributable -- the
# pre-#2349 composite-knob failure. nearfloor also already failed its own
# confirmation grid 0-of-3 (project_nearfloor_is_risk_not_return).
#
# Pinned-worktree + memory/disk guards per sweep-hygiene.md. NO flock: macOS has
# no flock(1), so single-instance rests on the caller.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=74aefdeb0
WT=/workspaces/trading-1/.claude/worktrees/sweep-rtfresh
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-rtfresh"
SPECS_HOST="$REPO/dev/experiments/rt-freshness-seeded-2026-08-20/specs"
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/rt-ab
LOG_HOST=/tmp/rt-ab-chain.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj

MIN_FREE_MIB=4096
TOTAL_MIB=7936
MIN_DISK_GB=6

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }

require_memory() {
  used_mib=$(docker stats --no-stream --format '{{.MemUsage}}' $C \
    | sed 's|/.*||' \
    | awk '/GiB/ {gsub(/GiB/,""); printf "%d", $1 * 1024; next}
           /MiB/ {gsub(/MiB/,""); printf "%d", $1; next}
           {print 0}')
  free_mib=$(( TOTAL_MIB - ${used_mib:-0} ))
  [ "$free_mib" -ge "$MIN_FREE_MIB" ] || { log "ABORT ($1): ${free_mib}MiB free, need ${MIN_FREE_MIB}"; exit 1; }
}

require_disk() {
  free_gb=$(df -g /System/Volumes/Data | tail -1 | awk '{print $4}')
  [ "${free_gb:-0}" -ge "$MIN_DISK_GB" ] || { log "ABORT ($1): ${free_gb}GB disk free, need ${MIN_DISK_GB}"; exit 1; }
}

touch "$LOG_HOST"
[ -d "$HOST_WT" ] || { log "ABORT: pinned worktree $HOST_WT missing"; exit 1; }
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD) (expect $PIN)"
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: run tree is dirty"; exit 1; }
require_disk pre-build
require_memory pre-build

docker exec $C mkdir -p $WORK
if ! docker exec $C test -f "$WORK/.built"; then
  log "building scenario_runner in the pinned worktree"
  run "dune build trading/backtest/scenarios/scenario_runner.exe 2>&1 | tail -5"
  docker exec $C touch "$WORK/.built"
fi
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" \
  || { log "ABORT: scenario_runner not built"; exit 1; }

# One cell = (arm, salt). Arms run CONCURRENTLY within a salt so the pair shares
# wall-clock conditions; salts run in sequence to hold memory at ~2 workers.
run_cell() {
  arm=$1; salt=$2
  tag="${arm}-s${salt}"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/rt-freshness-${arm}.sexp" $C:$d/
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=${salt} \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX --snapshot-dir $SNAP \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.-]+|total_trades [0-9]+|sharpe_ratio [0-9.-]+|max_drawdown_pct [0-9.-]+' ${out}/*/actual.sexp 2>/dev/null | tr '\n' ' '")
  log "RESULT $tag => ${m:-<no result — CHECK FOR OOM: empty child log + no stack is the signature>} (wall $(( $(date +%s) - start ))s)"
}

for salt in 0 1 2; do
  require_disk "pre-salt-$salt"; require_memory "pre-salt-$salt"
  ( run_cell 00-core "$salt" ) &
  p1=$!
  ( run_cell 02-rangetop "$salt" ) &
  p2=$!
  wait $p1 $p2
  log "salt $salt pair complete"
done

log "RT-FRESHNESS DONE"
log "TRIPWIRE: 00-core-s0 must read total_return_pct 281.707836178685"
