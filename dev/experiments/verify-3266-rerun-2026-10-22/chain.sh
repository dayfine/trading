#!/bin/sh
# verify-3266-rerun-2026-10-22: ONE 26y cell, M-pre3339 s0 on the #3391-deduped pit-v12 lists, read against the committed
# N s0 for the [after-merge] item of #3266. Pre-registration: README.md beside this file.
# NOT run by its author: the dispatcher launches it when the container is free (no agents, no other backtest).
#
# Subcommands (host side; POSIX sh):
#   sh chain.sh launch            pin a worktree at origin/main, stage inputs outside any VCS tree, start `run` detached
#   sh chain.sh run               (started by launch) lock -> guards -> build -> warehouse rebuild -> preflight -> 1 cell
#                                 -> review pack (build + render) -> artifacts staged under $STAGE/results
#   sh chain.sh validate [SPEC..] short-window parse/override check of the spec (needs a built tree AND a warehouse in
#                                 the container: container work, not run by the author)
#   sh chain.sh collect DEST      copy the per-arm artifacts from the sweep output into DEST (the results/ dir)
#
# Derived from ../verify-chain-v-2026-10-19/chain.sh (itself from breadth-fix-rb1's launch/driver/chain scripts). Changes:
#   1. One cell: v3266-Mpre3339 s0, with the pre-#3339 NYSE A-D fixture swapped in exactly as chain V did (TD_PRE),
#      paired with the committed N s0 validator report. No M / M3138 / M3174 arms.
#   2. Warehouse rebuild phase (`wh`) kept: /tmp/snap_top3000_pit_v12wk, same START / END / tail-exceptions as chain V,
#      built at the pinned tree (post-#3283), 4 chunks, one job at a time. The container was recreated 2026-10-22 and
#      /tmp/snap_top3000_pit_v12pit (the v12 manifest chain V took its symbol set from) is gone, so the symbol set is
#      derived from the run tree: union of top-3000-1999 and top-3000-20*.sexp, minus MEL (no CSV; the v12 convention),
#      plus GSPC.INDX, plus the 14 symbols the runner always loads outside list membership (the 11 SPDR sector ETFs and
#      GDAXI.INDX, N225.INDX, ISF.LSE), parsed at launch from the run tree's
#      trading/trading/weinstein/strategy/lib/macro_inputs.ml (`spdr_sector_etfs`, `default_global_indices`), never hardcoded.
#      Launch aborts unless the set is exactly EXPECT_WH=9236, N's manifest count. The cache line's n_symbols_absent
#      must then be N's 1 (MEL): after the preflight it must not exceed 1 (a short window touches fewer symbols), and
#      after the cell it must equal 1, else the cell is VOID (logged, no RESULT line). The old-vs-new warehouse
#      comparison (fix detector) is dropped with the old warehouse; the rebuild guarantee is now structural: the NEED
#      commits (incl. #3283 3f51d4afd) must be ancestors of the run tree, and the build runs from that tree's binary.
#   3. #3391 guard at launch: the run tree must contain 3d437597c, and no list may hold a confirmed twin pair
#      (twin-drops.txt rows are re-checked, and CMD/CMN must not co-occur in any list).
#   4. Chain V defect D2 fixed: the cash_rejection count normalises whitespace first (the audit sexp is pretty-printed,
#      so `(cash_rejection` is often at a line end and a per-line grep for `(cash_rejection ` undercounted).
#      Chain V defect D3 fixed: a cell with no actual.sexp (guard-killed by `timeout`, OOM, crash) logs
#      `GUARD-KILLED/FAILED ... exit=N` and writes no RESULT line (the run-end `NO RESULT` line flags the read as void); the validator and validator_diff do not run, so
#      no V6 line or `exit=0` can be printed for a cell that produced nothing.
#
# Cell guard: CELL_TIMEOUT=60000 s, sized from the MEASURED arm, not the null. Chain V's M-pre3339 s0 took 11,709 s
# (verify-chain-v-2026-10-19/results/chain.log, 10-19), but same-spec cells ran up to 39,142 s (#3381: the slowest
# observed). 1.5 x 39,142 = 58,713 s, rounded up to 60,000 s (16.7 h). Warehouse rebuild: chain V's four chunks took
# ~20 min per ~2,300 names (v12 chunk1: 1,190 s), so ~1.5 h.
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
C=${CONTAINER:-trading-1-dev}
REPO=${REPO:-/Users/difan/Projects/trading-1}
EXP=dev/experiments/verify-3266-rerun-2026-10-22
STAGE=${STAGE:-/tmp/v3266-run}                         # host, outside every VCS tree (sweep-hygiene.md: inputs too)
H=$REPO/.sweep-output                                # host side of the container's /tmp/sweeps bind-mount
ART=/tmp/sweeps/verify-3266-rerun                       # container side; host $H/verify-3266-rerun
WTREL=${WTREL:-.claude/worktrees/sweep-v3266}          # the pinned run tree, repo-relative (container-visible)
WT=/workspaces/trading-1/$WTREL; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
WH=${WH:-/tmp/snap_top3000_pit_v12wk}                # v12 symbol set, rebuilt at the pinned tree (post-#3283)
EXPECT_WH=${EXPECT_WH:-9236}                            # warehouse set = union - MEL + GSPC.INDX + 14 runner extras = N's manifest count
EXPECT_ABSENT=1                                          # N's cache line: n_symbols_absent=1 (MEL, no CSV)
EXPECT_UNION=${EXPECT_UNION:-9222}                     # distinct symbols in the run tree lists today; asserted at launch
WH_START=1998-01-01; WH_END=2026-10-07               # the v12 build's START and END (build_pit_warehouse_v12.sh, launched 10-07 PT)
CELL_TIMEOUT=${CELL_TIMEOUT:-60000}                     # >= 1.5 x 39,142 s (slowest same-spec cell, #3381); chain V M-pre3339 s0: 11,709 s
MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}     # #2839/#2882: >= manifest size, so the LRU never cycles
N_RES=dev/experiments/breadth-fix-rb1-2026-10-11/results   # the committed record N (in the pinned tree)
# Commits the run tree must contain: #3283 (#3266 fix), #3181 (#3173 guard), #3222 (dividend/guard default-on),
# #3193 (#3174 flag), #3195 (#3138 audit record), #3339 (#3263 A-D fixture fix).
FIX3339=1f2432fa2
FIX3391=3d437597c                                    # #3391: CMN dropped from pit-v12 2005/2009/2013-15 + twin-drops.txt
NEED="3f51d4afd e9d6bb7a0 904746e8c 974e91885 852e61c2e $FIX3339 $FIX3391"
ADCSV="trading/test_data/breadth/nyse_advn.csv trading/test_data/breadth/nyse_decln.csv"
TD_PRE=/tmp/v3266-td-pre3339                           # container: run-tree test_data + the pre-#3339 A-D CSVs
N_LAUNCH='2026-10-11 00:00:00'                       # N's inputs were staged 10-11/12 (breadth-fix launch.sh)
# token = spec:salt:pairs:data, pairs = label=partner-validator[,label=...] (container paths; "-" = no pair),
# data = main (the run tree's test_data) or pre3339 ($TD_PRE).
cells() {
  echo "v3266-Mpre3339:0:N=$WT/$N_RES/N-rb1-26-s0-v12-validator.sexp.sexp:pre3339"
}
SPECS="v3266-Mpre3339"
LOG_HOST=$STAGE/chain.log
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
die() { log "ABORT: $*"; exit 1; }
dx() { docker exec "$C" "$@"; }
run() { docker exec "$C" bash -c "cd $ROOT && eval \$(opam env) && $1"; }
host_free_ok() { free_gb=$(df -g / | awk 'NR==2{print $4}'); log "host free ${free_gb}G"; [ "$free_gb" -ge 20 ]; }

