#!/bin/sh
# floor-nearest-2026-10-25 arm SM: path-stability S with its yearly pit-v12 universe_schedule replaced by 320 month-end
# top-3000 lists (pit-v12-monthly, 1999-05-31 -> 2025-12-31) x K=6 perturbations = 6 cells, read against the
# path-stability S null (6 cells, same build, same window, same five deleted names, same seeds). Pre-registration and
# read rule: README.md beside this file, §"Arm SM" (with its 2026-10-25 amendment). The dispatcher launches it after the
# commit holding this script is pushed, when the container is free (no agents, no other backtest).
#
# Subcommands (host side; POSIX sh):
#   sh chain-sm.sh launch            reuse the null's run tree (.claude/worktrees/sweep-ps @ 3db869d32), stage the spec
#                                    from the PREREG commit and the 320 monthly lists from LISTS_SRC (md5-checked against
#                                    PREREG's composition.md5, twin-guarded) outside any VCS tree, start `run` detached
#   sh chain-sm.sh stage-lists       launch's host-only list staging alone (needs PREREG; no container): a dry run
#   sh chain-sm.sh run               (started by launch) lock -> guards -> build (no-op on the built tree) -> warehouse
#                                    check -> fixtures root -> preflight SM-p0 -> SM-p0 -> SM p1-p5 specs + lists (the
#                                    null's names) -> SM p1-p5 -> review pack -> collect -> summary
#   sh chain-sm.sh validate [SPEC..] short parse/override check of ps-SM-p0 plus a negative control (container work;
#                                    needs the staged lists, i.e. after launch or stage-lists)
#   sh chain-sm.sh collect DEST      copy the per-cell artifacts from the sweep output into DEST (the results/ dir)
#   sh chain-sm.sh summary [DIR]     SM vs S: the README rule, SM liveness, the amendment's displacement read. S rows come
#                                    from NULL_DIR (default: the path-stability results). POSIX sh + awk, host only.
#
# Derived from chain.sh (the SN chain, same dir). Changes:
#   1. ARMS=SM, specs ps-SM-p<k>, tags ps-SM-p<k>-s0; pk sets tiebreak_seed = k exactly as the null's S arm.
#   2. Own stage, work, fixtures and output dirs (/tmp/fsm-run, /tmp/fsm-work, /tmp/fsm-fix,
#      /tmp/sweeps/floor-refresh-sm). Run tree unchanged: the null's (RUN_SHA 3db869d32), so SM and S share one build.
#      At 3db869d32 Universe_schedule.load takes any dated entries (sorted on load, duplicates rejected) and the entry
#      dated d_i governs every screening date in [d_i, d_(i+1)) (universe_schedule.ml _entry_at: the last entry dated
#      <= d), and scenario_universe.ml ignores universe_path under a non-empty schedule. So 320 month-end entries put
#      the latest month-end list in force on each Friday, which is what the README's arm means.
#   3. Warehouse: $WH = /tmp/snap_top3000_pit_v12monthly (dev/scripts/build_monthly_universe_warehouse.sh), marker
#      .sm-build.stamp, EXPECT_WH 10125 = union of the 320 lists (10111) - MEL + GSPC.INDX + the 14 runner extras.
#   4. Lists: the run tree has no pit-v12-monthly lists (gitignored). launch copies them from LISTS_SRC (default: the
#      sweep-sm tree that built them) to $STAGE/lists-orig and aborts unless each file's md5 equals PREREG's
#      pit-v12-monthly/composition.md5 and the 320 names equal the spec's. Twin guard: every row of PREREG's
#      twin-drops-monthly.txt holds (dropped absent, survivor present), and no list holds both legs of a pit-v12
#      twin-drops.txt pair (the template's CMD/CMN check, generalised).
#   5. Every cell, p0 included, and the preflight run on FIXPS: phase_fixps symlinks the run tree's fixtures (except a
#      pit-v12-monthly entry, never written through) and copies the lists to $FIXPS/pit-v12-monthly/composition/,
#      md5-checked host vs container.
#   6. Perturbation: the null's five names cut from every monthly list holding them (same cut_symbol + checks); pk specs
#      rewrite all 321 list paths (320 schedule entries + universe_path, the first monthly list) to ps-lists/p<k>/.
#   7. summary: SM vs S per the README rule; SM liveness = >= 1 SM p0 trades.csv row in a symbol outside the yearly
#      pit-v12 list in force on its entry_date; plus the amendment's displacement read (entrants, displaced at the
#      decision and by the join, realised ln(1+R) of each set), with the parts left to the analyst named.
#
# Cell guard: CELL_TIMEOUT=14400 s, kept. The slowest cell on this build was 4,794 s (ps-A-p1, path-stability
# chain.log 10-24; S 2,360-2,863 s, SN 2,361-3,777 s in /tmp/fn-run/chain.log 10-25), so 14400 is 3.0 x the slowest
# and 3.8 x the slowest SN cell, ample for a warehouse 9.6 % larger (10,125 vs 9,236 symbols). Expect ~5-6 h.
set -u

