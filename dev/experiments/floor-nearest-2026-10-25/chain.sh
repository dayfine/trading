#!/bin/sh
# floor-nearest-2026-10-25: one arm (SN = path-stability S + stops_config support_floor_anchor_scope Nearest) x K=6
# perturbations = 6 cells, read against the path-stability S null (6 cells, same build, same window, same five deleted
# names, same seeds). Pre-registration and read rule: README.md beside this file. The dispatcher launches it after the
# pre-registration commit is pushed, when the container is free (no agents, no other backtest).
#
# Subcommands (host side; POSIX sh):
#   sh chain.sh launch            reuse the null's run tree (.claude/worktrees/sweep-ps, must be at RUN_SHA, default
#                                 3db869d32), stage inputs from the PREREG commit outside any VCS tree, copy the null's
#                                 perturbation names, start `run` detached
#   sh chain.sh run               (started by launch) lock -> guards -> build (no-op on the built tree) -> warehouse
#                                 check -> preflight SN-p0 -> SN-p0 -> SN p1-p5 specs + lists (the null's names) ->
#                                 SN p1-p5 -> review pack -> collect -> summary
#   sh chain.sh validate [SPEC..] short parse/override check of ps-SN-p0 plus a negative control (container work)
#   sh chain.sh collect DEST      copy the per-cell artifacts from the sweep output into DEST (the results/ dir)
#   sh chain.sh summary [DIR]     SN vs S: spreads, medians, decision-rule arithmetic, liveness counts. S rows come from
#                                 NULL_DIR (default: the path-stability results). POSIX sh + awk, host only.
#
# Derived from ../path-stability-2026-10-23/chain.sh. Changes:
#   1. One arm, SN, tags ps-SN-p<k>-s0; pk sets tiebreak_seed = k exactly as the null's S arm.
#   2. Run tree = the null's (RUN_SHA 3db869d32); launch refuses any other commit, so SN and S share one build.
#   3. Perturbation names are NOT re-chosen: they are the null's ($NULL_NAMES, chosen by rule from ps-A-p0), so pk
#      deletes the same symbol in SN as in S.
#   4. V6 gates: SN-p0 vs the null's A-p0 validator report; each SN pk vs SN-p0.
#   5. Own stage, work, fixtures and output dirs (/tmp/fn-run, /tmp/fn-work, /tmp/fn-fix, /tmp/sweeps/floor-nearest).
#   6. summary reads S from NULL_DIR, applies the README rule mechanically, and adds the liveness counts.
#
# Cell guard: CELL_TIMEOUT=14400 s as the null's chain (1.5 x 6 y x 1,505 s/yr, #3381). The null's S/SC cells took
# 3,000-3,600 s each (path-stability chain.log, 10-24), so this chain should take about 6-7 h.
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
C=${CONTAINER:-trading-1-dev}
REPO=${REPO:-/Users/difan/Projects/trading-1}
EXP=dev/experiments/floor-nearest-2026-10-25
STAGE=${STAGE:-/tmp/fn-run}                            # host, outside every VCS tree (sweep-hygiene.md: inputs too)
H=$REPO/.sweep-output                                # host side of the container's /tmp/sweeps bind-mount
ART=/tmp/sweeps/floor-nearest                          # container side; host $H/floor-nearest
HART=$H/floor-nearest
WTREL=${WTREL:-.claude/worktrees/sweep-ps}             # the pinned run tree, repo-relative (container-visible)
WT=/workspaces/trading-1/$WTREL; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
FIXPS=/tmp/fn-fix                                      # container: fixtures root for perturbed cells (symlinks + ps-lists/)
WH=${WH:-/tmp/snap_top3000_pit_v12wk}                # v12 warehouse built by the #3266 rerun; reused, not rebuilt
WH_MARK=.v3266-done                                  # its completion marker
EXPECT_WH=${EXPECT_WH:-9236}                            # manifest symbol count (N's)
EXPECT_ABSENT=${EXPECT_ABSENT:-1}                       # cache line n_symbols_absent (MEL, no CSV)
EXPECT_UNION=${EXPECT_UNION:-9222}                     # distinct symbols in the run tree's lists; asserted at launch
CELL_TIMEOUT=${CELL_TIMEOUT:-14400}                     # >= 1.5 x 6 y x 1,505 s/yr (slowest same-spec cell, #3381)
MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}     # #2839/#2882: >= manifest size, so the LRU never cycles
ARMS="SN"
KS="1 2 3 4 5"                                        # perturbations; p0 is unperturbed
PREFLIGHT_START=2024-10-01; PREFLIGHT_END=2024-12-31  # last quarter of the window
# Commits the run tree must contain (as the template): #3283 (#3266 fix), #3181, #3222, #3193, #3195, #3339 (A-D
# fixture fix), #3391 (pit-v12 CMN dedupe).
FIX3391=3d437597c
NEED="3f51d4afd e9d6bb7a0 904746e8c 974e91885 852e61c2e 1f2432fa2 $FIX3391"
SPECS0="ps-SN-p0"
# The null (path-stability S arm): its build, its results dir (host) and its sweep output (container, for A-p0's
# validator report, the SN-p0 V6 partner). NULL_DIR moves to the committed results dir once that PR merges.
NULL_SHA=3db869d32
NULL_DIR=${NULL_DIR:-/tmp/ps-run/results}
NULL_NAMES=$NULL_DIR/perturb-names.txt
NULL_ART=/tmp/sweeps/path-stability
LOG_HOST=$STAGE/chain.log
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
die() { log "ABORT: $*"; exit 1; }
dx() { docker exec "$C" "$@"; }
run() { docker exec "$C" bash -c "cd $ROOT && eval \$(opam env) && $1"; }
host_free_ok() { free_gb=$(df -g / | awk 'NR==2{print $4}'); log "host free ${free_gb}G"; [ "$free_gb" -ge 20 ]; }
syms_of() { grep -o '(symbol [^)]*)' "$1" | sed 's/(symbol //; s/)$//'; }   # one symbol per entry, file order
seeded() { case $1 in S | SR | SC | SN) return 0 ;; *) return 1 ;; esac; }