# ---------------------------------------------------------------------------------------------------------------- launch
cmd_launch() {
  mkdir -p "$STAGE"; cd "$REPO" || exit 1
  git fetch -q origin main
  SHA=$(git rev-parse --short=9 "${RUN_SHA:-origin/main}") || die "cannot resolve ${RUN_SHA:-origin/main}"
  for c in $NEED; do git merge-base --is-ancestor "$c" "$SHA" || die "run tree $SHA lacks $c"; done
  # M-pre3339 (#3263 read): #3339 must change no shipped code, and nothing after it may touch the A-D CSVs, so that
  # swapping in the pre-#3339 CSVs undoes #3339 and nothing else.
  extra=$(git diff --name-only "$FIX3339^" "$FIX3339" | grep -v -e '^trading/test_data/breadth/' -e '/test/' || true)
  [ -z "$extra" ] || die "#3339 touches more than the A-D fixture and tests: $extra"
  later=$(git log --format=%h "$FIX3339..$SHA" -- $ADCSV)
  [ -z "$later" ] || die "commits after #3339 touch the A-D CSVs ($later): M-pre3339 would revert them too"
  rm -rf "$STAGE/pre3339"; mkdir -p "$STAGE/pre3339"
  for f in $ADCSV; do
    git show "$FIX3339^:$f" > "$STAGE/pre3339/$(basename "$f")" || die "pre-#3339 $f"
    git show "$SHA:$f" | cmp -s - "$STAGE/pre3339/$(basename "$f")" && die "pre-#3339 $f equals the run tree's"
  done
  echo "pre-#3339 A-D CSVs staged: $(cat "$STAGE"/pre3339/*.csv | md5 -q)" | tee -a "$STAGE/launch.log"
  if [ -d "$WTREL" ]; then
    [ "$(git -C "$WTREL" rev-parse --short=9 HEAD)" = "$SHA" ] || die "$WTREL is not at $SHA; remove it first"
  else git worktree add --detach "$WTREL" "$SHA" || die "worktree add"; fi
  # Inputs come from a commit, never a working copy: the pre-registration commit (default: the run SHA itself,
  # which holds this directory once the PR is merged).
  PREREG=${PREREG:-$SHA}
  rm -rf "$STAGE/specs"; mkdir -p "$STAGE/specs"
  for s in $SPECS; do git show "$PREREG:$EXP/specs/$s.sexp" > "$STAGE/specs/$s.sexp" || die "spec $s not at $PREREG"; done
  git show "$PREREG:$EXP/chain.sh" > "$STAGE/chain.sh" || die "chain.sh not at $PREREG"
  # Warehouse symbol set = the run tree's lists (the v12 pit warehouse, whose manifest chain V used, is gone): union of
  # the yearly lists, minus MEL (no CSV; the v12 convention), plus the GSPC.INDX benchmark.
  L=$WTREL/trading/test_data/backtest_scenarios/pit-v12/composition
  for f in "$L"/top-3000-1999.sexp "$L"/top-3000-20*.sexp; do grep -o '(symbol [^)]*)' "$f"; done \
    | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u > "$STAGE/lists-union.txt"
  [ "$(wc -l < "$STAGE/lists-union.txt" | tr -d ' ')" = "$EXPECT_UNION" ] \
    || die "lists hold $(wc -l < "$STAGE/lists-union.txt" | tr -d ' ') distinct symbols, expected $EXPECT_UNION (set EXPECT_UNION if main moved on purpose)"
  # The runner always adds 14 symbols outside list membership (runner.ml _runner_base_config / _all_runner_symbols):
  # parse them from the run tree's macro_inputs.ml, do not hardcode.
  MI=$WTREL/trading/trading/weinstein/strategy/lib/macro_inputs.ml
  { sed -n '/^let spdr_sector_etfs/,/^  \]$/p' "$MI"; sed -n '/^let default_global_indices/,/\]$/p' "$MI"; } \
    | grep -o '("[A-Z0-9.]*",' | sed 's/("//; s/",$//' | LC_ALL=C sort -u > "$STAGE/runner-extras.txt"
  [ "$(wc -l < "$STAGE/runner-extras.txt" | tr -d ' ')" = 14 ] \
    || die "parsed $(wc -l < "$STAGE/runner-extras.txt" | tr -d ' ') runner extras from $MI, expected 14 (11 SPDR + 3 indices)"
  { grep -v -x -F MEL "$STAGE/lists-union.txt"; echo GSPC.INDX; cat "$STAGE/runner-extras.txt"; } | LC_ALL=C sort -u > "$STAGE/wh-syms.txt"
  [ "$(wc -l < "$STAGE/wh-syms.txt" | tr -d ' ')" = "$EXPECT_WH" ] \
    || die "warehouse set holds $(wc -l < "$STAGE/wh-syms.txt" | tr -d ' ') symbols, expected $EXPECT_WH (N's manifest count)"
  echo "warehouse symbol set: $(wc -l < "$STAGE/wh-syms.txt" | tr -d ' ') ($STAGE/wh-syms.txt)" | tee -a "$STAGE/launch.log"
  # #3391 guard: the dedupe is in the run tree and no confirmed twin pair co-occurs in a list (the V6 specimen of chain V).
  TD=$WTREL/trading/test_data/backtest_scenarios/pit-v12/twin-drops.txt
  [ -f "$TD" ] || die "$TD missing: the run tree lacks #3391"
  while read -r tl td ts _; do
    case "$tl" in '' | '#'*) continue ;; esac
    tf=$L/$tl.sexp; [ -f "$tf" ] || die "twin-drops list $tl missing"
    ! grep -q -F "(symbol $td)" "$tf" || die "$tl holds $td again (twin of $ts)"
    grep -q -F "(symbol $ts)" "$tf" || die "$tl lacks survivor $ts"
  done < "$TD"
  for f in "$L"/top-3000-1999.sexp "$L"/top-3000-20*.sexp; do
    if grep -q -F '(symbol CMD)' "$f" && grep -q -F '(symbol CMN)' "$f"; then die "$(basename "$f") holds both CMD and CMN"; fi
  done
  echo "twin guard OK: $(grep -c -v -e '^#' -e '^$' "$TD") twin-drops rows hold, CMD/CMN co-occur in no list" | tee -a "$STAGE/launch.log"
  echo "lists md5 $(cat "$L"/top-3000-1999.sexp "$L"/top-3000-20*.sexp | md5 -q)" > "$STAGE/lists.md5"
  # Dividends + splits (EODHD, #3158) into the run tree's test_data: dividend_crediting, split_dividend_guard and
  # ex_dividend_stop_adjust read them from TRADING_DATA_DIR. The files changed since N staged its copy are listed
  # first: they feed M but not N, so they are a confound of the M - N delta (README #3266 item 4, #3173).
  (cd data && find . \( -name dividends.csv -o -name splits.csv \) -newermt "$N_LAUNCH" | LC_ALL=C sort) > "$STAGE/corp-actions-changed.txt"
  echo "dividends/splits files modified since $N_LAUNCH: $(wc -l < "$STAGE/corp-actions-changed.txt" | tr -d ' ') ($STAGE/corp-actions-changed.txt)" | tee -a "$STAGE/launch.log"
  rsync -a -m --include='*/' --include='dividends.csv' --include='splits.csv' --exclude='*' data/ "$WTREL/trading/test_data/"
  echo "staged $(find "$WTREL/trading/test_data" -name dividends.csv | wc -l | tr -d ' ') dividends.csv" | tee -a "$STAGE/launch.log"
  nohup env REPO="$REPO" STAGE="$STAGE" WTREL="$WTREL" EXPECT_HEAD="$(git -C "$WTREL" rev-parse --short HEAD)" PREREG="$PREREG" \
    sh "$STAGE/chain.sh" run > "$STAGE/run.out" 2>&1 &
  echo "launched run pid $! (tree $SHA, prereg $PREREG); log $LOG_HOST"
}

