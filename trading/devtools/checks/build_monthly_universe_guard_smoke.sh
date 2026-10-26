#!/bin/sh
# build_monthly_universe_guard_smoke.sh -- dry harness for the list-side rules of
# dev/scripts/build_monthly_universe_warehouse.sh (arm SM prerequisite 3). The build itself takes hours in the
# container, so the script's pure helpers are sourced (SM_LIB_ONLY=1) and run on fixture lists:
#   a. map_yearly_drops: a pair named by a yearly row drops D from every monthly list holding D and S, whatever the
#      window (CMN/CMD in top-3000-2009-04-30, the 2008 window); an in-window list holding D without S is kept and
#      reported.
#   b. derive_monthly_drops: only pairs with a monthly-only leg drop, excluded pairs never, one row per co-occurring
#      list, carrying the scan's evidence; mode `other` returns the complementary (both-legs-yearly) pairs.
#   b2. ungoverned_cooccur: a both-legs-yearly pair drops where the yearly list in force holds at most one leg, never
#      where it holds both.
#   c. chained_survivors: a survivor that is also dropped in the same list fails; in another list it passes.
#   d. write_schedule: one dated entry per monthly list, ascending; yearly-named files are ignored.
#   e. warehouse_set: list union - MEL + GSPC.INDX + runner extras, sorted unique.
# and the abort guards, each case in a subshell (die exits):
#   f. pin_md5: match passes; mismatch aborts and leaves the pin; REPIN=1 re-pins; a missing pin is written.
#   g. check_may31: identical passes; raw md5, final bytes or May 31 count off aborts; month_ends counts.
#   h. report_unhandled: a surviving ungoverned cell aborts; none passes.
#   i. set_equal (verify): equal passes; an extra name, or a manifest name with no .weekly, fails.
#   j. check_drops_hold: a dropped leg still listed, or a missing survivor, aborts.
#   k. lists resume: a smoke run's marker never stands in for a full run; the list set must be the exact month ends.
#   l. warehouse stamp: a changed WH_START, WH_END or exceptions file rejects the old markers and output; an existing
#      $OUT without its stamp, or with another, aborts (check_out_stamp).
#   m. check_twinscan_done: install refuses a missing or stale twinscan completion stamp, accepts a matching one.
#
# Run: sh trading/devtools/checks/build_monthly_universe_guard_smoke.sh
set -eu

. "$(dirname "$0")/_check_lib.sh"
SCRIPT="$(repo_root)/dev/scripts/build_monthly_universe_warehouse.sh"

SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT
fails=0; passes=0
ok() { passes=$((passes + 1)); echo "PASS: $1"; }
bad() { fails=$((fails + 1)); echo "FAIL: $1"; }
# check <desc> <expected file> <actual file>
check() { if cmp -s "$2" "$3"; then ok "$1"; else bad "$1"; diff "$2" "$3" || true; fi; }

WORK=$SB/work; mkdir -p "$WORK"
SM_LIB_ONLY=1
export SM_LIB_ONLY
. "$SCRIPT"

# list <file> <symbol>...: a composition list fixture
list() { f=$1; shift; { echo "((entries ("; for s in "$@"; do echo "  ((symbol $s) (sector \"X\"))"; done; echo ")))"; } > "$f"; }

# --- a. yearly pairs drop in every list holding both legs, whatever the window ----------------------------------------
L=$SB/lists; mkdir -p "$L"
list "$L/top-3000-2009-04-30.sexp" CMN CMD A
list "$L/top-3000-2009-05-31.sexp" CMN CMD A
list "$L/top-3000-2010-05-31.sexp" CMN A
list "$L/top-3000-2010-06-30.sexp" CMN CMD
list "$L/top-3000-2012-01-31.sexp" CMN CMD
list "$L/top-3000-2012-02-29.sexp" A CMD
printf '# comment\ntop-3000-2009 CMN CMD\ntop-3000-2010 CMN CMD\n' > "$SB/drops.txt"
map_yearly_drops "$SB/drops.txt" "$L" "$SB/skipped.txt" > "$SB/mapped.txt"
printf 'top-3000-2009-05-31 CMN CMD\ntop-3000-2010-06-30 CMN CMD\n' > "$SB/want-in-window.txt"
grep -v -e 2009-04-30 -e 2012-01-31 "$SB/mapped.txt" > "$SB/mapped-in-window.txt" || true
check "a: a row lands on its [Y-05-31, Y+1-05-31) lists holding both legs" "$SB/want-in-window.txt" "$SB/mapped-in-window.txt"
printf 'top-3000-2009-04-30 CMN CMD\ntop-3000-2012-01-31 CMN CMD\n' > "$SB/want-gap.txt"
grep -e 2009-04-30 -e 2012-01-31 "$SB/mapped.txt" > "$SB/mapped-gap.txt" || true
check "a: the pair also drops where the yearly list in force holds at most one leg (CMN/CMD in 2009-04-30, the 2008 window) or no row's window applies (2012)" "$SB/want-gap.txt" "$SB/mapped-gap.txt"
echo 'top-3000-2010-05-31 CMN CMD survivor-absent' > "$SB/want-skipped.txt"
check "a: an in-window list holding D without its survivor is kept and reported; a list holding only S is untouched" "$SB/want-skipped.txt" "$SB/skipped.txt"

