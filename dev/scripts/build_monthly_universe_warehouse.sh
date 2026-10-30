#!/bin/sh
# Arm SM prerequisite 3 (dev/experiments/floor-nearest-2026-10-25/README.md §"Arm SM"): top-3000 lists at every month
# end FROM..TO (default 1999-05-31 .. 2025-12-31), built by the pit-v12 builder and post-processing, the dated
# universe_schedule over them, and a snapshot warehouse whose manifest equals the lists' union (plus the benchmark and
# the runner's 14 macro extras, minus MEL). POSIX sh. NOT run by the author: the dispatcher launches it when the
# container is free (no agents, no backtest).
#
# Usage (host, from the checkout holding this script):
#   RUN_TREE=/workspaces/trading-1/.claude/worktrees/sweep-sm \   # container path of a PINNED, built, clean tree
#     sh dev/scripts/build_monthly_universe_warehouse.sh <phase>
# Phases, in order (`all` runs them all; each is resumable or cheap to rerun):
#   preflight  guards: pinned tree clean + built, #2724 present, container free, disk, inputs, SGP_old1 store edit
#   lists      builder --month-ends Y-01-01,Y-12-31 --top-n 3000 --true-dollar-volume, one job per calendar year, on the
#              pit-v12 inputs (pit-v12/inventory.sexp, $DATA/symbol_types.sexp, $DATA/sectors.csv) -> $WORK/raw.
#              A year is skipped only when its .done marker names the same bounds and inputs (run tree commit,
#              builder flags, the three input files' md5s); afterwards $WORK/raw must hold exactly the month ends
#              FROM..TO, so a smoke run's partial year is rebuilt by a full run, never reused.
#   post       pit-v12 post-processing on a copy of raw, in its commit order (as pit_v12_month_end_repro_check.sh):
#              1-2. alias-lists.pl with v11's alias2.resolved, alias3.txt, then v12's alias-v12-new.txt
#              3.   pit-v12/twin-drops.txt (per list since #3475), re-keyed by window: a top-3000-Y row (D, S) applies
#                   only to the monthly lists dated in [Y-05-31, Y+1-05-31) holding both legs, chain-resolved per list
#                   (map_yearly_drops; D absent: nothing to drop; no survivor of D present: kept, logged). Cells
#                   outside every row's window are the twinscan phase's.
#              then every May 31 list must equal pit-v12/composition/top-3000-Y.sexp byte for byte (raw and final),
#              and there must be one per May 31 in FROM..TO (27 for the defaults).
#   twinscan   v12-twin-scan-2026-10-22/twin-scan.sh (host, CSV store, whole union, no chunks) over the post lists.
#              A confirmed pair with a leg that is in NO yearly pit-v12 list (top-1000 or top-3000, any year) and not in
#              exclude-pairs.txt loses its DROPPED leg (the detector's later-last-bar rule) from every monthly list that
#              holds both legs. A confirmed, non-excluded pair with both legs yearly-listed loses its DROPPED leg from
#              every monthly list holding both legs while the yearly list in force holds at most one (dispatcher
#              decision 2026-10-25; cells the yearly list also holds together are the pit-v12 state and stay). Rows +
#              the detector's evidence -> $DEST/twin-drops-monthly.txt (commit it). Afterwards no such cell may remain:
#              $DEST/twin-cooccur-unhandled.txt must hold no rows, or the phase aborts. Only then is
#              $WORK/twinscan.done written (cksums of the final lists and twin-drops-monthly.txt); the phase removes it
#              first, so an aborted twinscan leaves none.
#   install    requires $WORK/twinscan.done to match the current final lists and drops (a missing or stale stamp
#              aborts), then: final lists -> $DEST/composition, composition{,-raw}.md5, twin-drops.txt (the re-keyed yearly rows),
#              universe-schedule.sexp (one `(DATE "pit-v12-monthly/composition/top-3000-DATE.sexp")` per list).
#              The lists (~130 MB) and the schedule are gitignored and rebuilt by this script; only composition.md5,
#              composition-raw.md5 and twin-drops-monthly.txt are committed. Once the md5 files are committed, install
#              aborts unless the rebuild matches them byte for byte (REPIN=1 re-pins).
#   warehouse  build_snapshots -incremental over the warehouse set in chunks of CHUNK_SIZE, one job at a time, no twin
#              dedupe (twins are handled in the lists, as for the _v12wk warehouse the floor-nearest chain reads).
#              Markers and $OUT are reused only under the same build stamp (set, CHUNK_SIZE, WH_START, WH_END, tail
#              exceptions, run tree commit), which $OUT also carries; any other reuse aborts.
#   verify     manifest == warehouse set derived from $DEST's lists (the chain's set-equality check), every entry has a
#              .snap and a .weekly, no orphan .snap or .weekly, manifest <= handle cap.
#
# Resume caches (list .done markers, post.stamp, the twin-scan dir, twinscan.done, chunk markers, $OUT's stamp) bind the
# bounds, builder flags, metadata inputs (inventory, symbol types, sectors), list bytes and warehouse window. They do
# NOT cover the CSV bar contents: after any change to the bar store, start from a fresh WORK and OUT.
#
# Measured 2026-10-25 (smoke, FROM=2009-04-01 TO=2009-06-30): lists 145 s for 3 (48 s per list; 2025-10..12: 41 s);
# twin scan 83 s over a 2,959-name union (pit-v12's 9,279-name scan: 14 min); warehouse 0.87 s per name in 80-name
# chunks (the _v12wk rebuild: ~0.5 s per name in ~2,300-name chunks). Full-run estimate, container-exclusive:
# lists 320 x ~45 s = ~4 h, twin scan ~20 min (host), warehouse ~11-12k names = ~1.6-2.9 h; ~6-7 h in all.
#
# Env: RUN_TREE (required), CONTAINER (trading-1-dev), HOST_ROOT (/Users/difan/Projects/trading-1), FROM (1999-05-31),
#      TO (2025-12-31), WORK (/tmp/sm-monthly-work, host), CWORK (/tmp/sm-monthly, container), OUT
#      (/tmp/snap_top3000_pit_v12monthly, container), DEST ($HERE/trading/test_data/backtest_scenarios/pit-v12-monthly),
#      WH_START (1998-01-01), WH_END (2026-10-07, the _v12wk build's), CHUNK_SIZE (2500), SMOKE_SYMBOLS (unset; N keeps
#      the first N names of the warehouse set: smoke runs only), SNAPSHOT_MAX_MMAP_HANDLES (12000), REPIN (unset; 1
#      overwrites the committed md5 files at install).
set -u