# ---------------------------------------------------------------------------------------------------------------- launch
cmd_launch() {
  mkdir -p "$STAGE"; cd "$REPO" || exit 1
  git fetch -q origin main
  SHA=$(git rev-parse --short=9 "${RUN_SHA:-$NULL_SHA}") || die "cannot resolve ${RUN_SHA:-$NULL_SHA}"
  [ "$SHA" = "$NULL_SHA" ] || die "run tree $SHA is not the null's build $NULL_SHA (SN and S must share one build)"
  for c in $NEED; do git merge-base --is-ancestor "$c" "$SHA" || die "run tree $SHA lacks $c"; done
  # #3406 (Step 1): the Seeded tiebreak and its seed field must be in the run tree, else S/SR/SC cannot parse.
  git show "$SHA:trading/analysis/weinstein/screener/lib/screener_ranking.mli" | grep -q '^  | Seeded$' \
    || die "run tree $SHA lacks #3406: no '| Seeded' in screener_ranking.mli"
  git show "$SHA:trading/analysis/weinstein/screener/lib/screener.mli" | grep -q 'tiebreak_seed : int' \
    || die "run tree $SHA lacks #3406: no 'tiebreak_seed : int' in screener.mli"
  if [ -d "$WTREL" ]; then
    [ "$(git -C "$WTREL" rev-parse --short=9 HEAD)" = "$SHA" ] || die "$WTREL is not at $SHA; remove it first"
  else git worktree add --detach "$WTREL" "$SHA" || die "worktree add"; fi
  # Inputs come from a commit, never a working copy: the pre-registration commit (the run tree predates this directory).
  PREREG=${PREREG:?set PREREG to the pre-registration commit}
  rm -rf "$STAGE/specs"; mkdir -p "$STAGE/specs"
  for s in $SPECS0; do git show "$PREREG:$EXP/specs/$s.sexp" > "$STAGE/specs/$s.sexp" || die "spec $s not at $PREREG"; done
  git show "$PREREG:$EXP/chain.sh" > "$STAGE/chain.sh" || die "chain.sh not at $PREREG"
  # Warehouse symbol set the cells need (template derivation): union of the yearly lists, minus MEL (no CSV), plus the
  # GSPC.INDX benchmark, plus the 14 runner extras parsed from the run tree's macro_inputs.ml.
  L=$WTREL/trading/test_data/backtest_scenarios/pit-v12/composition
  for f in "$L"/top-3000-1999.sexp "$L"/top-3000-20*.sexp; do grep -o '(symbol [^)]*)' "$f"; done \
    | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u > "$STAGE/lists-union.txt"
  [ "$(wc -l < "$STAGE/lists-union.txt" | tr -d ' ')" = "$EXPECT_UNION" ] \
    || die "lists hold $(wc -l < "$STAGE/lists-union.txt" | tr -d ' ') distinct symbols, expected $EXPECT_UNION (set EXPECT_UNION if main moved on purpose; the warehouse check in run then decides)"
  MI=$WTREL/trading/trading/weinstein/strategy/lib/macro_inputs.ml
  { sed -n '/^let spdr_sector_etfs/,/^  \]$/p' "$MI"; sed -n '/^let default_global_indices/,/\]$/p' "$MI"; } \
    | grep -o '("[A-Z0-9.]*",' | sed 's/("//; s/",$//' | LC_ALL=C sort -u > "$STAGE/runner-extras.txt"
  [ "$(wc -l < "$STAGE/runner-extras.txt" | tr -d ' ')" = 14 ] \
    || die "parsed $(wc -l < "$STAGE/runner-extras.txt" | tr -d ' ') runner extras from $MI, expected 14 (11 SPDR + 3 indices)"
  { grep -v -x -F MEL "$STAGE/lists-union.txt"; echo GSPC.INDX; cat "$STAGE/runner-extras.txt"; } | LC_ALL=C sort -u > "$STAGE/wh-syms.txt"
  [ "$(wc -l < "$STAGE/wh-syms.txt" | tr -d ' ')" = "$EXPECT_WH" ] \
    || die "derived warehouse set holds $(wc -l < "$STAGE/wh-syms.txt" | tr -d ' ') symbols, expected $EXPECT_WH"
  # #3391 twin guard (as the template): the dedupe is in the run tree and no confirmed twin pair co-occurs in a list.
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
  echo "twin guard OK" | tee -a "$STAGE/launch.log"
  # The scheduled lists (from the p0 spec), copied out of the run tree: the source the perturbed lists are cut from.
  rm -rf "$STAGE/lists-orig"; mkdir -p "$STAGE/lists-orig"
  grep -o '"pit-v12/composition/top-3000-[0-9]*\.sexp"' "$STAGE/specs/ps-SN-p0.sexp" | tr -d '"' | LC_ALL=C sort -u > "$STAGE/sched-lists.txt"
  [ "$(wc -l < "$STAGE/sched-lists.txt" | tr -d ' ')" = 27 ] || die "expected 27 scheduled lists in ps-SN-p0.sexp"
  while read -r p; do cp "$WTREL/trading/test_data/backtest_scenarios/$p" "$STAGE/lists-orig/" || die "copy $p"; done < "$STAGE/sched-lists.txt"
  echo "lists md5 $(cat "$STAGE"/lists-orig/top-3000-*.sexp | md5 -q)" > "$STAGE/lists.md5"
  # Same lists and the same five names as the null, or the comparison is not like for like.
  cmp -s "$STAGE/lists.md5" "$NULL_DIR/lists.md5" || die "lists md5 differs from the null's ($NULL_DIR/lists.md5)"
  [ -s "$NULL_NAMES" ] || die "null perturbation names missing ($NULL_NAMES)"
  cp "$NULL_NAMES" "$STAGE/perturb-names.txt"
  dx test -s "$NULL_ART/ps-A-p0-s0-validator.sexp.sexp" || die "null A-p0 validator report missing in $C ($NULL_ART)"
  # Dividends + splits (EODHD, #3158) into the run tree's test_data (dividend_crediting, split_dividend_guard read them
  # from TRADING_DATA_DIR), as the template.
  rsync -a -m --include='*/' --include='dividends.csv' --include='splits.csv' --exclude='*' data/ "$WTREL/trading/test_data/"
  echo "staged $(find "$WTREL/trading/test_data" -name dividends.csv | wc -l | tr -d ' ') dividends.csv" | tee -a "$STAGE/launch.log"
  nohup env REPO="$REPO" STAGE="$STAGE" WTREL="$WTREL" EXPECT_HEAD="$(git -C "$WTREL" rev-parse --short HEAD)" PREREG="$PREREG" \
    sh "$STAGE/chain.sh" run > "$STAGE/run.out" 2>&1 &
  echo "launched run pid $! (tree $SHA, prereg $PREREG); log $LOG_HOST"
}

