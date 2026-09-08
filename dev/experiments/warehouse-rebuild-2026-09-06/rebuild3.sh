#!/bin/sh
# Armed splice-action rebuild of the 2000 vintage (PR-B, #2708), paired:
#   control   = -detect-splices -no-splice-action  (report-only: warehouse identical to an unarmed build, plus splice_actions.csv)
#   treatment = -detect-splices                    (drop interleaved, cut reuse/misscale at the last splice)
# Same builder (build_scenario_snapshots.exe, scenario-driven: universe + index + sector ETFs, warmup-windowed),
# same superset universe as the _v7mark build (staged OUTSIDE any VCS tree per sweep-hygiene.md), same exceptions file.
# Sequential; container-exclusive (no agents alongside). Pinned worktree: sweep-wh0908 @ 077b48973 (main after #2709).
set -u
C=trading-1-dev
WT=/workspaces/trading-1/.claude/worktrees/sweep-wh0908
ROOT=$WT/trading
EXE=$ROOT/_build/default/trading/backtest/snapshot_warehouse/build_scenario_snapshots.exe
CSV=/workspaces/trading-1/data
EXC=$ROOT/test_data/warehouse_exceptions.sexp
SPEC=/tmp/wh-rebuild/specs/wh-2000-superset.sexp
LOG_HOST=/tmp/wh-rebuild/rebuild3.log
LOCK=/tmp/wh-rebuild/rebuild3.lock
RES=dev/experiments/warehouse-rebuild-2026-09-06/results
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
mkdir -p /tmp/wh-rebuild; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C test -x $EXE || { log "ABORT: build_scenario_snapshots.exe not built in $WT"; exit 1; }
docker exec $C mkdir -p /tmp/wh-rebuild/specs
docker cp /tmp/wh-rebuild/specs/wh-2000-superset.sexp $C:/tmp/wh-rebuild/specs/
docker cp /tmp/wh-rebuild/specs/superset-2000.sexp $C:/tmp/wh-rebuild/specs/
log "run tree HEAD=$(git -C .claude/worktrees/sweep-wh0908 rev-parse --short HEAD) (expect 077b48973)"
for arm in ctl splice; do
  out=/tmp/snap_top3000_2000_v8$arm
  case $arm in ctl) extra="-no-splice-action";; splice) extra="";; esac
  if docker exec $C test -f $out/manifest.sexp; then log "SKIP $arm (manifest exists)"; continue; fi
  log "BUILD $arm -> $out ($extra)"
  docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $EXE -scenario $SPEC -fixtures-root /tmp/wh-rebuild/specs -csv-data-dir $CSV -output-dir $out -detect-splices $extra -tail-exceptions $EXC > /tmp/wh-rebuild/build3-$arm.log 2>&1; echo exit=\$? >> /tmp/wh-rebuild/build3-$arm.log"
  n_snap=$(docker exec $C sh -c "ls $out/*.snap 2>/dev/null | wc -l"); n_man=$(docker exec $C sh -c "grep -c '(symbol ' $out/manifest.sexp 2>/dev/null"); n_at=$(docker exec $C sh -c "grep -c active_through $out/manifest.sexp 2>/dev/null")
  log "RESULT $arm snaps=$n_snap manifest=$n_man active_through=$n_at $(docker exec $C tail -1 /tmp/wh-rebuild/build3-$arm.log)"
  for f in splice_actions.csv terminal_runs.csv splices.csv; do docker cp $C:$out/$f "$RES/${f%.csv}_2000_v8$arm.csv" 2>/dev/null || log "no $f for $arm"; done
done
log "REBUILD3 DONE"
