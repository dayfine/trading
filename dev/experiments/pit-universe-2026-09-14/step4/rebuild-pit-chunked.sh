#!/bin/sh
# Plan B for step 3b: the single-pass 10,504-name build sits at the 7.75 GB ceiling. Build the same superset in four
# first-letter chunks with -incremental into ONE output dir (manifest merges per #2724). Caveat recorded in the README:
# the rename-twin pass sees one chunk at a time, so cross-chunk renamed pairs are not deduped — V6 on the null run is the check.
set -u
C=trading-1-dev; WT=/workspaces/trading-1/.claude/worktrees/sweep-pit; ROOT=$WT/trading
EXE=$ROOT/_build/default/analysis/scripts/build_snapshots/build_snapshots.exe
CSV=/workspaces/trading-1/data; START=1998-01-01; END=2026-09-14
OUT=/tmp/snap_top3000_pit_v11pit; EXC_HOST=/Users/difan/Projects/trading-1/trading/test_data/warehouse_exceptions.sexp
RES=/Users/difan/Projects/trading-1/dev/experiments/pit-universe-2026-09-14/results
LOG_HOST=/tmp/pit-fetch/rebuild-pit-chunked.log; LOCK=/tmp/pit-fetch/rebuild-pit.lock
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
mkdir -p "$RES"; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock (single-pass build still holds it?)"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C test -x $EXE || { log "ABORT: exe missing"; exit 1; }
[ -z "$(git -C /Users/difan/Projects/trading-1/.claude/worktrees/sweep-pit status --porcelain)" ] || { log "ABORT: run tree dirty"; exit 1; }
free_gb=$(df -g / | awk 'NR==2{print $4}'); [ "$free_gb" -gt 30 ] || { log "ABORT: host free ${free_gb}G"; exit 1; }
log "run tree HEAD=$(git -C /Users/difan/Projects/trading-1/.claude/worktrees/sweep-pit rev-parse --short HEAD)"
docker cp "$EXC_HOST" $C:/tmp/warehouse_exceptions.sexp
for c in 1 2 3 4; do
  spec=/tmp/pit-fetch/specs/chunk-$c.sexp; docker cp "$spec" $C:/tmp/chunk-$c.sexp
  before=$(docker exec $C sh -c "ls $OUT/*.snap 2>/dev/null | wc -l")
  log "CHUNK $c BUILD ($(grep -c '(symbol ' "$spec") symbols) -> $OUT (snaps before=$before)"
  docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $EXE -universe-path /tmp/chunk-$c.sexp -csv-data-dir $CSV -output-dir $OUT -benchmark-symbol GSPC.INDX -start-date $START -end-date $END -incremental -dedupe-rename-twins -twin-basis returns -tail-exceptions /tmp/warehouse_exceptions.sexp > /tmp/build-pit-chunk$c.log 2>&1; echo exit=\$? >> /tmp/build-pit-chunk$c.log"
  after=$(docker exec $C sh -c "ls $OUT/*.snap 2>/dev/null | wc -l"); man=$(docker exec $C sh -c "grep -c '(symbol ' $OUT/manifest.sexp 2>/dev/null")
  log "CHUNK $c RESULT snaps=$after manifest=$man $(docker exec $C tail -1 /tmp/build-pit-chunk$c.log)"
  docker cp $C:$OUT/rename_twin_report.txt "$RES/rename_twin_report_pit_v11_chunk$c.txt" 2>/dev/null || log "no rename_twin_report for chunk $c"
  docker cp $C:/tmp/build-pit-chunk$c.log "$RES/build_pit_v11_chunk$c.log"
done
n_snap=$(docker exec $C sh -c "ls $OUT/*.snap 2>/dev/null | wc -l"); n_man=$(docker exec $C sh -c "grep -c '(symbol ' $OUT/manifest.sexp 2>/dev/null")
log "RESULT chunked snaps=$n_snap manifest=$n_man"
for f in terminal_runs.csv splice_actions.csv; do docker cp $C:$OUT/$f "$RES/${f%.*}_pit_v11.${f##*.}" 2>/dev/null || log "no $f"; done
log "REBUILD DONE"