# ---------------------------------------------------------------------------------------------------- warehouse check
phase_wh_check() {
  dx test -f "$WH/$WH_MARK" || die "$WH lacks its $WH_MARK marker (the #3266 rerun's build): rebuild it with ../verify-3266-rerun-2026-10-22/chain.sh's wh phase"
  dx sh -c "tr '\n' ' ' < $WH/manifest.sexp | grep -o '(symbol [^)]*)'" | sed 's/(symbol //; s/)$//' | LC_ALL=C sort > "$STAGE/wh-manifest.txt"
  n=$(wc -l < "$STAGE/wh-manifest.txt" | tr -d ' ')
  [ "$n" = "$EXPECT_WH" ] || die "$WH manifest holds $n symbols, expected $EXPECT_WH"
  cmp -s "$STAGE/wh-manifest.txt" "$STAGE/wh-syms.txt" || die "$WH manifest set differs from the set derived from the run tree's lists ($STAGE/wh-manifest.txt vs $STAGE/wh-syms.txt)"
  log "WH $WH reused: $n symbols, equal to the run tree's derived set"
}
# Fixtures root for perturbed cells: every entry of the run tree's fixtures root symlinked, plus ps-lists/p<k>/ (filled
# by phase_perturb). Rebuilt on every run (cheap).
phase_fixps() {
  dx sh -c "rm -rf $FIXPS && mkdir -p $FIXPS/ps-lists && for e in $FIX/*; do ln -s \$e $FIXPS/\$(basename \$e); done" || die "fixtures root $FIXPS"
  dx test -f "$FIXPS/pit-v12/composition/top-3000-2019.sexp" || die "$FIXPS does not expose pit-v12"
  log "FIXPS $FIXPS: $(dx sh -c "ls $FIXPS | wc -l" | tr -d ' ') entries"
}

