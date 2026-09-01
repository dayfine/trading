#!/bin/sh
# clock-surface cell-A null spread — the optional residual recorded in the
# #2611 decision (priorities doc + ledger amendment): cell A's +183.5pp
# (clockA-52 vs clockA-0, 26y top-3000 PIT-2000) is salt-0-only. This runs
# clockA-0 and clockA-52 at salts {1,2} — 4 cells — pinning the
# deployment-breadth win at the same evidentiary standard as cells B and D.
# Build MUST be 5dc61da07 (the #2587 arm build) so the committed s0 draws
# pair with these; the chain recreates the pinned worktree if absent.
# Specs: committed specs/clockA-{0,52}.sexp, staged at /tmp/clock52g-a-specs.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=5dc61da07
WT=/workspaces/trading-1/.claude/worktrees/sweep-clock52a
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-clock52a"
SPECS_HOST=/tmp/clock52g-a-specs
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/clock52anull
LOG_HOST=/tmp/clock52g-anull-chain.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj
LOCK=/tmp/clock52g-anull.lock

MIN_FREE_MIB=4096
TOTAL_MIB=7936
MIN_DISK_GB=6

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }

mkdir "$LOCK" 2>/dev/null || { echo "ABORT: another chain holds $LOCK"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# refuse to start while an sa2408 chain is live
[ -d /tmp/sa2408.lock ] && { echo "ABORT: run-surface.sh holds its lock"; exit 1; }
[ -d /tmp/sa2408spread.lock ] && { echo "ABORT: run-spread.sh holds its lock"; exit 1; }

require_memory() {
  used_mib=$(docker stats --no-stream --format '{{.MemUsage}}' $C \
    | sed 's|/.*||' \
    | awk '/GiB/ {gsub(/GiB/,""); printf "%d", $1 * 1024; next}
           /MiB/ {gsub(/MiB/,""); printf "%d", $1; next}
           {print 0}')
  free_mib=$(( TOTAL_MIB - ${used_mib:-0} ))
  [ "$free_mib" -ge "$MIN_FREE_MIB" ] || { log "ABORT ($1): ${free_mib}MiB free"; exit 1; }
}
require_disk() {
  free_gb=$(df -g /System/Volumes/Data | tail -1 | awk '{print $4}')
  [ "${free_gb:-0}" -ge "$MIN_DISK_GB" ] || { log "ABORT ($1): ${free_gb}GB free"; exit 1; }
}

touch "$LOG_HOST"

# (Re)create the pinned worktree at the #2587 build if absent, and build it.
if [ ! -d "$HOST_WT" ]; then
  log "creating pinned worktree at $PIN"
  git -C "$REPO" worktree add --detach "$HOST_WT" "$PIN" || { log "ABORT: worktree add failed"; exit 1; }
fi
HEAD_SHORT=$(git -C "$HOST_WT" rev-parse --short HEAD)
[ "$HEAD_SHORT" = "$PIN" ] || { log "ABORT: worktree HEAD $HEAD_SHORT != $PIN"; exit 1; }
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: dirty"; exit 1; }
require_disk pre-build; require_memory pre-build
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" || {
  log "building pinned tree (one-time)"
  run "dune build" || { log "ABORT: build failed"; exit 1; }
}

docker exec $C mkdir -p $WORK /tmp/sweeps/clock52g

run_cell() {
  arm=$1; salt=$2
  tag="${arm}-s${salt}"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/${arm}.sexp" $C:$d/ || { log "ABORT: spec $arm missing"; exit 1; }
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX --snapshot-dir $SNAP \
      --no-emit-all-eligible --parallel 1 --progress-every 52 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${out}/${arm}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "cp ${out}/${arm}/actual.sexp /tmp/sweeps/clock52g/${tag}-actual.sexp 2>/dev/null; \
    cp ${out}/${arm}/trades.csv /tmp/sweeps/clock52g/${tag}-trades.csv 2>/dev/null; \
    cp ${out}/${arm}/params.sexp /tmp/sweeps/clock52g/${tag}-params.sexp 2>/dev/null" || true
  log "RESULT $tag => ${m:-<no result - check $WORK/$tag.log; instant fail = missing input, OOM leaves empty log after real work>} (wall $(( $(date +%s) - start ))s)"
}

for salt in 1 2; do
  require_disk "pre-s$salt"; require_memory "pre-s$salt"
  run_cell clockA-0 "$salt"
  run_cell clockA-52 "$salt"
done
log "CLOCK52 A NULL SWEEP DONE"