# --- b. monthly-only pairs --------------------------------------------------------------------------------------------
printf 'X Y overlap=300 match=0.99 rule=fraction\nA B overlap=400 match=0.97 rule=fraction\nGOOG GOOGL overlap=900 rule=run\nP Q overlap=250 rule=run\n' > "$SB/twins.txt"
printf 'X Y: L1 L2\nA B: L1\nGOOG GOOGL: L2\nP Q: none\n' > "$SB/cooccur.txt"
printf 'GOOGL\nQ\nY\n' > "$SB/only.txt"
printf '# share classes\nGOOGL GOOG\n' > "$SB/excl.txt"
derive_monthly_drops "$SB/twins.txt" "$SB/cooccur.txt" "$SB/only.txt" "$SB/excl.txt" > "$SB/drops-m.txt"
printf 'L1 X Y overlap=300 match=0.99 rule=fraction\nL2 X Y overlap=300 match=0.99 rule=fraction\n' > "$SB/want-m.txt"
check "b: a monthly-only pair drops in every co-occurring list with its evidence; excluded and none-lists never" "$SB/want-m.txt" "$SB/drops-m.txt"
derive_monthly_drops "$SB/twins.txt" "$SB/cooccur.txt" "$SB/only.txt" "$SB/excl.txt" other > "$SB/other.txt"
echo 'L1 A B overlap=400 match=0.97 rule=fraction' > "$SB/want-other.txt"
check "b: mode other returns only the both-legs-yearly pairs" "$SB/want-other.txt" "$SB/other.txt"

# --- b2. both-legs-yearly pairs drop only where the yearly list in force holds at most one leg ------------------------
Y=$SB/yearly; M=$SB/monthly; mkdir -p "$Y" "$M"
list "$Y/top-3000-2008.sexp" A Z; list "$Y/top-3000-2009.sexp" A B
list "$M/top-3000-2009-04-30.sexp" A B; list "$M/top-3000-2009-05-31.sexp" A B; list "$M/top-3000-2009-06-30.sexp" A B
list "$M/top-3000-2007-08-31.sexp" A B; list "$M/top-3000-2009-03-31.sexp" A
printf 'top-3000-2009-04-30 A B ev=1\ntop-3000-2009-05-31 A B ev=1\ntop-3000-2009-06-30 A B ev=1\ntop-3000-2007-08-31 A B\ntop-3000-2009-03-31 A B ev=1\n' > "$SB/other-rows.txt"
ungoverned_cooccur "$SB/other-rows.txt" "$Y" "$M" > "$SB/ungoverned.txt"
printf 'top-3000-2009-04-30 A B ev=1\ntop-3000-2007-08-31 A B\n' > "$SB/want-ungoverned.txt"
check "b2: drops where the yearly list in force holds one leg or none exists; never where it holds both (May 31 keeps its bytes)" "$SB/want-ungoverned.txt" "$SB/ungoverned.txt"

# --- c. chained survivors ---------------------------------------------------------------------------------------------
printf 'L1 X Y\nL1 Y Z\n' > "$SB/chain.txt"
if chained_survivors "$SB/chain.txt" > /dev/null; then bad "c: a survivor dropped in the same list must fail"; else ok "c: a survivor dropped in the same list fails"; fi
printf 'L1 X Y\nL2 Y Z\n' > "$SB/nochain.txt"
if chained_survivors "$SB/nochain.txt" > /dev/null; then ok "c: the same symbols in different lists pass"; else bad "c: different lists must pass"; fi