CMD=${1:-}; [ $# -gt 0 ] && shift
C=${CONTAINER:-trading-1-dev}
REPO=${REPO:-/Users/difan/Projects/trading-1}
EXP=dev/experiments/floor-nearest-2026-10-25
STAGE=${STAGE:-/tmp/fsm-run}                           # host, outside every VCS tree (sweep-hygiene.md: inputs too)
H=$REPO/.sweep-output                                  # host side of the container's /tmp/sweeps bind-mount
ART=/tmp/sweeps/floor-refresh-sm                       # container side; host $H/floor-refresh-sm
HART=$H/floor-refresh-sm
WTREL=${WTREL:-.claude/worktrees/sweep-ps}             # the pinned run tree, repo-relative (container-visible)
WT=/workspaces/trading-1/$WTREL; ROOT=$WT/trading; FIX=$ROOT/test_data/backtest_scenarios
FIXPS=/tmp/fsm-fix                                     # container: fixtures root for every cell (symlinks + lists)
WH=${WH:-/tmp/snap_top3000_pit_v12monthly}             # built by dev/scripts/build_monthly_universe_warehouse.sh
WH_MARK=.sm-build.stamp                                # its build stamp (written when the warehouse phase starts; completeness = the manifest check)
EXPECT_WH=${EXPECT_WH:-10125}                          # manifest symbol count: union - MEL + GSPC.INDX + 14 extras
EXPECT_ABSENT=${EXPECT_ABSENT:-1}                      # cache line n_symbols_absent (MEL, no CSV)
EXPECT_UNION=${EXPECT_UNION:-10111}                    # distinct symbols across the 320 monthly lists
N_LISTS=320                                            # month ends 1999-05-31 .. 2025-12-31
N_PATHS=321                                            # list paths in the spec: 320 schedule entries + universe_path
MREL=trading/test_data/backtest_scenarios/pit-v12-monthly   # committed md5 + twin-drops files (read at PREREG)
SCHED=pit-v12-monthly/composition                      # the spec's list prefix, relative to the fixtures root
LISTS_SRC=${LISTS_SRC:-$REPO/.claude/worktrees/sweep-sm/$MREL/composition}   # the built lists (gitignored)
CELL_TIMEOUT=${CELL_TIMEOUT:-14400}                    # 3.0 x the slowest cell on this build (4,794 s), see header
MMAP_HANDLES=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}       # #2839/#2882: >= manifest size, so the LRU never cycles
ARMS="SM"
KS="1 2 3 4 5"                                         # perturbations; p0 is unperturbed
PREFLIGHT_START=2024-10-01; PREFLIGHT_END=2024-12-31   # last quarter of the window
# Commits the run tree must contain (as the template): #3283 (#3266 fix), #3181, #3222, #3193, #3195, #3339 (A-D
# fixture fix), #3391 (pit-v12 CMN dedupe).
FIX3391=3d437597c
NEED="3f51d4afd e9d6bb7a0 904746e8c 974e91885 852e61c2e 1f2432fa2 $FIX3391"
SPECS0="ps-SM-p0"
# The null (path-stability S arm): its build, its results dir (host) and its sweep output (container, for A-p0's
# validator report, the SM-p0 V6 partner).
NULL_SHA=3db869d32
NULL_DIR=${NULL_DIR:-/tmp/ps-run/results}
NULL_NAMES=$NULL_DIR/perturb-names.txt
NULL_ART=/tmp/sweeps/path-stability
# summary inputs: the yearly pit-v12 lists (SM liveness, entrants) and the S top-N decisions (the SN read's reduction
# of the S trade audits, committed with the SN results).
YEARLY_DIR=${YEARLY_DIR:-$REPO/$WTREL/trading/test_data/backtest_scenarios/pit-v12/composition}
S_DEC_DIR=${S_DEC_DIR:-$REPO/$EXP/results/read/decisions}
LOG_HOST=$STAGE/chain.log
log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG_HOST"; }
die() { log "ABORT: $*"; exit 1; }
dx() { docker exec "$C" "$@"; }
run() { docker exec "$C" bash -c "cd $ROOT && eval \$(opam env) && $1"; }
host_free_ok() { free_gb=$(df -g / | awk 'NR==2{print $4}'); log "host free ${free_gb}G"; [ "$free_gb" -ge 20 ]; }
syms_of() { grep -o '(symbol [^)]*)' "$1" | sed 's/(symbol //; s/)$//'; }   # one symbol per entry, file order
seeded() { case $1 in S | SR | SC | SN | SM) return 0 ;; *) return 1 ;; esac; }
md5_file() { md5 -q "$1" 2>/dev/null || md5sum "$1" | cut -c1-32; }
nl_of() { wc -l < "$1" | tr -d ' '; }

