#!/bin/sh
# record-kseed-2026-10-27: the record N (rb1-26) on main's Seeded default, K = 5 tie-order seeds (tiebreak_seed 0-4),
# 26y, path salt 0, one cell at a time. Pre-registration and read rule: README.md beside this file. The dispatcher
# launches it after the pre-registration commit is pushed, when the container is free (no agents, no other backtest).
#
# Subcommands (host side; POSIX sh):
#   sh chain.sh launch            pin a run tree at RUN_SHA (default origin/main; must contain #3425), stage inputs from
#                                 the PREREG commit outside any VCS tree, start `run` detached
#   sh chain.sh run               (started by launch) lock -> guards -> build -> warehouse check -> preflight k0, k1 ->
#                                 rk-k0 .. rk-k4 -> review pack -> collect -> summary
#   sh chain.sh collect DEST      copy the per-cell artifacts from the sweep output into DEST (the results/ dir)
#   sh chain.sh summary [DIR]     per-seed metrics, the K-seed band, and the old record N for reference. Host only.
#
# Derived from ../floor-nearest-2026-10-25/chain.sh (itself from ../path-stability-2026-10-23/chain.sh). Changes:
#   1. No perturbations and no null: five specs differing only by tiebreak_seed, all committed under specs/.
#   2. Own pinned run tree (.claude/worktrees/sweep-rk) at main, which carries the Seeded default (#3425).
#   3. V6 gate: each rk-k<k> vs rk-k0.
#   4. Own stage, work and output dirs (/tmp/rk-run, /tmp/rk-work, /tmp/sweeps/record-kseed).
#   5. One review pack holding all five seeds.
#
# Cell guard: CELL_TIMEOUT=60000 s = 1.5 x the slowest same-shape 26y cell on the ledger (vcv-M-s2, 39,142 s,
# dev/status/perf-long-cells.csv, 2026-10-21). The latest same-spec 26y cell took 27,309 s (v3266-Mpre3339-s0,
# 10-23), so the chain should take about 35-45 h.
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
C=${CONTAINER:-trading-1-dev}
REPO=${REPO:-/Users/difan/Projects/trading-1}
EXP=dev/experiments/record-kseed-2026-10-27
STAGE=${STAGE:-/tmp/rk-run}                          # host, outside every VCS tree (sweep-hygiene.md: inputs too)
H=$REPO/.sweep-output                                # host side of the container's /tmp/sweeps bind-mount
ART=/tmp/sweeps/record-kseed                         # container side; host $H/record-kseed
HART=$H/record-kseed
WTREL=${WTREL:-.claude/worktrees/sweep-rk}           # the pinned run tree, repo-relative (container-visible)
WT=/workspaces/trading-1/$WTREL; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
WH=${WH:-/tmp/snap_top3000_pit_v12wk}                # v12 warehouse built by the #3266 rerun; reused, not rebuilt
WH_MARK=.v3266-done                                  # its completion marker
EXPECT_WH=${EXPECT_WH:-9236}                         # manifest symbol count
EXPECT_ABSENT=${EXPECT_ABSENT:-1}                    # cache line n_symbols_absent (MEL, no CSV)
EXPECT_UNION=${EXPECT_UNION:-9222}                   # distinct symbols in the run tree's lists; asserted at launch
CELL_TIMEOUT=${CELL_TIMEOUT:-60000}                  # 1.5 x 39,142 s (slowest 26y cell, vcv-M-s2)
MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}     # #2839/#2882: >= manifest size, so the LRU never cycles
KS="0 1 2 3 4"
PREFLIGHT="0 1"                                      # k0 (the default) and k1 (a non-zero seed parses)
PREFLIGHT_START=2026-01-02; PREFLIGHT_END=2026-06-26 # last half-year of the window
# Commits the run tree must contain: the template's list (#3283, #3181, #3222, #3193, #3195, #3339, #3391) plus #3425
# (Seeded default).
FIX3425=cae75ca2a
NEED="3f51d4afd e9d6bb7a0 904746e8c 974e91885 852e61c2e 1f2432fa2 3d437597c $FIX3425"
OLD_DIR=${OLD_DIR:-$REPO/dev/experiments/breadth-fix-rb1-2026-10-11/results}   # the old record N (Alphabetical)
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
  git show "$SHA:trading/analysis/weinstein/screener/lib/screener.ml" | grep -q 'candidate_ranking : candidate_ranking; \[@sexp.default Seeded\]' \
    || die "run tree $SHA: candidate_ranking does not default to Seeded"
  if [ -d "$WTREL" ]; then
    [ "$(git -C "$WTREL" rev-parse --short=9 HEAD)" = "$SHA" ] || die "$WTREL is not at $SHA; remove it first"
  else git worktree add --detach "$WTREL" "$SHA" || die "worktree add"; fi
  PREREG=${PREREG:?set PREREG to the pre-registration commit}
  rm -rf "$STAGE/specs"; mkdir -p "$STAGE/specs"
  for k in $KS; do git show "$PREREG:$EXP/specs/rk-k$k.sexp" > "$STAGE/specs/rk-k$k.sexp" || die "spec rk-k$k not at $PREREG"; done
  git show "$PREREG:$EXP/chain.sh" > "$STAGE/chain.sh" || die "chain.sh not at $PREREG"
  # The five specs equal the record body up to name, description and the seed line.
  git show "$SHA:dev/experiments/breadth-fix-rb1-2026-10-11/specs/rb1-26.sexp" | sed -n '5,$p' > "$STAGE/rb1-body.txt"
  for k in $KS; do
    sed -n '5,$p' "$STAGE/specs/rk-k$k.sexp" | grep -v -x -F "   ((screening_config ((tiebreak_seed $k))))" > "$STAGE/rk-body.txt"
    cmp -s "$STAGE/rb1-body.txt" "$STAGE/rk-body.txt" || die "rk-k$k body differs from rb1-26 beyond the seed line"
    [ "$(grep -c "((tiebreak_seed $k))" "$STAGE/specs/rk-k$k.sexp")" = 1 ] || die "rk-k$k: seed line missing"
  done
  # Warehouse symbol set (template derivation): union of the yearly lists, minus MEL (no CSV), plus GSPC.INDX, plus the
  # 14 runner extras parsed from the run tree's macro_inputs.ml.
  L=$WTREL/trading/test_data/backtest_scenarios/pit-v12/composition
  for f in "$L"/top-3000-1999.sexp "$L"/top-3000-20*.sexp; do grep -o '(symbol [^)]*)' "$f"; done \
    | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u > "$STAGE/lists-union.txt"
  [ "$(wc -l < "$STAGE/lists-union.txt" | tr -d ' ')" = "$EXPECT_UNION" ] \
    || die "lists hold $(wc -l < "$STAGE/lists-union.txt" | tr -d ' ') distinct symbols, expected $EXPECT_UNION"
  MI=$WTREL/trading/trading/weinstein/strategy/lib/macro_inputs.ml
  { sed -n '/^let spdr_sector_etfs/,/^  \]$/p' "$MI"; sed -n '/^let default_global_indices/,/\]$/p' "$MI"; } \
    | grep -o '("[A-Z0-9.]*",' | sed 's/("//; s/",$//' | LC_ALL=C sort -u > "$STAGE/runner-extras.txt"
  [ "$(wc -l < "$STAGE/runner-extras.txt" | tr -d ' ')" = 14 ] || die "expected 14 runner extras in $MI"
  { grep -v -x -F MEL "$STAGE/lists-union.txt"; echo GSPC.INDX; cat "$STAGE/runner-extras.txt"; } | LC_ALL=C sort -u > "$STAGE/wh-syms.txt"
  [ "$(wc -l < "$STAGE/wh-syms.txt" | tr -d ' ')" = "$EXPECT_WH" ] || die "derived warehouse set != $EXPECT_WH"
  # md5 of the 27 scheduled lists, recorded for provenance (not compared: these are #3391's lists, not the old record's).
  grep -o '"pit-v12/composition/top-3000-[0-9]*\.sexp"' "$STAGE/specs/rk-k0.sexp" | tr -d '"' | LC_ALL=C sort -u > "$STAGE/sched-lists.txt"
  [ "$(wc -l < "$STAGE/sched-lists.txt" | tr -d ' ')" = 27 ] || die "expected 27 scheduled lists"
  echo "lists md5 $(while read -r p; do cat "$WTREL/trading/test_data/backtest_scenarios/$p"; done < "$STAGE/sched-lists.txt" | md5 -q)" > "$STAGE/lists-md5.txt"
  cat "$STAGE/lists-md5.txt" | tee -a "$STAGE/launch.log"
  # Dividends + splits (EODHD, #3158) into the run tree's test_data, as the template.
  rsync -a -m --include='*/' --include='dividends.csv' --include='splits.csv' --exclude='*' data/ "$WTREL/trading/test_data/"
  echo "staged $(find "$WTREL/trading/test_data" -name dividends.csv | wc -l | tr -d ' ') dividends.csv" | tee -a "$STAGE/launch.log"
  nohup env REPO="$REPO" STAGE="$STAGE" WTREL="$WTREL" EXPECT_HEAD="$(git -C "$WTREL" rev-parse --short HEAD)" PREREG="$PREREG" \
    sh "$STAGE/chain.sh" run > "$STAGE/run.out" 2>&1 &
  echo "launched run pid $! (tree $SHA, prereg $PREREG); log $LOG_HOST"
}