# --- d. schedule ------------------------------------------------------------------------------------------------------
S=$SB/sched; mkdir -p "$S"
list "$S/top-3000-2009-06-30.sexp" A; list "$S/top-3000-2009-05-31.sexp" A; list "$S/top-3000-2009.sexp" A
write_schedule "$S" > "$SB/sched.sexp"
printf '(universe_schedule (\n  (2009-05-31 "pit-v12-monthly/composition/top-3000-2009-05-31.sexp")\n  (2009-06-30 "pit-v12-monthly/composition/top-3000-2009-06-30.sexp")\n  ))\n' > "$SB/want-sched.sexp"
check "d: one ascending dated entry per monthly list; the yearly-named file is ignored" "$SB/want-sched.sexp" "$SB/sched.sexp"

# --- e. warehouse set -------------------------------------------------------------------------------------------------
E=$SB/wh; mkdir -p "$E"
list "$E/top-3000-2009-05-31.sexp" MEL BBB AAA; list "$E/top-3000-2009-06-30.sexp" AAA CCC
printf 'XLK\nSPY\n' > "$SB/extras.txt"
warehouse_set "$E" "$SB/extras.txt" > "$SB/set.txt"
printf 'AAA\nBBB\nCCC\nGSPC.INDX\nSPY\nXLK\n' > "$SB/want-set.txt"
check "e: union - MEL + GSPC.INDX + extras, sorted unique" "$SB/want-set.txt" "$SB/set.txt"

# --- guards: each case runs in a subshell, because die exits ---------------------------------------------------------
expect_pass() { d=$1; shift; if ( "$@" ) > "$SB/guard.out" 2>&1; then ok "$d"; else bad "$d"; cat "$SB/guard.out"; fi; }
expect_abort() { d=$1; shift; if ( "$@" ) > "$SB/guard.out" 2>&1; then bad "$d"; cat "$SB/guard.out"; else ok "$d"; fi; }

# --- f. pin_md5 -------------------------------------------------------------------------------------------------------
P=$SB/pin; mkdir -p "$P"
echo 'aaa  top-3000-2009-05-31.sexp' > "$P/new.md5"; cp "$P/new.md5" "$P/pinned.md5"
expect_pass "f: pin_md5 passes when the rebuild matches the pinned md5s" pin_md5 "$P/new.md5" "$P/pinned.md5"
echo 'bbb  top-3000-2009-05-31.sexp' > "$P/other.md5"
expect_abort "f: pin_md5 aborts on a rebuild that differs" pin_md5 "$P/other.md5" "$P/pinned.md5"
check "f: the aborted pin leaves the pinned file unchanged" "$P/new.md5" "$P/pinned.md5"
repin() { REPIN=1; pin_md5 "$@"; }   # REPIN stays inside expect_pass's subshell
expect_pass "f: REPIN=1 re-pins a differing rebuild" repin "$P/other.md5" "$P/pinned.md5"
check "f: REPIN=1 overwrites the pinned file" "$P/other.md5" "$P/pinned.md5"
expect_pass "f: a missing pin file is written" pin_md5 "$P/new.md5" "$P/first.md5"
check "f: the written pin file is the rebuild's" "$P/new.md5" "$P/first.md5"

# --- g. check_may31 ---------------------------------------------------------------------------------------------------
R=$SB/m31/raw; F=$SB/m31/final; V=$SB/m31/v12; mkdir -p "$R" "$F" "$V/composition"
list "$R/top-3000-2009-05-31.sexp" A B MEL; list "$F/top-3000-2009-05-31.sexp" A B; list "$F/top-3000-2009-06-30.sexp" A
cp "$F/top-3000-2009-05-31.sexp" "$V/composition/top-3000-2009.sexp"
echo "$(md5_file "$R/top-3000-2009-05-31.sexp")  top-3000-2009.sexp" > "$V/composition-raw.md5"
expect_pass "g: check_may31 passes on byte-identical raw and final May 31 lists (non-May lists ignored)" check_may31 "$R" "$F" "$V" 1
expect_abort "g: check_may31 aborts when the May 31 count differs from the range's" check_may31 "$R" "$F" "$V" 2
cp "$R/top-3000-2009-05-31.sexp" "$SB/m31/raw-keep.sexp"; list "$R/top-3000-2009-05-31.sexp" A B MEL Z
expect_abort "g: check_may31 aborts on a raw md5 mismatch" check_may31 "$R" "$F" "$V" 1
cp "$SB/m31/raw-keep.sexp" "$R/top-3000-2009-05-31.sexp"; list "$F/top-3000-2009-05-31.sexp" A
expect_abort "g: check_may31 aborts on a final-bytes mismatch" check_may31 "$R" "$F" "$V" 1
month_ends 1999-05-31 2025-12-31 | wc -l | tr -d ' ' > "$SB/n-ends.txt"; may31_count 1999-05-31 2025-12-31 >> "$SB/n-ends.txt"
month_ends 2100-01-31 2100-03-30 >> "$SB/n-ends.txt"
printf '320\n27\n2100-01-31\n2100-02-28\n' > "$SB/want-n-ends.txt"
check "g: the default range holds 320 month ends and 27 May 31s; 2100 is not a leap year" "$SB/want-n-ends.txt" "$SB/n-ends.txt"

