#!/bin/sh
# twin-dedupe-26y-2026-10-29: the record N (rk-k0..k2 of ../record-kseed-2026-10-27/) on the pit-v12 lists after the
# full rename-twin dedupe (#3388, "dd") vs the same seeds on main's lists before it ("cur", CMN/CMD only), 26y, path
# salt 0, paired per seed, one cell at a time. Pre-registration and read rule: README.md beside this file. The
# dispatcher launches it after the dedupe PR has merged, when the container is free (no agents, no other backtest).
#
# Subcommands (host side; POSIX sh):
#   sh chain.sh launch            pin a run tree at RUN_SHA (default origin/main; must hold the deduped lists), stage the
#                                 cur lists from BASE and the specs from PREREG outside any VCS tree, start `run` detached
#   sh chain.sh run               (started by launch) lock -> guards -> stage cur lists into the run tree (untracked
#                                 pit-v12-current/) -> build -> warehouse check -> preflight cur-k0, dd-k0 ->
#                                 cur-k0, dd-k0, cur-k1, dd-k1, cur-k2, dd-k2 -> review pack -> collect -> summary
#   sh chain.sh collect DEST      copy the per-cell artifacts from the sweep output into DEST (the results/ dir)
#   sh chain.sh summary [DIR]     paired per-seed read, the dd median against the record band, cur vs rk-k<k>. Host only.
#
# Derived from ../record-kseed-2026-10-27/chain.sh. Changes:
#   1. Two arms per seed: td-cur-k<k> (lists of BASE, staged untracked as pit-v12-current/composition/) and td-dd-k<k>
#      (the run tree's own pit-v12/composition/, deduped). Specs otherwise equal rk-k<k> below their header.
#   2. Seeds 0-2 only (K = 3 pairs), cur before dd within each seed.
#   3. V6 gate on dd: a dd cell whose validator lacks `V6 INVARIANT PASS` logs GATE-FAIL and its pair leaves the read.
#      validator_diff -check V6 dd vs cur is run and logged; cur is expected to hold the twins dd removed, so a mismatch
#      there is the defect being measured, not an exclusion.
#   4. Own stage, work and output dirs (/tmp/td-run, /tmp/td-work, /tmp/sweeps/twin-dedupe), run tree
#      .claude/worktrees/sweep-td. One review pack holding all six cells, built inside the run tree.
#
# Cell guard: CELL_TIMEOUT=60000 s = 1.5 x the slowest same-shape 26y cell on the ledger (vcv-M-s2, 39,142 s,
# dev/status/perf-long-cells.csv). record-kseed's five cells took 12,336-23,162 s, so six cells are about 25-40 h.
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
C=${CONTAINER:-trading-1-dev}
REPO=${REPO:-/Users/difan/Projects/trading-1}
EXP=dev/experiments/twin-dedupe-26y-2026-10-29
RK=dev/experiments/record-kseed-2026-10-27
STAGE=${STAGE:-/tmp/td-run}                          # host, outside every VCS tree (sweep-hygiene.md: inputs too)
H=$REPO/.sweep-output                                # host side of the container's /tmp/sweeps bind-mount
ART=/tmp/sweeps/twin-dedupe                          # container side; host $H/twin-dedupe
HART=$H/twin-dedupe
WTREL=${WTREL:-.claude/worktrees/sweep-td}           # the pinned run tree, repo-relative (container-visible)
WT=/workspaces/trading-1/$WTREL; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
BASE=${BASE:-7615dde7d}                              # main before the dedupe: its lists are the cur arm (md5 below)
WH=${WH:-/tmp/snap_top3000_pit_v12wk}                # v12 warehouse built by the #3266 rerun; reused, not rebuilt
WH_MARK=.v3266-done                                  # its completion marker
EXPECT_WH=${EXPECT_WH:-9236}                         # manifest symbol count
EXPECT_ABSENT=${EXPECT_ABSENT:-1}                    # cache line n_symbols_absent (MEL, no CSV; in both arms' lists)
EXPECT_UNION_CUR=${EXPECT_UNION_CUR:-9222}           # distinct symbols in the 27 scheduled cur lists
EXPECT_UNION_DD=${EXPECT_UNION_DD:-9185}             # distinct symbols in the 27 scheduled dd lists
MD5_CUR=51fba79e26a6273845c37c13f6aae070             # 27 scheduled lists concatenated, before #3388 (record-kseed's)
MD5_DD=369b988f703e2aa71d5248e5843d6ecb              # the same after #3388's full dedupe
CELL_TIMEOUT=${CELL_TIMEOUT:-60000}                  # 1.5 x 39,142 s (slowest 26y cell, vcv-M-s2)
MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}     # #2839/#2882: >= manifest size, so the LRU never cycles
KS="0 1 2"
PREFLIGHT_START=2026-01-02; PREFLIGHT_END=2026-06-26 # last half-year of the window
BAND_MED=2.7819; BAND_SD=0.2254                      # record K-seed band, median and SD of ln(1+R) (record-kseed, #3467)
# Commits the run tree must contain: record-kseed's list (#3283, #3181, #3222, #3193, #3195, #3339, #3391, #3425).
NEED="3f51d4afd e9d6bb7a0 904746e8c 974e91885 852e61c2e 1f2432fa2 3d437597c cae75ca2a"
RK_DIR=${RK_DIR:-$REPO/$RK/results}                  # rk-k<k>-s0-actual.sexp, for the cur reproduction check
LOG_HOST=$STAGE/chain.log
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
die() { log "ABORT: $*"; exit 1; }
dx() { docker exec "$C" "$@"; }
run() { docker exec "$C" bash -c "cd $ROOT && eval \$(opam env) && $1"; }
host_free_ok() { free_gb=$(df -g / | awk 'NR==2{print $4}'); log "host free ${free_gb}G"; [ "$free_gb" -ge 20 ]; }
union_of() { # $1 lists dir, $2 sched-lists file (pit-v12/composition/... paths) -> sorted distinct symbols
  while read -r p; do grep -o '(symbol [^)]*)' "$1/$(basename "$p")"; done < "$2" | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u
}
md5_of() { while read -r p; do cat "$1/$(basename "$p")"; done < "$2" | md5 -q; }

