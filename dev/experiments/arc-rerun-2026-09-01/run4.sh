#!/bin/sh
# arc-rerun-2026-09-01 — rerun the arc-faithful bundle on current main
# (deb45a7ee, post-#2530 stops basis) and decompose it.
# Cells, in order: b5-arc (5y smoke of the fresh build), arc26y (the
# deliverable), 5y cell-B ladder {dup-null, novol, macross, fullbook},
# arc26y-novol (26y control: §4.2 fill-week gate off).
# Specs staged OUTSIDE any VCS tree at /tmp/arc0901-specs (sweep-hygiene).
set -u
C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=94a8c6857
WT=/workspaces/trading-1/.claude/worktrees/sweep-arc0901fix
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-arc0901fix"
SPECS_HOST=/tmp/arc0901-specs
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/arc0901
OUT=/tmp/sweeps/arc0901
LOG_HOST=/tmp/arc0901-chain.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj
LOCK=/tmp/arc0901d.lock
MIN_FREE_MIB=4096
TOTAL_MIB=7936
MIN_DISK_GB=6

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }

mkdir "$LOCK" 2>/dev/null || { echo "ABORT: another chain holds $LOCK"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

require_memory() {
  used_mib=$(docker stats --no-stream --format '{{.MemUsage}}' $C | sed 's|/.*||' \
    | awk '/GiB/ {gsub(/GiB/,""); printf "%d", $1 * 1024; next} /MiB/ {gsub(/MiB/,""); printf "%d", $1; next} {print 0}')
  free_mib=$(( TOTAL_MIB - ${used_mib:-0} ))
  [ "$free_mib" -ge "$MIN_FREE_MIB" ] || { log "ABORT ($1): ${free_mib}MiB free"; exit 1; }
}
require_disk() {
  free_gb=$(df -g /System/Volumes/Data | tail -1 | awk '{print $4}')
  [ "${free_gb:-0}" -ge "$MIN_DISK_GB" ] || { log "ABORT ($1): ${free_gb}GB free"; exit 1; }
}

touch "$LOG_HOST"
if [ ! -d "$HOST_WT" ]; then
  log "creating pinned worktree at $PIN"
  git -C "$REPO" worktree add --detach "$HOST_WT" "$PIN" || { log "ABORT: worktree add failed"; exit 1; }
fi
HEAD_SHORT=$(git -C "$HOST_WT" rev-parse --short HEAD)
[ "$HEAD_SHORT" = "$PIN" ] || { log "ABORT: worktree HEAD $HEAD_SHORT != $PIN"; exit 1; }
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: dirty"; exit 1; }
log "run tree HEAD=$HEAD_SHORT"
require_disk pre-build; require_memory pre-build
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" || {
  log "building pinned tree (one-time)"
  run "dune build 2>&1 | tail -20" || { log "ABORT: build failed"; exit 1; }
  run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" || { log "ABORT: no runner exe after build"; exit 1; }
}
docker exec $C mkdir -p $WORK $OUT

run_cell() {
  arm=$1; salt=${2:-0}
  tag="${arm}-s${salt}"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  require_disk "pre-$tag"; require_memory "pre-$tag"
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
  docker exec $C sh -c "rm -rf $OUT/$tag; cp -r ${out}/${arm} $OUT/$tag 2>/dev/null; cp $WORK/$tag.log $OUT/$tag.log" || true
  log "RESULT $tag => ${m:-<no result - check $WORK/$tag.log; instant fail = missing input, OOM leaves empty log after real work>} (wall $(( $(date +%s) - start ))s)"
}

# Fix-armed arms (D1 sim_exit_fill_next_open + D2 stops_config.stop_skip_entry_bar),
# build pinned at main 94a8c6857 (#2642 + #2644 merged). Wait for any other
# arc0901 runner to finish first: one backtest at a time in the container.
while docker exec $C pgrep -f 'scenario_runner.exe --dir /tmp/arc0901/' >/dev/null 2>&1; do sleep 30; done
log "container free — starting fix-armed arms"
# Fast grid (user go 2026-09-02 18:1x PDT): 3 disjoint broad 5y windows × {fix, novol, s6, novol-s6},
# all on the fixed simulator (D1 + D2 flags armed), build 94a8c6857. 26y is confirmation-only.
# g19-fix is the already-run b5-arc-fix cell (same spec, different name) — not repeated.
while docker exec $C pgrep -f 'scenario_runner.exe --dir /tmp/arc0901/' >/dev/null 2>&1; do sleep 30; done
log "container free — starting fast grid"
for arm in g19-novol g19-s6 g19-novol-s6 g00-fix g00-novol g00-s6 g00-novol-s6 g05-fix g05-novol g05-s6 g05-novol-s6; do
  run_cell "$arm"
done
log "ARC0901 FAST GRID DONE"
