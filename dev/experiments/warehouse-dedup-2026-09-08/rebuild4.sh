#!/bin/sh
# _v10dedup: rebuild the three vintage warehouses DEDUPED (#2730 ask 3) with the #2733 build
# (build_snapshots.exe now carries the rename-twin pass) and MEL quarantined (#2732).
# Sequential; container-exclusive (no agents, no cells alongside — each vintage is a full
# 3,000-symbol build). Prereqs on the HOST:
#   git worktree add --detach .claude/worktrees/sweep-dedup <main sha ≥ c70c39c23>
#   docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/.claude/worktrees/sweep-dedup/trading && eval $(opam env) && dune build analysis/scripts/build_snapshots/'
#   specs: /tmp/wh-rebuild/specs/superset-{2000,2009,2019}.sexp (make_superset.sh, 09-06) — this
#   script stages MEL-free copies as superset-<v>-nomel.sexp before each build.
# Twin basis = returns (Levels missed 9 of 10 known renames — twin_detector.mli).
set -u
C=trading-1-dev
WT=/workspaces/trading-1/.claude/worktrees/sweep-dedup
ROOT=$WT/trading
EXE=$ROOT/_build/default/analysis/scripts/build_snapshots/build_snapshots.exe
CSV=/workspaces/trading-1/data
END=2026-09-06
RES=/Users/difan/Projects/trading-1/dev/experiments/warehouse-dedup-2026-09-08/results
LOG_HOST=/tmp/wh-rebuild/rebuild4.log
LOCK=/tmp/wh-rebuild/rebuild4.lock
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
mkdir -p /tmp/wh-rebuild "$RES"; mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock"; exit 1; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
docker exec $C test -x $EXE || { log "ABORT: build_snapshots.exe not built in $WT"; exit 1; }
[ -z "$(git -C /Users/difan/Projects/trading-1/.claude/worktrees/sweep-dedup status --porcelain)" ] || { log "ABORT: run tree dirty"; exit 1; }
log "run tree HEAD=$(git -C /Users/difan/Projects/trading-1/.claude/worktrees/sweep-dedup rev-parse --short HEAD) (expect >= c70c39c23 = PR #2733 merge)"
for v in 2000 2009 2019; do
  case $v in 2000) start=1999-01-01;; 2009) start=2008-01-01;; 2019) start=2018-01-01;; esac
  out=/tmp/snap_top3000_${v}_v10dedup
  src=/tmp/wh-rebuild/specs/superset-$v.sexp; spec_host=/tmp/wh-rebuild/specs/superset-$v-nomel.sexp
  grep -v '(symbol MEL)' "$src" > "$spec_host"; n_rm=$(( $(grep -c '(symbol ' "$src") - $(grep -c '(symbol ' "$spec_host") ))
  [ "$n_rm" = "1" ] || { log "ABORT: expected to drop exactly 1 MEL line from $src, dropped $n_rm"; exit 1; }
  docker cp "$spec_host" $C:$spec_host
  if docker exec $C test -f $out/manifest.sexp; then log "SKIP $v (manifest exists)"; continue; fi
  log "BUILD $v -> $out (MEL quarantined, twin pass armed, basis=returns)"
  docker exec $C bash -c "cd $ROOT && eval \$(opam env) && $EXE -universe-path $spec_host -csv-data-dir $CSV -output-dir $out -benchmark-symbol GSPC.INDX -start-date $start -end-date $END -dedupe-rename-twins -twin-basis returns > /tmp/wh-rebuild/build4-$v.log 2>&1; echo exit=\$? >> /tmp/wh-rebuild/build4-$v.log"
  n_snap=$(docker exec $C sh -c "ls $out/*.snap 2>/dev/null | wc -l"); n_man=$(docker exec $C sh -c "grep -c '(symbol ' $out/manifest.sexp 2>/dev/null"); n_twin=$(docker exec $C sh -c "grep -c '<-' $out/rename_twin_report.txt 2>/dev/null")
  log "RESULT $v snaps=$n_snap manifest=$n_man twin_groups=$n_twin $(docker exec $C tail -1 /tmp/wh-rebuild/build4-$v.log)"
  docker cp $C:$out/rename_twin_report.txt "$RES/rename_twin_report_${v}_v10.txt" 2>/dev/null || log "no rename_twin_report.txt for $v"
  docker cp $C:$out/terminal_runs.csv "$RES/terminal_runs_${v}_v10.csv" 2>/dev/null || log "no terminal_runs.csv for $v"
done
log "REBUILD DONE"