PHASE=${1:-}
CONTAINER=${CONTAINER:-trading-1-dev}
HOST_ROOT=${HOST_ROOT:-/Users/difan/Projects/trading-1}
FROM=${FROM:-1999-05-31}
TO=${TO:-2025-12-31}
WORK=${WORK:-/tmp/sm-monthly-work}
CWORK=${CWORK:-/tmp/sm-monthly}
OUT=${OUT:-/tmp/snap_top3000_pit_v12monthly}
WH_START=${WH_START:-1998-01-01}
WH_END=${WH_END:-2026-10-07}
CHUNK_SIZE=${CHUNK_SIZE:-2500}
SMOKE_SYMBOLS=${SMOKE_SYMBOLS:-}
HANDLE_CAP=${SNAPSHOT_MAX_MMAP_HANDLES:-12000}
DATA_C=/workspaces/trading-1/data
DATA_H=$HOST_ROOT/data
HERE=$(cd "$(dirname "$0")/../.." && pwd)
DEST=${DEST:-$HERE/trading/test_data/backtest_scenarios/pit-v12-monthly}
RUN_TREE=${RUN_TREE:-}
HOST_TREE=$(echo "$RUN_TREE" | sed "s#^/workspaces/trading-1#$HOST_ROOT#")
# Inputs, all read from the pinned tree so the lists follow its commit.
V12=$HOST_TREE/trading/test_data/backtest_scenarios/pit-v12
V11S4=$HOST_TREE/dev/experiments/pit-universe-2026-09-14/step4
TWINX=$HOST_TREE/dev/experiments/v12-twin-scan-2026-10-22
ALIAS_PL=$V11S4/twin-scan/alias-lists.pl
ALIAS_MAPS="$V11S4/specs/alias2.resolved $V11S4/twin-scan/alias3.txt $HOST_TREE/dev/experiments/rebaseline-v12-2026-10-08/warehouse-build/alias-v12-new.txt"
EXC=$HOST_TREE/trading/test_data/warehouse_exceptions.sexp
MACRO_INPUTS=$HOST_TREE/trading/trading/weinstein/strategy/lib/macro_inputs.ml
LIST_EXE=$RUN_TREE/trading/_build/default/analysis/data/universe/bin/build_composition_universes_runner.exe
SNAP_EXE=$RUN_TREE/trading/_build/default/analysis/scripts/build_snapshots/build_snapshots.exe
SCHED_PREFIX=pit-v12-monthly/composition

log() { mkdir -p "$WORK"; echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$WORK/build.log"; }
die() { log "ABORT: $*"; exit 1; }
dx() { docker exec "$CONTAINER" "$@"; }
syms_of() { grep -o '(symbol [^)]*)' "$@" | sed 's/.*(symbol //; s/)$//'; }
n_of() { wc -l < "$1" | tr -d ' '; }

# ------------------------------------------------------------------------------------------- pure list-side helpers
# (sourced by trading/devtools/checks/build_monthly_universe_guard_smoke.sh; no docker, no globals but their args)

# $1 dated list name (top-3000-YYYY-MM-DD). stdout: the year Y of the yearly list in force, the latest May 31 on or
# before the date (top-3000-2009-04-30 -> 2008, top-3000-2009-05-31 -> 2009).
window_year() {
  dt=${1#top-3000-}; wy=${dt%%-*}
  [ "$(echo "$dt" | cut -c6-7,9-10)" -lt 531 ] && wy=$((wy - 1))
  echo "$wy"
}

# $1 yearly drops file ("LIST D S [via=S0]", '#' comments; pit-v12/twin-drops.txt), $2 dir of
# top-3000-YYYY-MM-DD.sexp lists, $3 skipped-rows file. stdout: "top-3000-YYYY-MM-DD D S [via=S0]", ascending.
# A top-3000-Y row is a decision for its window only: it applies to the monthly lists dated in [Y-05-31, Y+1-05-31)
# and nowhere else (#3475 made twin-drops.txt per list: MEE/FLR are twins in 1998-1999 and distinct in 2001, where
# the yearly list keeps both). top-1000 rows are not read: the monthly lists are top-3000, and every top-1000 pair has
# its year's top-3000 row. Each row is taken as its ORIGINAL pair (D, S0), S0 = the via= leg when present, and kept
# where the monthly list holds both D and S0; the kept rows are then chain-resolved per list (resolve_chains), as
# apply-full-dedupe.sh resolved the yearly rows. On a May 31 list (raw bytes = the yearly raw) that keeps exactly the
# yearly list's rows, so the final May 31 list equals the yearly one byte for byte (check_may31). Mid-window, a
# survivor that is absent or itself dropped resolves through the chain the list actually holds. A list holding D
# while no row of D in the window has its survivor present is written to $3 ("LIST D S0 survivor-absent"; dropping D
# there would delete the instrument, not a second copy). Cells outside every row's window are the twinscan phase's
# (ungoverned_cooccur). Fails (exit 1) on a survivor cycle.
map_yearly_drops() {
  : > "$3"; mp=$3.pairs; : > "$mp"
  grep -v '^#' "$1" | awk '$1 ~ /^top-3000-[0-9][0-9][0-9][0-9]$/ && NF >= 3' > "$3.rows"
  for f in "$2"/top-3000-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].sexp; do
    [ -f "$f" ] || continue
    b=$(basename "$f" .sexp)
    awk -v l="$b" -v yl="top-3000-$(window_year "$b")" -v skip="$3" '
      FILENAME == ARGV[1] { while (match($0, /\(symbol [^)]*\)/)) { has[substr($0, RSTART + 8, RLENGTH - 9)] = 1; $0 = substr($0, RSTART + RLENGTH) } next }
      $1 != yl { next }
      { s0 = $3; if ($4 ~ /^via=/) s0 = substr($4, 5)
        if (!($2 in has)) next
        if (s0 in has) { print l, $2, s0; dropped[$2] = 1 } else if (!($2 in miss)) miss[$2] = s0 }
      END { for (d in miss) if (!(d in dropped)) print l, d, miss[d], "survivor-absent" >> skip }' "$f" "$3.rows"
  done | LC_ALL=C sort -u > "$mp"
  rc=0; resolve_chains "$mp" > "$mp.res" || rc=1; LC_ALL=C sort "$mp.res"; rm -f "$mp.res"
  LC_ALL=C sort -o "$3" "$3"; rm -f "$mp" "$3.rows"
  return "$rc"
}