# ----------------------------------------------------------------------------------------------------- perturbations
# Delete every entry ((symbol SYM) ...) from a list (file flattened to one line; entries hold no nested parens beyond
# their fields, strings skipped). $1 symbol, $2 in, $3 out.
cut_symbol() {
  tr '\n' ' ' < "$2" | awk -v sym="$1" '{
    s = $0; key = "((symbol " sym ") "
    while ((i = index(s, key)) > 0) {
      depth = 0; instr = 0; n = length(s)
      for (j = i; j <= n; j++) {
        c = substr(s, j, 1)
        if (c == "\"") instr = !instr
        else if (!instr) { if (c == "(") depth++; else if (c == ")") { depth--; if (depth == 0) break } }
      }
      s = substr(s, 1, i - 1) substr(s, j + 1)
    }
    print s }' > "$3"
}
phase_perturb() { # names: the null's (copied by launch), never re-chosen here
  [ -s "$STAGE/perturb-names.txt" ] || die "$STAGE/perturb-names.txt missing (launch copies the null's)"
  log "PERTURB names = the null's ($NULL_NAMES)"
  grep -v '^#' "$STAGE/perturb-names.txt" | while read -r pk s v n nl; do log "PERTURB $pk: delete $s (A-p0 total-return P&L $v over $n trades; in $nl of 27 scheduled lists)"; done
  for k in $KS; do
    s=$(awk -v p="p$k" '$1 == p { print $2 }' "$STAGE/perturb-names.txt"); [ -n "$s" ] || die "no symbol for p$k"
    P=$STAGE/perturb/p$k; rm -rf "$P"; mkdir -p "$P"; cut=0
    for f in "$STAGE"/lists-orig/top-3000-*.sexp; do b=$(basename "$f")
      if grep -q -F "(symbol $s)" "$f"; then
        cut_symbol "$s" "$f" "$P/$b"; cut=$((cut + 1))
        # the new list is the old one minus exactly the entries of $s, nothing else; parentheses balance
        syms_of "$f" | grep -v -x -F "$s" > "$STAGE/cut-expect.txt"; syms_of "$P/$b" > "$STAGE/cut-got.txt"
        cmp -s "$STAGE/cut-expect.txt" "$STAGE/cut-got.txt" || die "p$k $b: cutting $s changed more than its entries"
        bal=$(tr -cd '()' < "$P/$b" | awk '{ n = 0; for (i = 1; i <= length($0); i++) { n += (substr($0, i, 1) == "(") ? 1 : -1; if (n < 0) { print "neg"; exit } } print n }')
        [ "$bal" = 0 ] || die "p$k $b: unbalanced parentheses after the cut ($bal)"
      else cp "$f" "$P/$b"; fi
    done
    [ "$cut" -ge 1 ] || die "p$k: $s is in no scheduled list"
    dx mkdir -p "$FIXPS/ps-lists/p$k" || die "mkdir ps-lists/p$k"
    docker cp "$P/." "$C:$FIXPS/ps-lists/p$k/" || die "copy lists p$k"
    hm=$(cd "$P" && cat top-3000-*.sexp | md5 -q); cm=$(dx sh -c "cd $FIXPS/ps-lists/p$k && cat top-3000-*.sexp | md5sum | cut -c1-32")
    [ "$hm" = "$cm" ] || die "p$k lists differ host ($hm) vs container ($cm)"
    for arm in $ARMS; do
      src=$STAGE/specs/ps-$arm-p0.sexp; dst=$STAGE/specs/ps-$arm-p$k.sexp
      sed -e "s/(name \"ps-$arm-p0\")/(name \"ps-$arm-p$k\")/" \
          -e "s/(description \"floor-nearest $arm p0: /(description \"floor-nearest $arm p$k (deletes $s): /" \
          -e "s#\"pit-v12/composition/top-3000-#\"ps-lists/p$k/top-3000-#g" "$src" > "$dst"
      seeded "$arm" && { sed "s/(tiebreak_seed 0)/(tiebreak_seed $k)/" "$dst" > "$dst.tmp" && mv "$dst.tmp" "$dst"; }
      grep -q "^((name \"ps-$arm-p$k\")$" "$dst" || die "spec ps-$arm-p$k: name not set"
      [ "$(grep -c "\"ps-lists/p$k/top-3000-" "$dst")" = 28 ] || die "spec ps-$arm-p$k: expected 28 universe paths on ps-lists/p$k"
      ! grep -q '"pit-v12/composition/' "$dst" || die "spec ps-$arm-p$k: an unperturbed list path remains"
      if seeded "$arm"; then [ "$(grep -c "(tiebreak_seed $k)" "$dst")" = 1 ] || die "spec ps-$arm-p$k: tiebreak_seed $k not set"
      else ! grep -q tiebreak_seed "$dst" || die "spec ps-$arm-p$k: arm A must not set a seed"; fi
    done
    log "PERTURB p$k: $s cut from $cut lists; lists md5 $hm; specs ps-{A,S,SR,SC}-p$k generated"
  done
}

