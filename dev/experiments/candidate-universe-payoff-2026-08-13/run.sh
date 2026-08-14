#!/bin/sh
# Candidate-universe PAYOFF run — the same acceptance test, over a broad
# universe, where the compression is supposed to actually pay.
#
# The 2026-08-13 acceptance run validated the MECHANISM and said so plainly:
# 302 -> 291 symbols, 188s -> 185s. The source universe was already small, so
# almost every symbol became a candidate at some point and there was nothing to
# drop. The claim that makes per-mechanism scenarios affordable is the one this
# run tests: over top-3000, a six-year window screens only a few hundred
# distinct symbols, so the fixture should be an order of magnitude smaller than
# the universe and the re-run correspondingly cheaper.
#
# ONE VARIABLE CHANGED from the acceptance run: universe breadth
# (302 -> 3000). Same window (2018-01-02..2023-12-29), same config, same
# comparison. Window length is deliberately NOT varied here -- the 26y capture
# is a separate, much more expensive follow-up, and mixing the two would leave
# a compression ratio that cannot be attributed to either.
#
# Success is BINARY and unchanged: every artefact byte-identical. A smaller
# fixture that changes one trade is a failed run, not a cheaper one.
set -e
C=trading-1-dev
WT=/workspaces/trading-1/.claude/worktrees/sweep-p02-payoff
ROOT=$WT/trading
DATA=$ROOT/test_data
FIX=$DATA/backtest_scenarios
WORK=/tmp/p02-payoff
SNAP=/tmp/snap_top3000_dedup_v5thin_adj
# HOST path: $WORK is inside the container, so a host-side `tee` into it would
# fail before the first log line ever appeared.
LOG_HOST=/tmp/p02-payoff-chain.log

SPEC_NAME=p02-top3000-base
FIXTURE_SPEC_NAME=p02-top3000-fixture
SOURCE_UNIVERSE=universes/broad-3000-2010-01-01.sexp
OUT_UNIVERSE=universes/broad3000-candidates-2018-2023.sexp
WINDOW=2018-01-02..2023-12-29

# Container capacity guard (.claude/rules/container-capacity-scheduling.md).
# Measured via `docker stats`, NOT per-process RSS: the mmap'd columnar
# warehouse inflates RSS several-fold (10.4GB RSS against a real 2.2-2.4GB
# footprint on the 08-13 cell-09 run), so an RSS-based guard refuses to launch
# on a container with plenty of room.
MIN_FREE_MIB=4096
TOTAL_MIB=7936

run() { docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $1"; }
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_HOST"; }

require_memory() {
  used_mib=$(docker stats --no-stream --format '{{.MemUsage}}' $C \
    | sed 's|/.*||' \
    | awk '/GiB/ {gsub(/GiB/,""); printf "%d", $1 * 1024; next}
           /MiB/ {gsub(/MiB/,""); printf "%d", $1; next}
           {print 0}')
  free_mib=$(( TOTAL_MIB - ${used_mib:-0} ))
  if [ "$free_mib" -lt "$MIN_FREE_MIB" ]; then
    log "ABORT ($1): only ${free_mib}MiB free (need ${MIN_FREE_MIB}) — container is busy."
    log "  A launch here is OOM-killed SILENTLY: empty child log, no stack, '<no result>'."
    exit 1
  fi
  log "$1: container at ${used_mib}MiB, ${free_mib}MiB free"
}

HERE=$(cd "$(dirname "$0")" && pwd)

docker exec $C mkdir -p $WORK $WORK/run_base $WORK/run_fix
: > "$LOG_HOST"

# The two specs are committed next to this script (base.sexp / fixture.sexp) so
# the run is reproducible from the repo alone. The acceptance run's specs lived
# only in the container's /tmp and did not survive.
docker cp "$HERE/base.sexp"    $C:$WORK/base.sexp
docker cp "$HERE/base.sexp"    $C:$WORK/run_base/base.sexp
docker cp "$HERE/fixture.sexp" $C:$WORK/run_fix/fixture.sexp

# ---------------------------------------------------------------------------
# [0/5] pinned worktree + build
# ---------------------------------------------------------------------------
# Runs never build from the parent working copy (sweep-hygiene.md): the
# 2026-07-26 leverage-dawn surface ran from a tree that was mutated mid-run and
# produced silently wrong, irreproducible folds (#2108).
REPO=$(cd "$HERE/../../.." && pwd)
SHA=$(git -C "$REPO" rev-parse --short origin/main)
HOST_WT="$REPO/.claude/worktrees/sweep-p02-payoff"
log "[0/5] pinned worktree at $SHA"
if [ ! -d "$HOST_WT" ]; then
  git -C "$REPO" worktree add --detach "$HOST_WT" "$SHA"
fi
# The worktree lives under .claude/worktrees/ (repo-local) so the container
# sees it through the bind-mount; a /tmp path would be host-only and dune,
# running inside the container, would silently build the parent tree instead.
[ -z "$(git -C "$HOST_WT" status --porcelain)" ] || { log "ABORT: run tree is dirty"; exit 1; }
log "  run tree HEAD=$(git -C "$HOST_WT" rev-parse --short HEAD)"
require_memory "pre-build"
run "dune build trading/backtest/all_eligible/bin/all_eligible_runner.exe \
     trading/backtest/scenarios/candidate_universe/pick.exe \
     trading/backtest/scenarios/scenario_runner.exe 2>&1 | tail -5"

# ---------------------------------------------------------------------------
# [1/5] capture at the LOWEST gate
# ---------------------------------------------------------------------------
# min_grade F, not the default C: the fixture must be the superset over EVERY
# variant's gate, not just what the default config admits. This is the single
# precondition the soundness argument rests on and it is not checkable from
# inside the builder.
log "[1/5] capture at min_grade F over top-3000"
require_memory "pre-capture"
run "TRADING_DATA_DIR=$DATA ./_build/default/trading/backtest/all_eligible/bin/all_eligible_runner.exe \
  --scenario $WORK/base.sexp --min-grade F --snapshot-dir $SNAP \
  --out-dir $WORK/capture > $WORK/capture.log 2>&1"
run "wc -l < $WORK/capture/grade-F/trades.csv" | \
  while read -r n; do log "  capture rows: $n"; done

# ---------------------------------------------------------------------------
# [2/5] build the fixture universe
# ---------------------------------------------------------------------------
# --from-universe is load-bearing: sectors are inherited from the SOURCE
# universe, which is what the full run itself used. Falling back to the stub
# data/sectors.csv resolved 297 of 304 symbols to the default sector on the
# first real run, which would have collapsed the sector filter.
log "[2/5] build the fixture universe"
run "./_build/default/trading/backtest/scenarios/candidate_universe/pick.exe \
  --capture $WORK/capture/grade-F/trades.csv \
  --data-dir $DATA --from-universe $FIX/$SOURCE_UNIVERSE \
  --window $WINDOW --min-grade F -o $FIX/$OUT_UNIVERSE"

# universe_size must match the fixture's actual entry count: the runner treats
# it as a declared expectation, so a stale 3000 here would either fail
# validation or silently describe a universe the spec is not running.
# Read the count from pick.exe's own provenance header rather than counting
# lines: entries are pretty-printed and several share a line, so a line count
# reads 217 where the file holds 291 symbols.
NSYM=$(docker exec $C sh -c "grep -m1 '^;; total:' $FIX/$OUT_UNIVERSE | awk '{print \$3}'")
NSYM=$(printf '%s' "$NSYM" | tr -dc '0-9')
[ -n "$NSYM" ] && [ "$NSYM" -gt 0 ] || { log "ABORT: could not count fixture symbols in $OUT_UNIVERSE"; exit 1; }
log "  fixture universe: $NSYM symbols (source: 3000)"
docker exec $C sh -c "sed -i 's|(universe_size 0)|(universe_size $NSYM)|' $WORK/run_fix/fixture.sexp"

# The emitted universe lands in the pinned worktree's test_data, which is
# deleted with the worktree. Copy it back beside this script so the fixture --
# the actual deliverable of this run -- survives to be committed, together with
# the resolved fixture spec that names it.
docker cp "$C:$FIX/$OUT_UNIVERSE"        "$HERE/$(basename "$OUT_UNIVERSE")"
docker cp "$C:$WORK/run_fix/fixture.sexp" "$HERE/fixture.resolved.sexp"

# ---------------------------------------------------------------------------
# [3/5] baseline and fixture runs
# ---------------------------------------------------------------------------
# Sequential, not parallel: two top-3000 workers do not fit in 7.75GB, and the
# per-run wall time is itself one of the numbers this experiment reports.
for d in run_base run_fix; do
  log "[3/5] $d"
  require_memory "pre-$d"
  start=$(date +%s)
  run "TRADING_DATA_DIR=$DATA ./_build/default/trading/backtest/scenarios/scenario_runner.exe \
    --dir $WORK/$d --fixtures-root $FIX --snapshot-dir $SNAP \
    --no-emit-all-eligible --parallel 1 --progress-every 26 \
    > $WORK/$d.log 2>&1; echo exit=\$? >> $WORK/$d.log"
  log "  $d wall: $(( $(date +%s) - start ))s"
done

# ---------------------------------------------------------------------------
# [4/5] byte-compare every artefact
# ---------------------------------------------------------------------------
# Not headline metrics: a fixture can reproduce total_return_pct while
# reordering or substituting individual trades.
log "[4/5] byte-compare"
docker exec $C bash -c '
  b=$(grep "Output root" '"$WORK"'/run_base.log | tail -1 | sed "s/.*: //")/'"$SPEC_NAME"'
  f=$(grep "Output root" '"$WORK"'/run_fix.log  | tail -1 | sed "s/.*: //")/'"$FIXTURE_SPEC_NAME"'
  rc=0
  for x in actual.sexp trades.csv equity_curve.csv trade_audit.sexp macro_trend.sexp open_positions.csv; do
    if cmp -s "$b/$x" "$f/$x"; then echo "$x IDENTICAL"; else echo "$x DIFFERS"; rc=1; fi
  done
  echo "universe: $(wc -l < $b/universe.txt) -> $(wc -l < $f/universe.txt) symbols"
  exit $rc' 2>&1 | tee -a "$LOG_HOST"

log "[5/5] done"
