#!/bin/sh
# rt-freshness at 5y on the BROAD universe -- period isolated. See README.md.
#
# WHY: the 5y cell that produced the reversal (#2436) ran on sp500-500 while the
# 26y cell (#2433) ran on top-3000, so that comparison moved period AND universe
# at once. Per the user standing instruction (2026-08-20) sp500 is not a
# universe we care about -- even 5y runs on broad. This re-runs the SAME six-cell
# design at top-3000, PIT-2019, 2019-01-02..2023-12-29.
#
# The specs are the 26y specs verbatim with two coupled edits: the window, and
# the PIT composition year that must move with it. Breadth stays 3000.
#
# DECISION RULE is pre-registered in README.md and includes the outcome that
# RETRACTS a merged conclusion (if rt does not reverse here, #2436 headline was
# a universe effect, not a period one).
#
# NO determinism tripwire: this window x universe combination has never been
# run, so there is no prior draw to check against. The 26y run was tripwired.
#
# Pinned-worktree + guards per sweep-hygiene.md.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=9cce2ff11
WT=/workspaces/trading-1/.claude/worktrees/sweep-broad5y
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-broad5y"
SPECS_HOST="/tmp/broad5y-run/specs"   # was $REPO/... — a parent-tree jj op deleted it mid-run (2026-08-20)
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/broad5y
LOG_HOST=/tmp/broad5y-chain.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj

MIN_FREE_MIB=4096
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
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD) (expect $PIN)"
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

# One cell = (arm, salt). Arms run CONCURRENTLY within a salt so the pair shares
# wall-clock conditions; salts run in sequence to hold memory at ~2 workers.
run_cell() {
  arm=$1; salt=$2
  tag="${arm}-s${salt}"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/broad5y-${arm}.sexp" $C:$d/
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=${salt} \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX --snapshot-dir $SNAP \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|ulcer_index [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${out}/broad5y-${arm}/actual.sexp 2>/dev/null | tr '\n' ' '")
  log "RESULT $tag => ${m:-<no result — CHECK FOR OOM: empty child log + no stack is the signature>} (wall $(( $(date +%s) - start ))s)"
}

for salt in 0 1 2; do
  require_disk "pre-salt-$salt"; require_memory "pre-salt-$salt"
  ( run_cell 00-core "$salt" ) &
  p1=$!
  ( run_cell 02-rangetop "$salt" ) &
  p2=$!
  wait $p1 $p2
  log "salt $salt pair complete"
done

log "BROAD5Y DONE"
log "COMPARE: broad-5y null vs sp500-5y null (return 0.9862 / MaxDD 0.3616); and rt-vs-core under Rule 4"
