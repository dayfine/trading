#!/bin/sh
# Confirmation grid for nearfloor + ttl4 (promotion-confirmation.md).
#
# WHAT CAME BEFORE
# ----------------
# The seeded re-run (dev/experiments/ladder-v4-seeded-2026-08-14/results.md)
# established, on top-3000 x 2000-2026:
#   - null (cell 00, 3 salts): 265.4 / 281.7 / 398.0 -> spread 132.5pp
#   - nearfloor clears it three independent ways: 483.1 / 508.1 / 568.1, every
#     one above the null's MAXIMUM
#   - ttl4 costs +0.5pp against core on the same salt, and ttl8 vs ttl4 is
#     inside the null -> the re-screen cancel does the work, the clock number
#     is a free dial
#
# That is ONE window and ONE universe. Per promotion-confirmation.md an ACCEPT
# from a single surface is necessary but not sufficient: the candidate must be
# robust across >=3 (period x universe) contexts, and the promotable VALUE must
# be the one that survives the grid, not the single-window winner. The
# 2026-05-31 early-admission reversal is the standing warning — four agreeing
# post-2009 cells were overturned by one deep window.
#
# THE GRID
# --------
#   Cell A  top-3000 x 2000-2026   ALREADY RUN (spans dot-com bust + GFC, so it
#                                  is the macro-diverse cell the rule requires)
#   Cell B  sp500    x 2000-2026   UNIVERSE diversity, same period
#   Cell C  top-3000 x 2010-2026   PERIOD diversity — post-GFC only, i.e. the
#                                  bull-dominated regime. If nearfloor's edge is
#                                  a bear-regime artifact, this is where it dies.
#
# Four arms per cell, each differing from core by exactly one knob (or both):
#   core       ttl=0  support_floor_anchor_scope=Window_extreme
#   nearfloor  ttl=0  scope=Nearest
#   ttl4       ttl=4  scope=Window_extreme
#   both       ttl=4  scope=Nearest
#
# Cell B also runs core at 3 salts: the null is window- and universe-specific,
# so cell A's 132.5pp cannot be assumed to carry. Cell C gets 2 salts (its
# shorter window makes each run cheaper, but 3 would still cost more than the
# information is worth at this stage).
#
# DECISION RULE (from the rule file, not invented here): promote a value only if
# it beats baseline in a strong majority of cells AND is never badly dominated
# in any. On grid disagreement, keep the mechanism as a default-off axis and do
# NOT promote the headline single-window winner.
set -e
C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
WT=/workspaces/trading-1/.claude/worktrees/sweep-v4-seeded
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-v4-seeded"
SPECS_HOST=/tmp/v4grid-specs
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/v4grid
LOG_HOST=/tmp/v4grid-chain.log

SNAP_T3K=/tmp/snap_top3000_dedup_v5thin_adj
SNAP_SP5=/tmp/snap_sp500_2000_2026_v5thin_adj

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

# keep prior results so completed cells are skipped on resume
touch "$LOG_HOST"
docker exec $C mkdir -p $WORK

# Reuse the seeded run's pinned worktree — same binary, so grid results are
# directly comparable to cell A's rather than to a differently-built tree.
[ -d "$HOST_WT" ] || { log "ABORT: pinned worktree $HOST_WT missing"; exit 1; }
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD)"
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" \
  || { log "ABORT: scenario_runner not built in the pinned worktree"; exit 1; }

run_cell() {
  spec=$1; salt=$2; snap=$3
  tag="${spec}-s${salt}"
  d=$WORK/$tag
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/${spec}.sexp" $C:$d/${spec}.sexp
  require_memory "pre-$tag"; require_disk "pre-$tag"
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=${salt} \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX --snapshot-dir $snap \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  r=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.-]+' ${out}/*/actual.sexp 2>/dev/null | head -1")
  t=$(docker exec $C sh -c "grep -hoE 'total_trades [0-9]+' ${out}/*/actual.sexp 2>/dev/null | head -1")
  m=$(docker exec $C sh -c "grep -hoE 'max_drawdown_pct [0-9.-]+' ${out}/*/actual.sexp 2>/dev/null | head -1")
  log "RESULT $tag => ${r:-<no result — CHECK FOR OOM: empty child log + no stack is the signature>} ${t} ${m} (wall $(( $(date +%s) - start ))s)"
}

# --- Cell B: sp500 x 2000-2026. Null first, then the arms. ---
run_cell gridB-sp500-core      0 $SNAP_SP5
run_cell gridB-sp500-core      1 $SNAP_SP5
run_cell gridB-sp500-core      2 $SNAP_SP5
run_cell gridB-sp500-nearfloor 0 $SNAP_SP5

# --- Cell C: top-3000 x 2010-2026. ---
run_cell gridC-t3k2010-core      0 $SNAP_T3K
run_cell gridC-t3k2010-core      1 $SNAP_T3K
run_cell gridC-t3k2010-nearfloor 0 $SNAP_T3K

log "GRID DONE — read each cell against ITS OWN core salts, never against cell A's null."