# ---------------------------------------------------------------------------------------------------- warehouse check
phase_wh_check() {
  dx test -f "$WH/$WH_MARK" || die "$WH lacks its $WH_MARK marker (the #3266 rerun's build)"
  dx sh -c "tr '\n' ' ' < $WH/manifest.sexp | grep -o '(symbol [^)]*)'" | sed 's/(symbol //; s/)$//' | LC_ALL=C sort > "$STAGE/wh-manifest.txt"
  n=$(wc -l < "$STAGE/wh-manifest.txt" | tr -d ' ')
  [ "$n" = "$EXPECT_WH" ] || die "$WH manifest holds $n symbols, expected $EXPECT_WH"
  cmp -s "$STAGE/wh-manifest.txt" "$STAGE/wh-syms.txt" || die "$WH manifest set differs from the run tree's derived set"
  log "WH $WH reused: $n symbols, equal to the run tree's derived set"
}

# ----------------------------------------------------------------------------------------------------------- cells
run_cell() { # $1 spec name, $2 V6 partner validator report (container path) or -
  name=$1; pv=$2; tag="$name-s0"; d=$STAGE_C/$tag; td=$ROOT/test_data
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return 0; fi
  host_free_ok || die "host disk < 20G before $tag"
  if dx pgrep -f 'scenario_runner' >/dev/null; then die "a scenario_runner is still running in $C before $tag"; fi
  dx sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$STAGE/specs/$name.sexp" "$C:$d/" || { log "GUARD-KILLED/FAILED $tag: spec copy failed"; return 0; }
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
  v6=""; excl=""
  if [ "$pv" != "-" ]; then
    vl=$tag.v6diff-k0.log
    if ! dx test -s "$pv"; then
      v6=" vsk0:partner-missing"; excl=" vsk0: partner validator $(basename "$pv") missing (its cell failed or was VOID);"
    else
      run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$pv -report arm=$ART/${tag}-validator.sexp.sexp > $STAGE_C/$vl 2>&1; echo exit=\$? >> $STAGE_C/$vl"
      dx cp $STAGE_C/$vl $ART/$vl
      vx=$(dx sh -c "tail -1 $STAGE_C/$vl")
      v6=" vsk0($(basename "$pv")):$vx"
      if [ "$vx" != "exit=0" ]; then
        spec=$(dx sh -c "grep -v '^exit=' $STAGE_C/$vl | head -8 | tr '\n' '|' | cut -c1-600")
        excl=" vsk0 $vx (1 = V6 mismatch, 2 = unreadable/uncomparable) specimen: $spec;"
      fi
    fi
  fi
  log "GUARDS $tag => ${guards:-<none>} cash_rejections=$rej"
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6:- none} ${rss} ${cache} (wall $(( $(date +%s) - start ))s)"
  [ -z "$excl" ] || log "EXCLUDED $tag:$excl"
}

