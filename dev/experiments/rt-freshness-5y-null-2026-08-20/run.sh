#!/bin/sh
# Does the 5-year testbed have a drawdown null? Six cells, 2 arms x 3 salts.
#
# WHY THIS RUN EXISTS. The 26y seeded A/B
# (dev/experiments/rt-freshness-seeded-2026-08-20/) found Range_top_breakout
# improving MaxDD 38.76 -> 30.81 past a measured 4.76pp null at all three
# salts. The 5-year sp500 testbed says the OPPOSITE: 16.98 -> 21.43, i.e.
# +4.45pp the WRONG way.
#
# The 26y writeup originally dismissed that with "5 years of 187 names cannot
# resolve a ~3pp drawdown effect". THAT THRESHOLD WAS ASSERTED, NEVER MEASURED
# (qc-behavioral F4 on #2433). Dismissing the 5y result requires its drawdown
# null to be ABOVE ~4.5pp, and no run in this repo establishes any 5y null at
# all -- every prior 5y cell was a SINGLE realization, which cannot distinguish
# "deterministic" from "one draw".
#
# The 5y testbed is deterministic in the sense that re-running the same salt
# reproduces digit-for-digit (verified 2026-08-20). That says nothing about
# spread ACROSS salts, which is what a null is.
#
# WHY SIX CELLS AND NOT THREE. Three core salts alone give the null but not the
# paired treatment effect. Running both arms at the same three salts gives
# both, and pairs each comparison within a salt so the two arms see the same
# intraday path realization. Same design as the 26y run -- deliberately, so the
# two are directly comparable.
#
# COST. ~4 min a cell against committed test_data => ~25 min total. This is the
# cheapest measurement in the current program relative to what it settles.
#
# PRE-REGISTERED DECISION RULE (written before any number exists):
#   1. TRIPWIRE. core at salt 0 must reproduce total_return_pct 112.28 /
#      max_drawdown_pct 16.98 (the recorded 2026-08-12 figures, re-verified
#      2026-08-20). A miss means the binary or the data moved and NOTHING
#      below is interpretable.
#   2. Compute the 5y null per metric = max-minus-min across core's three
#      salts.
#   3. Read the answer off the null, not off the point estimate:
#      - 5y MaxDD null > 4.45pp  => the 5y contradiction is INSIDE its own
#        noise. It never was evidence against the 26y result, and the
#        dismissal in the 26y writeup becomes correct-for-the-first-time
#        (measured, not asserted).
#      - 5y MaxDD null < 4.45pp  => the contradiction is REAL and the 26y
#        drawdown finding is regime- or universe-conditional, not general.
#        That is the outcome that blocks a confirmation grid framed on 26y
#        alone, and it must be reported as loudly as the favourable one.
#      - null within ~1pp of 4.45 => underpowered at 3 salts; say so and
#        extend to 5 salts rather than picking a side.
#   4. Report the rt-vs-core gap per salt against that null under the same
#      all-three-salts rule the 26y run used. Sign flips => not moved.
#
# NOTE the two possible outcomes are stated BEFORE the run and one of them
# undercuts the finding this session already published. That is the point.
#
# Pinned-worktree + memory/disk guards per sweep-hygiene.md. NO flock: macOS
# has no flock(1), so single-instance rests on the caller.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
WT=/workspaces/trading-1/.claude/worktrees/sweep-rt5y
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-rt5y"
SPECS_HOST="$REPO/dev/experiments/rt-freshness-5y-null-2026-08-20/specs"
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/rt5y
LOG_HOST=/tmp/rt5y-chain.log

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
  docker cp "$SPECS_HOST/sm-v4-${arm}.sexp" $C:$d/
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
  ( run_cell 00-core-w4 "$salt" ) &
  p1=$!
  ( run_cell 02-fresh-rangetop "$salt" ) &
  p2=$!
  wait $p1 $p2
  log "salt $salt pair complete"
done

log "RT5Y DONE"
log "TRIPWIRE: 00-core-w4-s0 must read total_return_pct ~112.28 and max_drawdown_pct ~16.98"
