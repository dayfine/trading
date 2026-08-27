#!/bin/sh
# clock-surface (#2405) -- entry_order_max_rest_weeks surface {0,13,26,52,156}
# on two broad cells. See README.md for the pre-registered decision rule.
#
# Cell B: broad5y core lineage, 2019-01-02..2023-12-29, top-3000 PIT-2019.
# Cell A: record-baseline lineage, 2000-01-01..2026-06-26, top-3000 PIT-2000
#         (macro-diverse: dot-com bust + GFC in-window).
#
# Order: all B arms first (fast, early read), then A arms (multi-hour each).
# One 26y worker at a time; B arms run 2-concurrent per capacity table.
# Arm 0 of each cell is the FRESH NULL at this build -- the committed
# record-baseline (731.64) and broad5y tripwire (281.71) predate #2561's
# RS-lookback change and #2569's default flips, so a moved number on arm 0
# is expected (binary moved); arms diff against THIS run's arm 0 only.
#
# Pinned-worktree + guards per sweep-hygiene.md. Salt 0 only; noise floors
# from the committed 3-salt records (26y: 132.5pp old-basis; broad5y: see
# rt-freshness-broad5y README). Verdicts come from the paired trade-level
# dissection, not top-lines (mechanism-validation-rigor).
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=90dfd6e97
WT=/workspaces/trading-1/.claude/worktrees/sweep-clock2405
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-clock2405"
SPECS_HOST="/tmp/clock2405-run/specs"   # staged OUTSIDE any VCS tree (sweep-hygiene)
FIX=$ROOT/test_data/backtest_scenarios
WORK=/tmp/clock2405
LOG_HOST=/tmp/clock2405-chain.log
ART_HOST="$REPO/.sweep-output/clock2405"   # bind-mounted; per-arm artifacts land here
SNAP=/tmp/snap_top3000_dedup_v5thin_adj

MIN_FREE_MIB=4096
TOTAL_MIB=7936
MIN_DISK_GB=6
LOCK=/tmp/clock2405.lock

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }

mkdir "$LOCK" 2>/dev/null || { echo "ABORT: another chain instance holds $LOCK"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

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
mkdir -p "$ART_HOST"
[ -d "$HOST_WT" ] || { log "ABORT: pinned worktree $HOST_WT missing"; exit 1; }
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD) (expect $PIN)"
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: run tree is dirty"; exit 1; }
[ -d "$SPECS_HOST" ] || { log "ABORT: staged specs missing at $SPECS_HOST"; exit 1; }
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

# One cell = one arm at salt 0. Metric glob is scoped to the arm's own
# named subdir (sweep-hygiene: a metric glob must be scoped to ONE arm).
run_cell() {
  arm=$1
  tag="${arm}-s0"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  docker cp "$SPECS_HOST/${arm}.sexp" $C:$d/
  log "RUN $tag"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --fixtures-root $FIX --snapshot-dir $SNAP \
      --no-emit-all-eligible --parallel 1 --progress-every 26 \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${out}/${arm}/actual.sexp 2>/dev/null | tr '\n' ' '")
  # Commit-grade per-arm artifacts to the bind-mounted host dir
  # (feedback_commit_raw_per_arm_artifacts: never read numbers from a chain log).
  docker exec $C sh -c "cp ${out}/${arm}/actual.sexp /tmp/sweeps/clock2405/${arm}-actual.sexp 2>/dev/null; \
    cp ${out}/${arm}/trades.csv /tmp/sweeps/clock2405/${arm}-trades.csv 2>/dev/null; \
    cp ${out}/${arm}/params.sexp /tmp/sweeps/clock2405/${arm}-params.sexp 2>/dev/null" || true
  log "RESULT $tag => ${m:-<no result — CHECK FOR OOM: empty child log + no stack is the signature>} (wall $(( $(date +%s) - start ))s)"
}

# --- Cell C only (follow-on) ---


# --- Cell A: 26y, strictly one at a time ---
for arm in clockC-0 clockC-26 clockC-52; do
  require_disk "pre-$arm"; require_memory "pre-$arm"
  run_cell "$arm"
done
log "CELL C DONE"
