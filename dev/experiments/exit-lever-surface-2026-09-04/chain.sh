#!/bin/sh
# Exit-lever surface on the record convention, fixed basis (post #2648):
# four one-knob arms off the canonical record spec, 5y windows, salts {0,1,2}.
#   lagoff  = ((enable_laggard_rotation false))          (record: true, hysteresis 2)
#   s3off   = ((enable_stage3_force_exit false))         (record: true, hysteresis 1)
#   extoff  = extension_stop_config trigger 0.0 / trail 0.0 (record: 2.0 / 0.25)
#   clock52 = ((entry_order_max_rest_weeks 52))          (record pins 0; main default 52)
# ONE build: pinned worktree sweep-lever0904 @ e4984c5fe — the SAME build as
# record-rebase-2026-09-03 and stop-width-surface-2026-09-03, so the nulls are
# reused, not re-run:
#   salt 0: record-rebase-2026-09-03/results/rec5y-{2019,2000}-new-s0-*
#   salts 1,2: stop-width-surface-2026-09-03/results/sw5y-{2019,2000}-b1.0-s{1,2}-*
# Windows: xl5y-2019 (top-3000-2019, 2019-01-02..2023-12-29),
#          xl5y-2000 (top-3000-2000, 2000-01-03..2004-12-31).
# The two windows of one arm run 2-concurrent (capacity table: ~2.4 GB each).
# Warehouse /tmp/snap_top3000_dedup_v5thin_adj (2000 vintage — within-cell A/B
# valid, levels survivor-tilted on the 2019 window).
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=e4984c5fe
WT=/workspaces/trading-1/.claude/worktrees/sweep-lever0904
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-lever0904"
SPECS_HOST=/tmp/xl0904-run/specs
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/xl0904
ART=/tmp/sweeps/xl0904
LOG_HOST=/tmp/xl0904-run/chain.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj
LOCK=/tmp/xl0904-run/chain.lock

TOTAL_MIB=7936
MIN_DISK_GB=12
CELL_TIMEOUT=28800   # 8h hard cap per cell

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }

mkdir "$LOCK" 2>/dev/null || { echo "ABORT: another chain holds $LOCK"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

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

# $1 = cell name (spec basename), $2 = salt
run_cell() {
  name=$1; salt=$2; tag="$name-s$salt"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/$name.sexp" "$C:$d/" || { log "RESULT $tag => <no result - spec missing>"; return; }
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 timeout $CELL_TIMEOUT \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX --snapshot-dir $SNAP \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log" || true
  log "RESULT $tag => ${m:-<no result - see $ART/$tag.log; OOM leaves empty log>} (wall $(( $(date +%s) - start ))s)"
}
pair2() { require_disk "pre-$1-$3"; require_memory 4096 "pre-$1-$3"; ( run_cell "$1" "$2" ) & p1=$!; ( run_cell "$3" "$4" ) & p2=$!; wait $p1 $p2; }
# Nulls at every salt already exist (see header). Salt 0 for all four arms first
# (interim read), then salts 1 and 2.
for salt in 0 1 2; do
  for arm in lagoff s3off extoff clock52; do
    pair2 xl5y-2019-$arm $salt xl5y-2000-$arm $salt
  done
  log "SALT $salt COMPLETE"
done
log "XL0904 CHAIN DONE"
