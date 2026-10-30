#!/bin/sh
# Seed-band follow-up to tier4-seeded-repin-2026-10-29 (#3404; user decision
# 2026-10-29: seed-band pins for the four tight goldens-broad cells).
# Runs tiebreak_seed 1..4 on bull-crash, covid-recovery, six-year and decade
# at one pinned build; seed 0 is the new arm already committed in
# tier4-seeded-repin-2026-10-29/results/. Specs = the golden as on main with
# ((screening_config ((tiebreak_seed k)))) prepended to config_overrides,
# staged outside any VCS tree at /tmp/t4band-run/specs/goldens-broad/<name>-k<k>.sexp.
# Same invocation as the parent chain. Each cell gets a fresh stage dir under
# a fresh $WORK, so no stage cleanup is needed.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=${PIN:?set PIN to the run tree sha}
WT=/workspaces/trading-1/.claude/worktrees/sweep-t4band
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-t4band"
FIX=$ROOT/test_data/backtest_scenarios
SPECS_HOST=/tmp/t4band-run/specs
WORK=/tmp/t4band
ART=/tmp/sweeps/t4band              # bind-mounted -> $REPO/.sweep-output/t4band
LOG_HOST=/tmp/t4band-run/chain.log
LOCK=/tmp/t4band-run/chain.lock

MIN_FREE_MIB=3072
TOTAL_MIB=7936
MIN_DISK_GB=15
# Slowest of these four cells in the parent chain: decade-2014-2023-old,
# 717 s at cap 256; the 4 h cap is > 20x it.
CELL_TIMEOUT=14400
# All cells hold 1,000 symbols (top-1000 lists), so run at 12,000 (#2882);
# the cap changes no result (perf_pit_smoke.sh asserts 256 vs 12,000 identical).
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

# One cell. $1 = family subdir, $2 = basename, $3 = arm k<seed>
run_cell() {
  sub=$1; name=$2; arm=$3
  tag="$sub--$name-$arm"
  d=$WORK/$tag
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return; fi
  docker exec $C mkdir -p "$d"
  hspec="$SPECS_HOST/$sub/$name-$arm.sexp"
  docker cp "$hspec" "$C:$d/$name.sexp" \
    || { log "RESULT $tag => <no result - spec missing>"; return; }
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

for n in bull-crash-2015-2020 covid-recovery-2020-2024 six-year-2018-2023 decade-2014-2023; do
  for k in 1 2 3 4; do
    require_disk "$n-k$k"; require_memory $MIN_FREE_MIB "$n-k$k"   # 3 GiB: these cells peak at 0.9 GB RSS (parent chain)
    run_cell goldens-broad $n k$k
  done
done
log "T4BAND CHAIN DONE"