# ----------------------------------------------------------------------------------------------------------- cells
run_cell() { # $1 spec name, $2 pairs (label=partner-validator[,...] or -), $3 fixtures root (container)
  name=$1; pairs=$2; fix=$3; tag="$name-s0"; d=$STAGE_C/$tag; td=$ROOT/test_data
  if grep -q "RESULT $tag " "$LOG_HOST" 2>/dev/null; then log "SKIP $tag"; return 0; fi
  host_free_ok || die "host disk < 20G before $tag"
  if dx pgrep -f 'scenario_runner' >/dev/null; then die "a scenario_runner is still running in $C before $tag"; fi
  dx sh -c "mkdir -p $d && rm -rf $d/*"; docker cp "$STAGE/specs/$name.sexp" "$C:$d/" || { log "GUARD-KILLED/FAILED $tag: spec copy failed"; return 0; }
  log "RUN $tag on $WH (fixtures $fix)"; start=$(date +%s)
  run "TRADING_DATA_DIR=$td TRADING_PATH_SEED_SALT=0 SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES /usr/bin/time -f 'peak_rss_kb=%M' -o $STAGE_C/$tag.rss timeout $CELL_TIMEOUT ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $d --fixtures-root $fix --snapshot-dir $WH --no-emit-all-eligible --parallel 1 --progress-every 26 > $STAGE_C/$tag.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.log"
  out=$(dx sh -c "grep 'Output root' $STAGE_C/$tag.log | tail -1 | sed 's/.*: //'")
  # D3: a cell that wrote no actual.sexp (timeout 124, OOM 137, crash) never reaches the validator or validator_diff.
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
  # D2: the audit is pretty-printed, so normalise whitespace before counting.
  rej=$(dx sh -c "tr -s '\n\t ' '   ' < $ART/${tag}-trade_audit.sexp 2>/dev/null | grep -o '(cash_rejection ((required' | wc -l" | tr -d ' ')
  run "./_build/default/trading/backtest/validation/bin/post_run_validator_cli.exe -run-dir ${out}/${name} -data-dir /workspaces/trading-1/data -share-classes $ROOT/test_data/share_classes.sexp -out $ART/${tag}-validator.sexp > $STAGE_C/$tag.validator.log 2>&1; echo exit=\$? >> $STAGE_C/$tag.validator.log"
  q=$(dx sh -c "grep -hE 'V16 EXPECTATION|V17 EXPECTATION|V6 ' $ART/${tag}-validator.sexp.md 2>/dev/null | tr '\n' ' '")
  v6=""; excl=""
  if [ "$pairs" != "-" ]; then
    for p in $(echo "$pairs" | tr ',' ' '); do lab=${p%%=*}; pv=${p#*=}; vl=$tag.v6diff-$lab.log
      if ! dx test -s "$pv"; then
        v6="$v6 vs$lab:partner-missing"; excl="$excl vs$lab: partner validator $(basename "$pv") missing (its cell failed or was VOID);"
        continue
      fi
      run "./_build/default/trading/backtest/validation/bin/validator_diff.exe -check V6 -report pair=$pv -report arm=$ART/${tag}-validator.sexp.sexp > $STAGE_C/$vl 2>&1; echo exit=\$? >> $STAGE_C/$vl"
      dx cp $STAGE_C/$vl $ART/$vl
      vx=$(dx sh -c "tail -1 $STAGE_C/$vl")
      v6="$v6 vs$lab($(basename "$pv")):$vx"
      if [ "$vx" != "exit=0" ]; then
        spec=$(dx sh -c "grep -v '^exit=' $STAGE_C/$vl | head -8 | tr '\n' '|' | cut -c1-600")
        excl="$excl vs$lab $vx (1 = V6 mismatch, 2 = unreadable/uncomparable) specimen: $spec;"
      fi
    done
  fi
  log "GUARDS $tag => ${guards:-<none>} cash_rejections=$rej"
  log "RESULT $tag => ${m:-<no result>} ${q:-<no validator>} v6diff:${v6:- none} ${rss} ${cache} (wall $(( $(date +%s) - start ))s)"
  [ -z "$excl" ] || log "EXCLUDED $tag:$excl"
}
pv_of() { echo "$ART/ps-$1-p0-s0-validator.sexp.sexp"; }   # an arm's p0 validator report (container path)

# ---------------------------------------------------------------------------------------------------- review packs
phase_packs() {
  WTH=$REPO/$WTREL
  for arm in $ARMS; do
    pre=$HART/ps-$arm-p0-s0-
    [ -s "${pre}trades.csv" ] || { log "PACK $arm: no p0 run"; continue; }
    out=$WTH/.review/ps-$arm-p0
    log "PACK $arm: p0=$pre"
    sh "$WTH/dev/scripts/review_pack.sh" --out "$out" --title "floor-nearest $arm p0 (2019-2024, pit-v12)" \
      --snapshot-dir "$WH" --data-dir "$REPO/data" "p0=$pre" > "$STAGE/pack-$arm.log" 2>&1 || { log "PACK $arm build failed (see $STAGE/pack-$arm.log)"; continue; }
    sh "$WTH/dev/scripts/review_pack_render.sh" --site "$out/site" > "$STAGE/render-$arm.log" 2>&1 || log "RENDER $arm failed (see $STAGE/render-$arm.log)"
    rm -rf "$H/review-ps-$arm-p0"; mkdir -p "$H/review-ps-$arm-p0"
    cp -R "$out/site" "$out/render" "$H/review-ps-$arm-p0/" 2>/dev/null
    log "PACK $arm -> $H/review-ps-$arm-p0 (site/ + render/top.png, part-N.png)"
  done
}

# -------------------------------------------------------------------------------------------------------------- run
preflight_one() { # $1 spec name: last quarter of the window on the reused warehouse; a spec/override error costs minutes
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
  # a short window may touch fewer symbols than the cell, so only an excess fails here; the cell is held to exactly 1
  [ -n "$pabs" ] && [ "$pabs" -le "$EXPECT_ABSENT" ] || die "preflight $name: n_symbols_absent=${pabs:-<no cache line>}, expected <= $EXPECT_ABSENT (see $pd.log)"
  log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s)"
}
cmd_run() {
  mkdir -p "$STAGE"; LOCK=$STAGE/chain.lock; STAGE_C=/tmp/fn-work
  mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LOCK held (another floor-nearest instance)"; exit 1; }
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
  EXPECT_HEAD=${EXPECT_HEAD:?set by launch}
  head=$(git -C "$REPO/$WTREL" rev-parse --short HEAD)
  log "floor-nearest run tree $WTREL HEAD=$head (expect $EXPECT_HEAD) prereg=${PREREG:-?} $(cat "$STAGE/lists.md5" 2>/dev/null)"
  log "cell guard CELL_TIMEOUT=${CELL_TIMEOUT}s (1.5 x 6 y x 1,505 s/yr, the slowest same-spec cell #3381; #3266 rerun 1,031 s/yr); SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES"
  [ "$head" = "$EXPECT_HEAD" ] || die "wrong HEAD"
  [ -z "$(git -C "$REPO/$WTREL" status --porcelain --untracked-files=no)" ] || die "run tree dirty"
  host_free_ok || die "host disk < 20G"
  if dx pgrep -f 'build_snapshots|scenario_runner|panel_runner|bayesian_runner' >/dev/null; then die "another build/backtest is running in $C"; fi
  dx mkdir -p $STAGE_C $ART
  log "BUILD"
  run "dune build trading/backtest/scenarios/scenario_runner.exe trading/backtest/validation/bin/post_run_validator_cli.exe trading/backtest/validation/bin/validator_diff.exe trading/backtest/bin/trade_audit_report_bin.exe analysis/scripts/stage_chart/bin/stage_chart.exe > $STAGE_C/build.log 2>&1" || die "build failed ($STAGE_C/build.log in the container)"
  log "BUILD_DONE"
  phase_wh_check
  phase_fixps
  for name in $SPECS0; do preflight_one "$name"; done
  # SN-p0 (V6 vs the null's A-p0), then the lists and SN p1-p5 specs from the null's names, then SN p1-p5 (V6 vs SN-p0)
  run_cell ps-SN-p0 "A0=$NULL_ART/ps-A-p0-s0-validator.sexp.sexp" "$FIX"
  phase_perturb
  for k in $KS; do run_cell "ps-SN-p$k" "SN0=$(pv_of SN)" "$FIXPS"; done
  log "CELLS DONE: $(grep -c ' RESULT ps-' "$LOG_HOST") RESULT, $(grep -c ' EXCLUDED ps-' "$LOG_HOST") EXCLUDED, $(grep -c -e ' GUARD-KILLED/FAILED ps-' -e ' VOID ps-' "$LOG_HOST") failed/void (of 6)"
  phase_packs
  cmd_collect "$STAGE/results"
  cmd_summary "$STAGE/results" > "$STAGE/results/summary.txt" 2>&1 || log "SUMMARY failed (see $STAGE/results/summary.txt)"
  log "FLOOR-NEAREST DONE. Next: perf_long_cells.sh update $LOG_HOST; results-analyst read per README; results PR."
}

