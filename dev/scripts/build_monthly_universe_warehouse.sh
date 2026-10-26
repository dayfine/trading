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
#              A year with a .done marker is skipped.
#   post       pit-v12 post-processing on a copy of raw, in its commit order (as pit_v12_month_end_repro_check.sh):
#              1-2. alias-lists.pl with v11's alias2.resolved, alias3.txt, then v12's alias-v12-new.txt
#              3.   pit-v12/twin-drops.txt, re-keyed: each confirmed pair (D, S) it names loses D from EVERY monthly
#                   list that holds both legs, whatever the window (D absent: nothing to drop; S absent from a list in
#                   a row's [Y-05-31, Y+1-05-31) window: kept, logged)
#              then every May 31 list must equal pit-v12/composition/top-3000-Y.sexp byte for byte (raw and final).
#   twinscan   v12-twin-scan-2026-10-22/twin-scan.sh (host, CSV store, whole union, no chunks) over the post lists.
#              A confirmed pair with a leg that is in NO yearly pit-v12 list (top-1000 or top-3000, any year) and not in
#              exclude-pairs.txt loses its DROPPED leg (the detector's later-last-bar rule) from every monthly list that
#              holds both legs. A confirmed, non-excluded pair with both legs yearly-listed loses its DROPPED leg from
#              every monthly list holding both legs while the yearly list in force holds at most one (dispatcher
#              decision 2026-10-25; cells the yearly list also holds together are the pit-v12 state and stay). Rows +
#              the detector's evidence -> $DEST/twin-drops-monthly.txt (commit it). Afterwards no such cell may remain:
#              $DEST/twin-cooccur-unhandled.txt must hold no rows, or the phase aborts.
#   install    final lists -> $DEST/composition, composition{,-raw}.md5, twin-drops.txt (the re-keyed yearly rows),
#              universe-schedule.sexp (one `(DATE "pit-v12-monthly/composition/top-3000-DATE.sexp")` per list).
#              The lists (~130 MB) and the schedule are gitignored and rebuilt by this script; only composition.md5,
#              composition-raw.md5 and twin-drops-monthly.txt are committed. Once the md5 files are committed, install
#              aborts unless the rebuild matches them byte for byte (REPIN=1 re-pins).
#   warehouse  build_snapshots -incremental over the warehouse set in chunks of CHUNK_SIZE, one job at a time, no twin
#              dedupe (twins are handled in the lists, as for the _v12wk warehouse the floor-nearest chain reads).
#   verify     manifest == warehouse set derived from $DEST's lists (the chain's set-equality check), every entry has a
#              .snap, no orphan .snap, .weekly side-tables present, manifest <= handle cap.
#
# Measured 2026-10-25 (smoke, FROM=2009-04-01 TO=2009-06-30): lists 145 s for 3 (48 s per list; 2025-10..12: 41 s);
# twin scan 83 s over a 2,959-name union (pit-v12's 9,279-name scan: 14 min); warehouse 0.87 s per name in 80-name
# chunks (the _v12wk rebuild: ~0.5 s per name in ~2,300-name chunks). Full-run estimate, container-exclusive:
# lists 319 x ~45 s = ~4 h, twin scan ~20 min (host), warehouse ~11-12k names = ~1.6-2.9 h; ~6-7 h in all.
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

# $1 yearly drops file ("top-N-Y D S", '#' comments), $2 dir of top-3000-YYYY-MM-DD.sexp lists, $3 skipped-rows
# file. stdout: "top-3000-YYYY-MM-DD D S" for every monthly list holding both legs of a pair (D, S) named by any row,
# whatever its window: both legs of a confirmed pair can co-occur in a monthly list whose governing yearly list holds
# only one leg (CMN and CMD in top-3000-2009-04-30, the 2008 window; dispatcher decision 2026-10-25). Ascending by
# list, then pair. A list dated in a top-3000-Y row's window [Y-05-31, Y+1-05-31) that holds D without S is written to
# $3 (dropping D there would delete the instrument, not a second copy).
map_yearly_drops() {
  : > "$3"
  grep -v '^#' "$1" | awk 'NF >= 3 { print $2, $3 }' | LC_ALL=C sort -u | while read -r d s; do
    for f in "$2"/top-3000-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].sexp; do
      [ -f "$f" ] || continue
      grep -q -F "(symbol $d)" "$f" && grep -q -F "(symbol $s)" "$f" && echo "$(basename "$f" .sexp) $d $s"
    done
  done | LC_ALL=C sort
  grep -v '^#' "$1" | while read -r l d s _; do
    case "$l" in top-3000-[0-9][0-9][0-9][0-9]) ;; *) continue ;; esac
    y=${l#top-3000-}; lo="${y}0531"; hi="$((y + 1))0531"
    for f in "$2"/top-3000-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].sexp; do
      [ -f "$f" ] || continue
      b=$(basename "$f" .sexp); n=$(echo "${b#top-3000-}" | tr -d -)
      { [ "$n" -lt "$lo" ] || [ "$n" -ge "$hi" ]; } && continue
      grep -q -F "(symbol $d)" "$f" && ! grep -q -F "(symbol $s)" "$f" && echo "$b $d $s survivor-absent" >> "$3"
    done
  done
  return 0
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
# Specimen: CMN and CMD are both in top-3000-2009-04-30, whose yearly list in force (2008) holds one leg.
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