# $1 twins.txt ("D S <evidence...>"), $2 cooccur.txt ("D S: list..."), $3 sorted monthly-only symbols, $4 exclude
# pairs ("A B", '#' comments). stdout: "LIST D S <evidence>" for every pair with a monthly-only leg, not excluded, per
# list holding both legs.
# $5 = "other" inverts the leg test: pairs whose legs are BOTH in some yearly list (neither rule drops them).
derive_monthly_drops() {
  twins=$1; only=$3; excl=$4; mode=${5:-only}
  while IFS=: read -r pair lists; do
    d=${pair%% *}; s=${pair#* }
    if grep -q -x -F -e "$d" -e "$s" "$only"; then [ "$mode" = only ] || continue; else [ "$mode" = other ] || continue; fi
    awk -v a="$d" -v b="$s" '!/^#/ && (($1 == a && $2 == b) || ($1 == b && $2 == a)) { f = 1 } END { exit !f }' "$excl" && continue
    ev=$(awk -v a="$d" -v b="$s" '$1 == a && $2 == b { $1 = ""; $2 = ""; sub(/^  */, ""); print; exit }' "$twins")
    for l in $lists; do [ "$l" = none ] || echo "$l $d $s $ev"; done
  done < "$2" | LC_ALL=C sort
}

# $1 rows ("LIST D S <evidence>", e.g. derive_monthly_drops ... other), $2 dir of yearly top-3000-YYYY.sexp lists, $3
# dir of monthly lists. stdout: the rows whose monthly list holds both legs while the yearly list in force (the latest
# May 31 on or before LIST's date) holds at most one. A cell whose yearly list in force also holds both legs is the
# pit-v12 state (the unapplied 790-row proposal, #3391) and is left alone, so every May 31 list keeps its yearly bytes.
# Specimen: CMN and CMD are both in top-3000-2009-04-30, whose yearly list in force (2008) holds neither leg.
ungoverned_cooccur() {
  while read -r l d s ev; do
    [ -n "$l" ] || continue
    dt=${l#top-3000-}; y=${dt%%-*}; [ "$(echo "$dt" | cut -c6-7,9-10)" -lt 531 ] && y=$((y - 1))
    yf=$2/top-3000-$y.sexp
    [ -f "$yf" ] && grep -q -F "(symbol $d)" "$yf" && grep -q -F "(symbol $s)" "$yf" && continue
    grep -q -F "(symbol $d)" "$3/$l.sexp" && grep -q -F "(symbol $s)" "$3/$l.sexp" && echo "$l $d $s${ev:+ $ev}"
  done < "$1"
  return 0
}

# $1 rows ("LIST D S <evidence>"). stdout: the rows with each survivor resolved through the list's chain of drops to
# the last leg nobody drops, tagged "via=<scan survivor>" when it moved. Every row comes from a pair whose legs are
# both listed, so the chain's last leg is listed too and applying every row keeps one copy of the instrument.
# Specimen: top-3000-2005-06-30 drops LB1 (survivor LB_old1) and LB_old1 (survivor BBWI); LB1's row now names BBWI.
# Fails (exit 1, the cycle's rows on stderr) when a chain returns to its start: applying it would drop every leg.
resolve_chains() {
  awk 'NR == FNR { surv[$1 " " $2] = $3; next }
    { s = $3; n = 0
      while (($1 " " s) in surv) { s = surv[$1 " " s]; if (++n > 64 || s == $2) { print > "/dev/stderr"; bad = 1; next } }
      if (s != $3) { v = $3; $3 = s; $0 = $0 " via=" v }
      print }
    END { exit bad }' "$1" "$1"
}

# $1 dir of dated lists. stdout: the universe_schedule block, one entry per list, ascending by date.
write_schedule() {
  echo "(universe_schedule ("
  for f in "$1"/top-3000-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].sexp; do
    [ -f "$f" ] || continue
    b=$(basename "$f"); dt=${b#top-3000-}; dt=${dt%.sexp}
    echo "  ($dt \"$SCHED_PREFIX/$b\")"
  done
  echo "  ))"
}

# $1 dir of lists, $2 runner-extras file. stdout: (list union - MEL) + GSPC.INDX + extras, sorted unique.
warehouse_set() {
  { syms_of "$1"/top-3000-*.sexp | grep -v -x -F MEL; echo GSPC.INDX; cat "$2"; } | LC_ALL=C sort -u
}

# ------------------------------------------------------------------------------------------------ guard helpers
# (also sourced by the dry harness; they read only their args, plus WORK through log/die and REPIN in pin_md5)

md5_file() { md5 -q "$1" 2>/dev/null || md5sum "$1" 2>/dev/null | cut -c1-32; }

# $1 FROM, $2 TO (YYYY-MM-DD). stdout: every calendar month end d with FROM <= d <= TO, ascending (the builder's
# --month-ends semantics, build_composition_universes_runner_lib.mli month_ends).
month_ends() {
  lo=$(echo "$1" | tr -d -); hi=$(echo "$2" | tr -d -); yy=${1%%-*}
  while [ "$yy" -le "${2%%-*}" ]; do
    for mm in 01 02 03 04 05 06 07 08 09 10 11 12; do
      case $mm in 04|06|09|11) dd=30 ;; 02) dd=28
        if [ $((yy % 4)) = 0 ] && { [ $((yy % 100)) != 0 ] || [ $((yy % 400)) = 0 ]; }; then dd=29; fi ;; *) dd=31 ;; esac
      [ "$yy$mm$dd" -ge "$lo" ] && [ "$yy$mm$dd" -le "$hi" ] && echo "$yy-$mm-$dd"
    done
    yy=$((yy + 1))
  done
  return 0
}

