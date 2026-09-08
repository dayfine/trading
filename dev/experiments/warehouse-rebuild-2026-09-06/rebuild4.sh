#!/bin/sh
# Rebuild the 2009 and 2019 vintage warehouses on the GAP-FILLED store (fetch_gap.sh, 2026-09-08): same #2691/#2695 build-time
# time: active_through from series end, terminal-stub truncation, stray-bar drop,
# terminal_runs.csv report). Sequential; container-exclusive (no agents alongside).
# Prereqs (host): PIN worktree at the merged main that contains #2691 AND #2692,
# built: docker exec ... 'cd $WT/trading && dune build analysis/scripts/build_snapshots/'
#        superset universes staged in /tmp/wh-rebuild/specs/ via make_superset.sh
set -u
C=trading-1-dev
WT=/workspaces/trading-1/.claude/worktrees/sweep-wh0908
ROOT=$WT/trading
EXE=$ROOT/_build/default/analysis/scripts/build_snapshots/build_snapshots.exe
CSV=/workspaces/trading-1/data
END=2026-09-06
LOG_HOST=/tmp/wh-rebuild/rebuild4.log
LOCK=/tmp/wh-rebuild/rebuild4.lock
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
mkdir -p /tmp/wh-rebuild; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C test -x $EXE || { log "ABORT: build_snapshots.exe not built in $WT"; exit 1; }
log "run tree HEAD=$(git -C .claude/worktrees/sweep-wh0908 rev-parse --short HEAD) (expect 077b48973 = main after #2709)"
for v in 2009 2019; do
  case $v in 2000) start=1999-01-01;; 2009) start=2008-01-01;; 2019) start=2018-01-01;; esac
  out=/tmp/snap_top3000_${v}_v9gap
  spec=/tmp/wh-rebuild/specs/superset-$v.sexp
  docker cp "/tmp/wh-rebuild/specs/superset-$v.sexp" $C:$spec 2>/dev/null || true
  if docker exec $C test -f $out/manifest.sexp; then log "SKIP $v (manifest exists)"; continue; fi
  log "BUILD $v -> $out"
  docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $EXE -universe-path $spec -csv-data-dir $CSV -output-dir $out -benchmark-symbol GSPC.INDX -start-date $start -end-date $END > /tmp/wh-rebuild/build4-$v.log 2>&1; echo exit=\$? >> /tmp/wh-rebuild/build4-$v.log"
  n_snap=$(docker exec $C sh -c "ls $out/*.snap 2>/dev/null | wc -l"); n_man=$(docker exec $C sh -c "grep -c '(symbol ' $out/manifest.sexp 2>/dev/null"); n_at=$(docker exec $C sh -c "grep -c active_through $out/manifest.sexp 2>/dev/null")
  log "RESULT $v snaps=$n_snap manifest=$n_man active_through=$n_at $(docker exec $C tail -1 /tmp/wh-rebuild/build4-$v.log)"
  docker cp $C:$out/terminal_runs.csv "dev/experiments/warehouse-rebuild-2026-09-06/results/terminal_runs_${v}_v9gap.csv" 2>/dev/null || log "no terminal_runs.csv for $v"
done
log "REBUILD4 DONE"