# --------------------------------------------------------------------------------------------------------- validate
# Parse + override check only, never a backtest. scenario_runner loads the universe schedule and applies
# config_overrides BEFORE it prints "Running backtest" (backtest/lib/runner.ml). Each spec runs under `timeout 300` on
# the warehouse, in an already built tree, and is VALID iff its log reaches that line. A negative control (ps-SN-p0 plus
# a nonexistent override) must fail before that line, which shows the check can fail.
_validate_one() { # $1 label, $2 spec file (host)
  pd=$STAGE_C/$1; dx sh -c "mkdir -p $pd && rm -rf $pd/*"; docker cp "$2" "$C:$pd/$1.sexp"
  run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 300 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIX --snapshot-dir $VWH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
  dx grep -q 'Running backtest' $pd.log
}
cmd_validate() {
  VWH=${VALIDATE_WH:-$WH}; STAGE_C=/tmp/ps-validate; dx mkdir -p $STAGE_C
  dx test -d "$VWH" || { echo "validate needs a warehouse in $C at $VWH (set VALIDATE_WH) and a built tree at WTREL: container work"; return 2; }
  here=$(cd "$(dirname "$0")" && pwd); rc=0; tmp=${TMPDIR:-/tmp}/ps-validate.$$
  for name in ${*:-$SPECS0 control}; do
    if [ "$name" = control ]; then
      awk '{ print } $0 == "   ((dividend_crediting true))" { print "   ((ps_no_such_flag true))" }' "$here/specs/ps-SN-p0.sexp" \
        | sed 's/(name "ps-SN-p0")/(name "control")/' > "$tmp"
      if _validate_one control "$tmp"; then echo "CONTROL FAILED: a bogus override reached 'Running backtest'"; rc=1
      else echo "CONTROL OK (bogus override rejected): $(dx sh -c "grep -m2 -iE 'error|exception|unknown|fail' $STAGE_C/control.log | tr '\n' ' ' | cut -c1-300")"; fi
    else
      cp "$here/specs/$name.sexp" "$tmp"
      if _validate_one "$name" "$tmp"; then echo "VALID $name: parsed, overrides applied, reached 'Running backtest'"
      else echo "INVALID $name:"; dx tail -5 "$STAGE_C/$name.log"; rc=1; fi
    fi
  done
  rm -f "$tmp"; return $rc
}