# $1 FROM, $2 TO. stdout: how many May 31 lists the range holds (27 for the default 1999-05-31 .. 2025-12-31).
may31_count() { month_ends "$1" "$2" | grep -c -e '-05-31$' || :; }

# $1 raw dir, $2 year, $3 lo, $4 hi, $5 input provenance: the year's .done marker. A marker is honoured only for the
# same bounds and inputs, so a smoke run's partial year is rebuilt by a later full run (lists_plan).
write_list_marker() { echo "$3 $4 $5" > "$1/.done-$2"; }

# $1 FROM, $2 TO, $3 raw dir, $4 input provenance. stdout: "YEAR LO HI" for every calendar year the lists phase must
# (re)build: no marker, or a marker for other bounds or other inputs.
lists_plan() {
  py=${1%%-*}
  while [ "$py" -le "${2%%-*}" ]; do
    plo="$py-01-01"; phi="$py-12-31"; [ "$py" = "${1%%-*}" ] && plo=$1; [ "$py" = "${2%%-*}" ] && phi=$2
    [ -f "$3/.done-$py" ] && [ "$(cat "$3/.done-$py")" = "$plo $phi $4" ] || echo "$py $plo $phi"
    py=$((py + 1))
  done
}

# $1 sorted wanted set, $2 sorted actual set, $3 diff file. Exit 0 when equal; otherwise writes `comm -3` (col 1 =
# missing from $2, col 2 = extra in $2) to $3 and exits 1.
set_equal() {
  cmp -s "$1" "$2" && return 0
  LC_ALL=C comm -3 "$1" "$2" > "$3"; return 1
}

# $1 lists dir, $2 FROM, $3 TO. Aborts unless the dir's dated lists are exactly the month ends FROM..TO (nothing
# missing from a partial resume, nothing left over from another range).
check_list_set() {
  month_ends "$2" "$3" | sed 's/.*/top-3000-&.sexp/' > "$WORK/lists-want.txt"
  ls "$1" | grep -e '^top-3000-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\.sexp$' | LC_ALL=C sort > "$WORK/lists-got.txt" || :
  set_equal "$WORK/lists-want.txt" "$WORK/lists-got.txt" "$WORK/lists-diff.txt" \
    || die "$1 holds $(n_of "$WORK/lists-got.txt") lists, not the $(n_of "$WORK/lists-want.txt") month ends $2..$3 ($WORK/lists-diff.txt: col 1 = missing, col 2 = extra)"
}

# $1 raw dir, $2 final dir, $3 pit-v12 dir, $4 expected count. Every May 31 list equals pit-v12's yearly list: raw
# against composition-raw.md5, final against composition/; and there are exactly $4 of them.
check_may31() {
  mn=0
  for f in "$2"/top-3000-[0-9][0-9][0-9][0-9]-05-31.sexp; do
    [ -f "$f" ] || continue
    my=$(basename "$f" | cut -c10-13); b=top-3000-$my.sexp
    want=$(awk -v b="$b" '$2 == b { print $1 }' "$3/composition-raw.md5")
    got=$(md5_file "$1/top-3000-$my-05-31.sexp")
    [ -n "$want" ] && [ "$want" = "$got" ] || die "raw $my-05-31 md5 $got != pit-v12 composition-raw.md5 $want (builder or store moved)"
    cmp -s "$f" "$3/composition/$b" || die "final $my-05-31 differs from pit-v12/composition/$b (post-processing moved)"
    mn=$((mn + 1))
  done
  [ "$mn" = "$4" ] || die "May 31 check: $mn lists in $2, expected $4"
  log "May 31 check: $mn lists byte-identical to pit-v12 (raw md5 and final)"
}

# $1 rows (derive_monthly_drops ... other), $2 yearly dir, $3 monthly dir, $4 report file. Post-apply check: no
# confirmed, non-excluded pair with both legs yearly-listed still co-occurs in a monthly list whose yearly list in
# force holds at most one leg. By construction (the yearly pairs drop in every window, the rest through
# ungoverned_cooccur) the report comes out empty; a row means a drop rule missed a cell, and this aborts.
report_unhandled() {
  { echo "# Expected EMPTY: confirmed twin pairs, both legs in some yearly pit-v12 list, still co-occurring in a monthly"
    echo "# list after every drop rule while the yearly list in force holds at most one leg: LIST LEG_A LEG_B <evidence>."
    ungoverned_cooccur "$1" "$2" "$3"; } > "$4"
  nu=$(grep -c -v '^#' "$4" || :)
  [ "$nu" = 0 ] || die "$nu ungoverned twin cells survive the drops: $4"
  log "twinscan: no ungoverned twin co-occurrence left ($4 holds no rows)"
}

# $1 lists dir, $2... twin-drop files ("LIST D S ..."). Aborts unless every file holds on the lists: no DROPPED leg
# is back in its list and every survivor is present.
check_drops_hold() {
  hd=$1; shift
  for f in "$@"; do
    grep -v '^#' "$f" | while read -r l d s _; do
      [ -n "$l" ] || continue
      ! grep -q -F "(symbol $d)" "$hd/$l.sexp" || { echo "$l holds $d again"; exit 1; }
      grep -q -F "(symbol $s)" "$hd/$l.sexp" || { echo "$l lacks survivor $s"; exit 1; }
    done || die "twin-drop check failed on $f"
  done
}

md5_of_dir() { (cd "$1" && { md5sum top-3000-*.sexp 2>/dev/null || md5 -r top-3000-*.sexp | awk '{ print $1 "  " $2 }'; }); }

# $1 freshly computed manifest, $2 committed manifest. The lists are NOT committed (~130 MB, gitignored): the committed
# md5 files are the record, and every rebuild from the committed inputs must reproduce them byte for byte. A missing
# $2 (first build) or REPIN=1 writes it.
pin_md5() {
  if [ -f "$2" ] && [ -z "${REPIN:-}" ]; then
    cmp -s "$1" "$2" || die "rebuilt lists differ from the committed $(basename "$2") (diff $1 $2; REPIN=1 re-pins)"
    log "install: $(n_of "$2") lists match the committed $(basename "$2") byte for byte"
  else cp "$1" "$2"; log "install: wrote $(basename "$2") ($(n_of "$2") lists): commit it"; fi
}