# ---------------------------------------------------------------------------------------------------- review pack
phase_pack() {
  WTH=$REPO/$WTREL; out=$H/review-record-kseed-build; args=""
  for k in $KS; do [ -s "$HART/rk-k$k-s0-trades.csv" ] && args="$args k$k=$HART/rk-k$k-s0-"; done
  [ -n "$args" ] || { log "PACK: no cells"; return 0; }
  log "PACK:$args"
  # shellcheck disable=SC2086
  sh "$WTH/dev/scripts/review_pack.sh" --out "$out" --title "record N, Seeded K=5 seeds (2000-2026, pit-v12)" \
    --snapshot-dir "$WH" --data-dir "$REPO/data" $args > "$STAGE/pack.log" 2>&1 || { log "PACK build failed (see $STAGE/pack.log)"; return 0; }
  sh "$WTH/dev/scripts/review_pack_render.sh" --site "$out/site" > "$STAGE/render.log" 2>&1 || log "RENDER failed (see $STAGE/render.log)"
  log "PACK -> $out (site/ + render/top.png, part-N.png)"
}

# -------------------------------------------------------------------------------------------------------------- run
preflight_one() { # $1 spec name: last half-year of the window on the reused warehouse; a spec error costs minutes
  name=$1; pd=$STAGE_C/preflight-$name
  dx sh -c "mkdir -p $pd && rm -rf $pd/*"
  sed "s/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date $PREFLIGHT_START) (end_date $PREFLIGHT_END)))/" "$STAGE/specs/$name.sexp" > "$STAGE/preflight-$name.sexp"
  grep -q "(start_date $PREFLIGHT_START)" "$STAGE/preflight-$name.sexp" || die "preflight $name: window not replaced"
  docker cp "$STAGE/preflight-$name.sexp" "$C:$pd/$name.sexp" || die "preflight copy $name"
  log "PREFLIGHT $name"; t0=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIX --snapshot-dir $WH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
  pout=$(dx sh -c "grep 'Output root' $pd.log | tail -1 | sed 's/.*: //'")
  dx test -s "${pout}/${name}/actual.sexp" || die "preflight $name wrote no actual.sexp (see $pd.log)"
  pabs=$(dx sh -c "grep -h 'snapshot cache' $pd.log | tail -1" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
  [ -n "$pabs" ] && [ "$pabs" -le "$EXPECT_ABSENT" ] || die "preflight $name: n_symbols_absent=${pabs:-<no cache line>}, expected <= $EXPECT_ABSENT"
  dx grep -q "(tiebreak_seed ${name#rk-k})" "${pout}/${name}/params.sexp" || die "preflight $name: params.sexp does not carry tiebreak_seed ${name#rk-k}"
  log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s)"
}
cmd_run() {
  mkdir -p "$STAGE"; LOCK=$STAGE/chain.lock; STAGE_C=/tmp/rk-work
  mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LOCK held (another record-kseed instance)"; exit 1; }
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
  EXPECT_HEAD=${EXPECT_HEAD:?set by launch}
  head=$(git -C "$REPO/$WTREL" rev-parse --short HEAD)
  log "record-kseed run tree $WTREL HEAD=$head (expect $EXPECT_HEAD) prereg=${PREREG:-?} $(cat "$STAGE/lists-md5.txt" 2>/dev/null)"
  log "cell guard CELL_TIMEOUT=${CELL_TIMEOUT}s (1.5 x 39,142 s, vcv-M-s2); SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES"
  [ "$head" = "$EXPECT_HEAD" ] || die "wrong HEAD"
  [ -z "$(git -C "$REPO/$WTREL" status --porcelain --untracked-files=no)" ] || die "run tree dirty"
  host_free_ok || die "host disk < 20G"
  if dx pgrep -f 'build_snapshots|scenario_runner|panel_runner|bayesian_runner' >/dev/null; then die "another build/backtest is running in $C"; fi
  dx mkdir -p $STAGE_C $ART
  log "BUILD"
  run "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe trading/backtest/bin/trade_audit_report_bin.exe analysis/scripts/stage_chart/bin/stage_chart.exe > $STAGE_C/build.log 2>&1" || die "build failed ($STAGE_C/build.log in the container)"
  log "BUILD_DONE"
  phase_wh_check
  for k in $PREFLIGHT; do preflight_one "rk-k$k"; done
  run_cell rk-k0 -
  for k in $KS; do [ "$k" = 0 ] || run_cell "rk-k$k" "$ART/rk-k0-s0-validator.sexp.sexp"; done
  log "CELLS DONE: $(grep -c ' RESULT rk-' "$LOG_HOST") RESULT, $(grep -c ' EXCLUDED rk-' "$LOG_HOST") EXCLUDED, $(grep -c -e ' GUARD-KILLED/FAILED rk-' -e ' VOID rk-' "$LOG_HOST") failed/void (of 5)"
  phase_pack
  cmd_collect "$STAGE/results"
  cmd_summary "$STAGE/results" > "$STAGE/results/summary.txt" 2>&1 || log "SUMMARY failed (see $STAGE/results/summary.txt)"
  log "RECORD-KSEED DONE. Next: perf_long_cells.sh update $LOG_HOST; look at the pack; results-analyst read per README; results PR."
}

