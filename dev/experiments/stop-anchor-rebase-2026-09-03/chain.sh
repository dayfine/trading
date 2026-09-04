#!/bin/sh
# #2408 stop-anchor surface, RE-MEASURED on the fixed exit basis (post PR #2648).
# Same 11 specs as dev/experiments/stop-anchor-surface-2026-08-31 (wip/sa2408,
# build 90dfd6e97-era, defective simulator), run at ONE build: pinned worktree
# sweep-record0903 @ e4984c5fe (main after #2648). The specs do not pin the two
# flipped knobs, so they inherit the fixed basis by default — no spec edits.
# Old-basis actuals for the paired read: /tmp/sa2408b-run/old-basis/*.
#   surface: {anchor off,on} x buffer {1.0, 0.98, 0.96, 0.92, 0.885} + null-dup, salt 0
#   spreads: on-b0.92 and off-b1.0 (null) at salts 1,2 — the two the old run spread
# 5y broad cells, 2-concurrent (capacity table). ~35-40 min/cell on the warehouse.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=e4984c5fe
WT=/workspaces/trading-1/.claude/worktrees/sweep-record0903
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-record0903"
SPECS_HOST=/tmp/sa2408b-run/specs
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/sa2408b
ART=/tmp/sweeps/sa2408b
LOG_HOST=/tmp/sa2408b-run/chain.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj
LOCK=/tmp/sa2408b-run/chain.lock

TOTAL_MIB=7936
MIN_DISK_GB=12
CELL_TIMEOUT=14400

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }

mkdir "$LOCK" 2>/dev/null || { echo "ABORT: another chain holds $LOCK"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
[ -d /tmp/rec0903-run/chain.lock ] && { log "ABORT: rec0903 chain still holds the container"; exit 1; }

require_memory() {
  used_mib=$(docker stats --no-stream --format '{{.MemUsage}}' $C \
    | sed 's|/.*||' \
    | awk '/GiB/ {gsub(/GiB/,""); printf "%d", $1 * 1024; next}
           /MiB/ {gsub(/MiB/,""); printf "%d", $1; next}
           {print 0}')
  free_mib=$(( TOTAL_MIB - ${used_mib:-0} ))
  [ "$free_mib" -ge "$1" ] || { log "ABORT ($2): ${free_mib}MiB free < $1"; exit 1; }
}
require_disk() {
  free_gb=$(df -g /System/Volumes/Data | tail -1 | awk '{print $4}')
  [ "${free_gb:-0}" -ge "$MIN_DISK_GB" ] || { log "ABORT ($1): ${free_gb}GB free"; exit 1; }
}

touch "$LOG_HOST"
[ -d "$HOST_WT" ] || { log "ABORT: worktree missing"; exit 1; }
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD) (expect $PIN)"
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: dirty"; exit 1; }
require_disk pre; require_memory 4096 pre
docker exec $C mkdir -p $WORK $ART
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" \
  || { log "ABORT: scenario_runner not built"; exit 1; }
docker exec $C test -d $SNAP || { log "ABORT: warehouse $SNAP missing"; exit 1; }

# $1 = arm (spec basename), $2 = salt
run_cell() {
  arm=$1; salt=$2; tag="$arm-s$salt"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/$arm.sexp" "$C:$d/" || { log "RESULT $tag => <no result - spec missing>"; return; }
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 timeout $CELL_TIMEOUT \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX --snapshot-dir $SNAP \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${out}/${arm}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp trade_audit.sexp; do cp ${out}/${arm}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log" || true
  log "RESULT $tag => ${m:-<no result - see $ART/$tag.log; OOM leaves empty log>} (wall $(( $(date +%s) - start ))s)"
}

pair2() { # two cells concurrently
  require_disk "pre-$1-$3"; require_memory 4096 "pre-$1-$3"
  ( run_cell "$1" "$2" ) & p1=$!
  ( run_cell "$3" "$4" ) & p2=$!
  wait $p1 $p2
}

# --- surface, salt 0 (null pair first so a read is possible early) ---
pair2 sa-off-b1.0 0   sa-null-dup 0
pair2 sa-on-b0.92 0   sa-on-b1.0 0
pair2 sa-off-b0.98 0  sa-on-b0.98 0
pair2 sa-off-b0.96 0  sa-on-b0.96 0
pair2 sa-off-b0.92 0  sa-on-b0.885 0
pair2 sa-off-b0.885 0 sa-on-b0.92 1
log "SURFACE S0 COMPLETE"
# --- salt spreads for the null and the old headline arm ---
pair2 sa-off-b1.0 1   sa-off-b1.0 2
pair2 sa-on-b0.92 2   sa-off-b0.98 1
pair2 sa-off-b0.98 2  sa-on-b1.0 1
log "SA2408B CHAIN DONE"
