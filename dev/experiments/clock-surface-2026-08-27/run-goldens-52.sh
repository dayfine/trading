#!/bin/sh
# clock-52 flip (#2405 / PR #2587): run the 13 inheriting strategy goldens at
# the flipped default. The current pinned expectations ARE the old arm, so one
# run per cell + compare-to-pin = the paired table config-default-blast-radius
# requires. 5y cells first (fast read), then the historical multi-hour cells.
# Mirrors golden_sp500_postsubmit.sh's invocation (stage dir, --parallel 1,
# --fixtures-root, no snapshot-dir) so numbers are pin-comparable.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=5dc61da07
WT=/workspaces/trading-1/.claude/worktrees/sweep-clock52
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-clock52"
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/clock52g
LOG_HOST=/tmp/clock52g-chain.log
ART_HOST="$REPO/.sweep-output/clock52g"
LOCK=/tmp/clock52g.lock

MIN_FREE_MIB=4096
TOTAL_MIB=7936
MIN_DISK_GB=6

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
  [ "$free_mib" -ge "$MIN_FREE_MIB" ] || { log "ABORT ($1): ${free_mib}MiB free"; exit 1; }
}
require_disk() {
  free_gb=$(df -g /System/Volumes/Data | tail -1 | awk '{print $4}')
  [ "${free_gb:-0}" -ge "$MIN_DISK_GB" ] || { log "ABORT ($1): ${free_gb}GB free"; exit 1; }
}

touch "$LOG_HOST"; mkdir -p "$ART_HOST"
[ -d "$HOST_WT" ] || { log "ABORT: worktree missing"; exit 1; }
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD) (expect $PIN)"
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: dirty"; exit 1; }
require_disk pre-build; require_memory pre-build

docker exec $C mkdir -p $WORK
if ! docker exec $C test -f "$WORK/.built"; then
  log "building scenario_runner in pinned worktree"
  run "dune build trading/backtest/scenarios/scenario_runner.exe 2>&1 | tail -3"
  docker exec $C touch "$WORK/.built"
fi
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" \
  || { log "ABORT: not built"; exit 1; }

# One golden cell. $1 = subdir, $2 = basename (no .sexp)
run_cell() {
  sub=$1; name=$2
  tag="$name"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker exec $C cp "$FIX/$sub/$name.sexp" $d/
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --parallel 1 --fixtures-root $FIX \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "cp ${out}/${name}/actual.sexp /tmp/sweeps/clock52g/${name}-actual.sexp 2>/dev/null; \
    cp ${out}/${name}/trades.csv /tmp/sweeps/clock52g/${name}-trades.csv 2>/dev/null" || true
  log "RESULT $tag => ${m:-<no result - check $WORK/$tag.log; OOM leaves empty log>} (wall $(( $(date +%s) - start ))s)"
}

# --- 5y cells (fast) ---
for n in sp500-2019-2023-armed-stoplimit sp500-2019-2023-long-only sp500-2019-2023; do
  require_disk "pre-$n"; require_memory "pre-$n"
  run_cell goldens-sp500 "$n"
done
for n in weinstein-2019-full-pool weinstein-2019-top-500; do
  require_disk "pre-$n"; require_memory "pre-$n"
  run_cell goldens-custom-universe-scenarios "$n"
done
log "5Y CELLS COMPLETE"

# --- historical cells (multi-hour each, strictly sequential) ---
for n in sp500-2010-2026 sp500-2010-2026-longshort sp500-2000-2026-catstop \
         sp500-2000-2026-catstop-armon sp500-2000-2026-longshort \
         sp500-1998-2026 top3000-2000-2026-catstop; do
  require_disk "pre-$n"; require_memory "pre-$n"
  run_cell goldens-sp500-historical "$n"
done
log "CLOCK52 GOLDEN SWEEP DONE"
