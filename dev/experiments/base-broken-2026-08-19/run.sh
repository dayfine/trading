#!/bin/sh
# E4 / #2407 companion measurement — regenerate the 26y record-base artifacts.
#
# WHY A RE-RUN AND NOT AN EXISTING ARTIFACT:
#   The only post-#2317 artifact set for this base was ttl-retest-00-null's,
#   written to the container's /tmp/sweeps/ttl-retest and since lost with the
#   container's /tmp. Every trade_audit.sexp still on disk (ladder-v4,
#   2026-08-12) predates #2317's audit-join fix, so its fill ages cap at 0/1wk
#   and it CANNOT measure rest time (project_prefix_artifacts_cannot_measure_rest).
#
# WHAT IT RUNS: one arm, ttl-retest-00-null, verbatim, at the same pinned
#   commit (59b26c3bf) and the same warehouse. It is a determinism tripwire as
#   well as a data source: the top line MUST read 281.707836178685 with
#   TRADING_PATH_SEED_SALT=0, or the binary moved and the artifacts do not
#   describe the record base.
#
# WHAT PHASE 2 DOES WITH IT: joins trade_audit.sexp (placement_date,
#   suggested_stop, local_range_top, symbol) to trades.csv (pnl_dollars) on
#   position_id -- the ONLY valid join key (feedback_position_id_is_the_only_join_key)
#   -- then reads weekly bars between placement and fill to split fills into
#   base-held vs base-broken and attribute P&L to each.
#
# Pinned-worktree + memory/disk guards per sweep-hygiene.md.
#
# NO flock: macOS has no flock(1), so the single-instance guard that rule asks
# for is NOT implemented here (an earlier version of this header claimed it was).
# Concurrency safety for this script rests on the pinned worktree and on the
# caller not launching it twice; if you extend it into a multi-arm chain, add a
# real mutex first.
set -e

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=59b26c3bf
WT=/workspaces/trading-1/.claude/worktrees/sweep-base-broken
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-base-broken"
SPEC_SRC="$REPO/dev/experiments/ttl-retest-2026-08-16/specs/ttl-retest-00-null.sexp"
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/sweeps/base-broken
LOG_HOST=/tmp/base-broken-chain.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj

MIN_FREE_MIB=4096
TOTAL_MIB=7936

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_HOST"; }
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
  [ "${free_gb:-0}" -ge 15 ] || { log "ABORT ($1): ${free_gb}GB disk free, need 15"; exit 1; }
}

touch "$LOG_HOST"
require_memory pre-setup
require_disk pre-setup

# --- pinned worktree (never build or run from the parent tree) -------------
if [ ! -d "$HOST_WT" ]; then
  log "creating pinned worktree at $PIN"
  git -C "$REPO" worktree add --detach "$HOST_WT" "$PIN"
fi
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD)"
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: run tree is dirty"; exit 1; }

docker exec $C mkdir -p $WORK
d=$WORK/null
docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
docker cp "$SPEC_SRC" $C:$d/ttl-retest-00-null.sexp

# The build marker must be a CONTAINER path: $WORK lives under /tmp/sweeps,
# which exists only inside the container (bind-mounted from .sweep-output).
# A host-side `touch "$WORK.built"` fails and, under `set -e`, kills the script
# AFTER a successful 90-second build — which is exactly what happened at 15:44.
if ! docker exec $C test -f "$WORK.built"; then
  log "building scenario_runner in the pinned worktree"
  run "dune build trading/backtest/scenarios/scenario_runner.exe 2>&1 | tail -5"
  docker exec $C touch "$WORK.built"
fi
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" \
  || { log "ABORT: scenario_runner not built in the pinned worktree"; exit 1; }

require_memory pre-run
log "RUN null (expect ~7200s wall; tripwire total_return_pct 281.707836178685)"
start=$(date +%s)
run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=0 \
  ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
    --dir $d --fixtures-root $FIX --snapshot-dir $SNAP \
    --no-emit-all-eligible --parallel 1 --progress-every 26 \
    > $WORK/null.log 2>&1; echo exit=\$? >> $WORK/null.log"

out=$(docker exec $C sh -c "grep 'Output root' $WORK/null.log | tail -1 | sed 's/.*: //'")
r=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.-]+' ${out}/*/actual.sexp 2>/dev/null | head -1")
t=$(docker exec $C sh -c "grep -hoE 'total_trades [0-9]+' ${out}/*/actual.sexp 2>/dev/null | head -1")
log "RESULT null => ${r:-<no result — CHECK FOR OOM: empty child log + no stack is the signature>} ${t} (wall $(( $(date +%s) - start ))s)"
log "OUT=$out"

case "$r" in
  "total_return_pct 281.707836178685") log "TRIPWIRE OK — artifacts describe the record base" ;;
  *) log "TRIPWIRE FAILED — expected total_return_pct 281.707836178685, got '$r'. Artifacts are NOT the record base." ;;
esac