# ---------------------------------------------------------------------------------------------------------- collect
# One CSV row per trade_audit.sexp record (template): position_id,symbol,entry_date,cancel_reason,
# ticket_age_weeks_at_cancel,required,available (the last two only on a ticket_lifecycle cash_rejection, #3195).
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
  dest=${1:?usage: chain.sh collect DEST}; mkdir -p "$dest"; src=$HART
  echo "cell,entry_year,cash_rejections" > "$dest/cash_rejections_by_year.csv"
  for f in "$src"/ps-*-p[0-9]-s0-*; do
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
      # liveness (README): top-N decision outcomes only, never the re-listings in alternatives_considered
      tr -s '\n\t ' '   ' < "$f" | grep -oE '\(outcome (Placed|\(Skipped [A-Za-z_]+)' \
        | sed 's/^(outcome (Skipped //; s/^(outcome //' | LC_ALL=C sort | uniq -c | awk '{ print $2 "," $1 }' > "$dest/$b-audit_outcomes.csv"
      continue ;; esac
    cp "$f" "$dest/"
  done
  for f in "$src"/ps-*-s0.log "$src"/ps-*-s0.rss "$src"/ps-*-s0.v6diff-*.log; do [ -f "$f" ] && cp "$f" "$dest/"; done
  [ -f "$LOG_HOST" ] && cp "$LOG_HOST" "$dest/chain.log"
  for f in perturb-names.txt perturb-ranking.csv lists.md5; do [ -f "$STAGE/$f" ] && cp "$STAGE/$f" "$dest/"; done
  # the 5 generated specs (the p0 spec is committed under specs/)
  if ls "$STAGE"/specs/ps-*-p[1-9].sexp >/dev/null 2>&1; then mkdir -p "$dest/specs-generated"; cp "$STAGE"/specs/ps-*-p[1-9].sexp "$dest/specs-generated/"; fi
  echo "collected into $dest: $(ls "$dest" | wc -l | tr -d ' ') files (trade_audit.sexp reduced to audit_entries.csv + cash_rejections.csv + audit_outcomes.csv)"
}