# ---------------------------------------------------------------------------------------------------------- warehouse
pinned_spec() { echo "(Pinned ("; sed 's/.*/  ((symbol &) (sector "Unknown"))/; s/((symbol GSPC.INDX) (sector "Unknown"))/((symbol GSPC.INDX) (sector "Index"))/' "$1"; echo "))"; }
manifest_rows() { # $1 warehouse -> "symbol payload_md5 csv_mtime", sorted
  dx sh -c "tr '\n' ' ' < $1/manifest.sexp | tr -s ' ' | grep -o '(symbol [^)]*) (path [^)]*) (byte_size [0-9]*) (payload_md5 [0-9a-f]*) (csv_mtime [0-9.e+-]*)'" \
    | sed 's/(symbol \([^)]*\)) (path [^)]*) (byte_size [0-9]*) (payload_md5 \([0-9a-f]*\)) (csv_mtime \([^)]*\))/\1 \2 \3/' | LC_ALL=C sort
}
phase_wh() {
  if dx test -f $WH/.v3266-done; then log "WH $WH already rebuilt (marker present); skipped"; return 0; fi
  dx test -e $WH && die "$WH exists without its .v3266-done marker (a half-built rebuild): remove it and relaunch"
  W=$STAGE/wh; mkdir -p "$W"
  cp "$STAGE/wh-syms.txt" "$W/syms.txt"
  # four equal chunks (a single pass of ~9k names OOMs at 7.75 GB); the benchmark goes in chunk 1, as in the v12 build
  grep -v -x GSPC.INDX "$W/syms.txt" > "$W/syms-nobench.txt"
  awk -v d="$W" '{ c = int((NR - 1) * 4 / n) + 1; print > (d "/chunk-" c ".txt") }' n="$(wc -l < "$W/syms-nobench.txt" | tr -d ' ')" "$W/syms-nobench.txt"
  grep -q -x GSPC.INDX "$W/syms.txt" && echo GSPC.INDX >> "$W/chunk-1.txt"
  docker cp "$REPO/$WTREL/trading/test_data/warehouse_exceptions.sexp" "$C:/tmp/v3266-warehouse_exceptions.sexp" || die "exceptions copy"
  for c in 1 2 3 4; do
    pinned_spec "$W/chunk-$c.txt" > "$W/chunk-$c.sexp"; docker cp "$W/chunk-$c.sexp" "$C:/tmp/v3266-chunk-$c.sexp" || die "chunk $c copy"
    log "WH BUILD chunk $c ($(wc -l < "$W/chunk-$c.txt" | tr -d ' ') symbols) -> $WH"; t0=$(date +%s)
    run "/usr/bin/time -f 'peak_rss_kb=%M' -o /tmp/v3266-chunk-$c.rss ./_build/default/analysis/scripts/build_snapshots/build_snapshots.exe -universe-path /tmp/v3266-chunk-$c.sexp -csv-data-dir /workspaces/trading-1/data -output-dir $WH -benchmark-symbol GSPC.INDX -start-date $WH_START -end-date $WH_END -incremental -tail-exceptions /tmp/v3266-warehouse_exceptions.sexp > /tmp/v3266-chunk-$c.build.log 2>&1; echo exit=\$? >> /tmp/v3266-chunk-$c.build.log"
    docker cp "$C:/tmp/v3266-chunk-$c.build.log" "$W/chunk-$c.build.log" 2>/dev/null
    tail -1 "$W/chunk-$c.build.log" | grep -qx 'exit=0' || die "chunk $c did not exit 0 (see $W/chunk-$c.build.log; exit=137 = OOM)"
    log "WH chunk $c done: $(dx tail -1 /tmp/v3266-chunk-$c.rss) (wall $(( $(date +%s) - t0 ))s)"
  done
  # The old warehouse is gone, so there is no old-vs-new comparison. Structural checks instead: the rebuilt manifest holds
  # exactly the intended symbol set, every entry has its .snap (no #2724 clobber), and the weekly side-tables exist.
  manifest_rows $WH > "$W/rows-new.txt"
  awk '{ print $1 }' "$W/rows-new.txt" > "$W/syms-new.txt"
  cmp -s "$W/syms.txt" "$W/syms-new.txt" || die "rebuilt manifest symbol set differs from the intended set (see $W/syms-new.txt vs $W/syms.txt)"
  dx sh -c "ls $WH/*.snap | sed 's#.*/##; s#\\.snap\$##' | LC_ALL=C sort -u" > "$W/snaps.txt"
  LC_ALL=C comm -23 "$W/syms-new.txt" "$W/snaps.txt" > "$W/missing-snaps.txt"
  [ ! -s "$W/missing-snaps.txt" ] || die "$(wc -l < "$W/missing-snaps.txt" | tr -d ' ') manifest entries have no .snap (see $W/missing-snaps.txt)"
  n_wk=$(dx sh -c "ls $WH/*.weekly 2>/dev/null | wc -l" | tr -d ' ')
  log "WH verify: entries=$(wc -l < "$W/syms-new.txt" | tr -d ' ') snaps=$(wc -l < "$W/snaps.txt" | tr -d ' ') weekly=$n_wk"
  [ "$n_wk" -gt 0 ] || die "no .weekly side-table in $WH: the build did not write the weekly columns"
  dx touch $WH/.v3266-done
}
# M-pre3339's data dir: every run-tree test_data entry symlinked, except the two A-D CSVs, which are the pre-#3339
# copies staged by launch. Rebuilt on every run (cheap); checked to differ from the run tree's CSVs and only there.
phase_td_pre() {
  dx sh -c "rm -rf $TD_PRE && mkdir -p $TD_PRE/breadth && for e in $ROOT/test_data/*; do b=\$(basename \$e); [ \$b = breadth ] || ln -s \$e $TD_PRE/\$b; done && for e in $ROOT/test_data/breadth/*; do b=\$(basename \$e); case \$b in nyse_advn.csv|nyse_decln.csv) ;; *) ln -s \$e $TD_PRE/breadth/\$b ;; esac; done" || die "pre-#3339 data dir"
  for f in nyse_advn.csv nyse_decln.csv; do
    docker cp "$STAGE/pre3339/$f" "$C:$TD_PRE/breadth/$f" || die "pre-#3339 $f copy"
    dx cmp -s "$TD_PRE/breadth/$f" "$ROOT/test_data/breadth/$f" && die "pre-#3339 $f equals the run tree's"
  done
  log "TD_PRE $TD_PRE: A-D md5 $(dx sh -c "cat $TD_PRE/breadth/nyse_advn.csv $TD_PRE/breadth/nyse_decln.csv | md5sum | cut -c1-32") (run tree $(dx sh -c "cat $ROOT/test_data/breadth/nyse_advn.csv $ROOT/test_data/breadth/nyse_decln.csv | md5sum | cut -c1-32")); $(dx sh -c "ls $TD_PRE | wc -l") entries"
}

