#!/bin/sh
# Record convention re-based onto the fixed exit basis (post PR #2648).
# Six cells at ONE build (pinned worktree sweep-record0903 @ e4984c5fe = main
# after #2648/#2652): the record-baseline spec (2026-08-24 lineage, clock 0
# pin retained) with the period/universe swapped per window, in two arms —
#   new = as committed (inherits the flipped defaults: next-open exit fill,
#         no entry-bar stop-out)
#   old = + ((sim_exit_fill_next_open false)) ((stops_config ((stop_skip_entry_bar false))))
# Windows: rec5y-2019 (top-3000-2019, 2019-01-02..2023-12-29),
#          rec5y-2000 (top-3000-2000, 2000-01-03..2004-12-31),
#          rec26y     (top-3000-2000, 2000-01-01..2026-06-26 — the canonical record).
# 5y pairs run 2-concurrent (capacity table); the 26y arms run one at a time.
# Warehouse /tmp/snap_top3000_dedup_v5thin_adj (2000 vintage — within-cell A/B
# valid, levels survivor-tilted on the 2019 window). Salt 0 only; salts are a
# follow-up if a lever read hangs on this null.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=e4984c5fe
WT=/workspaces/trading-1/.claude/worktrees/sweep-record0903
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-record0903"
SPECS_HOST=/tmp/rec0903-run/specs
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/rec0903
ART=/tmp/sweeps/rec0903
LOG_HOST=/tmp/rec0903-run/chain.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj
LOCK=/tmp/rec0903-run/chain.lock

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

# $1 = cell name (spec basename without .sexp), salt 0
run_cell() {
  name=$1; tag="$name-s0"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/$name.sexp" "$C:$d/" || { log "RESULT $tag => <no result - spec missing>"; return; }
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 timeout $CELL_TIMEOUT \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX --snapshot-dir $SNAP \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log" || true
  log "RESULT $tag => ${m:-<no result - see $ART/$tag.log; OOM leaves empty log>} (wall $(( $(date +%s) - start ))s)"
}

# --- 5y pairs, two concurrent ---
for w in rec5y-2019 rec5y-2000; do
  require_disk "pre-$w"; require_memory 4096 "pre-$w"
  ( run_cell $w-new ) & p1=$!
  ( run_cell $w-old ) & p2=$!
  wait $p1 $p2
  log "PAIR $w COMPLETE"
done

# --- 26y record, one arm at a time ---
for arm in new old; do
  require_disk "pre-rec26y-$arm"; require_memory 4096 "pre-rec26y-$arm"
  run_cell rec26y-$arm
done
log "REC0903 CHAIN DONE"
