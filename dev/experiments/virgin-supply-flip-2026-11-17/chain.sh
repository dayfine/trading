#!/bin/sh
# virgin_supply_basis default flip (#3664): PAIRED golden runs at one pinned build (the flip PR tip,
# checked out at .claude/worktrees/sweep-vsb so the container sees it).
#   new arm = the golden spec as committed (inherits the flipped default, One_basis)
#   old arm = the same spec with ((virgin_supply_basis Legacy_mixed)) prepended to config_overrides,
#             written OUTSIDE any VCS tree at $SPECS_HOST/<family>/<name>-old.sexp (sweep-hygiene)
# Both arms run directly; every cell is a pair. Mirrors exit-basis-flip-2026-09-03/chain.sh (stage dir,
# --parallel 1, --fixtures-root, CSV bars from the worktree's test_data, no snapshot dir) so numbers are
# pin-comparable. Skipped as in that chain: bah-* cells (no strategy config), goldens-hybrid-tier-experiment
# (spec parse only), goldens-broad/sp500-30y-capacity-1996 (untagged probe), and the runtest goldens
# (panel_goldens, smoke/panel-golden-*, smoke/tiered-loader-parity), which the flip commit regenerates.
set -u

C=trading-1-dev
REPO=/Users/difan/Projects/trading-1
PIN=${PIN:?PIN=<flip PR tip sha>}
WT=/workspaces/trading-1/.claude/worktrees/sweep-vsb
ROOT=$WT/trading
HOST_WT="$REPO/.claude/worktrees/sweep-vsb"
FIX=$ROOT/test_data/backtest_scenarios
HOST_FIX="$HOST_WT/trading/test_data/backtest_scenarios"
RUN_HOST=${RUN_HOST:-/tmp/vsb-flip-run}   # 11-17 run used $REPO/.sweep-output/vsb-flip-run after a host restart
SPECS_HOST=$RUN_HOST/specs
WORK=/tmp/vsbg
ART=/tmp/sweeps/vsbg              # bind-mounted -> $REPO/.sweep-output/vsbg
LOG_HOST=$RUN_HOST/chain.log
LOCK=$RUN_HOST/chain.lock
OLD_OVERRIDE='((virgin_supply_basis Legacy_mixed))'

MIN_FREE_MIB=3072
MIN_DISK_GB=15
CELL_TIMEOUT=14400   # 4 h hard cap per cell; the slowest precedent cell took 958 s

mkdir -p "$RUN_HOST" "$SPECS_HOST"
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }

mkdir "$LOCK" 2>/dev/null || { echo "ABORT: another chain holds $LOCK"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

TOTAL_MIB=$(docker exec $C sh -c "awk '/MemTotal/ {print int(\$2/1024)}' /proc/meminfo")
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

# Old-arm spec: insert $OLD_OVERRIDE as the first element of the config_overrides list.
write_old_spec() { # $1 family, $2 name
  mkdir -p "$SPECS_HOST/$1"
  awk -v ov="$OLD_OVERRIDE" '
    st == 2 { print; next }
    st == 0 && (i = index($0, "(config_overrides")) { st = 1; pre = substr($0, 1, i + 16); rest = substr($0, i + 17) }
    st == 0 { print; next }
    st == 1 && pre == "" { rest = $0 }
    st == 1 { j = index(rest, "(")
              if (j > 0) { print pre substr(rest, 1, j) ov " " substr(rest, j + 1); st = 2 } else print pre rest
              pre = "" }
    END { if (st != 2) exit 1 }' "$HOST_FIX/$1/$2.sexp" > "$SPECS_HOST/$1/$2-old.sexp" \
    || { log "ABORT: no config_overrides list in $1/$2"; exit 1; }
}

touch "$LOG_HOST"
[ -d "$HOST_WT" ] || { log "ABORT: worktree missing"; exit 1; }
head=$(git -C "$HOST_WT" rev-parse HEAD)
log "run tree HEAD=$head (expect $PIN)"
case $head in "$PIN"*) ;; *) log "ABORT: HEAD is not $PIN"; exit 1 ;; esac
[ -z "$(git -C "$HOST_WT" status --porcelain --untracked-files=no)" ] || { log "ABORT: dirty"; exit 1; }
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
    hspec="$SPECS_HOST/$sub/$name-old.sexp"
    docker cp "$hspec" "$C:$d/$name.sexp" || { log "RESULT $tag => <no result - old spec missing>"; return; }
  else
    hspec="$HOST_FIX/$sub/$name.sexp"
    docker exec $C cp "$FIX/$sub/$name.sexp" $d/
  fi
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

pair() { write_old_spec "$1" "$2"; run_cell "$1" "$2" new; run_cell "$1" "$2" old; }
guard() { require_disk "$1"; require_memory "$2" "$1"; }

# --- Phase 1: PR-time and postsubmit cells (fast) ---
guard p1 $MIN_FREE_MIB
for n in bull-3m bull-6m bull-1y bull-3y; do pair perf-sweep $n; done
for n in bull-2019h2 crash-2020h1 recovery-2023; do pair smoke $n; done
for n in sp500-2019-2023-armed-stoplimit sp500-2019-2023-long-only sp500-2019-2023; do pair goldens-sp500 $n; done
for n in weinstein-2019-armed-e weinstein-2019-full-pool weinstein-2019-top-500; do pair goldens-custom-universe-scenarios $n; done
log "PHASE 1 COMPLETE"

# --- Phase 2: tier-2 nightly (goldens-small) ---
guard p2 $MIN_FREE_MIB
for n in bull-crash-2015-2020 covid-recovery-2020-2024 six-year-2018-2023; do pair goldens-small $n; done
log "PHASE 2 COMPLETE"

# --- Phase 3: historical (tagged nightly + untagged pinned) ---
for n in sp500-2010-2026 sp500-2010-2026-longshort sp500-2000-2026-catstop sp500-2000-2026-catstop-armon \
         sp500-2000-2026-longshort sp500-1998-2026 top3000-2000-2026-catstop; do
  guard "p3-$n" 4096
  pair goldens-sp500-historical $n
done
log "PHASE 3 COMPLETE"

# --- Phase 4: tier-4 release gate ---
for n in tier4-broad-1y bull-crash-2015-2020 covid-recovery-2020-2024 six-year-2018-2023 \
         decade-2014-2023 tier4-broad-10y; do
  guard "p4-$n" 4096
  pair goldens-broad $n
done
log "PHASE 4 COMPLETE"
log "VSB GOLDEN CHAIN DONE"