# ------------------------------------------------------------------------------------------------------ list staging
# Host only, no container: the monthly lists from LISTS_SRC into $STAGE/lists-orig, each md5 equal to PREREG's
# composition.md5 ("md5  filename"), the names equal to the spec's schedule, the twin guards, and the derived
# warehouse set. Needs $STAGE/specs/ps-SM-p0.sexp (launch writes it; stage-lists writes it too).
stage_lists() {
  PREREG=${PREREG:?set PREREG to the commit holding ps-SM-p0.sexp and the pit-v12-monthly md5 files}
  cd "$REPO" || exit 1
  mkdir -p "$STAGE/specs"
  [ -s "$STAGE/specs/ps-SM-p0.sexp" ] || git show "$PREREG:$EXP/specs/ps-SM-p0.sexp" > "$STAGE/specs/ps-SM-p0.sexp" || die "spec not at $PREREG"
  git show "$PREREG:$MREL/composition.md5" > "$STAGE/composition.md5" || die "composition.md5 not at $PREREG"
  git show "$PREREG:$MREL/twin-drops-monthly.txt" > "$STAGE/twin-drops-monthly.txt" || die "twin-drops-monthly.txt not at $PREREG"
  [ "$(nl_of "$STAGE/composition.md5")" = "$N_LISTS" ] || die "composition.md5 at $PREREG has $(nl_of "$STAGE/composition.md5") rows, expected $N_LISTS"
  grep -o "\"$SCHED/top-3000-[0-9-]*\\.sexp\"" "$STAGE/specs/ps-SM-p0.sexp" | tr -d '"' | LC_ALL=C sort -u > "$STAGE/sched-lists.txt"
  [ "$(nl_of "$STAGE/sched-lists.txt")" = "$N_LISTS" ] || die "expected $N_LISTS scheduled lists in ps-SM-p0.sexp, found $(nl_of "$STAGE/sched-lists.txt")"
  [ "$(grep -c "\"$SCHED/top-3000-" "$STAGE/specs/ps-SM-p0.sexp")" = "$N_PATHS" ] || die "expected $N_PATHS list paths in ps-SM-p0.sexp"
  ! grep -q '"pit-v12/' "$STAGE/specs/ps-SM-p0.sexp" || die "ps-SM-p0.sexp still names a yearly pit-v12 list"
  sed 's#.*/##' "$STAGE/sched-lists.txt" > "$STAGE/sched-names.txt"
  awk '{ print $2 }' "$STAGE/composition.md5" | LC_ALL=C sort > "$STAGE/md5-names.txt"
  cmp -s "$STAGE/sched-names.txt" "$STAGE/md5-names.txt" || die "the spec's $N_LISTS lists differ from composition.md5's names"
  [ -d "$LISTS_SRC" ] || die "LISTS_SRC $LISTS_SRC missing (build_monthly_universe_warehouse.sh install writes it)"
  rm -rf "$STAGE/lists-orig"; mkdir -p "$STAGE/lists-orig"
  while read -r want b; do
    cp "$LISTS_SRC/$b" "$STAGE/lists-orig/$b" || die "copy $b from $LISTS_SRC"
    got=$(md5_file "$STAGE/lists-orig/$b"); [ "$got" = "$want" ] || die "$b md5 $got, expected $want (composition.md5 at $PREREG)"
  done < "$STAGE/composition.md5"
  echo "lists md5 $(cat "$STAGE"/lists-orig/top-3000-*.sexp | md5 -q)" > "$STAGE/lists.md5"
  echo "lists OK: $N_LISTS files from $LISTS_SRC match composition.md5 at $PREREG; $(cat "$STAGE/lists.md5")" | tee -a "$STAGE/launch.log"
  # Twin guard 1: every twin-drops-monthly.txt row (LIST DROPPED SURVIVOR <evidence>) holds in the staged lists.
  nr=0
  while read -r tl td ts _; do
    case "$tl" in '' | '#'*) continue ;; esac
    tf=$STAGE/lists-orig/$tl.sexp; [ -f "$tf" ] || die "twin-drops-monthly list $tl missing"
    ! grep -q -F "(symbol $td)" "$tf" || die "$tl holds $td (twin of $ts, dropped in twin-drops-monthly.txt)"
    grep -q -F "(symbol $ts)" "$tf" || die "$tl lacks survivor $ts"
    nr=$((nr + 1))
  done < "$STAGE/twin-drops-monthly.txt"
  # Twin guard 2: no monthly list holds both legs of a confirmed pit-v12 pair (the template's CMD/CMN check, every row).
  TD=$WTREL/trading/test_data/backtest_scenarios/pit-v12/twin-drops.txt
  [ -f "$TD" ] || die "$TD missing: the run tree lacks #3391"
  grep -v '^#' "$TD" | awk 'NF >= 3 { print $2, $3 }' | LC_ALL=C sort -u > "$STAGE/yearly-pairs.txt"
  for f in "$STAGE"/lists-orig/top-3000-*.sexp; do
    syms_of "$f" | awk -v F="$(basename "$f")" 'NR == FNR { s[$1] = 1; next } ($1 in s) && ($2 in s) { print F " holds both " $1 " and " $2; bad = 1 } END { exit bad }' - "$STAGE/yearly-pairs.txt" \
      || die "a monthly list holds both legs of a pit-v12 twin pair (above)"
  done
  echo "twin guard OK: $nr twin-drops-monthly rows hold; no list holds both legs of the $(nl_of "$STAGE/yearly-pairs.txt") pit-v12 pairs" | tee -a "$STAGE/launch.log"
  # Warehouse symbol set the cells need: union of the monthly lists, minus MEL (no CSV), plus the GSPC.INDX benchmark,
  # plus the 14 runner extras parsed from the run tree's macro_inputs.ml.
  for f in "$STAGE"/lists-orig/top-3000-*.sexp; do syms_of "$f"; done | LC_ALL=C sort -u > "$STAGE/lists-union.txt"
  [ "$(nl_of "$STAGE/lists-union.txt")" = "$EXPECT_UNION" ] \
    || die "lists hold $(nl_of "$STAGE/lists-union.txt") distinct symbols, expected $EXPECT_UNION"
  grep -q -x -F MEL "$STAGE/lists-union.txt" || die "MEL is not in the union (EXPECT_ABSENT=1 assumes it is)"
  MI=$WTREL/trading/trading/weinstein/strategy/lib/macro_inputs.ml
  { sed -n '/^let spdr_sector_etfs/,/^  \]$/p' "$MI"; sed -n '/^let default_global_indices/,/\]$/p' "$MI"; } \
    | grep -o '("[A-Z0-9.]*",' | sed 's/("//; s/",$//' | LC_ALL=C sort -u > "$STAGE/runner-extras.txt"
  [ "$(nl_of "$STAGE/runner-extras.txt")" = 14 ] \
    || die "parsed $(nl_of "$STAGE/runner-extras.txt") runner extras from $MI, expected 14 (11 SPDR + 3 indices)"
  { grep -v -x -F MEL "$STAGE/lists-union.txt"; echo GSPC.INDX; cat "$STAGE/runner-extras.txt"; } | LC_ALL=C sort -u > "$STAGE/wh-syms.txt"
  [ "$(nl_of "$STAGE/wh-syms.txt")" = "$EXPECT_WH" ] \
    || die "derived warehouse set holds $(nl_of "$STAGE/wh-syms.txt") symbols, expected $EXPECT_WH"
  echo "union $EXPECT_UNION symbols; derived warehouse set $EXPECT_WH" | tee -a "$STAGE/launch.log"
}

# ---------------------------------------------------------------------------------------------------------- launch
cmd_launch() {
  mkdir -p "$STAGE"; cd "$REPO" || exit 1
  git fetch -q origin main
  SHA=$(git rev-parse --short=9 "${RUN_SHA:-$NULL_SHA}") || die "cannot resolve ${RUN_SHA:-$NULL_SHA}"
  [ "$SHA" = "$NULL_SHA" ] || die "run tree $SHA is not the null's build $NULL_SHA (SM and S must share one build)"
  for c in $NEED; do git merge-base --is-ancestor "$c" "$SHA" || die "run tree $SHA lacks $c"; done
  # #3406 (Step 1): the Seeded tiebreak and its seed field must be in the run tree, else S/SM cannot parse.
  git show "$SHA:trading/analysis/weinstein/screener/lib/screener_ranking.mli" | grep -q '^  | Seeded$' \
    || die "run tree $SHA lacks #3406: no '| Seeded' in screener_ranking.mli"
  git show "$SHA:trading/analysis/weinstein/screener/lib/screener.mli" | grep -q 'tiebreak_seed : int' \
    || die "run tree $SHA lacks #3406: no 'tiebreak_seed : int' in screener.mli"
  # Dated-entry semantics (header change 2): the last entry dated <= d governs d.
  git show "$SHA:trading/trading/backtest/scenarios/universe_schedule.ml" | grep -q 'if Date.( <= ) e.date d then Some e else acc' \
    || die "run tree $SHA: universe_schedule.ml _entry_at is not the last-entry-dated-<=-d rule this arm assumes"
  if [ -d "$WTREL" ]; then
    [ "$(git -C "$WTREL" rev-parse --short=9 HEAD)" = "$SHA" ] || die "$WTREL is not at $SHA; remove it first"
  else git worktree add --detach "$WTREL" "$SHA" || die "worktree add"; fi
  # Inputs come from a commit, never a working copy: the PREREG commit (the run tree predates the SM files).
  PREREG=${PREREG:?set PREREG to the commit holding ps-SM-p0.sexp and chain-sm.sh}
  rm -rf "$STAGE/specs"; mkdir -p "$STAGE/specs"
  for s in $SPECS0; do git show "$PREREG:$EXP/specs/$s.sexp" > "$STAGE/specs/$s.sexp" || die "spec $s not at $PREREG"; done
  git show "$PREREG:$EXP/chain-sm.sh" > "$STAGE/chain-sm.sh" || die "chain-sm.sh not at $PREREG"
  stage_lists
  [ -s "$NULL_NAMES" ] || die "null perturbation names missing ($NULL_NAMES)"
  cp "$NULL_NAMES" "$STAGE/perturb-names.txt"
  dx test -s "$NULL_ART/ps-A-p0-s0-validator.sexp.sexp" || die "null A-p0 validator report missing in $C ($NULL_ART)"
  # Dividends + splits (EODHD, #3158) into the run tree's test_data (dividend_crediting, split_dividend_guard read them
  # from TRADING_DATA_DIR), as the template.
  rsync -a -m --include='*/' --include='dividends.csv' --include='splits.csv' --exclude='*' data/ "$WTREL/trading/test_data/"
  echo "staged $(find "$WTREL/trading/test_data" -name dividends.csv | wc -l | tr -d ' ') dividends.csv" | tee -a "$STAGE/launch.log"
  nohup env REPO="$REPO" STAGE="$STAGE" WTREL="$WTREL" EXPECT_HEAD="$(git -C "$WTREL" rev-parse --short HEAD)" PREREG="$PREREG" \
    sh "$STAGE/chain-sm.sh" run > "$STAGE/run.out" 2>&1 &
  echo "launched run pid $! (tree $SHA, prereg $PREREG); log $LOG_HOST"
}

