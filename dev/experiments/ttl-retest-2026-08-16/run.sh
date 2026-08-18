#!/bin/sh
# TTL re-test chain — defect D of dev/plans/entry-anchor-and-ttl-2026-08-15.md.
#
# FOUR runs, not the six specs in the directory. The clock arms are deferred,
# for a quantified reason: joining cell 00's own filled tickets
# (position_id -> ticket_age_weeks_at_fill -> pnl_dollars) puts every clock
# value's GROSS effect at 8-30pp against a 132.5pp null, i.e. 4-13x below the
# noise floor. A single-salt clock arm cannot come back with an interpretable
# number in either direction. See the README for the per-bucket table.
#
# What runs instead:
#   00-null          rescreen=false clock=0   salt 0     determinism tripwire
#   01-rescreen-only rescreen=true  clock=0   salts 0,1,2  the one resolvable question
#
# The re-screen cancels on stage/sector/macro flips rather than elapsed time, so
# its population is NOT bounded by the rest-time table and its effect is genuinely
# unknown. Three salts give it a distribution; it is compared against cell 00's
# already-measured three (265.44 / 281.71 / 397.95, spread 132.5pp) from
# dev/experiments/ladder-v4-seeded-2026-08-14 — same base, window, universe,
# warehouse.
#
# Run 1 is a TRIPWIRE, not a datum: post-#2279 the runs are deterministic and the
# default path is untouched by #2348/#2349, so it must return 281.71 exactly. Any
# other value means the binary moved, the BORROWED null is invalid, and the whole
# comparison is void -- stop there.
#
# OPERATIONAL (sweep-hygiene.md):
#  - runs from a PINNED worktree, never the parent working copy;
#  - reads its specs from /tmp, never the repo (jj new deletes uncommitted repo
#    paths out from under a running chain -- it killed two chains on 08-15);
#  - skips any arm that already has a RESULT line, so a restart is cheap;
#  - refuses to start an arm without memory + disk headroom.
#  - WORK is under /tmp/sweeps/ (container-side, bind-mounted to host) per
#    sweep-hygiene.md: every $WORK read/write happens inside `docker exec`,
#    so an un-mounted /tmp path would land on the Docker writable layer --
#    the exact failure class (Docker.raw runaway growth, host ENOSPC) that
#    rule was written after. LOG_HOST deliberately stays plain /tmp: it is
#    written and read only on the HOST side (outside docker exec), so it was
#    never on the writable layer, and it doubles as the resume predicate
#    (`grep RESULT "$LOG_HOST"`) and the documented log read path -- moving
#    it would silently blank a running chain's resume state. Do not "fix"
#    LOG_HOST for consistency with WORK; they are different-side variables.
C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
WT=/workspaces/trading-1/.claude/worktrees/sweep-ttl-retest
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-ttl-retest"
SPECS_HOST=/tmp/ttl-retest-specs
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/sweeps/ttl-retest
LOG_HOST=/tmp/ttl-retest-chain.log
SNAP=/tmp/snap_top3000_dedup_v5thin_adj

MIN_FREE_MIB=4096
TOTAL_MIB=7936

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_HOST"; }
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
  [ "${free_gb:-0}" -ge 20 ] || { log "ABORT ($1): ${free_gb}GB disk free, need 20"; exit 1; }
}

# Migration note: WORK moved from /tmp/ttl-retest to /tmp/sweeps/ttl-retest
# (rework of #2368). Any arm already completed under the old path has its
# RESULT line in $LOG_HOST (so it is still correctly skipped below) but its
# per-arm log/output ($WORK/$tag.log, $d) is at the OLD path, not under this
# WORK -- no code moves those artifacts, this is just stating the fact.
touch "$LOG_HOST"
docker exec $C mkdir -p $WORK

[ -d "$HOST_WT" ] || { log "ABORT: pinned worktree $HOST_WT missing"; exit 1; }
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD)"
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: run tree is dirty"; exit 1; }
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" \
  || { log "ABORT: scenario_runner not built in the pinned worktree"; exit 1; }

run_arm() {
  spec=$1; salt=$2
  tag="${spec}-s${salt}"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/${spec}.sexp" $C:$d/${spec}.sexp
  require_memory "pre-$tag"; require_disk "pre-$tag"
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=${salt} \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX --snapshot-dir $SNAP \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  r=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.-]+' ${out}/*/actual.sexp 2>/dev/null | head -1")
  t=$(docker exec $C sh -c "grep -hoE 'total_trades [0-9]+' ${out}/*/actual.sexp 2>/dev/null | head -1")
  m=$(docker exec $C sh -c "grep -hoE 'max_drawdown_pct [0-9.-]+' ${out}/*/actual.sexp 2>/dev/null | head -1")
  n=$(docker exec $C sh -c "grep -c 'WARN: portfolio rejected fill' $WORK/$tag.log 2>/dev/null || echo 0")
  log "RESULT $tag => ${r:-<no result — CHECK FOR OOM: empty child log + no stack is the signature>} ${t} ${m} rejected_fills=${n} (wall $(( $(date +%s) - start ))s)"
}

run_arm ttl-retest-00-null 0
run_arm ttl-retest-01-rescreen-only 0
run_arm ttl-retest-01-rescreen-only 1
run_arm ttl-retest-01-rescreen-only 2

log "TTL RE-TEST DONE — cell 00 must read 281.71 or the borrowed null is invalid."
log "Compare the three rescreen draws against cell 00's own three: 265.44 / 281.71 / 397.95 (spread 132.5pp)."