# ---------------------------------------------------------------------------------------------------------- collect
cmd_collect() { # $1 destination results dir (host); trade_audit.sexp is too large to commit, its outcome counts are kept
  dest=${1:?usage: chain.sh collect DEST}; mkdir -p "$dest"
  for f in "$HART"/rk-k[0-9]-s0-*; do
    [ -f "$f" ] || continue
    case "$f" in *-trade_audit.sexp)
      b=$(basename "$f" -trade_audit.sexp)
      tr -s '\n\t ' '   ' < "$f" | grep -oE '\(outcome (Placed|\(Skipped [A-Za-z_]+)' \
        | sed 's/^(outcome (Skipped //; s/^(outcome //' | LC_ALL=C sort | uniq -c | awk '{ print $2 "," $1 }' > "$dest/$b-audit_outcomes.csv"
      continue ;; esac
    cp "$f" "$dest/"
  done
  for f in "$HART"/rk-*-s0.log "$HART"/rk-*-s0.rss "$HART"/rk-*-s0.v6diff-*.log; do [ -f "$f" ] && cp "$f" "$dest/"; done
  [ -f "$LOG_HOST" ] && cp "$LOG_HOST" "$dest/chain.log"
  [ -f "$STAGE/lists-md5.txt" ] && cp "$STAGE/lists-md5.txt" "$dest/"
  echo "collected into $dest: $(ls "$dest" | wc -l | tr -d ' ') files"
}