# --- h. report_unhandled ----------------------------------------------------------------------------------------------
expect_abort "h: report_unhandled aborts when an ungoverned twin cell survives" report_unhandled "$SB/other-rows.txt" "$Y" "$M" "$SB/unhandled.txt"
grep -v '^#' "$SB/unhandled.txt" > "$SB/unhandled-rows.txt" || true
check "h: the report names the surviving cells" "$SB/want-ungoverned.txt" "$SB/unhandled-rows.txt"
: > "$SB/no-rows.txt"
expect_pass "h: report_unhandled passes when no cell survives" report_unhandled "$SB/no-rows.txt" "$Y" "$M" "$SB/unhandled-none.txt"

# --- i. set_equal: the verify comparisons (manifest vs list set, .snap and .weekly vs manifest) ------------------------
printf 'A\nB\nC\n' > "$SB/want-set3.txt"
printf 'A\nB\nC\n' > "$SB/got-eq.txt"; expect_pass "i: equal sets pass" set_equal "$SB/want-set3.txt" "$SB/got-eq.txt" "$SB/sd.txt"
printf 'A\nB\nC\nD\n' > "$SB/got-extra.txt"; expect_abort "i: an extra name fails" set_equal "$SB/want-set3.txt" "$SB/got-extra.txt" "$SB/sd.txt"
printf 'A\nC\n' > "$SB/weekly.txt"; expect_abort "i: a manifest name with no .weekly side-table fails" set_equal "$SB/want-set3.txt" "$SB/weekly.txt" "$SB/wd.txt"
echo B > "$SB/want-wd.txt"
check "i: the diff names the symbol missing its .weekly" "$SB/want-wd.txt" "$SB/wd.txt"

# --- j. check_drops_hold ----------------------------------------------------------------------------------------------
H=$SB/hold; mkdir -p "$H"; list "$H/top-3000-2009-06-30.sexp" CMN A
printf '# header\ntop-3000-2009-06-30 CMD CMN\n' > "$H/drops.txt"
expect_pass "j: check_drops_hold passes when the dropped leg is gone and the survivor present" check_drops_hold "$H" "$H/drops.txt"
printf 'top-3000-2009-06-30 A CMN\n' > "$H/back.txt"
expect_abort "j: check_drops_hold aborts when a dropped leg is still in its list" check_drops_hold "$H" "$H/drops.txt" "$H/back.txt"
printf 'top-3000-2009-06-30 CMD XYZ\n' > "$H/nosurv.txt"
expect_abort "j: check_drops_hold aborts when the survivor is missing" check_drops_hold "$H" "$H/nosurv.txt"

# --- k. list resume: a smoke run's markers never stand in for a full run ----------------------------------------------
K=$SB/resume; mkdir -p "$K"
for d in 2009-04-30 2009-05-31 2009-06-30; do list "$K/top-3000-$d.sexp" A; done
write_list_marker "$K" 2009 2009-04-01 2009-06-30 prov1
lists_plan 2009-04-01 2009-06-30 "$K" prov1 > "$SB/plan-smoke.txt"
check "k: a rerun of the smoke range reuses its marker" /dev/null "$SB/plan-smoke.txt"
expect_pass "k: the smoke range's lists are exactly its month ends" check_list_set "$K" 2009-04-01 2009-06-30
lists_plan 2008-12-31 2009-12-31 "$K" prov1 > "$SB/plan-full.txt"
printf '2008 2008-12-31 2008-12-31\n2009 2009-01-01 2009-12-31\n' > "$SB/want-plan-full.txt"
check "k: a full run after the smoke rebuilds 2009 (marker for other bounds) and builds 2008" "$SB/want-plan-full.txt" "$SB/plan-full.txt"
expect_abort "k: the smoke's partial 2009 fails the full range's list-set check" check_list_set "$K" 2008-12-31 2009-12-31
for d in $(month_ends 2008-12-31 2009-12-31); do list "$K/top-3000-$d.sexp" A; done
write_list_marker "$K" 2008 2008-12-31 2008-12-31 prov1; write_list_marker "$K" 2009 2009-01-01 2009-12-31 prov1
lists_plan 2008-12-31 2009-12-31 "$K" prov1 > "$SB/plan-done.txt"
check "k: once the full run has written its markers nothing is rebuilt" /dev/null "$SB/plan-done.txt"
expect_pass "k: the full range's lists are exactly its month ends" check_list_set "$K" 2008-12-31 2009-12-31
lists_plan 2008-12-31 2009-12-31 "$K" prov2 > "$SB/plan-prov.txt"
check "k: changed inputs rebuild every year" "$SB/want-plan-full.txt" "$SB/plan-prov.txt"
expect_abort "k: lists left over from a wider range fail a narrower range's check" check_list_set "$K" 2009-04-01 2009-06-30