# ---------------------------------------------------------------------------------------------------- warehouse check
phase_wh_check() {
  dx test -f "$WH/$WH_MARK" || die "$WH lacks its $WH_MARK stamp: build it with dev/scripts/build_monthly_universe_warehouse.sh (warehouse + verify)"
  dx sh -c "tr '\n' ' ' < $WH/manifest.sexp | grep -o '(symbol [^)]*)'" | sed 's/(symbol //; s/)$//' | LC_ALL=C sort > "$STAGE/wh-manifest.txt"
  n=$(nl_of "$STAGE/wh-manifest.txt")
  [ "$n" = "$EXPECT_WH" ] || die "$WH manifest holds $n symbols, expected $EXPECT_WH"
  cmp -s "$STAGE/wh-manifest.txt" "$STAGE/wh-syms.txt" || die "$WH manifest set differs from the set derived from the staged lists ($STAGE/wh-manifest.txt vs $STAGE/wh-syms.txt)"
  log "WH $WH: $n symbols, equal to the set derived from the $N_LISTS staged lists"
}
# Fixtures root for every cell: each entry of the run tree's fixtures root symlinked (a pit-v12-monthly entry, if a
# later run tree has one, is skipped so nothing is written through a link), the staged monthly lists copied to
# pit-v12-monthly/composition/, and ps-lists/p<k>/ (filled by phase_perturb). Rebuilt on every run (cheap).
phase_fixps() {
  [ -d "$STAGE/lists-orig" ] || die "$STAGE/lists-orig missing (launch / stage-lists stages it)"
  dx sh -c "rm -rf $FIXPS && mkdir -p $FIXPS/ps-lists $FIXPS/$SCHED && for e in $FIX/*; do b=\$(basename \$e); [ \"\$b\" = pit-v12-monthly ] || ln -s \$e $FIXPS/\$b; done" || die "fixtures root $FIXPS"
  docker cp "$STAGE/lists-orig/." "$C:$FIXPS/$SCHED/" || die "copy monthly lists to $FIXPS/$SCHED"
  hm=$(cat "$STAGE"/lists-orig/top-3000-*.sexp | md5 -q)
  cm=$(dx sh -c "cd $FIXPS/$SCHED && cat top-3000-*.sexp | md5sum | cut -c1-32")
  [ "$hm" = "$cm" ] || die "monthly lists differ host ($hm) vs container ($cm)"
  [ "$(dx sh -c "ls $FIXPS/$SCHED | wc -l" | tr -d ' ')" = "$N_LISTS" ] || die "$FIXPS/$SCHED does not hold $N_LISTS lists"
  dx test -f "$FIXPS/pit-v12/composition/top-3000-2019.sexp" || die "$FIXPS does not expose pit-v12"
  log "FIXPS $FIXPS: $(dx sh -c "ls $FIXPS | wc -l" | tr -d ' ') entries; $N_LISTS monthly lists md5 $hm (host = container)"
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
  grep -v '^#' "$STAGE/perturb-names.txt" | while read -r pk s v n nl; do log "PERTURB $pk: delete $s (A-p0 total-return P&L $v over $n trades; in $nl of 27 yearly lists)"; done
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
    [ "$cut" -ge 1 ] || die "p$k: $s is in no monthly list"
    dx mkdir -p "$FIXPS/ps-lists/p$k" || die "mkdir ps-lists/p$k"
    docker cp "$P/." "$C:$FIXPS/ps-lists/p$k/" || die "copy lists p$k"
    hm=$(cd "$P" && cat top-3000-*.sexp | md5 -q); cm=$(dx sh -c "cd $FIXPS/ps-lists/p$k && cat top-3000-*.sexp | md5sum | cut -c1-32")
    [ "$hm" = "$cm" ] || die "p$k lists differ host ($hm) vs container ($cm)"
    for arm in $ARMS; do
      src=$STAGE/specs/ps-$arm-p0.sexp; dst=$STAGE/specs/ps-$arm-p$k.sexp
      sed -e "s/(name \"ps-$arm-p0\")/(name \"ps-$arm-p$k\")/" \
          -e "s/(description \"floor-nearest $arm p0: /(description \"floor-nearest $arm p$k (deletes $s): /" \
          -e "s#\"$SCHED/top-3000-#\"ps-lists/p$k/top-3000-#g" "$src" > "$dst"
      seeded "$arm" && { sed "s/(tiebreak_seed 0)/(tiebreak_seed $k)/" "$dst" > "$dst.tmp" && mv "$dst.tmp" "$dst"; }
      grep -q "^((name \"ps-$arm-p$k\")$" "$dst" || die "spec ps-$arm-p$k: name not set"
      [ "$(grep -c "\"ps-lists/p$k/top-3000-" "$dst")" = "$N_PATHS" ] || die "spec ps-$arm-p$k: expected $N_PATHS universe paths on ps-lists/p$k"
      ! grep -q "\"$SCHED/" "$dst" || die "spec ps-$arm-p$k: an unperturbed list path remains"
      [ "$(grep -c "(tiebreak_seed $k)" "$dst")" = 1 ] || die "spec ps-$arm-p$k: tiebreak_seed $k not set"
    done
    log "PERTURB p$k: $s cut from $cut of $N_LISTS lists; lists md5 $hm; spec ps-SM-p$k generated"
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
    sh "$WTH/dev/scripts/review_pack.sh" --out "$out" --title "floor-refresh $arm p0 (2019-2024, pit-v12-monthly)" \
      --snapshot-dir "$WH" --data-dir "$REPO/data" "p0=$pre" > "$STAGE/pack-$arm.log" 2>&1 || { log "PACK $arm build failed (see $STAGE/pack-$arm.log)"; continue; }
    sh "$WTH/dev/scripts/review_pack_render.sh" --site "$out/site" > "$STAGE/render-$arm.log" 2>&1 || log "RENDER $arm failed (see $STAGE/render-$arm.log)"
    rm -rf "$H/review-ps-$arm-p0"; mkdir -p "$H/review-ps-$arm-p0"
    cp -R "$out/site" "$out/render" "$H/review-ps-$arm-p0/" 2>/dev/null
    log "PACK $arm -> $H/review-ps-$arm-p0 (site/ + render/top.png, part-N.png)"
  done
}

