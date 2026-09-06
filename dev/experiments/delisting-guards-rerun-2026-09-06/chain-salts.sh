#!/bin/sh
# #2672 delisting-guards paired re-run: record convention, guards OFF vs ON,
# at ONE build (pinned worktree sweep-dg0906 @ the merged feat/delisting-guards-2672
# SHA). Same specs as the record (rec26y-new lineage) with the two 26y arms
#   off = as committed (all three #2672 guards default off — must reproduce
#         rec26y-new-s0 302.65% / 723 digit-for-digit; the build-drift tripwire)
#   on  = + ((entry_max_bar_age_days 10)) ((stale_exit_without_prior_bar true)) ((stub_print_max_ratio 0.05))
# plus the 2019 window pair on the 2019-VINTAGE warehouse (/tmp/snap_top3000_2019,
# where DTV/ABK live). 26y arms one at a time; the 5y pair 2-concurrent.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=3113f751e
WT=/workspaces/trading-1/.claude/worktrees/sweep-dg0906
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-dg0906"
SPECS_HOST=/tmp/dg0906-run/specs
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/dg0906
ART=/tmp/sweeps/dg0906
LOG_HOST=/tmp/dg0906-run/chain-salts.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj
LOCK=/tmp/dg0906-run/chain-salts.lock

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

# $1 = cell name, $2 = salt
run_cell_salt() {
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
  docker exec $C sh -c "for f in actual.sexp trades.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $WORK/$tag.log $ART/${tag}.log" || true
  log "RESULT $tag => ${m:-<no result - see $ART/$tag.log; OOM leaves empty log>} (wall $(( $(date +%s) - start ))s)"
}

for salt in 1 2; do
  for arm in off on; do
    require_disk "pre-dg-26y-$arm-s$salt"; require_memory 4096 "pre-dg-26y-$arm-s$salt"
    run_cell_salt dg-26y-$arm $salt
  done
done
log "DG0906 SALTS CHAIN DONE"
