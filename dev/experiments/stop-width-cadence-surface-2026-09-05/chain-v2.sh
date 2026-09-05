#!/bin/sh
# v2 (salts 1-2, launched after salt 0): survivors only — see README "Salt-0 verdict".
# stop-width-cadence-surface 2026-09-05: initial_stop_buffer {1.0,0.9583,0.9375,0.9167,0.8958}
# = fallback width {4,8,10,12,14}% x stop_update_cadence {Daily,Weekly}, record convention,
# fixed basis, build e4984c5fe (pinned worktree sweep-stop0905). 2019-23 x top-3000-2019 on the
# 2019-VINTAGE warehouse (fresh null w4-D there); 2000-04 x top-3000-2000 on the 2000-vintage
# warehouse (null w4-D = record-rebase rec5y-2000-new-s0). Salt 0 first, 2-concurrent.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=e4984c5fe
WT=/workspaces/trading-1/.claude/worktrees/sweep-stop0905
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-stop0905"
SPECS_HOST=/tmp/sw0905-run/specs
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/sw0905
ART=/tmp/sweeps/sw0905
LOG_HOST=/tmp/sw0905-run/chain.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj
SNAP2019=/tmp/snap_top3000_2019
LOCK=/tmp/sw0905-run/chain.lock

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
  name=$1; salt=$2; tag="$name-s$salt"; case $name in *-2019-*) snapdir=$SNAP2019 ;; *) snapdir=$SNAP ;; esac
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/$name.sexp" "$C:$d/" || { log "RESULT $tag => <no result - spec missing>"; return; }
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 timeout $CELL_TIMEOUT \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX --snapshot-dir $snapdir \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log" || true
  log "RESULT $tag => ${m:-<no result - see $ART/$tag.log; OOM leaves empty log>} (wall $(( $(date +%s) - start ))s)"
}
pair2() { require_disk "pre-$1-$3"; require_memory 4096 "pre-$1-$3"; ( run_cell "$1" "$2" ) & p1=$!; ( run_cell "$3" "$4" ) & p2=$!; wait $p1 $p2; }
# Wait for the salt-0 chain, then salts 1-2 for the arms that passed tests (2)+(3) at salt 0.
# 2019-23 nulls (w4-D) must be re-run per salt on the 2019-vintage warehouse; the 2000-04 nulls
# at salts 1-2 are stop-width-surface-2026-09-03/results/sw5y-2000-b1.0-s{1,2} (same build).
until grep -q 'SW0905 CHAIN DONE' "$LOG_HOST"; do sleep 30; done
log "v2 salts 1-2 start"
for salt in 1 2; do
  pair2 sw5y-2019-w4-D $salt   sw5y-2019-w14-D $salt
  pair2 sw5y-2019-w12-W $salt  sw5y-2000-w8-D $salt
  pair2 sw5y-2000-w10-D $salt  sw5y-2000-w10-W $salt
  pair2 sw5y-2000-w14-D $salt  sw5y-2000-w12-W $salt
  log "SALT $salt COMPLETE (survivors)"
done
log "SW0905 V2 DONE"