# -------------------------------------------------------------------------------------------------------------- run
preflight_one() { # $1 spec name: last quarter of the window on the warehouse; a spec/override error costs minutes
  name=$1; pd=$STAGE_C/preflight-$name
  dx sh -c "mkdir -p $pd && rm -rf $pd/*"
  sed "s/(period ((start_date [0-9-]*) (end_date [0-9-]*)))/(period ((start_date $PREFLIGHT_START) (end_date $PREFLIGHT_END)))/" "$STAGE/specs/$name.sexp" > "$STAGE/preflight-$name.sexp"
  grep -q "(start_date $PREFLIGHT_START)" "$STAGE/preflight-$name.sexp" || die "preflight $name: window not replaced"
  docker cp "$STAGE/preflight-$name.sexp" "$C:$pd/$name.sexp" || die "preflight copy $name"
  log "PREFLIGHT $name"; t0=$(date +%s)
  run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 3600 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIXPS --snapshot-dir $WH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
  pout=$(dx sh -c "grep 'Output root' $pd.log | tail -1 | sed 's/.*: //'")
  dx test -s "${pout}/${name}/actual.sexp" || die "preflight $name wrote no actual.sexp (see $pd.log)"
  pabs=$(dx sh -c "grep -h 'snapshot cache' $pd.log | tail -1" | sed -n 's/.*n_symbols_absent=\([0-9]*\).*/\1/p')
  # a short window may touch fewer symbols than the cell, so only an excess fails here; the cell is held to exactly 1
  [ -n "$pabs" ] && [ "$pabs" -le "$EXPECT_ABSENT" ] || die "preflight $name: n_symbols_absent=${pabs:-<no cache line>}, expected <= $EXPECT_ABSENT (see $pd.log)"
  log "PREFLIGHT_OK $name ($(( $(date +%s) - t0 ))s)"
}
cmd_run() {
  mkdir -p "$STAGE"; LOCK=$STAGE/chain.lock; STAGE_C=/tmp/fsm-work
  mkdir "$LOCK" 2>/dev/null || { echo "ABORT: lock $LOCK held (another floor-refresh-sm instance)"; exit 1; }
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT
  EXPECT_HEAD=${EXPECT_HEAD:?set by launch}
  head=$(git -C "$REPO/$WTREL" rev-parse --short HEAD)
  log "floor-refresh-sm run tree $WTREL HEAD=$head (expect $EXPECT_HEAD) prereg=${PREREG:-?} $(cat "$STAGE/lists.md5" 2>/dev/null)"
  log "cell guard CELL_TIMEOUT=${CELL_TIMEOUT}s (3.0 x the slowest cell on this build, ps-A-p1 4,794 s); SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES"
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
  # SM-p0 (V6 vs the null's A-p0), then the lists and SM p1-p5 specs from the null's names, then SM p1-p5 (V6 vs SM-p0)
  run_cell ps-SM-p0 "A0=$NULL_ART/ps-A-p0-s0-validator.sexp.sexp" "$FIXPS"
  phase_perturb
  for k in $KS; do run_cell "ps-SM-p$k" "SM0=$(pv_of SM)" "$FIXPS"; done
  log "CELLS DONE: $(grep -c ' RESULT ps-' "$LOG_HOST") RESULT, $(grep -c ' EXCLUDED ps-' "$LOG_HOST") EXCLUDED, $(grep -c -e ' GUARD-KILLED/FAILED ps-' -e ' VOID ps-' "$LOG_HOST") failed/void (of 6)"
  phase_packs
  cmd_collect "$STAGE/results"
  cmd_summary "$STAGE/results" > "$STAGE/results/summary.txt" 2>&1 || log "SUMMARY failed (see $STAGE/results/summary.txt)"
  log "FLOOR-REFRESH SM DONE. Next: perf_long_cells.sh update $LOG_HOST; results-analyst read per README; results PR."
}