# $1 post.stamp, $2 twin-scan.sh, $3 bar-store path. stdout: the twin-scan cache key: the post lists, the scanner's bytes
# (its thresholds are constants in the file) and its effective settings. A cache from another scanner or MIN_SHARED is
# rescanned. The bar store's contents are not bound (start from a fresh WORK after any data change).
scan_stamp() {
  echo "post=$(cat "$1") scanner=$(cksum < "$2" | awk '{ print $1 "-" $2 }') MIN_SHARED=${MIN_SHARED:-8} DATA=$3"
}

# $1 dir of dated lists, $2 twin-drops-monthly.txt. stdout: the twinscan completion stamp, the cksums of the lists'
# bytes and of the drop evidence. Written to $WORK/twinscan.done only after report_unhandled passes.
twinscan_stamp() {
  echo "lists=$(cat "$1"/top-3000-*.sexp | cksum | awk '{ print $1 "-" $2 }') drops=$(cksum < "$2" | awk '{ print $1 "-" $2 }')"
}

# $1 dir of dated lists, $2 twin-drops-monthly.txt, $3 recorded completion stamp. Install's precondition: aborts unless
# a twinscan completed (every check passed) on exactly these lists and drops. A twinscan that aborted part way writes
# no stamp (the phase removes it first), and a list or drop file changed since leaves a stale one.
check_twinscan_done() {
  [ -s "$3" ] || die "no twinscan completion stamp $3: run the twinscan phase first (an aborted twinscan leaves none)"
  twinscan_stamp "$1" "$2" | cmp -s - "$3" || die "$1 or $2 changed since the twinscan completed ($3 is stale): rerun post and twinscan"
}

# $1 warehouse set, $2 CHUNK_SIZE, $3 WH_START, $4 WH_END, $5 tail-exceptions file, $6 run tree commit. stdout: the
# one-line provenance of a warehouse build. Chunk markers and an existing $OUT are reused only under the same line:
# build_snapshots -incremental skips a symbol whose CSV is unchanged, so a changed set, chunking, window, exception
# list or run tree would otherwise keep the old snapshots silently. The stamp does NOT cover the CSV bar contents:
# after any change to the bar store, start from a fresh WORK and OUT.
wh_stamp() {
  echo "syms=$(cksum < "$1" | awk '{ print $1 "-" $2 }') k=$2 start=$3 end=$4 exc=$(cksum < "$5" | awk '{ print $1 "-" $2 }') tree=$6"
}

# $1 recorded stamp (may be absent: a fresh build), $2 new stamp. Exit 0 when reuse is compatible.
stamp_compatible() { [ ! -f "$1" ] || cmp -s "$1" "$2"; }

# $1 $OUT (for messages), $2 the stamp copied out of an existing $OUT (absent or empty: it had none), $3 new stamp.
# An existing $OUT is reused only when it carries the same stamp; one without a stamp, or with another, aborts.
check_out_stamp() {
  [ -s "$2" ] || die "$1 exists without a build stamp: move it or set OUT"
  cmp -s "$2" "$3" || die "$1 was built for another window or input set ($2 vs $3): remove it and the chunk markers"
}

[ -z "${SM_LIB_ONLY:-}" ] || { return 0 2>/dev/null || exit 0; }   # dry-harness hook

# ----------------------------------------------------------------------------------------------------------- phases
runner_extras() {
  { sed -n '/^let spdr_sector_etfs/,/^  \]$/p' "$MACRO_INPUTS"; sed -n '/^let default_global_indices/,/\]$/p' "$MACRO_INPUTS"; } \
    | grep -o '("[A-Z0-9.]*",' | sed 's/("//; s/",$//' | LC_ALL=C sort -u > "$WORK/runner-extras.txt"
  [ "$(n_of "$WORK/runner-extras.txt")" = 14 ] || die "parsed $(n_of "$WORK/runner-extras.txt") runner extras from $MACRO_INPUTS, expected 14"
}

phase_preflight() {
  [ -n "$RUN_TREE" ] || die "RUN_TREE (container path of a pinned, built tree) is required"
  git -C "$HOST_TREE" rev-parse --git-dir >/dev/null 2>&1 || die "run tree $HOST_TREE is not a git tree (set HOST_ROOT)"
  [ -z "$(git -C "$HOST_TREE" status --porcelain)" ] || die "run tree $HOST_TREE is dirty"
  git -C "$HOST_TREE" merge-base --is-ancestor 6141b23c3239cca9e9c4a0927694ec163adfb610 HEAD || die "run tree lacks #2724 (6141b23c3)"
  dx test -x "$LIST_EXE" || die "not built: $LIST_EXE"
  dx test -x "$SNAP_EXE" || die "not built: $SNAP_EXE"
  for f in "$ALIAS_PL" $ALIAS_MAPS "$TWINX/twin-scan.sh" "$TWINX/apply-drops.sh" "$TWINX/exclude-pairs.txt" \
    "$V12/twin-drops.txt" "$V12/inventory.sexp" "$V12/composition-raw.md5" "$EXC" "$MACRO_INPUTS" \
    "$DATA_H/symbol_types.sexp" "$DATA_H/sectors.csv"; do
    [ -f "$f" ] || die "missing input $f"
  done
  if dx pgrep -f 'build_snapshots|scenario_runner|panel_runner|bayesian_runner|build_composition_universes' >/dev/null; then die "another build/backtest is running in $CONTAINER"; fi
  log "run tree HEAD=$(git -C "$HOST_TREE" rev-parse --short HEAD); container mem $(docker stats --no-stream --format '{{.MemUsage}}' "$CONTAINER")"
  free_gb=$(df -g / | awk 'NR==2{print $4}'); [ "$free_gb" -gt 30 ] || die "host free ${free_gb} GB < 30 GB"
  if dx test -e "$OUT" && ! ls "$WORK"/wh/chunk-*.done >/dev/null 2>&1; then die "$OUT exists with no chunk marker in $WORK/wh: move it or set OUT"; fi
  late=$(dx awk -F, '$1 > "2009-11-03" && $1 ~ /^[0-9]/' "$DATA_C/S/1/SGP_old1/data.csv" | wc -l | tr -d ' ')
  [ "$late" = 0 ] || die "SGP_old1 has $late rows after 2009-11-03: the store edit is missing"
  runner_extras
  log "preflight OK: FROM=$FROM TO=$TO WORK=$WORK OUT=$OUT DEST=$DEST"
}