# ---------------------------------------------------------------------------------------------------------- summary
# README §"Decision rule", mechanically. SN rows from DIR (default: this chain's sweep output), S rows from NULL_DIR
# (the path-stability results). A cell counts when its chain log holds its RESULT line, no EXCLUDED line, and
# <dir>/<tag>-actual.sexp exists. spread = sample SD (n-1) of ln(1 + R), R = total_return_pct / 100.
_rows() { # $1 arm, $2 dir, $3 chain log -> "arm k status R sharpe maxdd calmar" per cell
  for k in 0 $KS; do
    tag=ps-$1-p$k-s0; f=$2/$tag-actual.sexp
    if ! grep -q " RESULT $tag " "$3"; then st=no_result
    elif grep -q " EXCLUDED $tag:" "$3"; then st=excluded
    elif [ ! -s "$f" ]; then st=no_artifact
    else st=included; fi
    vals="nan nan nan nan"
    if [ -s "$f" ]; then
      nt=$(grep -o 'total_return_pct' "$f" | wc -l | tr -d ' ')
      [ "$nt" = 1 ] || { echo "TRIPWIRE: $f holds $nt total_return_pct tokens" >&2; return 1; }
      vals=$(tr '\n' ' ' < "$f" | awk '{
        n = split("total_return_pct sharpe_ratio max_drawdown_pct calmar_ratio", k, " ")
        for (i = 1; i <= n; i++) { v = "nan"; if (match($0, "\\(" k[i] " [-0-9.eE+]+\\)")) { v = substr($0, RSTART + length(k[i]) + 2, RLENGTH - length(k[i]) - 3) } printf "%s ", v }
      }')
    fi
    echo "$1 $k $st $vals"
  done
}
cmd_summary() {
  dir=${1:-$HART}; lg=$dir/chain.log; [ -f "$lg" ] || lg=$LOG_HOST
  nlg=$NULL_DIR/chain.log
  [ -f "$lg" ] || { echo "summary: no chain log in $dir or at $LOG_HOST"; return 2; }
  [ -f "$nlg" ] || { echo "summary: no null chain log at $nlg (set NULL_DIR)"; return 2; }
  rows=${TMPDIR:-/tmp}/fn-summary.$$
  { _rows S "$NULL_DIR" "$nlg" && _rows SN "$dir" "$lg"; } > "$rows" || { rm -f "$rows"; return 1; }
  echo "floor-nearest summary: SN from $dir, S (null) from $NULL_DIR"
  echo
  echo "liveness (README; SN p0 vs the null's S p0 = decision outcomes No_structural_stop 5078, Placed 190, path-stability ps-S-p0-s0 trade_audit):"
  oc=$dir/ps-SN-p0-s0-audit_outcomes.csv
  if [ -s "$oc" ]; then
    awk -F, '{ c[$1] = $2 } END { nss = c["No_structural_stop"] + 0; pl = c["Placed"] + 0
      printf "  SN p0: No_structural_stop %d (%.3f x S), Placed %d (%.3f x S)\n", nss, nss / 5078, pl, pl / 190
      if (nss <= 0.75 * 5078 && pl > 190) print "  -> LIVE (No_structural_stop <= 0.75 x S and Placed > S)"
      else print "  -> NOT LIVE as screened: no return read (README)" }' "$oc"
  else echo "  n/a: $oc missing"; fi
  echo
  echo "cell                 status     total_return_pct  ln(1+R)    sharpe   max_dd_pct  calmar"
  awk '
    function lnr(r) { return log(1 + r / 100) }
    function med(a, n,   i, j, t, b) { for (i = 1; i <= n; i++) b[i] = a[i]
      for (i = 2; i <= n; i++) { t = b[i]; for (j = i - 1; j >= 1 && b[j] > t; j--) b[j + 1] = b[j]; b[j + 1] = t }
      if (n == 0) return "nan"; return (n % 2) ? b[(n + 1) / 2] : (b[n / 2] + b[n / 2 + 1]) / 2 }
    function fmt(x) { return (x == "nan" || x == "") ? "n/a" : sprintf("%.4f", x) }
    {
      arm = $1; k = $2; st = $3
      printf "%-20s %-10s %16s  %-9s  %-7s  %-10s  %s\n", "ps-" arm "-p" k, st, $4, ($4 == "nan" ? "n/a" : sprintf("%.4f", lnr($4))), $5, $6, $7
      if (st != "included" || $4 == "nan") next
      n[arm]++; i = n[arm]; x[arm, i] = lnr($4); sh[arm, i] = $5; dd[arm, i] = $6; ca[arm, i] = $7
    }
    END {
      print ""; print "arm  n  spread_sd  range      median_ln  median_sharpe  median_maxdd  median_calmar"
      split("S SN", arms, " ")
      for (a = 1; a <= 2; a++) { A = arms[a]; m = n[A] + 0
        delete v1; delete v2; delete v3; delete v4; s = 0; lo = ""; hi = ""
        for (i = 1; i <= m; i++) { v1[i] = x[A, i]; v2[i] = sh[A, i]; v3[i] = dd[A, i]; v4[i] = ca[A, i]; s += x[A, i]
          if (lo == "" || x[A, i] < lo) lo = x[A, i]; if (hi == "" || x[A, i] > hi) hi = x[A, i] }
        sd = "nan"; if (m >= 2) { mu = s / m; ss = 0; for (i = 1; i <= m; i++) ss += (x[A, i] - mu) ^ 2; sd = sqrt(ss / (m - 1)) }
        SD[A] = sd; MX[A] = med(v1, m); MDD[A] = med(v3, m); MCA[A] = med(v4, m)
        printf "%-4s %-2d %-10s %-10s %-10s %-14s %-13s %s\n", A, m, fmt(sd), (m >= 2 ? fmt(hi - lo) : "n/a"), fmt(MX[A]), fmt(med(v2, m)), fmt(MDD[A]), fmt(MCA[A])
      }
      # descriptive: of the n(SN) x n(S) cross pairs, how many SN cells beat the S cell on ln(1+R)
      w = 0; t = 0; for (i = 1; i <= n["SN"]; i++) for (j = 1; j <= n["S"]; j++) { t++; if (x["SN", i] > x["S", j]) w++ }
      print ""
      if (n["SN"] < 4 || n["S"] < 4 || SD["S"] == "nan") { print "decision: n/a (need >= 4 included cells in each arm)"; exit }
      d = MX["SN"] - MX["S"]; b = SD["S"]
      printf "delta median ln(1+R) = %.4f (bar = spread(S) = %.4f); SN beats S in %d of %d cross pairs; spread(SN)/spread(S) = %s\n", d, b, w, t, (SD["SN"] == "nan" ? "n/a" : sprintf("%.4f", SD["SN"] / b))
      ddc = MDD["SN"] - MDD["S"]
      printf "median max DD SN - S = %+.2f pp (DD-cost bar %.2f pp); median Calmar SN %.4f vs S %.4f\n", ddc, 100 * b, MCA["SN"], MCA["S"]
      if (d >= b) { v = "PROMISING: escalate to the 26y + pre-2009 grid (a new pre-registration)"; if (ddc > 100 * b) v = v ", WITH A DD COST (user decision)" }
      else if (d <= -b) v = "NO-BUILD decision for this lever at this window (keep the axis)"
      else v = "INCONCLUSIVE: no escalation on return"
      print "decision-rule arithmetic (mechanical; README; applies only if liveness reads LIVE): " v
    }' "$rows"
  rm -f "$rows"
  echo
  echo "divergence onset (first date an SN pk NAV differs from SN p0; descriptive):"
  p0=$dir/ps-SN-p0-s0-equity_curve.csv
  for k in $KS; do pk=$dir/ps-SN-p$k-s0-equity_curve.csv; tag=ps-SN-p$k-s0
    if [ ! -s "$p0" ] || [ ! -s "$pk" ]; then echo "  $tag: n/a (curve missing)"; continue; fi
    on=$(awk -F, 'NR == FNR { if (FNR > 1) v[$1] = $2; next }
      FNR > 1 && !done { if (!($1 in v) || v[$1] != $2) { print $1; done = 1 } }
      END { if (!done) print "never" }' "$p0" "$pk")
    echo "  $tag: $on"
  done
}

case "$CMD" in
  launch) cmd_launch ;;
  run) cmd_run ;;
  validate) cmd_validate "$@" ;;
  collect) cmd_collect "${1:-}" ;;
  summary) cmd_summary "${1:-}" ;;
  *) echo "usage: sh $0 {launch|run|validate|collect DEST|summary [DIR]}" >&2; exit 2 ;;
esac