# $1 rows ("LIST D S ..."). Fails (exit 1, offending rows on stdout) when a row's survivor is a dropped leg of another
# row in the same list: applying both would delete the instrument from that list.
chained_survivors() {
  awk 'NR == FNR { dropped[$1 " " $2] = 1; next } ($1 " " $3) in dropped { print; bad = 1 } END { exit bad }' "$1" "$1"
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

phase_lists() {
  mkdir -p "$WORK/raw"; y=${FROM%%-*}; last=${TO%%-*}
  while [ "$y" -le "$last" ]; do
    lo="$y-01-01"; hi="$y-12-31"; [ "$y" = "${FROM%%-*}" ] && lo=$FROM; [ "$y" = "$last" ] && hi=$TO
    if [ -f "$WORK/raw/.done-$y" ]; then log "lists $y: done (marker)"; y=$((y + 1)); continue; fi
    d=$CWORK/dated-$y; dx rm -rf "$d"; dx mkdir -p "$d"; t0=$(date +%s)
    dx "$LIST_EXE" --bars-root "$DATA_C" --symbol-types "$DATA_C/symbol_types.sexp" --sectors-csv "$DATA_C/sectors.csv" \
      --inventory "$RUN_TREE/trading/test_data/backtest_scenarios/pit-v12/inventory.sexp" --out-dir "$d" \
      --month-ends "$lo,$hi" --top-n 3000 --true-dollar-volume > "$WORK/lists-$y.log" 2>&1 || die "builder failed for $y (see $WORK/lists-$y.log)"
    grep -q 'skipped=0$' "$WORK/lists-$y.log" || die "builder skipped anchors in $y (see $WORK/lists-$y.log)"
    n=$(sed -n 's/.*written=\([0-9]*\) .*/\1/p' "$WORK/lists-$y.log"); [ "${n:-0}" -gt 0 ] || die "builder wrote no list for $y"
    docker cp "$CONTAINER:$d/." "$WORK/raw/" || die "docker cp $d"; dx rm -rf "$d"
    w=$(( $(date +%s) - t0 )); touch "$WORK/raw/.done-$y"
    log "lists $y: $n lists $lo..$hi (wall ${w}s, $((w / n))s per list)"
    y=$((y + 1))
  done
  log "lists: $(ls "$WORK"/raw/top-3000-*.sexp | wc -l | tr -d ' ') raw lists in $WORK/raw"
}

# Every May 31 list equals pit-v12's yearly list: raw against composition-raw.md5, final against composition/.
check_may31() {
  n=0
  for f in "$WORK"/final/top-3000-[0-9][0-9][0-9][0-9]-05-31.sexp; do
    [ -f "$f" ] || continue
    y=$(basename "$f" | cut -c10-13); b=top-3000-$y.sexp
    want=$(awk -v b="$b" '$2 == b { print $1 }' "$V12/composition-raw.md5")
    got=$(md5 -q "$WORK/raw/top-3000-$y-05-31.sexp" 2>/dev/null || md5sum "$WORK/raw/top-3000-$y-05-31.sexp" | cut -c1-32)
    [ "$want" = "$got" ] || die "raw $y-05-31 md5 $got != pit-v12 composition-raw.md5 $want (builder or store moved)"
    cmp -s "$f" "$V12/composition/$b" || die "final $y-05-31 differs from pit-v12/composition/$b (post-processing moved)"
    n=$((n + 1))
  done
  log "May 31 check: $n lists byte-identical to pit-v12 (raw md5 and final)"
}

phase_post() {
  ls "$WORK"/raw/top-3000-*.sexp >/dev/null 2>&1 || die "no raw lists: run the lists phase"
  rm -rf "$WORK/final"; mkdir -p "$WORK/final"; cp "$WORK"/raw/top-3000-*.sexp "$WORK/final/"
  : > "$WORK/post.log"
  for m in $ALIAS_MAPS; do perl "$ALIAS_PL" "$m" "$WORK"/final/*.sexp >> "$WORK/post.log" || die "alias-lists.pl $m"; done
  map_yearly_drops "$V12/twin-drops.txt" "$WORK/final" "$WORK/drops-yearly-skipped.txt" > "$WORK/drops-yearly-mapped.txt"
  if [ -s "$WORK/drops-yearly-mapped.txt" ]; then
    sh "$TWINX/apply-drops.sh" "$WORK/drops-yearly-mapped.txt" "$WORK/final" >> "$WORK/post.log" || die "apply-drops (yearly rows)"
  fi
  log "post: aliases applied; yearly twin-drops -> $(n_of "$WORK/drops-yearly-mapped.txt") monthly rows applied, $(n_of "$WORK/drops-yearly-skipped.txt") kept (survivor absent)"
  check_may31
  cat "$WORK"/final/*.sexp | cksum > "$WORK/post.stamp"
}

phase_twinscan() {
  [ -s "$WORK/post.stamp" ] || die "run the post phase first"
  cat "$WORK"/final/*.sexp | cksum | cmp -s - "$WORK/post.stamp" || die "$WORK/final changed since post (monthly drops already applied?): rerun post first"
  S=$WORK/twin-scan
  if [ -s "$S/cooccur.txt" ] && cmp -s "$S/stamp" "$WORK/post.stamp"; then log "twinscan: reusing $S (same post lists)"
  else
    rm -rf "$S"; mkdir -p "$S"; t0=$(date +%s)
    DATA=$DATA_H LISTS=$WORK/final sh "$TWINX/twin-scan.sh" "$S" 2>> "$WORK/build.log" || die "twin-scan.sh failed"
    cp "$WORK/post.stamp" "$S/stamp"; log "twinscan: $(n_of "$S/twins.txt") confirmed pairs (wall $(( $(date +%s) - t0 ))s)"
  fi
  [ ! -s "$S/missing-csv.txt" ] || log "twinscan: $(n_of "$S/missing-csv.txt") list symbols have no CSV (e.g. $(head -3 "$S/missing-csv.txt" | tr '\n' ' '))"
  syms_of "$V12"/composition/top-*.sexp | LC_ALL=C sort -u > "$WORK/yearly-union.txt"
  syms_of "$WORK"/final/top-3000-*.sexp | LC_ALL=C sort -u > "$WORK/monthly-union.txt"
  LC_ALL=C comm -23 "$WORK/monthly-union.txt" "$WORK/yearly-union.txt" > "$WORK/monthly-only.txt"
  derive_monthly_drops "$S/twins.txt" "$S/cooccur.txt" "$WORK/monthly-only.txt" "$TWINX/exclude-pairs.txt" > "$WORK/drops-monthly-only.txt"
  derive_monthly_drops "$S/twins.txt" "$S/cooccur.txt" "$WORK/monthly-only.txt" "$TWINX/exclude-pairs.txt" other > "$WORK/cooccur-other.txt"
  ungoverned_cooccur "$WORK/cooccur-other.txt" "$V12/composition" "$WORK/final" > "$WORK/drops-cooccur.txt"
  LC_ALL=C sort "$WORK/drops-monthly-only.txt" "$WORK/drops-cooccur.txt" > "$WORK/drops-monthly.txt"
  chained_survivors "$WORK/drops-monthly.txt" > "$WORK/drops-chained.txt" || die "chained twins (a survivor is also dropped in the same list): $WORK/drops-chained.txt; resolve by hand"
  write_monthly_drops_file
  if [ -s "$WORK/drops-monthly.txt" ]; then sh "$TWINX/apply-drops.sh" "$WORK/drops-monthly.txt" "$WORK/final" >> "$WORK/post.log" || die "apply-drops (monthly rows)"; fi
  report_unhandled "$S"
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

# Post-apply check: no confirmed, non-excluded pair with both legs yearly-listed still co-occurs in a monthly list whose
# yearly list in force holds at most one leg. By construction (the yearly pairs drop in every window, the rest through
# ungoverned_cooccur) the file comes out empty; a row means a drop rule missed a cell, and the phase aborts.
report_unhandled() {
  ungoverned_cooccur "$WORK/cooccur-other.txt" "$V12/composition" "$WORK/final" > "$WORK/cooccur-unhandled.txt"
  { echo "# Expected EMPTY: confirmed twin pairs, both legs in some yearly pit-v12 list, still co-occurring in a monthly"
    echo "# list after every drop rule while the yearly list in force holds at most one leg: LIST LEG_A LEG_B <evidence>."
    cat "$WORK/cooccur-unhandled.txt"; } > "$DEST/twin-cooccur-unhandled.txt"
  [ ! -s "$WORK/cooccur-unhandled.txt" ] || die "$(n_of "$WORK/cooccur-unhandled.txt") ungoverned twin cells survive the drops: $DEST/twin-cooccur-unhandled.txt"
  log "twinscan: no ungoverned twin co-occurrence left ($DEST/twin-cooccur-unhandled.txt holds no rows)"
}

# Both twin-drop files hold on the final lists: no DROPPED leg is back in its list and every survivor is present.
check_drops_hold() {
  for f in "$DEST/twin-drops.txt" "$DEST/twin-drops-monthly.txt"; do
    grep -v '^#' "$f" | while read -r l d s _; do
      [ -n "$l" ] || continue
      ! grep -q -F "(symbol $d)" "$1/$l.sexp" || { echo "$l holds $d again"; exit 1; }
      grep -q -F "(symbol $s)" "$1/$l.sexp" || { echo "$l lacks survivor $s"; exit 1; }
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

phase_install() {
  [ -f "$WORK/drops-monthly.txt" ] && [ "$WORK/drops-monthly.txt" -nt "$WORK/post.stamp" ] || die "run the twinscan phase first"
  mkdir -p "$DEST/composition"; rm -f "$DEST"/composition/top-3000-*.sexp
  cp "$WORK"/final/top-3000-*.sexp "$DEST/composition/"
  { echo "# Yearly pit-v12 twin-drops re-keyed to the monthly lists (build_monthly_universe_warehouse.sh post): LIST DROPPED SURVIVOR"
    cat "$WORK/drops-yearly-mapped.txt"; } > "$DEST/twin-drops.txt"
  check_drops_hold "$DEST/composition"
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

phase_warehouse() {
  wh_syms; W=$WORK/wh
  # chunk markers are only valid for the set they were built from
  echo "$(cksum < "$W/syms.txt") k=$CHUNK_SIZE" > "$W/syms.stamp.new"
  if [ -f "$W/syms.stamp" ]; then cmp -s "$W/syms.stamp" "$W/syms.stamp.new" || die "warehouse set or CHUNK_SIZE changed since the chunk markers in $W were written: remove $OUT and $W/chunk-*"
  else mv "$W/syms.stamp.new" "$W/syms.stamp"; fi
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
  cmp -s "$W/syms.txt" "$W/manifest.txt" || {
    LC_ALL=C comm -3 "$W/syms.txt" "$W/manifest.txt" > "$W/set-diff.txt"
    die "manifest set differs from the lists' warehouse set ($(n_of "$W/set-diff.txt") names, $W/set-diff.txt: col 1 = missing, col 2 = extra)"
  }
  dx sh -c "ls $OUT/*.snap | sed 's#.*/##; s#\\.snap\$##' | LC_ALL=C sort -u" > "$W/snaps.txt"
  cmp -s "$W/manifest.txt" "$W/snaps.txt" || die "manifest entries and .snap files differ (#2724 clobber or orphans; $W/snaps.txt)"
  n_wk=$(dx sh -c "ls $OUT/*.weekly 2>/dev/null | wc -l" | tr -d ' '); [ "$n_wk" -gt 0 ] || die "no .weekly side-table in $OUT"
  m=$(n_of "$W/manifest.txt"); [ "$m" -le "$HANDLE_CAP" ] || log "WARNING: manifest $m > handle cap $HANDLE_CAP: chains on $OUT must export SNAPSHOT_MAX_MMAP_HANDLES >= $m"
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
