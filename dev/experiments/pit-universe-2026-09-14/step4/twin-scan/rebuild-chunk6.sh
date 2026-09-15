#!/bin/sh
# Chunk 6: re-run build_snapshots -incremental with the twin pass over the cross-chunk twin PAIRS (survivor + dropped
# legs together) so the losing legs leave the manifest (Build_runner: dropped legs are excluded from the carry set).
# Usage: sh rebuild-chunk6.sh <pairs file: "SURVIVOR DROPPED" per line>
set -u
PAIRS=$1; C=trading-1-dev; WT=/workspaces/trading-1/.claude/worktrees/sweep-pit; ROOT=$WT/trading
EXE=$ROOT/_build/default/analysis/scripts/build_snapshots/build_snapshots.exe
CSV=/workspaces/trading-1/data; START=1998-01-01; END=2026-09-14; OUT=/tmp/snap_top3000_pit_v11pit
LOG_HOST=/tmp/twin-scan/rebuild-chunk6.log
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
spec=/tmp/twin-scan/chunk-6.sexp
{ echo "(Pinned ("; awk '{print $1; print $2}' "$PAIRS" | LC_ALL=C sort -u | sed 's/.*/  ((symbol &) (sector "Unknown"))/'; echo '  ((symbol GSPC.INDX) (sector "Index"))'; echo "))"; } > $spec
n=$(grep -c '(symbol ' $spec); docker cp $spec $C:/tmp/chunk-6.sexp
before=$(docker exec $C sh -c "grep -c '(symbol ' $OUT/manifest.sexp"); log "CHUNK 6 BUILD ($n symbols from $(wc -l < $PAIRS) pairs) manifest before=$before"
docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $EXE -universe-path /tmp/chunk-6.sexp -csv-data-dir $CSV -output-dir $OUT -benchmark-symbol GSPC.INDX -start-date $START -end-date $END -incremental -dedupe-rename-twins -twin-basis returns -tail-exceptions /tmp/warehouse_exceptions.sexp > /tmp/build-pit-chunk6.log 2>&1; echo exit=\$? >> /tmp/build-pit-chunk6.log"
after=$(docker exec $C sh -c "grep -c '(symbol ' $OUT/manifest.sexp"); log "CHUNK 6 RESULT manifest=$after (expected $((before - $(wc -l < $PAIRS)))) $(docker exec $C tail -1 /tmp/build-pit-chunk6.log)"
docker cp $C:$OUT/rename_twin_report.txt /tmp/twin-scan/rename_twin_report_chunk6.txt; docker cp $C:/tmp/build-pit-chunk6.log /tmp/twin-scan/build_pit_v11_chunk6.log
echo "--- dropped legs still in manifest (expect none):"; awk '{print $2}' "$PAIRS" | while read s; do docker exec $C grep -q "(symbol $s)" $OUT/manifest.sexp && echo "STILL INDEXED: $s"; done
log "CHUNK 6 DONE"