# ---------------------------------------------------------------------------------------------------------------- launch
cmd_launch() {
  mkdir -p "$STAGE"; cd "$REPO" || exit 1
  git fetch -q origin main
  SHA=$(git rev-parse --short=9 "${RUN_SHA:-origin/main}") || die "cannot resolve ${RUN_SHA:-origin/main}"
  for c in $NEED; do git merge-base --is-ancestor "$c" "$SHA" || die "run tree $SHA lacks $c"; done
  git show "$SHA:trading/analysis/weinstein/screener/lib/screener.ml" | grep -q 'candidate_ranking : candidate_ranking; \[@sexp.default Seeded\]' \
    || die "run tree $SHA: candidate_ranking does not default to Seeded"
  if [ -d "$WTREL" ]; then
    [ "$(git -C "$WTREL" rev-parse --short=9 HEAD)" = "$SHA" ] || die "$WTREL is not at $SHA; remove it first"
  else git worktree add --detach "$WTREL" "$SHA" || die "worktree add"; fi
  PREREG=${PREREG:?set PREREG to the pre-registration commit}
  rm -rf "${STAGE:?}/specs" "${STAGE:?}/lists-cur"; mkdir -p "$STAGE/specs" "$STAGE/lists-cur"
  for k in $KS; do for a in dd cur; do
    git show "$PREREG:$EXP/specs/td-$a-k$k.sexp" > "$STAGE/specs/td-$a-k$k.sexp" || die "spec td-$a-k$k not at $PREREG"
  done; done
  git show "$PREREG:$EXP/chain.sh" > "$STAGE/chain.sh" || die "chain.sh not at $PREREG"
  # dd == rk-k<k> below the header; cur == dd except the list directory.
  for k in $KS; do
    git show "$SHA:$RK/specs/rk-k$k.sexp" | sed -n '5,$p' > "$STAGE/rk-body.txt" || die "rk-k$k not at $SHA"
    sed -n '5,$p' "$STAGE/specs/td-dd-k$k.sexp" > "$STAGE/dd-body.txt"
    cmp -s "$STAGE/rk-body.txt" "$STAGE/dd-body.txt" || die "td-dd-k$k body differs from rk-k$k"
    sed -n '5,$p' "$STAGE/specs/td-cur-k$k.sexp" | sed 's|"pit-v12-current/composition/|"pit-v12/composition/|g' > "$STAGE/cur-body.txt"
    cmp -s "$STAGE/dd-body.txt" "$STAGE/cur-body.txt" || die "td-cur-k$k differs from td-dd-k$k beyond the list directory"
    [ "$(grep -c '"pit-v12/' "$STAGE/specs/td-cur-k$k.sexp")" = 0 ] || die "td-cur-k$k still names pit-v12/ lists"
  done
  grep -o '"pit-v12/composition/top-3000-[0-9]*\.sexp"' "$STAGE/specs/td-dd-k0.sexp" | tr -d '"' | LC_ALL=C sort -u > "$STAGE/sched-lists.txt"
  [ "$(wc -l < "$STAGE/sched-lists.txt" | tr -d ' ')" = 27 ] || die "expected 27 scheduled lists"
  # cur lists from BASE (every list, so the staged dir mirrors pit-v12/composition); dd lists are the run tree's own.
  for f in $(git ls-tree --name-only "$BASE" trading/test_data/backtest_scenarios/pit-v12/composition/); do
    git show "$BASE:$f" > "$STAGE/lists-cur/$(basename "$f")" || die "cannot stage $f from $BASE"
  done
  LD=$WTREL/trading/test_data/backtest_scenarios/pit-v12/composition
  mc=$(md5_of "$STAGE/lists-cur" "$STAGE/sched-lists.txt"); md=$(md5_of "$LD" "$STAGE/sched-lists.txt")
  [ "$mc" = "$MD5_CUR" ] || die "cur lists (BASE $BASE) md5 $mc, expected $MD5_CUR"
  [ "$md" = "$MD5_DD" ] || die "run tree $SHA lists md5 $md, expected $MD5_DD (the #3388 dedupe not on the run tree?)"
  echo "lists md5 cur $mc dd $md" > "$STAGE/lists-md5.txt"
  union_of "$STAGE/lists-cur" "$STAGE/sched-lists.txt" > "$STAGE/union-cur.txt"
  union_of "$LD" "$STAGE/sched-lists.txt" > "$STAGE/union-dd.txt"
  [ "$(wc -l < "$STAGE/union-cur.txt" | tr -d ' ')" = "$EXPECT_UNION_CUR" ] || die "cur union != $EXPECT_UNION_CUR"
  [ "$(wc -l < "$STAGE/union-dd.txt" | tr -d ' ')" = "$EXPECT_UNION_DD" ] || die "dd union != $EXPECT_UNION_DD"
  [ -z "$(LC_ALL=C comm -23 "$STAGE/union-dd.txt" "$STAGE/union-cur.txt")" ] || die "dd union is not a subset of cur's"
  echo "unions cur $EXPECT_UNION_CUR dd $EXPECT_UNION_DD (dd subset of cur)" >> "$STAGE/lists-md5.txt"
  # Warehouse symbol set (record-kseed's derivation over the cur union, which holds dd's): minus MEL (no CSV), plus
  # GSPC.INDX, plus the 14 runner extras parsed from the run tree's macro_inputs.ml.
  MI=$WTREL/trading/trading/weinstein/strategy/lib/macro_inputs.ml
  { sed -n '/^let spdr_sector_etfs/,/^  \]$/p' "$MI"; sed -n '/^let default_global_indices/,/\]$/p' "$MI"; } \
    | grep -o '("[A-Z0-9.]*",' | sed 's/("//; s/",$//' | LC_ALL=C sort -u > "$STAGE/runner-extras.txt"
  [ "$(wc -l < "$STAGE/runner-extras.txt" | tr -d ' ')" = 14 ] || die "expected 14 runner extras in $MI"
  { grep -v -x -F MEL "$STAGE/union-cur.txt"; echo GSPC.INDX; cat "$STAGE/runner-extras.txt"; } | LC_ALL=C sort -u > "$STAGE/wh-syms.txt"
  [ "$(wc -l < "$STAGE/wh-syms.txt" | tr -d ' ')" = "$EXPECT_WH" ] || die "derived warehouse set != $EXPECT_WH"
  tee -a "$STAGE/launch.log" < "$STAGE/lists-md5.txt"
  rsync -a -m --include='*/' --include='dividends.csv' --include='splits.csv' --exclude='*' data/ "$WTREL/trading/test_data/"
  echo "staged $(find "$WTREL/trading/test_data" -name dividends.csv | wc -l | tr -d ' ') dividends.csv" | tee -a "$STAGE/launch.log"
  nohup env REPO="$REPO" STAGE="$STAGE" WTREL="$WTREL" EXPECT_HEAD="$(git -C "$WTREL" rev-parse --short HEAD)" PREREG="$PREREG" \
    sh "$STAGE/chain.sh" run > "$STAGE/run.out" 2>&1 &
  echo "launched run pid $! (tree $SHA, base $BASE, prereg $PREREG); log $LOG_HOST"
}

# ---------------------------------------------------------------------------------------------------- warehouse check
phase_wh_check() {
  dx test -f "$WH/$WH_MARK" || die "$WH lacks its $WH_MARK marker (the #3266 rerun's build)"
  dx sh -c "tr '\n' ' ' < $WH/manifest.sexp | grep -o '(symbol [^)]*)'" | sed 's/(symbol //; s/)$//' | LC_ALL=C sort > "$STAGE/wh-manifest.txt"
  n=$(wc -l < "$STAGE/wh-manifest.txt" | tr -d ' ')
  [ "$n" = "$EXPECT_WH" ] || die "$WH manifest holds $n symbols, expected $EXPECT_WH"
  cmp -s "$STAGE/wh-manifest.txt" "$STAGE/wh-syms.txt" || die "$WH manifest set differs from the run tree's derived set"
  log "WH $WH reused: $n symbols, equal to the derived set (cur union; dd's is a subset)"
}

# ----------------------------------------------------------------------------------------------------------- cells
run_cell() { # $1 spec name, $2 V6 partner validator report (container path) or -
  name=$1; pv=$2; tag="$name-s0"; d=$STAGE_C/$tag; td=$ROOT/test_data
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return 0; fi
  host_free_ok || die "host disk < 20G before $tag"
  if dx pgrep -f 'scenario_runner' >/dev/null; then die "a scenario_runner is still running in $C before $tag"; fi
  dx sh -c "mkdir -p ${d:?} && rm -rf ${d:?}/*"; docker cp "$STAGE/specs/$name.sexp" "$C:$d/" || { log "GUARD-KILLED/FAILED $tag: spec copy failed"; return 0; }
  log "RUN $tag on $WH"; start=$(date +%s)
  run "TRADING_DATA_DIR=$td TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $STAGE_C/$tag.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 --progress-every 26 > $STAGE_C/$tag.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.log"
  out=$(dx sh -c "grep 'Output root' $STAGE_C/$tag.log | tail -1 | sed 's/.*: //'")
  ex=$(dx sh -c "tail -1 $STAGE_C/$tag.log")
  if [ -z "$out" ] || ! dx test -s "${out}/${name}/actual.sexp"; then
    dx sh -c "cp $STAGE_C/$tag.log $ART/${tag}.log; cp $STAGE_C/$tag.rss $ART/${tag}.rss 2>/dev/null" || true
    log "GUARD-KILLED/FAILED $tag: no actual.sexp; last log line '${ex}' (exit=124 = CELL_TIMEOUT ${CELL_TIMEOUT}s, exit=137 = OOM); validator and V6 gate NOT run (wall $(( $(date +%s) - start ))s)"
    return 0
  fi
  cache=$(dx sh -c "grep -h 'snapshot cache' $STAGE_C/$tag.log | tail -1")
  absent=$(echo "$cache" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
  if [ "$absent" != "$EXPECT_ABSENT" ]; then
    log "VOID $tag: n_symbols_absent=${absent:-<no cache line>}, expected $EXPECT_ABSENT (MEL); no RESULT written; $cache"
    return 0
  fi
  # one cell's actual.sexp only (sweep-hygiene.md metric-glob rule)
  m=$(dx sh -c "grep -hoE 'total_return_pct [0-9.eE+-]+|total_trades [0-9]+|sharpe_ratio [0-9.eE+-]+|max_drawdown_pct [0-9.eE+-]+|calmar_ratio [0-9.eE+-]+' ${out}/${name}/actual.sexp 2>/dev/null | tr '\n' ' '")
  dx sh -c "for f in actual.sexp trades.csv splits.csv params.sexp summary.sexp trade_audit.sexp open_positions.csv force_liquidations.sexp equity_curve.csv macro_trend.sexp; do cp ${out}/${name}/\$f $ART/${tag}-\$f 2>/dev/null; done; cp $STAGE_C/$tag.log $ART/${tag}.log; cp $STAGE_C/$tag.rss $ART/${tag}.rss 2>/dev/null" || true
  rss=$(dx sh -c "tail -1 $STAGE_C/$tag.rss 2>/dev/null")
  guards=$(dx sh -c "grep -hE 'Panel_runner: (split_dividend_guard|ex_dividend_stop_adjust)' $STAGE_C/$tag.log | tr '\n' ' '")
  rej=$(dx sh -c "tr -s '\n\t ' '   ' < $ART/${tag}-trade_audit.sexp 2>/dev/null | grep -o '(cash_rejection ((required' | wc -l" | tr -d ' ')
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -share-classes $ROOT/test_data/share_classes.sexp -out $ART/${tag}-validator.sexp > $STAGE_C/$tag.validator.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.validator.log"
  q=$(dx sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  v6=""
  if [ "$pv" != "-" ]; then # a dd cell: the V6 gate, then the descriptive diff against its cur partner
    dx grep -q 'V6 INVARIANT PASS' "$ART/${tag}-validator.sexp.md" \
      || log "GATE-FAIL $tag: validator lacks 'V6 INVARIANT PASS' (${q:-<no validator>}); this seed's pair leaves the read"
    vl=$tag.v6diff-cur.log
    if ! dx test -s "$pv"; then v6=" vscur:partner-missing"
    else
      run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report cur=$pv -report dd=$ART/${tag}-validator.sexp.sexp > $STAGE_C/$vl 2>&1; echo exit=\$? >> $STAGE_C/$vl"
      dx cp $STAGE_C/$vl $ART/$vl
      v6=" vscur($(basename "$pv")):$(dx sh -c "tail -1 $STAGE_C/$vl")"
    fi
  fi
  log "GUARDS $tag => ${guards:-<none>} cash_rejections=$rej"
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6:- none} ${rss} ${cache} (wall $(( $(date +%s) - start ))s)"
}

# ---------------------------------------------------------------------------------------------------- review pack
phase_pack() { # built with the run tree's own scripts
  WTH=$REPO/$WTREL; out=$H/review-twin-dedupe-build; args=""
  for k in $KS; do for a in cur dd; do
    [ -s "$HART/td-$a-k$k-s0-trades.csv" ] && args="$args $a$k=$HART/td-$a-k$k-s0-"
  done; done
  [ -n "$args" ] || { log "PACK: no cells"; return 0; }
  log "PACK:$args"
  # shellcheck disable=SC2086
  sh "$WTH/dev/scripts/review_pack.sh" --out "$out" --title "record N, full twin dedupe vs current lists, seeds 0-2 (2000-2026, pit-v12)" \
    --snapshot-dir "$WH" --data-dir "$REPO/data" $args > "$STAGE/pack.log" 2>&1 || { log "PACK build failed (see $STAGE/pack.log)"; return 0; }
  sh "$WTH/dev/scripts/review_pack_render.sh" --site "$out/site" > "$STAGE/render.log" 2>&1 || log "RENDER failed (see $STAGE/render.log)"
  log "PACK -> $out (site/ + render/top.png, part-N.png)"
}

# -------------------------------------------------------------------------------------------------------------- run
preflight_one() { # $1 spec name: last half-year of the window on the reused warehouse; a spec error costs minutes
  name=$1; pd=$STAGE_C/preflight-$name
  dx sh -c "mkdir -p ${pd:?} && rm -rf ${pd:?}/*"
  sed "s/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date $PREFLIGHT_START) (end_date $PREFLIGHT_END)))/" "$STAGE/specs/$name.sexp" > "$STAGE/preflight-$name.sexp"
  grep -q "(start_date $PREFLIGHT_START)" "$STAGE/preflight-$name.sexp" || die "preflight $name: window not replaced"
  docker cp "$STAGE/preflight-$name.sexp" "$C:$pd/$name.sexp" || die "preflight copy $name"
  log "PREFLIGHT $name"; t0=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
  pout=$(dx sh -c "grep 'Output root' $pd.log | tail -1 | sed 's/.*: //'")
  dx test -s "${pout}/${name}/actual.sexp" || die "preflight $name wrote no actual.sexp (see $pd.log)"
  pabs=$(dx sh -c "grep -h 'snapshot cache' $pd.log | tail -1" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
  [ -n "$pabs" ] && [ "$pabs" -le "$EXPECT_ABSENT" ] || die "preflight $name: n_symbols_absent=${pabs:-<no cache line>}, expected <= $EXPECT_ABSENT"
  log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s)"
}
stage_cur_lists() { # the cur arm's lists, untracked in the run tree (the cur specs name pit-v12-current/composition/)
  CL=$REPO/$WTREL/trading/test_data/backtest_scenarios/pit-v12-current/composition
  rm -rf "${CL:?}"; mkdir -p "$CL"; cp "$STAGE"/lists-cur/*.sexp "$CL/"
  [ "$(md5_of "$CL" "$STAGE/sched-lists.txt")" = "$MD5_CUR" ] || die "staged cur lists md5 moved"
  log "staged cur lists -> $CL ($(ls "$CL" | wc -l | tr -d ' ') files, untracked)"
}
cmd_run() {
  mkdir -p "$STAGE"; LOCK=$STAGE/chain.lock; STAGE_C=/tmp/td-work
  mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LOCK held (another twin-dedupe instance)"; exit 1; }
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
  EXPECT_HEAD=${EXPECT_HEAD:?set by launch}
  head=$(git -C "$REPO/$WTREL" rev-parse --short HEAD)
  log "twin-dedupe run tree $WTREL HEAD=$head (expect $EXPECT_HEAD) prereg=${PREREG:-?} $(tr '\n' ' ' < "$STAGE/lists-md5.txt" 2>/dev/null)"
  log "cell guard CELL_TIMEOUT=${CELL_TIMEOUT}s (1.5 x 39,142 s, vcv-M-s2); SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES"
  [ "$head" = "$EXPECT_HEAD" ] || die "wrong HEAD"
  [ -z "$(git -C "$REPO/$WTREL" status --porcelain --untracked-files=no)" ] || die "run tree dirty"
  host_free_ok || die "host disk < 20G"
  if dx pgrep -f 'build_snapshots|scenario_runner|panel_runner|bayesian_runner' >/dev/null; then die "another build/backtest is running in $C"; fi
  stage_cur_lists
  dx mkdir -p $STAGE_C $ART
  log "BUILD"
  run "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe trading/backtest/bin/trade_audit_report_bin.exe analysis/scripts/stage_chart/bin/stage_chart.exe > $STAGE_C/build.log 2>&1" || die "build failed ($STAGE_C/build.log in the container)"
  log "BUILD_DONE (one build for every cell)"
  phase_wh_check
  preflight_one td-cur-k0; preflight_one td-dd-k0
  for k in $KS; do
    run_cell "td-cur-k$k" -
    run_cell "td-dd-k$k" "$ART/td-cur-k$k-s0-validator.sexp.sexp"
  done
  log "CELLS DONE: $(grep -c ' RESULT td-' "$LOG_HOST") RESULT, $(grep -c ' GATE-FAIL td-' "$LOG_HOST") GATE-FAIL, $(grep -c -e ' GUARD-KILLED/FAILED td-' -e ' VOID td-' "$LOG_HOST") failed/void (of 6)"
  phase_pack
  cmd_collect "$STAGE/results"
  cmd_summary "$STAGE/results" > "$STAGE/results/summary.txt" 2>&1 || log "SUMMARY failed (see $STAGE/results/summary.txt)"
  log "TWIN-DEDUPE DONE. Next: perf_long_cells.sh update $LOG_HOST; look at the pack; results-analyst read per README; results PR."
}

# ---------------------------------------------------------------------------------------------------------- collect
cmd_collect() { # $1 destination results dir (host); trade_audit.sexp is too large to commit, its outcome counts are kept
  dest=${1:?usage: chain.sh collect DEST}; mkdir -p "$dest"
  for f in "$HART"/td-*-k[0-9]-s0-*; do
    [ -f "$f" ] || continue
    case "$f" in *-trade_audit.sexp)
      b=$(basename "$f" -trade_audit.sexp)
      tr -s '\n\t ' '   ' < "$f" | grep -oE '\(outcome (Placed|\(Skipped [A-Za-z_]+)' \
        | sed 's/^(outcome (Skipped //; s/^(outcome //' | LC_ALL=C sort | uniq -c | awk '{ print $2 "," $1 }' > "$dest/$b-audit_outcomes.csv"
      continue ;; esac
    cp "$f" "$dest/"
  done
  for f in "$HART"/td-*-s0.log "$HART"/td-*-s0.rss "$HART"/td-*-s0.v6diff-*.log; do [ -f "$f" ] && cp "$f" "$dest/"; done
  [ -f "$LOG_HOST" ] && cp "$LOG_HOST" "$dest/chain.log"
  [ -f "$STAGE/lists-md5.txt" ] && cp "$STAGE/lists-md5.txt" "$dest/"
  echo "collected into $dest: $(ls "$dest" | wc -l | tr -d ' ') files"
}

# ---------------------------------------------------------------------------------------------------------- summary
# README §"What is read", mechanically. A pair counts when both cells have a RESULT line and an actual.sexp and the dd
# cell has no GATE-FAIL line. d = ln(1 + R_dd) - ln(1 + R_cur), R = total_return_pct / 100; SD is the sample SD (n-1).
_metrics() { # $1 actual.sexp -> "R sharpe maxdd calmar trades"
  nt=$(grep -o 'total_return_pct' "$1" | wc -l | tr -d ' ')
  [ "$nt" = 1 ] || { echo "TRIPWIRE: $1 holds $nt total_return_pct tokens" >&2; return 1; }
  tr '\n' ' ' < "$1" | awk '{
    n = split("total_return_pct sharpe_ratio max_drawdown_pct calmar_ratio total_trades", k, " ")
    for (i = 1; i <= n; i++) { v = "nan"; if (match($0, "\\(" k[i] " [-0-9.eE+]+\\)")) { v = substr($0, RSTART + length(k[i]) + 2, RLENGTH - length(k[i]) - 3) } printf "%s ", v }
  }'
}
_status() { # $1 tag, $2 dir, $3 chain log
  if ! grep -q " RESULT $1 " "$3"; then echo no_result
  elif grep -q " GATE-FAIL $1:" "$3"; then echo gate_fail
  elif [ ! -s "$2/$1-actual.sexp" ]; then echo no_artifact
  else echo ok; fi
}
_paired() { # $1 rows file ("k arm status R sharpe maxdd calmar trades")
  awk -v bm="$BAND_MED" -v bs="$BAND_SD" '
    function med(a, n,   i, j, t, b) { for (i = 1; i <= n; i++) b[i] = a[i]
      for (i = 2; i <= n; i++) { t = b[i]; for (j = i - 1; j >= 1 && b[j] > t; j--) b[j + 1] = b[j]; b[j + 1] = t }
      return (n % 2) ? b[(n + 1) / 2] : (b[n / 2] + b[n / 2 + 1]) / 2 }
    function cls(z) { z = (z < 0) ? -z : z; return (z <= 1) ? "<= 1 band SD" : (z <= 2) ? "1-2 band SD" : "> 2 band SD" }
    { st[$1, $2] = $3; r[$1, $2] = $4; ks[$1] = 1 }
    END {
      print "seed  ln(1+R_cur)  ln(1+R_dd)  d = dd - cur"
      n = 0; s = 0; pos = 0; neg = 0
      for (k = 0; k <= 9; k++) { if (!(k in ks)) continue
        if (st[k, "cur"] != "ok" || st[k, "dd"] != "ok" || r[k, "cur"] == "nan" || r[k, "dd"] == "nan") { printf "k%d    pair out (cur %s, dd %s)\n", k, st[k, "cur"], st[k, "dd"]; continue }
        lc = log(1 + r[k, "cur"] / 100); ld = log(1 + r[k, "dd"] / 100); d = ld - lc
        n++; x[n] = d; s += d; dd[n] = ld; if (d > 0) pos++; else if (d < 0) neg++
        printf "k%d    %.4f       %.4f      %+.4f\n", k, lc, ld, d }
      print ""
      if (n == 0) { print "paired read: no pair included"; exit }
      mu = s / n; sd = "n/a"; if (n >= 2) { ss = 0; for (i = 1; i <= n; i++) ss += (x[i] - mu) ^ 2; sd = sprintf("%.4f", sqrt(ss / (n - 1))) }
      printf "paired: n = %d, mean d %+.4f, SD %s, sign %d+ / %d- / %d zero\n", n, mu, sd, pos, neg, n - pos - neg
      printf "movement class (|mean d| / band SD = %.2f): %s\n", (mu < 0 ? -mu : mu) / bs, cls(mu / bs)
      m = med(dd, n); z = (m - bm) / bs
      printf "dd median ln(1+R) %.4f vs record band median %.4f: %+.2f band SD (%s)\n", m, bm, z, cls(z)
    }' "$1"
}
_checks() { # $1 dir: cur vs rk-k<k>, and the same-build check on params.sexp
  echo "cur reproduces rk-k<k> (actual.sexp byte-for-byte; a difference means the run tree moved since record-kseed):"
  for k in $KS; do f=$1/td-cur-k$k-s0-actual.sexp; g=$RK_DIR/rk-k$k-s0-actual.sexp
    if [ ! -s "$f" ] || [ ! -s "$g" ]; then echo "  k$k: n/a (missing)"
    elif cmp -s "$f" "$g"; then echo "  k$k: yes"
    else echo "  k$k: NO (rk R $(_metrics "$g" | awk '{ print $1 }') vs cur R $(_metrics "$f" | awk '{ print $1 }'))"; fi
  done
  echo
  echo "same build: dd vs cur params.sexp per seed, (universe_size N) masked (expected equal; sizes cur 9222, dd 9185):"
  for k in $KS; do a=$1/td-cur-k$k-s0-params.sexp; b=$1/td-dd-k$k-s0-params.sexp
    if [ ! -s "$a" ] || [ ! -s "$b" ]; then echo "  k$k: n/a (missing)"; continue; fi
    ua=$(grep -o '(universe_size [0-9]*)' "$a"); ub=$(grep -o '(universe_size [0-9]*)' "$b")
    if [ "$(sed 's/(universe_size [0-9]*)//' "$a" | md5 -q)" = "$(sed 's/(universe_size [0-9]*)//' "$b" | md5 -q)" ]; then
      echo "  k$k: equal (cur $ua, dd $ub)"
    else echo "  k$k: DIFFER in $(diff "$a" "$b" | grep -c '^<') line(s) (cur $ua, dd $ub)"; fi
  done
}
cmd_summary() {
  dir=${1:-$HART}; lg=$dir/chain.log; [ -f "$lg" ] || lg=$LOG_HOST
  [ -f "$lg" ] || { echo "summary: no chain log in $dir or at $LOG_HOST"; return 2; }
  rows=${TMPDIR:-/tmp}/td-summary.$$; : > "$rows"
  echo "twin-dedupe summary: cells from $dir; record band median $BAND_MED SD $BAND_SD (record-kseed); rk-k<k> from $RK_DIR"
  echo
  echo "cell        status       total_return_pct  sharpe   max_dd_pct  calmar   trades   v6diff_vs_cur"
  for k in $KS; do
    for a in cur dd; do
      tag=td-$a-k$k-s0; st=$(_status "$tag" "$dir" "$lg")
      vals="nan nan nan nan nan"; [ -s "$dir/$tag-actual.sexp" ] && { vals=$(_metrics "$dir/$tag-actual.sexp") || { rm -f "$rows"; return 1; }; }
      vd=-; [ "$a" = dd ] && [ -f "$dir/$tag.v6diff-cur.log" ] && vd=$(tail -1 "$dir/$tag.v6diff-cur.log")
      echo "$k $a $st $vals" >> "$rows"
      echo "$tag $st $vals $vd" | awk '{ printf "%-11s %-12s %16s  %-8s %-11s %-8s %-8s %s\n", $1, $2, $3, $4, $5, $6, $7, $8 }'
    done
  done
  echo
  _paired "$rows"; rm -f "$rows"
  echo
  _checks "$dir"
}

case "$CMD" in
  launch) cmd_launch ;;
  run) cmd_run ;;
  collect) cmd_collect "${1:-}" ;;
  summary) cmd_summary "${1:-}" ;;
  *) echo "usage: sh $0 {launch|run|collect DEST|summary [DIR]}" >&2; exit 2 ;;
esac
