#!/bin/sh
# D1/D2 exit-basis default flip (PR #2648): PAIRED golden runs at one pinned
# build (.claude/worktrees/sweep-d1d2 @ 398f57111 = the flip commit).
#   new arm  = the golden spec as committed (inherits the flipped defaults)
#   old arm  = the same spec + ((sim_exit_fill_next_open false))
#              ((stops_config ((stop_skip_entry_bar false)))) prepended to
#              config_overrides, staged OUTSIDE any VCS tree at
#              /tmp/d1d2-run/specs/<family>/<name>-old.sexp (sweep-hygiene).
# For the 12 cells that #2587 ran at 5dc61da07 (clock-surface results/goldens/
# *-actual.sexp) the old arm is that committed artifact — bit-identical to
# current main by R1 (every merge since was default-off or docs) — validated
# by ONE direct old-arm re-run (sp500-2019-2023-armed-stoplimit-old).
# Mirrors golden_sp500_postsubmit.sh / perf_tier*.sh invocation (stage dir,
# --parallel 1, --fixtures-root, no snapshot-dir) so numbers are pin-comparable.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=398f57111
WT=/workspaces/trading-1/.claude/worktrees/sweep-d1d2
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-d1d2"
FIX=$ROOT/test_data/backtest_scenarios
SPECS_HOST=/tmp/d1d2-run/specs
WORK=/tmp/d1d2g
ART=/tmp/sweeps/d1d2g            # bind-mounted -> $REPO/.sweep-output/d1d2g
LOG_HOST=/tmp/d1d2-run/chain.log
LOCK=/tmp/d1d2-run/chain.lock

MIN_FREE_MIB=3072
TOTAL_MIB=7936
MIN_DISK_GB=15
CELL_TIMEOUT=14400   # 4h hard cap per cell

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
  [ "$free_mib" -ge "$1" ] || { log "ABORT ($2): ${free_mib}MiB free < $1"; exit 1; }
}
require_disk() {
  free_gb=$(df -g /System/Volumes/Data | tail -1 | awk '{print $4}')
  [ "${free_gb:-0}" -ge "$MIN_DISK_GB" ] || { log "ABORT ($1): ${free_gb}GB free"; exit 1; }
}

touch "$LOG_HOST"
[ -d "$HOST_WT" ] || { log "ABORT: worktree missing"; exit 1; }
log "run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD) (expect $PIN)"
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: dirty"; exit 1; }
require_disk pre-build; require_memory $MIN_FREE_MIB pre-build
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
    docker cp "$SPECS_HOST/$sub/$name-old.sexp" "$C:$d/$name.sexp" \
      || { log "RESULT $tag => <no result - old spec missing>"; return; }
  else
    docker exec $C cp "$FIX/$sub/$name.sexp" $d/
  fi
  if [ "$arm" = old ]; then hspec="$SPECS_HOST/$sub/$name-old.sexp"; else hspec="$HOST_WT/trading/test_data/backtest_scenarios/$sub/$name.sexp"; fi
  sname=$(grep -oE '^\(\(name "[^"]+"' "$hspec" | sed 's/.*"\(.*\)"/\1/')
  sname=${sname:-$name}
  log "RUN $tag (spec name $sname)"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data timeout $CELL_TIMEOUT \
    ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
      --dir $d --parallel 1 --fixtures-root $FIX --no-emit-all-eligible \
      > $WORK/$tag.log 2>&1; echo exit=\$? >> $WORK/$tag.log"
  out=$(docker exec $C sh -c "grep 'Output root' $WORK/$tag.log | tail -1 | sed 's/.*: //'")
  m=$(docker exec $C sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|win_rate [0-9.eE+-]+' ${out}/${sname}/actual.sexp 2>/dev/null | tr '\n' ' '")
  docker exec $C sh -c "cp ${out}/${sname}/actual.sexp $ART/${tag}-actual.sexp 2>/dev/null; \
    cp ${out}/${sname}/trades.csv $ART/${tag}-trades.csv 2>/dev/null; \
    cp ${out}/${sname}/summary.sexp $ART/${tag}-summary.sexp 2>/dev/null; \
    cp $WORK/$tag.log $ART/${tag}.log 2>/dev/null" || true
  verdict=$(docker exec $C sh -c "grep -oE '(PASS|FAIL[^|]*)' $WORK/$tag.log | tail -1")
  log "RESULT $tag => ${m:-<no result - see $ART/$tag.log; OOM leaves empty log>} [$verdict] (wall $(( $(date +%s) - start ))s)"
}

pair() { run_cell "$1" "$2" new; run_cell "$1" "$2" old; }
guard() { require_disk "$1"; require_memory "$2" "$1"; }

# --- Phase 1: postsubmit 5y cells (CI-facing; fast) ---
guard p1 $MIN_FREE_MIB
pair     goldens-sp500 sp500-2019-2023-armed-stoplimit      # old = lineage check vs #2587 artifact
run_cell goldens-sp500 sp500-2019-2023-long-only new
run_cell goldens-sp500 sp500-2019-2023 new
run_cell goldens-custom-universe-scenarios weinstein-2019-full-pool new
run_cell goldens-custom-universe-scenarios weinstein-2019-top-500 new
pair     goldens-custom-universe-scenarios weinstein-2019-armed-e
log "PHASE 1 COMPLETE"

# --- Phase 2: tagged historical (nightly) ---
guard p2 $MIN_FREE_MIB
run_cell goldens-sp500-historical sp500-2010-2026 new
run_cell goldens-sp500-historical sp500-2010-2026-longshort new
log "PHASE 2 COMPLETE"

# --- Phase 3: tier-2 nightly (goldens-small + smoke) ---
guard p3 $MIN_FREE_MIB
for n in bull-crash-2015-2020 covid-recovery-2020-2024 six-year-2018-2023; do pair goldens-small $n; done
for n in bull-2019h2 crash-2020h1 recovery-2023; do pair smoke $n; done
log "PHASE 3 COMPLETE"

# --- Phase 4: tier-3 weekly perf-sweep ---
guard p4 $MIN_FREE_MIB
for n in bull-1y bull-3y; do pair perf-sweep $n; done
log "PHASE 4 COMPLETE"

# --- Phase 5: untagged historical (multi-hour; old arm = #2587 artifacts) ---
for n in sp500-2000-2026-catstop sp500-2000-2026-catstop-armon sp500-2000-2026-longshort \
         sp500-1998-2026 top3000-2000-2026-catstop; do
  guard "p5-$n" 4096
  run_cell goldens-sp500-historical $n new
done
log "PHASE 5 COMPLETE"

# --- Phase 6: tier-4 release gate (paired, multi-hour) ---
for n in tier4-broad-1y bull-crash-2015-2020 covid-recovery-2020-2024 six-year-2018-2023 \
         decade-2014-2023 tier4-broad-10y; do
  guard "p6-$n" 4096
  pair goldens-broad $n
done
log "PHASE 6 COMPLETE"
log "D1D2 GOLDEN CHAIN DONE"