# What the lists depend on besides the bounds: the builder's commit and flags, and its three input files.
list_prov() {
  echo "tree=$(git -C "$HOST_TREE" rev-parse HEAD) top-n=3000 tdv inv=$(md5_file "$V12/inventory.sexp") types=$(md5_file "$DATA_H/symbol_types.sexp") sectors=$(md5_file "$DATA_H/sectors.csv")"
}

phase_lists() {
  mkdir -p "$WORK/raw"; prov=$(list_prov)
  lists_plan "$FROM" "$TO" "$WORK/raw" "$prov" > "$WORK/lists-plan.txt"
  log "lists: $(n_of "$WORK/lists-plan.txt") years to build (the rest have a marker for the same bounds and inputs)"
  while read -r y lo hi <&3; do   # fd 3: nothing in the loop body can eat the plan
    rm -f "$WORK/raw/.done-$y" "$WORK/raw/top-3000-$y-"*.sexp
    d=$CWORK/dated-$y; dx rm -rf "$d"; dx mkdir -p "$d"; t0=$(date +%s)
    dx "$LIST_EXE" --bars-root "$DATA_C" --symbol-types "$DATA_C/symbol_types.sexp" --sectors-csv "$DATA_C/sectors.csv" \
      --inventory "$RUN_TREE/trading/test_data/backtest_scenarios/pit-v12/inventory.sexp" --out-dir "$d" \
      --month-ends "$lo,$hi" --top-n 3000 --true-dollar-volume > "$WORK/lists-$y.log" 2>&1 || die "builder failed for $y (see $WORK/lists-$y.log)"
    grep -q 'skipped=0$' "$WORK/lists-$y.log" || die "builder skipped anchors in $y (see $WORK/lists-$y.log)"
    n=$(sed -n 's/.*written=\([0-9]*\) .*/\1/p' "$WORK/lists-$y.log"); [ "${n:-0}" -gt 0 ] || die "builder wrote no list for $y"
    docker cp "$CONTAINER:$d/." "$WORK/raw/" || die "docker cp $d"; dx rm -rf "$d"
    w=$(( $(date +%s) - t0 )); write_list_marker "$WORK/raw" "$y" "$lo" "$hi" "$prov"
    log "lists $y: $n lists $lo..$hi (wall ${w}s, $((w / n))s per list)"
  done 3< "$WORK/lists-plan.txt"
  check_list_set "$WORK/raw" "$FROM" "$TO"
  log "lists: $(ls "$WORK"/raw/top-3000-*.sexp | wc -l | tr -d ' ') raw lists in $WORK/raw, exactly the month ends $FROM..$TO"
}

