#!/bin/sh
# Capital-contention test of the noise-floor mechanism (see README.md).
#
# One knob vs the committed 5y core spec: max_position_pct_long 0.14 -> 0.33.
# Control is already committed (rt-freshness-5y-null results, 0 differing rows
# across salts); this runs only the tightened arm at salts 0,1,2.
#
# PREDICTION, registered before the run: if capital contention is what opens
# the discrete channel, cross-salt trade-set divergence goes from 0% to clearly
# nonzero. If it stays ~0%, the mechanism story in PR #2436 is WRONG and both
# that record and the agent memory must be corrected.
#
# NOTE there is no determinism tripwire here: the tightened arm has never been
# run, so no prior draw exists to check against. The control arm it is compared
# with was tripwire-verified in the 5y-null run.
#
# Pinned-worktree + guards per sweep-hygiene.md.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
WT=/workspaces/trading-1/.claude/worktrees/sweep-cont
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-cont"
SPECS_HOST="$REPO/dev/experiments/contention-null-mechanism-2026-08-20/specs"
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/cont
LOG_HOST=/tmp/cont-chain.log

# Small run: 500 symbols x 5y against committed bar data, no snapshot
# warehouse. The 26y chain's 4096MiB floor is sized for top-3000 x 26y and
# would refuse to launch here for no reason.
MIN_FREE_MIB=1536
TOTAL_MIB=7936
MIN_DISK_GB=6

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
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
  [ "${free_gb:-0}" -ge "$MIN_DISK_GB" ] || { log "ABORT ($1): ${free_gb}GB disk free, need ${MIN_DISK_GB}"; exit 1; }
}

touch "$LOG_HOST"
[ -d "$HOST_WT" ] || { log "ABORT: pinned worktree $HOST_WT missing"; exit 1; }
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD)"
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: run tree is dirty"; exit 1; }
require_disk pre-build
require_memory pre-build

docker exec $C mkdir -p $WORK
if ! docker exec $C test -f "$WORK/.built"; then
  log "building scenario_runner in the pinned worktree"
  run "dune build trading/backtest/scenarios/scenario_runner.exe 2>&1 | tail -5"
  docker exec $C touch "$WORK/.built"
fi
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" \
  || { log "ABORT: scenario_runner not built"; exit 1; }

# One cell = (arm, salt). Arms run CONCURRENTLY within a salt so the pair
# shares wall-clock conditions; salts run in sequence to hold memory at ~2
# workers. Each cell gets its OWN spec dir AND its own --dir, because --dir is
# where the runner reads specs from and a shared dir garbles the RESULT lines
# (observed on the 26y chain).
run_cell() {
  arm=$1; salt=$2
  tag="${arm}-s${salt}"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/${arm}.sexp" $C:$d/
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=${salt} \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.-]+|total_trades [0-9]+|sharpe_ratio [0-9.-]+|max_drawdown_pct [0-9.-]+|ulcer_index [0-9.-]+|win_rate [0-9.-]+|avg_holding_days [0-9.-]+' ${out}/*/actual.sexp 2>/dev/null | tr '\n' ' '")
  log "RESULT $tag => ${m:-<no result — CHECK FOR OOM: empty child log + no stack is the signature>} (wall $(( $(date +%s) - start ))s)"
}

for salt in 0 1 2; do
  require_disk "pre-salt-$salt"; require_memory "pre-salt-$salt"
  run_cell contention-tight "$salt"
done

log "CONTENTION DONE"
log "COMPARE against rt-freshness-5y-null-2026-08-20/results/s*-core-trades.csv (0 differing rows)"
