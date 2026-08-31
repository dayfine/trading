#!/bin/sh
# clock-52 flip (#2405 / PR #2587): OLD-ARM (entry_order_max_rest_weeks=0)
# runs for the 5 wide-band goldens whose pinned expectations are sentinel
# smoke bounds, not old-arm points (sp500-2000-2026-catstop{,-armon},
# sp500-2000-2026-longshort, sp500-1998-2026, top3000-2000-2026-catstop).
# The 6 tight-pinned cells need no old-arm run: their pin midpoints ARE the
# old arm (verified bit-identical for 5 no-op cells). Specs are the golden
# specs + ((entry_order_max_rest_weeks 0)) prepended to config_overrides,
# staged outside any VCS tree at /tmp/clock52g-w0-specs (sweep-hygiene).
# Same pinned worktree + invocation as run-goldens-52.sh; pin-comparable.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=5dc61da07
WT=/workspaces/trading-1/.claude/worktrees/sweep-clock52
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-clock52"
SPECS_HOST=/tmp/clock52g-w0-specs
WORK=/tmp/clock52w0
LOG_HOST=/tmp/clock52g-w0-chain.log
LOCK=/tmp/clock52g-w0.lock

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

touch "$LOG_HOST"
[ -d "$HOST_WT" ] || { log "ABORT: worktree missing"; exit 1; }
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD) (expect $PIN)"
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: dirty"; exit 1; }
require_disk pre-build; require_memory pre-build

docker exec $C mkdir -p $WORK
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" \
  || { log "ABORT: not built"; exit 1; }

run_cell() {
  name=$1
  tag="$name"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/$name.sexp" $C:$d/ || { log "ABORT: spec $name missing"; exit 1; }
  log "RUN $tag"
  start=$(date +%s)
  # --no-emit-all-eligible: emission-only toggle, no effect on metrics. The
  # 3001-symbol deep cell burns HOURS in the all_eligible scan after writing
  # actual.sexp in ~9 min (observed 2026-08-30); the paired table needs only
  # actual.sexp + trades.csv.
  run "TRADING_DATA_DIR=$ROOT/test_data \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --parallel 1 --fixtures-root $ROOT/test_data/backtest_scenarios \
      --no-emit-all-eligible \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  # The output subdir is the spec's INTERNAL (name ...), which differs from
  # the file basename for the -historical/-deep goldens. Each run dir holds
  # exactly one scenario, so the single-subdir glob is scoped to one arm
  # (sweep-hygiene: metric glob scoped to ONE arm — holds, 1 spec per --dir).
  sub=$(docker exec $C sh -c "ls -d ${out}/*/ 2>/dev/null | head -1")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${sub}actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "cp ${sub}actual.sexp /tmp/sweeps/clock52g/${name}-actual.sexp 2>/dev/null; \
    cp ${sub}trades.csv /tmp/sweeps/clock52g/${name}-trades.csv 2>/dev/null" || true
  log "RESULT $tag => ${m:-<no result - check $WORK/$tag.log; OOM leaves empty log>} (wall $(( $(date +%s) - start ))s)"
}

# armed-stoplimit-w0 first: the one tight-pinned cell that MOVED at 52 —
# its w0 arm supplies the old-arm trades.csv for the trade-level dissection
# (fast, ~16 min). The 5 wide-band cells follow (their pins are sentinel
# bounds, so w0 IS their old-arm measurement).
for n in sp500-2019-2023-armed-stoplimit-w0 \
         sp500-2000-2026-catstop-w0 sp500-2000-2026-catstop-armon-w0 \
         sp500-2000-2026-longshort-w0 sp500-1998-2026-w0 \
         top3000-2000-2026-catstop-w0; do
  require_disk "pre-$n"; require_memory "pre-$n"
  run_cell "$n"
done
log "CLOCK52 W0 OLD-ARM SWEEP DONE"