phase_post() {
  check_list_set "$WORK/raw" "$FROM" "$TO"
  rm -rf "$WORK/final"; mkdir -p "$WORK/final"; cp "$WORK"/raw/top-3000-*.sexp "$WORK/final/"
  : > "$WORK/post.log"
  for m in $ALIAS_MAPS; do perl "$ALIAS_PL" "$m" "$WORK"/final/*.sexp >> "$WORK/post.log" || die "alias-lists.pl $m"; done
  map_yearly_drops "$V12/twin-drops.txt" "$WORK/final" "$WORK/drops-yearly-skipped.txt" > "$WORK/drops-yearly-mapped.txt" \
    || die "yearly twin-drops: survivor cycle in a monthly list ($WORK/drops-yearly-mapped.txt)"
  if [ -s "$WORK/drops-yearly-mapped.txt" ]; then
    sh "$TWINX/apply-drops.sh" "$WORK/drops-yearly-mapped.txt" "$WORK/final" >> "$WORK/post.log" || die "apply-drops (yearly rows)"
  fi
  log "post: aliases applied; yearly twin-drops -> $(n_of "$WORK/drops-yearly-mapped.txt") monthly rows applied, $(n_of "$WORK/drops-yearly-skipped.txt") kept (survivor absent)"
  check_may31 "$WORK/raw" "$WORK/final" "$V12" "$(may31_count "$FROM" "$TO")"
  cat "$WORK"/final/*.sexp | cksum > "$WORK/post.stamp"
}

phase_twinscan() {
  rm -f "$WORK/twinscan.done"   # an abort below must leave install refusing
  [ -s "$WORK/post.stamp" ] || die "run the post phase first"
  cat "$WORK"/final/*.sexp | cksum | cmp -s - "$WORK/post.stamp" || die "$WORK/final changed since post (monthly drops already applied?): rerun post first"
  S=$WORK/twin-scan
  if [ -s "$S/cooccur.txt" ] && scan_stamp "$WORK/post.stamp" "$TWINX/twin-scan.sh" "$DATA_H" | cmp -s - "$S/stamp"; then
    log "twinscan: reusing $S (same post lists, scanner and settings)"
  else
    rm -rf "$S"; mkdir -p "$S"; t0=$(date +%s)
    DATA=$DATA_H LISTS=$WORK/final sh "$TWINX/twin-scan.sh" "$S" 2>> "$WORK/build.log" || die "twin-scan.sh failed"
    scan_stamp "$WORK/post.stamp" "$TWINX/twin-scan.sh" "$DATA_H" > "$S/stamp"; log "twinscan: $(n_of "$S/twins.txt") confirmed pairs (wall $(( $(date +%s) - t0 ))s)"
  fi
  [ ! -s "$S/missing-csv.txt" ] || log "twinscan: $(n_of "$S/missing-csv.txt") list symbols have no CSV (e.g. $(head -3 "$S/missing-csv.txt" | tr '\n' ' '))"
  syms_of "$V12"/composition/top-*.sexp | LC_ALL=C sort -u > "$WORK/yearly-union.txt"
  syms_of "$WORK"/final/top-3000-*.sexp | LC_ALL=C sort -u > "$WORK/monthly-union.txt"
  LC_ALL=C comm -23 "$WORK/monthly-union.txt" "$WORK/yearly-union.txt" > "$WORK/monthly-only.txt"
  derive_monthly_drops "$S/twins.txt" "$S/cooccur.txt" "$WORK/monthly-only.txt" "$TWINX/exclude-pairs.txt" > "$WORK/drops-monthly-only.txt"
  derive_monthly_drops "$S/twins.txt" "$S/cooccur.txt" "$WORK/monthly-only.txt" "$TWINX/exclude-pairs.txt" other > "$WORK/cooccur-other.txt"
  ungoverned_cooccur "$WORK/cooccur-other.txt" "$V12/composition" "$WORK/final" > "$WORK/drops-cooccur.txt"
  LC_ALL=C sort "$WORK/drops-monthly-only.txt" "$WORK/drops-cooccur.txt" > "$WORK/drops-scan.txt"
  resolve_chains "$WORK/drops-scan.txt" > "$WORK/drops-monthly.txt" 2> "$WORK/drops-cycle.txt" || die "twin-drop cycle (applying it drops every leg): $WORK/drops-cycle.txt; add the pair to exclude-pairs.txt"
  write_monthly_drops_file
  if [ -s "$WORK/drops-monthly.txt" ]; then sh "$TWINX/apply-drops.sh" "$WORK/drops-monthly.txt" "$WORK/final" >> "$WORK/post.log" || die "apply-drops (monthly rows)"; fi
  report_unhandled "$WORK/cooccur-other.txt" "$V12/composition" "$WORK/final" "$DEST/twin-cooccur-unhandled.txt"
  twinscan_stamp "$WORK/final" "$DEST/twin-drops-monthly.txt" > "$WORK/twinscan.done"   # only now: every check passed
  log "twinscan: monthly-only symbols $(n_of "$WORK/monthly-only.txt") of union $(n_of "$WORK/monthly-union.txt"); $(awk '{ print $2, $3 }' "$WORK/drops-monthly.txt" | sort -u | wc -l | tr -d ' ') pairs -> $(n_of "$WORK/drops-monthly.txt") list rows dropped ($(n_of "$WORK/drops-monthly-only.txt") monthly-only, $(n_of "$WORK/drops-cooccur.txt") both-legs-yearly) -> $DEST/twin-drops-monthly.txt"
}

write_monthly_drops_file() {
  mkdir -p "$DEST"
  {
    echo "# Monthly rename-twin drops (arm SM, dev/scripts/build_monthly_universe_warehouse.sh twinscan): LIST DROPPED SURVIVOR"
    echo "# <twin-scan.sh evidence>. Pairs confirmed by dev/experiments/v12-twin-scan-2026-10-22/twin-scan.sh over the monthly"
    echo "# lists' union, not in exclude-pairs.txt. DROPPED (the detector's later-last-bar loser) leaves (a) every monthly list"
    echo "# holding both legs when a leg is in no yearly pit-v12 list, and (b) every monthly list holding both legs while the"
    echo "# yearly list in force holds at most one, when both legs are yearly-listed. Lists $FROM..$TO, run tree"
    echo "# $(git -C "$HOST_TREE" rev-parse --short HEAD 2>/dev/null)."
    cat "$WORK/drops-monthly.txt"
  } > "$DEST/twin-drops-monthly.txt"
}

phase_install() {
  check_twinscan_done "$WORK/final" "$DEST/twin-drops-monthly.txt" "$WORK/twinscan.done"
  mkdir -p "$DEST/composition"; rm -f "$DEST"/composition/top-3000-*.sexp
  cp "$WORK"/final/top-3000-*.sexp "$DEST/composition/"
  { echo "# Yearly pit-v12 twin-drops re-keyed to the monthly lists (build_monthly_universe_warehouse.sh post): LIST DROPPED SURVIVOR"
    cat "$WORK/drops-yearly-mapped.txt"; } > "$DEST/twin-drops.txt"
  check_drops_hold "$DEST/composition" "$DEST/twin-drops.txt" "$DEST/twin-drops-monthly.txt"
  md5_of_dir "$DEST/composition" > "$WORK/composition.md5"; pin_md5 "$WORK/composition.md5" "$DEST/composition.md5"
  md5_of_dir "$WORK/raw" > "$WORK/composition-raw.md5"; pin_md5 "$WORK/composition-raw.md5" "$DEST/composition-raw.md5"
  write_schedule "$DEST/composition" > "$DEST/universe-schedule.sexp"
  n=$(ls "$DEST"/composition/top-3000-*.sexp | wc -l | tr -d ' '); ns=$(grep -c '"pit-v12-monthly/' "$DEST/universe-schedule.sexp")
  [ "$n" = "$ns" ] || die "schedule has $ns entries for $n lists"
  log "install: $n lists, $(du -sh "$DEST/composition" | awk '{ print $1 }') -> $DEST (lists and schedule gitignored; commit the md5 files and twin-drops-monthly.txt)"
}

pinned_spec() {
  echo "(Pinned ("
  sed 's/.*/  ((symbol &) (sector "Unknown"))/' "$1" | sed 's/((symbol GSPC.INDX) (sector "Unknown"))/((symbol GSPC.INDX) (sector "Index"))/'
  echo "))"
}

manifest_syms() { dx sh -c "tr '\n' ' ' < $OUT/manifest.sexp | grep -o '(symbol [^)]*)'" | sed 's/(symbol //; s/)$//' | LC_ALL=C sort -u; }

# The intended warehouse set from $DEST's lists -> $WORK/wh/syms.txt (SMOKE_SYMBOLS truncates it, smoke runs only).
wh_syms() {
  mkdir -p "$WORK/wh"; [ -s "$WORK/runner-extras.txt" ] || runner_extras
  warehouse_set "$DEST/composition" "$WORK/runner-extras.txt" > "$WORK/wh/syms-full.txt"
  if [ -n "$SMOKE_SYMBOLS" ]; then
    { echo GSPC.INDX; grep -v -x GSPC.INDX "$WORK/wh/syms-full.txt" | head -n "$SMOKE_SYMBOLS"; } | LC_ALL=C sort -u > "$WORK/wh/syms.txt"
    log "SMOKE: warehouse set truncated to $(n_of "$WORK/wh/syms.txt") of $(n_of "$WORK/wh/syms-full.txt") names"
  else cp "$WORK/wh/syms-full.txt" "$WORK/wh/syms.txt"; fi
}

