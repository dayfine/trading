#!/bin/sh
# Cross-chunk rename-twin scan: run build_snapshots' twin pass on each chunk-pair union (report is written before the
# per-symbol loop), stop the build once the report exists, keep the report. Each pair ~5.2k names.
set -u
C=trading-1-dev; ROOT=/workspaces/trading-1/.claude/worktrees/sweep-pit/trading; SP=/tmp/pit-fetch/specs; OUT=/tmp/twin-scan
LOG=/tmp/twin-scan/pair-scan.log
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }
for pair in "1 2" "1 3" "1 4" "2 3" "2 4" "3 4"; do
  set -- $pair; i=$1; j=$2; tag=pair-$i$j; d=$OUT/$tag; mkdir -p $d
  { echo "(Pinned ("; for c in $i $j; do grep -E '^\s*\(\(symbol ' $SP/chunk-$c.sexp; done | grep -v 'GSPC.INDX' | sort -u; echo '  ((symbol GSPC.INDX) (sector "Index"))'; echo "))"; } > $d/universe.sexp
  n=$(grep -c '(symbol ' $d/universe.sexp)
  docker exec $C mkdir -p $d; docker cp $d/universe.sexp $C:$d/universe.sexp
  log "SCAN $tag ($n symbols)"; start=$(date +%s)
  docker exec -d $C bash -c "cd $ROOT && eval \$(opam env) && ./_build/default/analysis/scripts/build_snapshots/build_snapshots.exe -universe-path $d/universe.sexp -csv-data-dir /workspaces/trading-1/data -output-dir $d -benchmark-symbol GSPC.INDX -start-date 1998-01-01 -end-date 2026-09-14 -dedupe-rename-twins -twin-basis returns > $d/build.log 2>&1; echo exit=\$? >> $d/build.log"
  sleep 5
  while :; do
    if docker exec $C test -f $d/rename_twin_report.txt; then docker exec $C pkill -x build_snapshots; sleep 2; docker cp $C:$d/rename_twin_report.txt $d/rename_twin_report.txt; log "RESULT $tag => $(sed -n 2p $d/rename_twin_report.txt) (wall $(( $(date +%s) - start ))s, peak seen $(docker stats --no-stream --format '{{.MemUsage}}' $C))"; break; fi
    if ! docker exec $C pgrep -x build_snapshots >/dev/null; then log "RESULT $tag => <no report> $(docker exec $C tail -1 $d/build.log) (wall $(( $(date +%s) - start ))s)"; break; fi
    sleep 20
  done
  docker exec $C sh -c "rm -f $d/*.snap $d/*.weekly $d/manifest.sexp" 2>/dev/null
done
log "PAIR SCAN DONE"