# --------------------------------------------------------------------------------------------------------- validate
# Parse + override check only, never a backtest. scenario_runner loads the universe schedule and applies
# config_overrides BEFORE it prints "Running backtest" (backtest/lib/runner.ml). Each spec runs under `timeout 300` on
# the warehouse, in an already built tree, and is VALID iff its log reaches that line. A negative control (ps-SM-p0 plus
# a nonexistent override) must fail before that line, which shows the check can fail.
_validate_one() { # $1 label, $2 spec file (host)
  pd=$STAGE_C/$1; dx sh -c "mkdir -p $pd && rm -rf $pd/*"; docker cp "$2" "$C:$pd/$1.sexp"
  run "TRADING_DATA_DIR=$ROOT/test_data SNAPSHOT_CACHE_MB=1024 SNAPSHOT_MAX_MMAP_HANDLES=$MMAP_HANDLES timeout 300 ./_build/default/trading/backtest/scenarios/scenario_runner.exe --dir $pd --fixtures-root $FIXPS --snapshot-dir $VWH --no-emit-all-eligible --parallel 1 > $pd.log 2>&1"
  dx grep -q 'Running backtest' $pd.log
}
cmd_validate() {
  VWH=${VALIDATE_WH:-$WH}; STAGE_C=/tmp/fsm-validate; dx mkdir -p $STAGE_C
  dx test -d "$VWH" || { echo "validate needs a warehouse in $C at $VWH (set VALIDATE_WH) and a built tree at WTREL: container work"; return 2; }
  phase_fixps
  here=$(cd "$(dirname "$0")" && pwd); rc=0; tmp=${TMPDIR:-/tmp}/fsm-validate.$$
  for name in ${*:-$SPECS0 control}; do
    if [ "$name" = control ]; then
      awk '{ print } $0 == "   ((dividend_crediting true))" { print "   ((ps_no_such_flag true))" }' "$here/specs/ps-SM-p0.sexp" \
        | sed 's/(name "ps-SM-p0")/(name "control")/' > "$tmp"
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
# Top-N decisions: date,symbol,outcome from cascade_summaries only, never alternatives_considered (the SN read's
# reduction, results/read/fn-analysis.sh step 1, so SM decisions join the committed S ones row for row).
decision_rows() { # $1 trade_audit.sexp
  tr -s '\n\t ' '   ' < "$1" | awk '{
    i = index($0, "(cascade_summaries"); s = substr($0, i); n = split(s, wk, /\(\(date /)
    for (w = 2; w <= n; w++) { d = substr(wk[w], 1, 10); r = wk[w]
      while (match(r, /\(\(symbol [^)]*\) \(side [A-Za-z]+\) \(outcome (Placed|\(Skipped [A-Za-z_]+\))\)/)) {
        rec = substr(r, RSTART, RLENGTH); r = substr(r, RSTART + RLENGTH); split(rec, a, /[() ]+/)
        print d "," a[3] "," ((rec ~ /Placed/) ? "Placed" : a[8]) } } }'
}
cmd_collect() { # $1 destination results dir (host)
  dest=${1:?usage: chain-sm.sh collect DEST}; mkdir -p "$dest"; src=$HART
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
      decision_rows "$f" > "$dest/$b-decisions.csv"
      awk -F, '{ n[$3]++ } END { for (o in n) print o "," n[o] }' "$dest/$b-decisions.csv" | LC_ALL=C sort > "$dest/$b-audit_outcomes.csv"
      continue ;; esac
    cp "$f" "$dest/"
  done
  for f in "$src"/ps-*-s0.log "$src"/ps-*-s0.rss "$src"/ps-*-s0.v6diff-*.log; do [ -f "$f" ] && cp "$f" "$dest/"; done
  [ -f "$LOG_HOST" ] && cp "$LOG_HOST" "$dest/chain.log"
  for f in perturb-names.txt lists.md5 launch.log; do [ -f "$STAGE/$f" ] && cp "$STAGE/$f" "$dest/"; done
  # the 5 generated specs (the p0 spec is committed under specs/)
  if ls "$STAGE"/specs/ps-*-p[1-9].sexp >/dev/null 2>&1; then mkdir -p "$dest/specs-generated"; cp "$STAGE"/specs/ps-*-p[1-9].sexp "$dest/specs-generated/"; fi
  echo "collected into $dest: $(ls "$dest" | wc -l | tr -d ' ') files (trade_audit.sexp reduced to audit_entries.csv + cash_rejections.csv + decisions.csv + audit_outcomes.csv)"
}

# ---------------------------------------------------------------------------------------------------------- summary
# README §"Arm SM" (rule = SN's), mechanically. SM rows from DIR (default: this chain's sweep output), S rows from
# NULL_DIR (the path-stability results). A cell counts when its chain log holds its RESULT line, no EXCLUDED line, and
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
_yearly_pairs() { # $1 dir of yearly top-3000-YYYY.sexp -> "YYYY SYMBOL" per member
  for f in "$1"/top-3000-[0-9][0-9][0-9][0-9].sexp; do
    [ -f "$f" ] || continue; y=$(basename "$f" .sexp); y=${y#top-3000-}
    syms_of "$f" | sed "s/^/$y /"
  done
}
# The yearly list in force on date D (YYYY-MM-DD): top-3000-Y, Y = D's year if D >= Y-05-31, else Y-1. awk helper.
YR_AWK='function yr(d,   y) { y = substr(d, 1, 4) + 0; if (substr(d, 6, 5) < "05-31") y--; return y }'
# Realised ln(1+R) per closed trade: R = (pnl_dollars + dividends_received) / (entry_price x quantity).
LNR_AWK='function lnr(   c) { c = $6 * $8; return (c > 0) ? log(1 + ($9 + $25) / c) : "" }'
_stats() { # stdin: one value per line -> "n mean median p10 p90 >+100%" (linear-interpolated quantiles)
  LC_ALL=C sort -g | awk 'function q(p,   h, i) { h = 1 + p * (n - 1); i = int(h); return (i >= n) ? v[n] : v[i] + (h - i) * (v[i + 1] - v[i]) }
    $1 != "" { n++; v[n] = $1; s += $1; if ($1 > log(2)) t++ }
    END { if (n == 0) { printf "n=0"; exit }
      printf "n=%d mean=%+.4f median=%+.4f p10=%+.4f p90=%+.4f share>+100%%=%.1f%%", n, s / n, q(0.5), q(0.1), q(0.9), 100 * t / n }'
}
# $1 trades.csv, $2 audit_entries.csv (may be absent), $3 yearly pairs. stdout, one line: "N of T closed trades outside
# the yearly list in force by entry_date (D also by decision date)[: specimens]" -- the README's test is by entry_date
# (trades.csv entry_date = the fill); D re-tests those N at the decision (audit entry_date via position_id, "n/a"
# without the audit). Exit status 0 iff N >= 1.
_outside() {
  ae=/dev/null; [ -s "$2" ] && ae=$2
  awk -F, "$YR_AWK"' FILENAME == ARGV[1] { split($0, a, " "); m[a[1] " " a[2]] = 1; have[a[1]] = 1; next }
    FILENAME == ARGV[2] { if (FNR > 1) dd[$1] = $3; hasae = 1; next }
    FNR == 1 { next }
    { y = yr($3); if (!(y in have)) { miss++; next } t++
      if (!((y " " $1) in m)) { e++; if (e <= 12) ex = ex " " $1 "@" $3 (($20 in dd) ? "(decided " dd[$20] ")" : "")
        if (($20 in dd) && !((yr(dd[$20]) " " $1) in m)) d++ } }
    END { printf "%d of %d closed trades outside the yearly list in force by entry_date (%s also by decision date)%s%s%s\n",
        e, t, (hasae ? d + 0 : "n/a"), (e ? ":" ex : ""), (e > 12 ? " ..." : ""), (miss ? "; WARNING: " miss " trades in a year with no yearly list" : "")
      exit (e >= 1) ? 0 : 1 }' "$3" "$ae" "$1"
}
_liveness() { # $1 SM results dir, $2 yearly pairs file, $3 SM p0 status
  ldir=$1; lyp=$2; tr=$1/ps-SM-p0-s0-trades.csv
  echo "liveness (README §Arm SM: >= 1 SM p0 trade in a symbol outside the yearly pit-v12 list in force on its entry date):"
  if [ "$3" != included ]; then echo "  n/a: SM p0 is $3 -> nothing is read (README)"; return 2; fi
  [ -s "$tr" ] || { echo "  n/a: $tr missing"; return 2; }
  [ -s "$lyp" ] || { echo "  n/a: no yearly lists read from $YEARLY_DIR"; return 2; }
  # Descriptive base rate: the same test on the null's S cells, which screen only yearly lists. A ticket decided before
  # a May 31 roll and filled after it, in a name the new yearly list drops, passes the entry_date test.
  for k in 0 $KS; do
    echo "  null S p$k (base rate, descriptive): $(_outside "$NULL_DIR/ps-S-p$k-s0-trades.csv" "$NULL_DIR/ps-S-p$k-s0-audit_entries.csv" "$lyp")"
  done
  if out=$(_outside "$tr" "$ldir/ps-SM-p0-s0-audit_entries.csv" "$lyp"); then
    echo "  SM p0: $out"; echo "  -> LIVE"; return 0
  fi
  echo "  SM p0: $out"; echo "  -> NOT LIVE: no return read (README)"; return 1
}
cmd_summary() {
  dir=${1:-$HART}; lg=$dir/chain.log; [ -f "$lg" ] || lg=$LOG_HOST
  nlg=$NULL_DIR/chain.log
  [ -f "$lg" ] || { echo "summary: no chain log in $dir or at $LOG_HOST"; return 2; }
  [ -f "$nlg" ] || { echo "summary: no null chain log at $nlg (set NULL_DIR)"; return 2; }
  tmp=${TMPDIR:-/tmp}/fsm-summary.$$; mkdir -p "$tmp"; rows=$tmp/rows
  { _rows S "$NULL_DIR" "$nlg" && _rows SM "$dir" "$lg"; } > "$rows" || { rm -rf "$tmp"; return 1; }
  _yearly_pairs "$YEARLY_DIR" > "$tmp/yearly"
  echo "floor-refresh SM summary: SM from $dir, S (null) from $NULL_DIR, yearly lists from $YEARLY_DIR"
  echo
  st0=$(awk '$1 == "SM" && $2 == 0 { print $3 }' "$rows")
  _liveness "$dir" "$tmp/yearly" "$st0"; case $? in 0) live=LIVE ;; 1) live=NOT_LIVE ;; *) live=n/a ;; esac
  echo
  echo "cell                 status     total_return_pct  ln(1+R)    sharpe   max_dd_pct  calmar"
  awk -v LIVE="$live" '
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
      split("S SM", arms, " ")
      for (a = 1; a <= 2; a++) { A = arms[a]; m = n[A] + 0
        delete v1; delete v2; delete v3; delete v4; s = 0; lo = ""; hi = ""
        for (i = 1; i <= m; i++) { v1[i] = x[A, i]; v2[i] = sh[A, i]; v3[i] = dd[A, i]; v4[i] = ca[A, i]; s += x[A, i]
          if (lo == "" || x[A, i] < lo) lo = x[A, i]; if (hi == "" || x[A, i] > hi) hi = x[A, i] }
        sd = "nan"; if (m >= 2) { mu = s / m; ss = 0; for (i = 1; i <= m; i++) ss += (x[A, i] - mu) ^ 2; sd = sqrt(ss / (m - 1)) }
        SD[A] = sd; MX[A] = med(v1, m); MDD[A] = med(v3, m); MCA[A] = med(v4, m)
        printf "%-4s %-2d %-10s %-10s %-10s %-14s %-13s %s\n", A, m, fmt(sd), (m >= 2 ? fmt(hi - lo) : "n/a"), fmt(MX[A]), fmt(med(v2, m)), fmt(MDD[A]), fmt(MCA[A])
      }
      # descriptive: of the n(SM) x n(S) cross pairs, how many SM cells beat the S cell on ln(1+R)
      w = 0; t = 0; for (i = 1; i <= n["SM"]; i++) for (j = 1; j <= n["S"]; j++) { t++; if (x["SM", i] > x["S", j]) w++ }
      print ""
      if (n["SM"] < 4 || n["S"] < 4 || SD["S"] == "nan") { print "decision: n/a (need >= 4 included cells in each arm)"; exit }
      d = MX["SM"] - MX["S"]; b = SD["S"]
      printf "delta median ln(1+R) = %.4f (bar = spread(S) = %.4f; README: 0.2108); SM beats S in %d of %d cross pairs; spread(SM)/spread(S) = %s\n", d, b, w, t, (SD["SM"] == "nan" ? "n/a" : sprintf("%.4f", SD["SM"] / b))
      ddc = MDD["SM"] - MDD["S"]
      printf "median max DD SM - S = %+.2f pp (DD-cost bar %.2f pp); median Calmar SM %.4f vs S %.4f\n", ddc, 100 * b, MCA["SM"], MCA["S"]
      if (d >= b) { v = "PROMISING: escalate to the 26y + pre-2009 grid (a new pre-registration)"; if (ddc > 100 * b) v = v ", WITH A DD COST (user decision)" }
      else if (d <= -b) v = "NO-BUILD decision for this lever at this window (keep the axis)"
      else v = "INCONCLUSIVE: no escalation on return"
      if (LIVE == "LIVE") print "decision (liveness LIVE; README rule, mechanical): " v
      else print "decision: not read (liveness " LIVE "); the arithmetic would read: " v
    }' "$rows"
  echo
  echo "divergence onset (first date an SM pk NAV differs from SM p0; descriptive):"
  p0=$dir/ps-SM-p0-s0-equity_curve.csv
  for k in $KS; do pk=$dir/ps-SM-p$k-s0-equity_curve.csv; tag=ps-SM-p$k-s0
    if [ ! -s "$p0" ] || [ ! -s "$pk" ]; then echo "  $tag: n/a (curve missing)"; continue; fi
    on=$(awk -F, 'NR == FNR { if (FNR > 1) v[$1] = $2; next }
      FNR > 1 && !done { if (!($1 in v) || v[$1] != $2) { print $1; done = 1 } }
      END { if (!done) print "never" }' "$p0" "$pk")
    echo "  $tag: $on"
  done
  echo
  _displacement "$dir" "$tmp"
  rm -rf "$tmp"
}
# README §Arm SM amendment, displacement read (descriptive; explains the delta, never changes the rule). Per pair SM pk
# vs S pk, then pooled: (a) entrants, (b) displaced at the decision and by the symbol + entry_date join, (c) realised
# ln(1+R) of each set (closed trades only).
_displacement() { # $1 SM results dir, $2 tmp dir holding yearly
  dir=$1; t=$2
  echo "displacement read (README amendment 2026-10-25; descriptive). ln(1+R) of CLOSED trades, R = (pnl_dollars + dividends) / (entry_price x qty)."
  echo "  S decisions from $S_DEC_DIR (the SN read's reduction of the S audits); SM decisions from $dir/*-decisions.csv."
  : > "$t/all-ent"; : > "$t/all-dd"; : > "$t/all-dj"; : > "$t/all-smo"
  for k in 0 $KS; do
    SMT=$dir/ps-SM-p$k-s0-trades.csv; ST=$NULL_DIR/ps-S-p$k-s0-trades.csv
    SMD=$dir/ps-SM-p$k-s0-decisions.csv; SD=$S_DEC_DIR/ps-S-p$k-s0-decisions.csv; SAE=$NULL_DIR/ps-S-p$k-s0-audit_entries.csv
    SMO=$dir/ps-SM-p$k-s0-open_positions.csv
    echo "  pair p$k (SM pk vs S pk, same seed and deletion):"
    if [ ! -s "$SMT" ] || [ ! -s "$ST" ]; then echo "    n/a: trades.csv missing ($SMT or $ST)"; continue; fi
    # (a) entrants: SM closed trades, SM open positions and SM Placed decisions outside the yearly list in force
    awk -F, "$YR_AWK $LNR_AWK"' NR == FNR { split($0, a, " "); m[a[1] " " a[2]] = 1; next } FNR > 1 && !((yr($3) " " $1) in m) { print lnr() }' "$t/yearly" "$SMT" > "$t/ent"
    eo=n/a; [ -s "$SMO" ] && eo=$(awk -F, "$YR_AWK"' NR == FNR { split($0, a, " "); m[a[1] " " a[2]] = 1; next } FNR > 1 && !((yr($3) " " $1) in m) { e++ } END { print e + 0 }' "$t/yearly" "$SMO")
    edp=n/a; [ -s "$SMD" ] && edp=$(awk -F, "$YR_AWK"' NR == FNR { split($0, a, " "); m[a[1] " " a[2]] = 1; next } $3 == "Placed" { p++; if (!((yr($1) " " $2) in m)) e++ } END { printf "%d of %d", e, p }' "$t/yearly" "$SMD")
    echo "    (a) entrants: Placed decisions $edp; open at the end $eo; closed trades $(_stats < "$t/ent")"
    # (b1) displaced at the decision: S Placed where SM reads Insufficient_cash (same Friday + symbol) -> S trade
    if [ -s "$SMD" ] && [ -s "$SD" ] && [ -s "$SAE" ]; then
      awk -F, 'NR == FNR { o[$1 "," $2] = $3; next } $3 == "Placed" && o[$1 "," $2] == "Insufficient_cash" { print $2 "|" $1 }' "$SMD" "$SD" > "$t/ddkeys"
      awk -F, "$LNR_AWK"' FILENAME == ARGV[1] { k[$1] = 1; next } FILENAME == ARGV[2] { if (($2 "|" $3) in k) p[$1] = 1; next } FNR > 1 && ($20 in p) { print lnr() }' "$t/ddkeys" "$SAE" "$ST" > "$t/dd"
      echo "    (b) displaced at the decision (S Placed, SM Insufficient_cash): $(nl_of "$t/ddkeys") decisions; their closed S trades $(_stats < "$t/dd")"
      cat "$t/dd" >> "$t/all-dd"
    else echo "    (b) displaced at the decision: n/a (decisions or S audit_entries missing: $SMD, $SD, $SAE)"; fi
    # (b2) displaced by the join: S closed trades whose symbol|entry_date is not an SM closed trade (mixes in path effects)
    awk -F, "$LNR_AWK"' NR == FNR { if (FNR > 1) k[$1 "|" $3] = 1; next } FNR > 1 && !(($1 "|" $3) in k) { print lnr() }' "$SMT" "$ST" > "$t/dj"
    awk -F, "$LNR_AWK"' NR == FNR { if (FNR > 1) k[$1 "|" $3] = 1; next } FNR > 1 && !(($1 "|" $3) in k) { print lnr() }' "$ST" "$SMT" > "$t/smo"
    echo "    (b) S-only by the symbol + entry_date join: $(_stats < "$t/dj")"
    echo "        SM-only by the same join (for reference): $(_stats < "$t/smo")"
    cat "$t/ent" >> "$t/all-ent"; cat "$t/dj" >> "$t/all-dj"; cat "$t/smo" >> "$t/all-smo"
  done
  echo "  pooled over the pairs:"
  echo "    entrants, closed:            $(_stats < "$t/all-ent")"
  echo "    displaced at the decision:   $(_stats < "$t/all-dd")"
  echo "    S-only by the join:          $(_stats < "$t/all-dj")"
  echo "    SM-only by the join:         $(_stats < "$t/all-smo")"
  echo "  Left to the analyst (not mechanical here): open positions' marks (unrealised P&L of entrants and of displaced"
  echo "  tickets still open at the end), the NAV-gap decomposition by decision class, which displaced tickets never filled,"
  echo "  entrants refused for cash, the tail-name ledger, and separating path effects from the join."
}

case "$CMD" in
  launch) cmd_launch ;;
  stage-lists) mkdir -p "$STAGE"; stage_lists ;;
  run) cmd_run ;;
  validate) cmd_validate "$@" ;;
  collect) cmd_collect "${1:-}" ;;
  summary) cmd_summary "${1:-}" ;;
  *) echo "usage: sh $0 {launch|stage-lists|run|validate|collect DEST|summary [DIR]}" >&2; exit 2 ;;
esac
