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
check "a: the pair also drops where the yearly list in force holds one leg (CMN/CMD in 2009-04-30, the 2008 window) or no row's window applies (2012)" "$SB/want-gap.txt" "$SB/mapped-gap.txt"
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

echo "build_monthly_universe_guard_smoke: $passes passed, $fails failed"
[ "$fails" = 0 ]