# --- l. warehouse resume stamp ----------------------------------------------------------------------------------------
L2=$SB/stamp; mkdir -p "$L2"; printf 'A\nGSPC.INDX\n' > "$L2/syms.txt"; echo '(exceptions ())' > "$L2/exc.sexp"
wh_stamp "$L2/syms.txt" 2500 1998-01-01 2026-10-07 "$L2/exc.sexp" abc > "$L2/old.stamp"
wh_stamp "$L2/syms.txt" 2500 1998-01-01 2026-10-07 "$L2/exc.sexp" abc > "$L2/same.stamp"
expect_pass "l: the same build reuses its markers" stamp_compatible "$L2/old.stamp" "$L2/same.stamp"
expect_pass "l: no recorded stamp is a fresh build" stamp_compatible "$L2/absent.stamp" "$L2/same.stamp"
wh_stamp "$L2/syms.txt" 2500 1998-01-01 2026-12-31 "$L2/exc.sexp" abc > "$L2/end.stamp"
expect_abort "l: a changed WH_END rejects the old markers and output" stamp_compatible "$L2/old.stamp" "$L2/end.stamp"
wh_stamp "$L2/syms.txt" 2500 2000-01-01 2026-10-07 "$L2/exc.sexp" abc > "$L2/start.stamp"
expect_abort "l: a changed WH_START rejects them" stamp_compatible "$L2/old.stamp" "$L2/start.stamp"
echo '(exceptions (X))' > "$L2/exc.sexp"; wh_stamp "$L2/syms.txt" 2500 1998-01-01 2026-10-07 "$L2/exc.sexp" abc > "$L2/exc.stamp"
expect_abort "l: changed tail exceptions reject them" stamp_compatible "$L2/old.stamp" "$L2/exc.stamp"
# $OUT side: an existing $OUT is reused only under its own copy of the same stamp
expect_abort "l: an existing \$OUT without a build stamp aborts" check_out_stamp OUT "$L2/absent.stamp" "$L2/same.stamp"
: > "$L2/empty.stamp"
expect_abort "l: an existing \$OUT with an empty build stamp aborts" check_out_stamp OUT "$L2/empty.stamp" "$L2/same.stamp"
expect_abort "l: an existing \$OUT with another build stamp aborts" check_out_stamp OUT "$L2/end.stamp" "$L2/same.stamp"
expect_pass "l: an existing \$OUT with the same build stamp is reused" check_out_stamp OUT "$L2/old.stamp" "$L2/same.stamp"

# --- m. install requires a completed twinscan on the current lists and drops ------------------------------------------
T=$SB/twindone; mkdir -p "$T/final"; list "$T/final/top-3000-2009-06-30.sexp" CMN A
printf '# header\ntop-3000-2009-06-30 CMD CMN\n' > "$T/drops.txt"
expect_abort "m: install aborts with no twinscan completion stamp (an aborted twinscan writes none)" check_twinscan_done "$T/final" "$T/drops.txt" "$T/twinscan.done"
twinscan_stamp "$T/final" "$T/drops.txt" > "$T/twinscan.done"
expect_pass "m: install accepts a stamp matching the current lists and drops" check_twinscan_done "$T/final" "$T/drops.txt" "$T/twinscan.done"
list "$T/final/top-3000-2009-06-30.sexp" CMN CMD A
expect_abort "m: install aborts on a stale stamp (the lists changed since the twinscan)" check_twinscan_done "$T/final" "$T/drops.txt" "$T/twinscan.done"
list "$T/final/top-3000-2009-06-30.sexp" CMN A; echo 'top-3000-2009-06-30 X Y' >> "$T/drops.txt"
expect_abort "m: install aborts on a stale stamp (the drop evidence changed since the twinscan)" check_twinscan_done "$T/final" "$T/drops.txt" "$T/twinscan.done"

echo "build_monthly_universe_guard_smoke: $passes passed, $fails failed"
[ "$fails" = 0 ]