# ---------------------------------------------------------------------------------------------------------- summary
# README §"What is read", mechanically. A cell counts when its chain log holds its RESULT line, no EXCLUDED line, and
# <dir>/<tag>-actual.sexp exists. spread = sample SD (n-1) of ln(1 + R), R = total_return_pct / 100.
_metrics() { # $1 actual.sexp -> "R sharpe maxdd calmar trades"
  nt=$(grep -o 'total_return_pct' "$1" | wc -l | tr -d ' ')
  [ "$nt" = 1 ] || { echo "TRIPWIRE: $1 holds $nt total_return_pct tokens" >&2; return 1; }
  tr '\n' ' ' < "$1" | awk '{
    n = split("total_return_pct sharpe_ratio max_drawdown_pct calmar_ratio total_trades", k, " ")
    for (i = 1; i <= n; i++) { v = "nan"; if (match($0, "\\(" k[i] " [-0-9.eE+]+\\)")) { v = substr($0, RSTART + length(k[i]) + 2, RLENGTH - length(k[i]) - 3) } printf "%s ", v }
  }'
}
cmd_summary() {
  dir=${1:-$HART}; lg=$dir/chain.log; [ -f "$lg" ] || lg=$LOG_HOST
  [ -f "$lg" ] || { echo "summary: no chain log in $dir or at $LOG_HOST"; return 2; }
  rows=${TMPDIR:-/tmp}/rk-summary.$$; : > "$rows"
  for k in $KS; do
    tag=rk-k$k-s0; f=$dir/$tag-actual.sexp
    if ! grep -q " RESULT $tag " "$lg"; then st=no_result
    elif grep -q " EXCLUDED $tag:" "$lg"; then st=excluded
    elif [ ! -s "$f" ]; then st=no_artifact
    else st=included; fi
    vals="nan nan nan nan nan"; [ -s "$f" ] && { vals=$(_metrics "$f") || { rm -f "$rows"; return 1; }; }
    echo "new k$k $st $vals" >> "$rows"
  done
  for s in 0 1 2; do f=$OLD_DIR/N-rb1-26-s$s-v12-actual.sexp
    if [ -s "$f" ]; then echo "old s$s reference $(_metrics "$f")" >> "$rows"; else echo "old s$s missing nan nan nan nan nan" >> "$rows"; fi
  done
  echo "record-kseed summary: seeds from $dir; old record N (Alphabetical, salts 0-2) from $OLD_DIR"
  echo
  echo "cell     status     total_return_pct  ln(1+R)   sharpe   max_dd_pct  calmar   trades"
  awk '
    function med(a, n,   i, j, t, b) { for (i = 1; i <= n; i++) b[i] = a[i]
      for (i = 2; i <= n; i++) { t = b[i]; for (j = i - 1; j >= 1 && b[j] > t; j--) b[j + 1] = b[j]; b[j + 1] = t }
      if (n == 0) return "nan"; return (n % 2) ? b[(n + 1) / 2] : (b[n / 2] + b[n / 2 + 1]) / 2 }
    function fmt(x) { return (x == "nan" || x == "") ? "n/a" : sprintf("%.4f", x) }
    {
      lr = ($4 == "nan") ? "nan" : log(1 + $4 / 100)
      printf "%-4s %-3s %-10s %16s  %-8s  %-7s  %-10s  %-7s  %s\n", $1, $2, $3, $4, fmt(lr), $5, $6, $7, $8
      if ($3 != "included" && $3 != "reference") next
      if (lr == "nan") next
      g = $1; n[g]++; i = n[g]; x[g, i] = lr; sh[g, i] = $5; dd[g, i] = $6; ca[g, i] = $7
    }
    END {
      print ""; print "set  n  median_ln  sd_ln    min_ln   max_ln   median_sharpe  median_maxdd  median_calmar"
      split("new old", gs, " ")
      for (a = 1; a <= 2; a++) { G = gs[a]; m = n[G] + 0
        delete v1; delete v2; delete v3; delete v4; s = 0; lo = ""; hi = ""
        for (i = 1; i <= m; i++) { v1[i] = x[G, i]; v2[i] = sh[G, i]; v3[i] = dd[G, i]; v4[i] = ca[G, i]; s += x[G, i]
          if (lo == "" || x[G, i] < lo) lo = x[G, i]; if (hi == "" || x[G, i] > hi) hi = x[G, i] }
        sd = "nan"; if (m >= 2) { mu = s / m; ss = 0; for (i = 1; i <= m; i++) ss += (x[G, i] - mu) ^ 2; sd = sqrt(ss / (m - 1)) }
        printf "%-4s %-2d %-10s %-8s %-8s %-8s %-14s %-13s %s\n", G, m, fmt(med(v1, m)), fmt(sd), fmt(lo), fmt(hi), fmt(med(v2, m)), fmt(med(v3, m)), fmt(med(v4, m))
        MED[G] = med(v1, m); LO[G] = lo; HI[G] = hi; N[G] = m
      }
      print ""
      if (N["new"] < 4) { print "record: NOT REPLACED (fewer than 4 included seeds; README)"; exit }
      printf "record: replaced by the K-seed set (n = %d); headline median ln(1+R) %.4f, range [%.4f, %.4f]\n", N["new"], MED["new"], LO["new"], HI["new"]
      if (N["old"] > 0) printf "old record N median ln(1+R) %.4f lies %s the new seed range (descriptive; salts vs seeds, not paired)\n", MED["old"], (MED["old"] >= LO["new"] && MED["old"] <= HI["new"]) ? "inside" : "outside"
    }' "$rows"
  rm -f "$rows"
  echo
  echo "divergence onset (first date a seed's NAV differs from k0's; descriptive):"
  p0=$dir/rk-k0-s0-equity_curve.csv
  for k in $KS; do [ "$k" = 0 ] && continue; pk=$dir/rk-k$k-s0-equity_curve.csv
    if [ ! -s "$p0" ] || [ ! -s "$pk" ]; then echo "  k$k: n/a (curve missing)"; continue; fi
    on=$(awk -F, 'NR == FNR { if (FNR > 1) v[$1] = $2; next }
      FNR > 1 && !done { if (!($1 in v) || v[$1] != $2) { print $1; done = 1 } }
      END { if (!done) print "never" }' "$p0" "$pk")
    echo "  k$k: $on"
  done
}

case "$CMD" in
  launch) cmd_launch ;;
  run) cmd_run ;;
  collect) cmd_collect "${1:-}" ;;
  summary) cmd_summary "${1:-}" ;;
  *) echo "usage: sh $0 {launch|run|collect DEST|summary [DIR]}" >&2; exit 2 ;;
esac
