#!/bin/sh
# build_monthly_twin_window_check.sh -- fixture-driven regression for the monthly builder's re-key of the per-list
# pit-v12/twin-drops.txt (#3475, #3388; Codex finding on #3475). dev/scripts/build_monthly_universe_warehouse.sh `post`
# used to apply every named pair to every monthly list holding both legs, whatever the window; with per-window rows
# (MEE/FLR twins in 1998-1999, distinct in 2001) that dropped MEE from the 2001 May 31 list and check_may31 aborted.
#
# Fixture: trading/devtools/checks/fixtures/monthly_twin_window/ -- raw monthly lists in the 1999, 2000 and 2001
# windows, the yearly final lists and composition-raw.md5 they must reproduce, a twin-drops.txt in the per-list shape
# (with a via= chain row and top-1000 rows), and the expected mapped and skipped rows. The script's pure helpers are
# sourced (SM_LIB_ONLY=1); the post phase's map_yearly_drops -> apply-drops.sh -> check_may31 sequence runs on a copy.
# Checks:
#   1. the mapped rows: each top-3000-Y row lands only on the lists of its window [Y-05-31, Y+1-05-31); top-1000 rows
#      are not read; a mid-window list without the resolved survivor drops through the chain it holds (BAC-WS-B leaves
#      for BAC-WS-A), and a leg with no present survivor is kept and reported;
#   2. every May 31 list equals its yearly list byte for byte after the drops (check_may31 passes);
#   3. a pair that is a twin in an early window but distinct later is retained later (MEE in 2000-05-31, 2001-05-31,
#      2001-06-30) and still dropped in its own window (2000-04-30, the 1999 window);
#   4. a survivor cycle fails map_yearly_drops.
#
# Run: sh trading/devtools/checks/build_monthly_twin_window_check.sh
set -eu

. "$(dirname "$0")/_check_lib.sh"
ROOT=$(repo_root)
SCRIPT="$ROOT/dev/scripts/build_monthly_universe_warehouse.sh"
APPLY="$ROOT/dev/experiments/v12-twin-scan-2026-10-22/apply-drops.sh"
FX="$ROOT/trading/devtools/checks/fixtures/monthly_twin_window"

SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT
fails=0; passes=0
ok() { passes=$((passes + 1)); echo "PASS: $1"; }
bad() { fails=$((fails + 1)); echo "FAIL: $1"; }
check() { if cmp -s "$2" "$3"; then ok "$1"; else bad "$1"; diff "$2" "$3" || true; fi; }

WORK=$SB/work; mkdir -p "$WORK"
SM_LIB_ONLY=1
export SM_LIB_ONLY
. "$SCRIPT"

F=$SB/final; mkdir -p "$F"; cp "$FX"/raw/top-3000-*.sexp "$F/"

# 1. mapped and skipped rows
if map_yearly_drops "$FX/twin-drops.txt" "$F" "$SB/skipped.txt" > "$SB/mapped.txt"; then ok "1: map_yearly_drops exits 0"; else bad "1: map_yearly_drops exits 0"; fi
check "1: rows land only in their window, top-1000 rows unread, chains resolved per monthly list" "$FX/want-mapped.txt" "$SB/mapped.txt"
check "1: a leg with no survivor present in its list is kept and reported" "$FX/want-skipped.txt" "$SB/skipped.txt"

# 2. the post phase's apply + May 31 identity
if sh "$APPLY" "$SB/mapped.txt" "$F" > "$SB/apply.log" 2>&1; then ok "2: apply-drops.sh applies the mapped rows"; else bad "2: apply-drops.sh applies the mapped rows"; cat "$SB/apply.log"; fi
if ( check_may31 "$FX/raw" "$F" "$FX/yearly" 3 ) > "$SB/may31.out" 2>&1; then ok "2: every May 31 list equals its yearly list (check_may31)"; else bad "2: every May 31 list equals its yearly list (check_may31)"; cat "$SB/may31.out"; fi

# 3. window-specific twins: MEE leaves only in the 1999 window
for l in 2000-05-31 2001-05-31 2001-06-30; do
  if grep -q -F '(symbol MEE)' "$F/top-3000-$l.sexp"; then ok "3: MEE retained in $l (distinct after the 1999 window)"; else bad "3: MEE retained in $l (distinct after the 1999 window)"; fi
done
for l in 1999-05-31 1999-08-31 2000-04-30; do
  if grep -q -F '(symbol MEE)' "$F/top-3000-$l.sexp"; then bad "3: MEE dropped in $l (the 1999 window)"; else ok "3: MEE dropped in $l (the 1999 window)"; fi
done
if grep -q -F '(symbol BAC-WS-A)' "$F/top-3000-1999-08-31.sexp" && ! grep -q -F '(symbol BAC-WS-B)' "$F/top-3000-1999-08-31.sexp"; then
  ok "3: mid-window list without BAC keeps one copy (BAC-WS-A)"
else bad "3: mid-window list without BAC keeps one copy (BAC-WS-A)"; fi

# 4. a survivor cycle fails
C=$SB/cyc; mkdir -p "$C"; cp "$FX/raw/top-3000-1999-05-31.sexp" "$C/"
printf 'top-3000-1999 MEE FLR\ntop-3000-1999 FLR MEE\n' > "$SB/cycle.txt"
if map_yearly_drops "$SB/cycle.txt" "$C" "$SB/cyc-skipped.txt" > /dev/null 2>&1; then bad "4: a survivor cycle fails"; else ok "4: a survivor cycle fails"; fi

echo "build_monthly_twin_window_check: $passes passed, $fails failed"
[ "$fails" = 0 ]
