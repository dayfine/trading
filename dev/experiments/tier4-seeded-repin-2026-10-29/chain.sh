#!/bin/sh
# Tier-4 local golden re-pin for the Seeded tiebreak default (#3425, #3404):
# PAIRED golden runs at one pinned build (.claude/worktrees/sweep-t4seed @
# cb4243309 = origin/main 2026-10-29).
#   new arm = the golden spec as committed (default candidate_ranking Seeded, seed 0)
#   old arm = the same spec + ((screening_config ((candidate_ranking Alphabetical))))
#             prepended to config_overrides, staged OUTSIDE any VCS tree at
#             /tmp/t4seed-run/specs/<family>/<name>-old.sexp by stage_specs.sh.
# Same invocation as dev/experiments/exit-basis-flip-2026-09-03/chain.sh
# (stage dir, --parallel 1, --fixtures-root, CSV bars from the run tree's
# committed test_data, no snapshot-dir), plus GNU-time peak RSS per cell.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=cb4243309
WT=/workspaces/trading-1/.claude/worktrees/sweep-t4seed
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-t4seed"
FIX=$ROOT/test_data/backtest_scenarios
SPECS_HOST=/tmp/t4seed-run/specs
WORK=/tmp/t4seedg
ART=/tmp/sweeps/t4seedg            # bind-mounted -> $REPO/.sweep-output/t4seedg
LOG_HOST=/tmp/t4seed-run/chain.log
LOCK=/tmp/t4seed-run/chain.lock

MIN_FREE_MIB=3072
TOTAL_MIB=7936
MIN_DISK_GB=15
# 4h hard cap per cell; slowest measured cell of these shapes is the 30y
# capacity probe at 1,918 s (dev/notes/n1000-30y-capacity-2026-04-30.md), so
# the cap is > 7x it; every other cell measured <= 611 s on 2026-09-03.
CELL_TIMEOUT=14400
# Snapshot mmap handle cap (#2882). Every cell here holds > 256 symbols (sp500
# 510-525, top-1000, top-3000), so the 256 default LRU-thrashes: the first
# segment of this chain (cells up to tier4-broad-10y) ran at 256 and the
# 15y sp500 cell was still running after 35 min vs 412 s on GHA the same day.
# The cap changes no result (perf_pit_smoke.sh asserts 256 vs 12,000
# byte-identical); both arms of every pair ran at the same cap except the
# capacity probe (new arm at 256 in the first segment, old arm at 12,000).
CAP=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec -w "$ROOT" $C sh -c "$1"; }

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
log "HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD) (run tree; expect $PIN)"
log "SNAPSHOT_MAX_MMAP_HANDLES=$CAP"
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: dirty"; exit 1; }
require_disk pre-run; require_memory $MIN_FREE_MIB pre-run
docker exec $C mkdir -p $WORK $ART
run "test -x ./_build/default/trading/backtest/scenarios/scenario_runner.exe" \
  || { log "ABORT: scenario_runner not built"; exit 1; }

# One cell. $1 = family subdir, $2 = basename, $3 = new|old
run_cell() {
  sub=$1; name=$2; arm=$3
  tag="$sub--$name-$arm"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C sh -c "mkdir -p $d && rm -rf $d/*"
  if [ "$arm" = old ]; then
    hspec="$SPECS_HOST/$sub/$name-old.sexp"
    docker cp "$hspec" "$C:$d/$name.sexp" \
      || { log "RESULT $tag => <no result - old spec missing>"; return; }
  else
    hspec="$HOST_WT/trading/test_data/backtest_scenarios/$sub/$name.sexp"
    docker exec $C cp "$FIX/$sub/$name.sexp" $d/
  fi
  sname=$(grep -oE '^\(\(name "[^"]+"' "$hspec" | sed 's/.*"\(.*\)"/\1/')
  sname=${sname:-$name}
  log "RUN $tag (spec name $sname)"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_MAX_MMAP_HANDLES=$CAP timeout $CELL_TIMEOUT \
    /usr/bin/time -f %M -o $WORK/$tag.rss \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --parallel 1 --fixtures-root $FIX --no-emit-all-eligible \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${out}/${sname}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "cp ${out}/${sname}/actual.sexp $ART/${tag}-actual.sexp 2>/dev/null; \
    cp ${out}/${sname}/trades.csv $ART/${tag}-trades.csv 2>/dev/null; \
    cp ${out}/${sname}/summary.sexp $ART/${tag}-summary.sexp 2>/dev/null; \
    cp $WORK/$tag.rss $ART/${tag}.rss 2>/dev/null; \
    cp $WORK/$tag.log $ART/${tag}.log 2>/dev/null" || true
  verdict=$(docker exec $C sh -c "grep -oE '(PASS|FAIL[^|]*)' $WORK/$tag.log | tail -1")
  rss=$(docker exec $C sh -c "tail -1 $WORK/$tag.rss 2>/dev/null")
  log "RESULT $tag => ${m:-<no result - see $ART/$tag.log; OOM leaves empty log>} [$verdict] (peak_rss_kb ${rss:-?}) (wall $(( $(date +%s) - start ))s)"
}

pair() { run_cell "$1" "$2" new; run_cell "$1" "$2" old; }
guard() { require_disk "$1"; require_memory "$2" "$1"; }

# --- Phase 1: the two cells with no ledger time (measured first) ---
guard p1 4096
run_cell goldens-broad sp500-30y-capacity-1996 new
pair     goldens-sp500-historical sp500-2011-2026-bah-brk-b   # BAH: must be bit-identical
log "PHASE 1 COMPLETE"

# --- Phase 2: goldens-broad (tier 4 release gate) ---
for n in tier4-broad-1y bull-crash-2015-2020 covid-recovery-2020-2024 six-year-2018-2023 \
         decade-2014-2023 tier4-broad-10y; do
  guard "p2-$n" 4096
  pair goldens-broad $n
done
log "PHASE 2 COMPLETE"

# --- Phase 3: goldens-sp500-historical ---
for n in sp500-2010-2026 sp500-2010-2026-longshort sp500-2000-2026-catstop \
         sp500-2000-2026-catstop-armon sp500-2000-2026-longshort sp500-1998-2026 \
         top3000-2000-2026-catstop; do
  guard "p3-$n" 4096
  pair goldens-sp500-historical $n
done
log "PHASE 3 COMPLETE"

# --- Phase 4: capacity probe old arm ---
guard p4 4096
run_cell goldens-broad sp500-30y-capacity-1996 old
log "PHASE 4 COMPLETE"
log "T4SEED GOLDEN CHAIN DONE"