# ----------------------------------------------------------------------------------------------------------- cells
td_of() { case $1 in pre3339) echo "$TD_PRE" ;; *) echo "$ROOT/test_data" ;; esac; }
run_cell() { # $1 spec name, $2 salt, $3 pairs (label=validator[,...] or -), $4 data (main|pre3339)
  name=$1; salt=$2; pairs=$3; tag="$name-s$salt"; d=$STAGE_C/$tag; td=$(td_of "$4")
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return 0; fi
  host_free_ok || die "host disk < 20G before $tag"
  dx sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$STAGE/specs/$name.sexp" "$C:$d/" || { log "RESULT $tag => <spec missing>"; return 0; }
  log "RUN $tag on $WH (TRADING_DATA_DIR=$td)"; start=$(date +%s)
  run "TRADING_DATA_DIR=$td TRADING_PATH_SEED_SALT=$salt SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $STAGE_C/$tag.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 --progress-every 26 > $STAGE_C/$tag.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.log"
  out=$(dx sh -c "grep 'Output root' $STAGE_C/$tag.log | tail -1 | sed 's/.*: //'")
  # D3 (chain V): a cell that wrote no actual.sexp (timeout 124, OOM 137, crash) must not reach the validator or
  # validator_diff, which would print V6 lines and `exit=0` for a run that produced nothing.
  ex=$(dx sh -c "tail -1 $STAGE_C/$tag.log")
  if [ -z "$out" ] || ! dx test -s "${out}/${name}/actual.sexp"; then
    dx sh -c "cp $STAGE_C/$tag.log $ART/${tag}.log; cp $STAGE_C/$tag.rss $ART/${tag}.rss 2>/dev/null" || true
    log "GUARD-KILLED/FAILED $tag: no actual.sexp; last log line '${ex}' (exit=124 = CELL_TIMEOUT ${CELL_TIMEOUT}s, exit=137 = OOM); validator and V6 gate NOT run (wall $(( $(date +%s) - start ))s)"
    return 0
  fi
  # Void the read unless the cache saw exactly N's absent set (MEL only): a missing runner extra or list member would
  # make this cell a different experiment from N.
  cache=$(dx sh -c "grep -h 'snapshot cache' $STAGE_C/$tag.log | tail -1")
  absent=$(echo "$cache" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
  if [ "$absent" != "$EXPECT_ABSENT" ]; then
    log "VOID $tag: n_symbols_absent=${absent:-<no cache line>}, expected $EXPECT_ABSENT (MEL); warehouse differs from N's, no RESULT written; $cache"
    return 0
  fi
  # one arm's actual.sexp only (sweep-hygiene.md metric-glob rule)
  m=$(dx sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  dx sh -c "for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $STAGE_C/$tag.log $ART/${tag}.log; cp $STAGE_C/$tag.rss $ART/${tag}.rss 2>/dev/null" || true
  rss=$(dx sh -c "tail -1 $STAGE_C/$tag.rss 2>/dev/null")
  guards=$(dx sh -c "grep -hE 'Panel_runner: (split_dividend_guard|ex_dividend_stop_adjust)' $STAGE_C/$tag.log | tr '\n' ' '")
  # D2 (chain V): the audit is pretty-printed, so normalise whitespace before counting (same pattern as audit_rows).
  rej=$(dx sh -c "tr -s '\n\t ' '   ' < $ART/${tag}-trade_audit.sexp 2>/dev/null | grep -o '(cash_rejection ((required' | wc -l" | tr -d ' ')
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -share-classes $ROOT/test_data/share_classes.sexp -out $ART/${tag}-validator.sexp > $STAGE_C/$tag.validator.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.validator.log"
  q=$(dx sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  v6=""
  if [ "$pairs" != "-" ]; then
    for p in $(echo "$pairs" | tr ',' ' '); do lab=${p%%=*}; pv=${p#*=}; vl=$tag.v6diff-$lab.log
      run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$pv -report arm=$ART/${tag}-validator.sexp.sexp > $STAGE_C/$vl 2>&1; echo exit=\$? >> $STAGE_C/$vl"
      dx cp $STAGE_C/$vl $ART/$vl
      v6="$v6 vs$lab($(basename "$pv")):$(dx sh -c "tail -1 $STAGE_C/$vl")"
    done
  fi
  log "GUARDS $tag => ${guards:-<none>} cash_rejections=$rej"
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6:- none} ${rss} ${cache} (wall $(( $(date +%s) - start ))s)"
}

# ---------------------------------------------------------------------------------------------------- review packs
phase_packs() {
  WTH=$REPO/$WTREL
  for arm in Mpre3339; do
    runs=""; for s in 0 1 2; do [ -s "$H/verify-3266-rerun/v3266-$arm-s$s-trades.csv" ] && runs="$runs s$s=$H/verify-3266-rerun/v3266-$arm-s$s-"; done
    [ -n "$runs" ] || { log "PACK $arm: no runs"; continue; }
    out=$WTH/.review/v3266-$arm
    log "PACK $arm:$runs"
    # shellcheck disable=SC2086
    sh "$WTH/dev/scripts/review_pack.sh" --out "$out" --title "verify-3266-rerun $arm (26y, rebuilt v12 warehouse)" \
      --snapshot-dir $WH --data-dir "$REPO/data" $runs > "$STAGE/pack-$arm.log" 2>&1 || { log "PACK $arm build failed (see $STAGE/pack-$arm.log)"; continue; }
    sh "$WTH/dev/scripts/review_pack_render.sh" --site "$out/site" > "$STAGE/render-$arm.log" 2>&1 || log "RENDER $arm failed (see $STAGE/render-$arm.log)"
    rm -rf "$H/review-v3266-$arm"; mkdir -p "$H/review-v3266-$arm"
    cp -R "$out/site" "$out/render" "$H/review-v3266-$arm/" 2>/dev/null
    log "PACK $arm -> $H/review-v3266-$arm (site/ + render/top.png, part-N.png)"
  done
}

# -------------------------------------------------------------------------------------------------------------- run
cmd_run() {
  mkdir -p "$STAGE"; LOCK=$STAGE/chain.lock; STAGE_C=/tmp/v3266-work
  mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LOCK held (another verify-3266-rerun instance)"; exit 1; }
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
  EXPECT_HEAD=${EXPECT_HEAD:?set by launch}
  head=$(git -C "$REPO/$WTREL" rev-parse --short HEAD)
  log "verify-3266-rerun run tree $WTREL HEAD=$head (expect $EXPECT_HEAD) prereg=${PREREG:-?} $(cat "$STAGE/lists.md5" 2>/dev/null)"
  log "cell guard CELL_TIMEOUT=${CELL_TIMEOUT}s (chain V M-pre3339 s0 11,709 s; slowest same-spec cell 39,142 s, #3381); SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES"
  [ "$head" = "$EXPECT_HEAD" ] || die "wrong HEAD"
  [ -z "$(git -C "$REPO/$WTREL" status --porcelain --untracked-files=no)" ] || die "run tree dirty"
  host_free_ok || die "host disk < 20G"
  if dx pgrep -f 'build_snapshots|scenario_runner|panel_runner|bayesian_runner' >/dev/null; then die "another build/backtest is running in $C"; fi
  dx mkdir -p $STAGE_C $ART
  log "BUILD"
  run "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe analysis/scripts/build_snapshots/build_snapshots.exe trading/backtest/bin/trade_audit_report_bin.exe analysis/scripts/stage_chart/bin/stage_chart.exe > $STAGE_C/build.log 2>&1" || die "build failed ($STAGE_C/build.log in the container)"
  log "BUILD_DONE"
  phase_wh
  phase_td_pre
  # PREFLIGHT: every spec over the last ~3 months on the rebuilt warehouse; a spec/override error costs minutes.
  for name in $SPECS; do pd=$STAGE_C/preflight-$name
    [ "$name" = v3266-Mpre3339 ] && td=$(td_of pre3339) || td=$(td_of main)
    dx sh -c "mkdir -p $pd && rm -rf $pd/*"
    sed 's/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date 2026-04-01) (end_date 2026-06-26)))/' "$STAGE/specs/$name.sexp" > "$STAGE/preflight-$name.sexp"
    docker cp "$STAGE/preflight-$name.sexp" "$C:$pd/$name.sexp" || die "preflight copy $name"
    log "PREFLIGHT $name (TRADING_DATA_DIR=$td)"; t0=$(date +%s)
    run "TRADING_DATA_DIR=$td SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
    pout=$(dx sh -c "grep 'Output root' $pd.log | tail -1 | sed 's/.*: //'")
    dx test -s "${pout}/${name}/actual.sexp" || die "preflight $name wrote no actual.sexp (see $pd.log)"
    pabs=$(dx sh -c "grep -h 'snapshot cache' $pd.log | tail -1" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
    # a ~3-month window touches fewer symbols than the full cell, so only an excess over N's 1 fails here; the cell
    # itself is held to exactly 1.
    [ -n "$pabs" ] && [ "$pabs" -le "$EXPECT_ABSENT" ] || die "preflight $name: n_symbols_absent=${pabs:-<no cache line>}, expected <= $EXPECT_ABSENT: the warehouse lacks list members or runner extras (see $pd.log)"
    log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s)"
  done
  for tok in $(cells); do
    name=${tok%%:*}; rest=${tok#*:}; salt=${rest%%:*}; rest=${rest#*:}; pairs=${rest%:*}; data=${rest##*:}
    run_cell "$name" "$salt" "$pairs" "$data"
  done
  log "CELLS DONE"
  grep -q "RESULT v3266-Mpre3339-s0 " "$LOG_HOST" || log "NO RESULT: the cell wrote no actual.sexp (GUARD-KILLED/FAILED above) or was VOIDed on n_symbols_absent; the #3266 read is void, relaunch after tracing"
  phase_packs
  cmd_collect "$STAGE/results"
  log "VERIFY-3266-RERUN DONE. Next: perf_long_cells.sh update $LOG_HOST; collect into the results PR; read per README."
}

# --------------------------------------------------------------------------------------------------------- validate
# Parse + override check only, never a backtest. scenario_runner parses the spec and applies config_overrides
# (Overlay_validator.apply_overrides, in Runner._load_deps) BEFORE it prints "Running backtest" (backtest/lib/runner.ml).
# Each spec runs under `timeout 300` on an existing warehouse, in an already built tree, and is VALID iff its log
# reaches that line; the timeout then kills it. A negative control (v3266-Mpre3339 plus a nonexistent override) must fail
# before that line, which shows the check can fail.
_validate_one() { # $1 label, $2 spec file (host)
  pd=$STAGE_C/$1; dx sh -c "mkdir -p $pd && rm -rf $pd/*"; docker cp "$2" "$C:$pd/$1.sexp"
  run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 300 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIX --snapshot-dir $VWH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
  dx grep -q 'Running backtest' $pd.log
}
cmd_validate() {
  VWH=${VALIDATE_WH:-$WH}; STAGE_C=/tmp/v3266-validate; dx mkdir -p $STAGE_C
  dx test -d "$VWH" || { echo "validate needs a warehouse in $C at $VWH (set VALIDATE_WH) and a built tree at WTREL: container work"; return 2; }
  here=$(cd "$(dirname "$0")" && pwd); rc=0; tmp=${TMPDIR:-/tmp}/v3266-validate.$$
  for name in ${*:-$SPECS control}; do
    if [ "$name" = control ]; then
      awk '{ print } $0 == "   ((dividend_crediting true))" { print "   ((v3266_no_such_flag true))" }' "$here/specs/v3266-Mpre3339.sexp" \
        | sed 's/(name "v3266-Mpre3339")/(name "control")/' > "$tmp"
      if _validate_one control "$tmp"; then echo "CONTROL FAILED: a bogus override reached 'Running backtest'"; rc=1
      else echo "CONTROL OK (bogus override rejected): $(dx sh -c "grep -m2 -iE 'error|exception|unknown|fail' $STAGE_C/control.log | tr '\n' ' ' | cut -c1-300")"; fi
    else
      f=$(grep -oE '\((entry_fill_size_to_available|ex_dividend_stop_adjust) true\)' "$here/specs/$name.sexp" || echo "(none)")
      cp "$here/specs/$name.sexp" "$tmp"
      if _validate_one "$name" "$tmp"; then echo "VALID $name: parsed, overrides applied, reached 'Running backtest'; arm flag $f"
      else echo "INVALID $name:"; dx tail -5 "$STAGE_C/$name.log"; rc=1; fi
    fi
  done
  rm -f "$tmp"; return $rc
}

# ---------------------------------------------------------------------------------------------------------- collect
# One CSV row per trade_audit.sexp record: position_id,symbol,entry_date,cancel_reason,ticket_age_weeks_at_cancel,
# required,available (the last two only on a ticket_lifecycle cash_rejection, #3195). entry_date is the audit's join
# key, the placement date; the cancel step's date is not stored (it is placement + ticket_age_weeks_at_cancel weeks).
audit_rows() { # $1 trade_audit.sexp
  echo "position_id,symbol,entry_date,cancel_reason,ticket_age_weeks_at_cancel,required,available"
  tr -s '\n\t ' '   ' < "$1" | awk '
    function fld(k,   s) { if (match($0, "\\(" k " [^()]*\\)")) return substr($0, RSTART + length(k) + 2, RLENGTH - length(k) - 3); return "" }
    BEGIN { RS = "\\(\\(entry \\(\\(symbol "; OFS = "," }
    NR > 1 {
      req = ""; av = ""
      if (match($0, /\(cash_rejection \(\(required [-0-9.e+]+\) \(available [-0-9.e+]+\)\)\)/)) {
        split(substr($0, RSTART, RLENGTH), a, /[() ]+/); req = a[4]; av = a[6] }
      print fld("position_id"), substr($0, 1, index($0, ")") - 1), fld("entry_date"), fld("cancel_reason"),
        fld("ticket_age_weeks_at_cancel"), req, av }'
}
cmd_collect() { # $1 destination results dir (host)
  dest=${1:?usage: chain.sh collect DEST}; mkdir -p "$dest"; src=$H/verify-3266-rerun
  echo "cell,entry_year,cash_rejections" > "$dest/cash_rejections_by_year.csv"
  for f in "$src"/v3266-*-s[0-9]-*; do
    [ -f "$f" ] || continue
    case "$f" in *-trade_audit.sexp)
      b=$(basename "$f" -trade_audit.sexp)
      audit_rows "$f" > "$dest/$b-audit_entries.csv"
      awk -F, 'NR == 1 { print "position_id,symbol,entry_date,ticket_age_weeks_at_cancel,required,available,funded_fraction"; next }
        $6 != "" { printf "%s,%s,%s,%s,%s,%s,%.4f\n", $1, $2, $3, $5, $6, $7, ($6 > 0 ? $7 / $6 : 0) }' \
        "$dest/$b-audit_entries.csv" > "$dest/$b-cash_rejections.csv"
      echo $(( $(wc -l < "$dest/$b-cash_rejections.csv") - 1 )) > "$dest/$b-cash_rejections.txt"
      awk -F, -v c="$b" 'NR > 1 { n[substr($3, 1, 4)]++ } END { for (y in n) print c "," y "," n[y] }' \
        "$dest/$b-cash_rejections.csv" | LC_ALL=C sort >> "$dest/cash_rejections_by_year.csv"
      continue ;; esac
    cp "$f" "$dest/"
  done
  for f in "$src"/v3266-*-s[0-9].log "$src"/v3266-*-s[0-9].rss "$src"/v3266-*-s[0-9].v6diff-*.log; do [ -f "$f" ] && cp "$f" "$dest/"; done
  [ -f "$LOG_HOST" ] && cp "$LOG_HOST" "$dest/chain.log"
  [ -f "$STAGE/corp-actions-changed.txt" ] && cp "$STAGE/corp-actions-changed.txt" "$dest/"
  [ -d "$STAGE/wh" ] && { mkdir -p "$dest/wh"; cp "$STAGE"/wh/chunk-*.build.log "$STAGE/wh/syms.txt" "$dest/wh/" 2>/dev/null; }
  echo "collected into $dest: $(ls "$dest" | wc -l | tr -d ' ') files (trade_audit.sexp reduced to audit_entries.csv + cash_rejections.csv)"
}

case "$CMD" in
  launch) cmd_launch ;;
  run) cmd_run ;;
  validate) cmd_validate "$@" ;;
  collect) cmd_collect "${1:-}" ;;
  *) echo "usage: sh $0 {launch|run|validate|collect DEST}" >&2; exit 2 ;;
esac