# Chunk markers and $OUT are reused only for the build they were made by (wh_stamp: set, CHUNK_SIZE, WH_START, WH_END,
# tail exceptions, run tree). $OUT carries its own copy of the stamp, so deleting the markers cannot make an old $OUT
# look fresh to build_snapshots -incremental. An $OUT without a stamp, or with another, aborts.
wh_resume_guard() {
  wh_stamp "$W/syms.txt" "$CHUNK_SIZE" "$WH_START" "$WH_END" "$EXC" "$(git -C "$HOST_TREE" rev-parse HEAD)" > "$W/build.stamp.new"
  stamp_compatible "$W/build.stamp" "$W/build.stamp.new" \
    || die "the chunk markers in $W were written for another build ($W/build.stamp vs $W/build.stamp.new): remove $OUT and $W/chunk-* $W/build.stamp"
  if dx test -e "$OUT"; then
    dx cat "$OUT/.sm-build.stamp" > "$W/out.stamp" 2>/dev/null || rm -f "$W/out.stamp"
    check_out_stamp "$OUT" "$W/out.stamp" "$W/build.stamp.new"
  else
    rm -f "$W"/chunk-*.done; dx mkdir -p "$OUT"; docker cp "$W/build.stamp.new" "$CONTAINER:$OUT/.sm-build.stamp" || die "stamp $OUT"
  fi
  mv "$W/build.stamp.new" "$W/build.stamp"
}

phase_warehouse() {
  wh_syms; W=$WORK/wh
  wh_resume_guard
  rm -f "$W"/chunk-*.txt
  grep -v -x GSPC.INDX "$W/syms.txt" > "$W/syms-nobench.txt"
  awk -v d="$W" -v k="$CHUNK_SIZE" '{ print > (d "/chunk-" (int((NR - 1) / k) + 1) ".txt") }' "$W/syms-nobench.txt"
  echo GSPC.INDX >> "$W/chunk-1.txt"
  docker cp "$EXC" "$CONTAINER:/tmp/sm-warehouse_exceptions.sexp" || die "docker cp exceptions"
  for c in $(ls "$W"/chunk-*.txt | sed 's#.*/chunk-##; s#\.txt$##' | sort -n); do
    [ -f "$W/chunk-$c.done" ] && { log "WH chunk $c: done (marker)"; continue; }
    pinned_spec "$W/chunk-$c.txt" > "$W/chunk-$c.sexp"; docker cp "$W/chunk-$c.sexp" "$CONTAINER:/tmp/sm-chunk-$c.sexp" || die "chunk $c copy"
    log "WH BUILD chunk $c ($(n_of "$W/chunk-$c.txt") symbols) -> $OUT"; t0=$(date +%s)
    dx /usr/bin/time -f 'peak_rss_kb=%M' -o "/tmp/sm-chunk-$c.rss" "$SNAP_EXE" -universe-path "/tmp/sm-chunk-$c.sexp" \
      -csv-data-dir "$DATA_C" -output-dir "$OUT" -benchmark-symbol GSPC.INDX -start-date "$WH_START" -end-date "$WH_END" \
      -incremental -tail-exceptions /tmp/sm-warehouse_exceptions.sexp > "$W/chunk-$c.build.log" 2>&1 \
      || die "chunk $c did not exit 0 (see $W/chunk-$c.build.log; 137 = OOM)"
    touch "$W/chunk-$c.done"; log "WH chunk $c done: $(dx tail -1 "/tmp/sm-chunk-$c.rss") (wall $(( $(date +%s) - t0 ))s)"
  done
  phase_verify
}

phase_verify() {
  wh_syms; W=$WORK/wh
  manifest_syms > "$W/manifest.txt"
  set_equal "$W/syms.txt" "$W/manifest.txt" "$W/set-diff.txt" \
    || die "manifest set differs from the lists' warehouse set ($(n_of "$W/set-diff.txt") names, $W/set-diff.txt: col 1 = missing, col 2 = extra)"
  dx sh -c "ls $OUT | sed -n 's/\\.snap\$//p' | LC_ALL=C sort -u" > "$W/snaps.txt"
  set_equal "$W/manifest.txt" "$W/snaps.txt" "$W/snap-diff.txt" \
    || die "manifest entries and .snap files differ (#2724 clobber or orphans; $W/snap-diff.txt: col 1 = no .snap, col 2 = orphan)"
  dx sh -c "ls $OUT | sed -n 's/\\.weekly\$//p' | LC_ALL=C sort -u" > "$W/weekly.txt"
  set_equal "$W/manifest.txt" "$W/weekly.txt" "$W/weekly-diff.txt" \
    || die "manifest entries and .weekly side-tables differ ($W/weekly-diff.txt: col 1 = no .weekly, col 2 = orphan)"
  n_wk=$(n_of "$W/weekly.txt"); m=$(n_of "$W/manifest.txt"); [ "$m" -le "$HANDLE_CAP" ] || log "WARNING: manifest $m > handle cap $HANDLE_CAP: chains on $OUT must export SNAPSHOT_MAX_MMAP_HANDLES >= $m"
  log "VERIFY OK: manifest $m == lists' warehouse set (union - MEL + GSPC.INDX + 14 extras); snaps $m; weekly $n_wk; size $(dx du -sh "$OUT" | awk '{ print $1 }'). Chains: EXPECT_WH=$m, EXPECT_ABSENT=1 (MEL)"
}

case "$PHASE" in
  preflight) phase_preflight ;;
  lists) phase_lists ;;
  post) phase_post ;;
  twinscan) phase_twinscan ;;
  install) phase_install ;;
  warehouse) phase_warehouse ;;
  verify) phase_verify ;;
  all) phase_preflight && phase_lists && phase_post && phase_twinscan && phase_install && phase_warehouse ;;
  *) echo "usage: $0 {preflight|lists|post|twinscan|install|warehouse|verify|all}" >&2; exit 2 ;;
esac
