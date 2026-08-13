#!/bin/sh
# Fixture-driven self-test for linter_file_length.sh's `.mli` signature-line
# counting (H-MLI-FILE-LENGTH-BLIND-SPOT, P0.1, filed
# dev/notes/next-session-priorities-2026-08-14.md).
#
# linter_file_length.sh's `.mli` handling is non-trivial: it strips
# `(* ... *)` comment blocks (including NESTED ones, via a depth counter)
# and blank lines before comparing against the 300/500 line limits, rather
# than using raw `wc -l` like the pre-existing `.ml` handling. That metric
# choice is the entire point of the fix (see the linter's own header for
# the raw-vs-signature measurement that drove it) and had no fixture
# coverage before this. This test builds real fixture "trading dirs" under
# `mktemp -d` (a private copy of the linter + _check_lib.sh, two directory
# levels below a `lib/` containing crafted `.mli` files) and exercises the
# three cases the P0.1 brief requires plus one large-module-marker parity
# check:
#
#   A. Raw-line count exceeds 300 but signature-line count does not -> must
#      PASS. This is the exact P0.1 bug: a naive `.mli` fix that reused
#      `.ml`'s raw `wc -l` would flag this file (312 raw lines, one big doc
#      comment) even though it has only 2 real signature lines. Mutation
#      that reddens this fixture: use `wc -l` (or any metric that does not
#      strip comment-block content) for `.mli` instead of
#      `_mli_signature_line_count`.
#
#   B. Signature-line count exceeds 300 (310 real `val` lines, negligible
#      comment content) -> must FAIL, violator named in output. Mutation
#      that greens this fixture: an over-aggressive stripper that treats
#      real code as comment/blank content (e.g. stripping on any line
#      containing "(" rather than only inside a genuine `(* ... *)` span).
#
#   C. Nested comment `(* outer (* inner *) still outer *)` spanning many
#      lines -> the correctly-parsed signature count is 2 (well under the
#      300 limit) -> must PASS. Mutation that reddens this fixture: a
#      boolean in/out-of-comment toggle instead of a depth counter -- the
#      toggle closes the comment at the FIRST "*)" (the inner one),
#      leaking the 305 filler lines between the inner close and the outer
#      close as if they were real code. Verified by hand while writing this
#      test: the depth-counter implementation counts 2 signature lines on
#      this fixture; a boolean-toggle implementation of the identical
#      algorithm counts 307 on the identical input -- crossing the 300
#      threshold in the wrong direction. See linter_file_length.sh's
#      `_mli_signature_line_count` header comment for the full nested-vs-
#      naive walkthrough.
#
#   D. `@large-module` marker parity for `.mli`: a file with 350 signature
#      lines (> 300 soft limit, < 500 hard limit) marked `@large-module`
#      must PASS (opted into the 300-500 band, same as `.ml`); the
#      identical file WITHOUT the marker must FAIL. Mutation that reddens
#      the PASS half: the `.mli` loop not checking for the marker at all,
#      or checking it against the wrong limit constant.
#
#   E. SEPARATE-POPULATION MAX_LARGE_PCT cap, both directions. The linter's
#      header ("Why .ml and .mli populations are tracked separately")
#      claims the 11% opt-out cap is applied to each population
#      independently, precisely so that one population's `@large-module`
#      markers cannot subsidize the other's opt-out budget. Fixtures A-D
#      never exercise that claim: each uses a single population, and D1
#      deliberately keeps the marked share at 10% so the cap stays out of
#      the way. E pins it directly, and is constructed so it can ONLY be
#      green under separate tracking:
#
#        E1: 2 marked-large `.mli` out of 10 `.mli` (20% > 11% -> the
#            `.mli` cap must trip) alongside 9 clean, unmarked `.ml`
#            files. POOLED, that is 2 large of 19 total = 10.5%, UNDER
#            the 11% cap -- so a linter that summed both populations into
#            one TOTAL/LARGE_COUNT pair would report OK and let 20% of
#            the `.mli` population opt out, subsidized by the clean `.ml`
#            files. Mutation that greens E1: pooling the counters.
#            Verified by hand while writing this test -- replacing the
#            `.mli` cap condition's `LARGE_COUNT_MLI`/`TOTAL_MLI` with
#            `(LARGE_COUNT_MLI + LARGE_COUNT)`/`(TOTAL_MLI + TOTAL)` and
#            re-running turns E1 (and only E1) red: the mutant exits 0
#            with `OK: ... 2 declared-large of 10 total`.
#        E2: the mirror image (2 marked-large `.ml` of 10 `.ml`, 9 clean
#            `.mli`) -- the `.ml` cap must trip on the same pooled-vs-
#            separate arithmetic. E2 exists because the header's claim is
#            symmetric ("and vice versa"); E1 alone would leave the `.ml`
#            direction unpinned.
#
#      Both halves also assert WHICH cap message is emitted (`Too many
#      declared-large .mli files:` vs `Too many declared-large files:`), so
#      a linter that trips the wrong population's cap -- e.g. by counting
#      `.mli` markers into the `.ml` pair -- fails rather than passing on a
#      coincidentally-non-zero exit. The marked files are deliberately
#      TINY (5 signature lines), well under the 300 soft limit, so the only
#      thing that can fail these fixtures is the cap check itself and not a
#      per-file length violation.
#
# How to re-verify by hand:
#   sh trading/devtools/checks/linter_file_length_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

LINTER="$(dirname "$0")/linter_file_length.sh"
LIB="$(dirname "$0")/_check_lib.sh"
[ -f "$LINTER" ] || die "linter_file_length_test: $LINTER not found"

PASS=0
FAIL=0

ok() {
  printf 'OK: %s\n' "$1"
  PASS=$((PASS + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

BASE_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$BASE_DIR"
}
trap cleanup EXIT INT TERM

# Private fixture "trading dir": a copy of the linter + _check_lib.sh two
# directory levels below the fixture root (mirrors the real
# trading/devtools/checks/ layout), so trading_dir()'s `$(dirname "$0")/../..`
# resolves to the fixture root. $1 = fixture root to create.
make_fixture_trading_dir() {
  mkdir -p "$1/devtools/checks" "$1/lib"
  cp "$LINTER" "$1/devtools/checks/linter_file_length.sh"
  cp "$LIB" "$1/devtools/checks/_check_lib.sh"
}

run_linter() {
  # $1 = fixture root
  sh "$1/devtools/checks/linter_file_length.sh"
}

# =============================================================================
# Fixture A: raw > 300, signature-line count <= 300 -> PASS (the P0.1 bug,
# reversed: a naive raw-wc-l `.mli` check would fail this file)
# =============================================================================

FIXA="${BASE_DIR}/fixA"
make_fixture_trading_dir "$FIXA"
{
  echo "(*"
  i=1
  while [ "$i" -le 308 ]; do
    echo "  doc line $i of a long module docstring"
    i=$((i + 1))
  done
  echo "*)"
  echo "val a : int"
  echo "val b : int"
} > "${FIXA}/lib/big_doc_small_sig.mli"

set +e
OUTA=$(run_linter "$FIXA" 2>&1)
CODEA=$?
set -e

RAWA=$(wc -l < "${FIXA}/lib/big_doc_small_sig.mli")
if [ "$RAWA" -le 300 ]; then
  bad "fixture A setup — expected raw line count > 300, got ${RAWA} (fixture construction bug)"
elif [ "$CODEA" -eq 0 ] && echo "$OUTA" | grep -q "^OK:"; then
  ok "fixture A — raw ${RAWA} lines / 2 signature lines -> PASS (comment-block content correctly excluded)"
else
  bad "fixture A — expected exit 0 (2 signature lines, well under 300); got exit=$CODEA output=<<$OUTA>>"
fi

# =============================================================================
# Fixture B: signature-line count > 300 (310 real `val` lines) -> FAIL,
# violator named in output
# =============================================================================

FIXB="${BASE_DIR}/fixB"
make_fixture_trading_dir "$FIXB"
{
  i=1
  while [ "$i" -le 310 ]; do
    echo "val f${i} : int"
    i=$((i + 1))
  done
} > "${FIXB}/lib/oversized_sig.mli"

set +e
OUTB=$(run_linter "$FIXB" 2>&1)
CODEB=$?
set -e

if [ "$CODEB" -ne 0 ] && echo "$OUTB" | grep -q "oversized_sig.mli.*310 signature lines"; then
  ok "fixture B — 310 real signature lines -> FAIL, names oversized_sig.mli with the correct count"
else
  bad "fixture B — expected non-zero exit naming oversized_sig.mli (310 signature lines); got exit=$CODEB output=<<$OUTB>>"
fi

# =============================================================================
# Fixture C: nested comment spanning many lines -> signature count is 2
# (well under 300) -> PASS. Pins the depth-counter (not boolean-toggle)
# nested-comment semantics -- see file header for the hand-verified naive
# count (307) on this exact input.
# =============================================================================

FIXC="${BASE_DIR}/fixC"
make_fixture_trading_dir "$FIXC"
{
  echo "(* top doc *)"
  echo "val a : int"
  echo "(* outer start (* inner *)"
  i=1
  while [ "$i" -le 305 ]; do
    echo "leaked_line_${i}"
    i=$((i + 1))
  done
  echo "still outer *)"
  echo "val b : int"
} > "${FIXC}/lib/nested_comment.mli"

set +e
OUTC=$(run_linter "$FIXC" 2>&1)
CODEC=$?
set -e

if [ "$CODEC" -eq 0 ] && echo "$OUTC" | grep -q "^OK:"; then
  ok "fixture C — nested (* outer (* inner *) still outer *) spanning 305 filler lines -> PASS (2 real signature lines, depth-counter semantics)"
else
  bad "fixture C — expected exit 0 (2 signature lines under correct nested-comment parsing); got exit=$CODEC output=<<$OUTC>>"
fi

# =============================================================================
# Fixture D: @large-module marker parity for .mli -- 350 signature lines
# (between the 300 soft and 500 hard limits) PASSES only with the marker
# =============================================================================

FIXD1="${BASE_DIR}/fixD1"
make_fixture_trading_dir "$FIXD1"
{
  echo "(* @large-module: fixture pins marker parity between .ml and .mli *)"
  i=1
  while [ "$i" -le 350 ]; do
    echo "val f${i} : int"
    i=$((i + 1))
  done
} > "${FIXD1}/lib/marked_large.mli"
# 9 small, unmarked sibling .mli files so the declared-large population is
# 1/10 = 10% -- under the 11% MAX_LARGE_PCT cap. Without these, the single
# marked file alone would be 1/1 = 100% and trip the cap check instead of
# exercising the per-file limit this fixture targets.
i=1
while [ "$i" -le 9 ]; do
  echo "val small${i} : int" > "${FIXD1}/lib/small${i}.mli"
  i=$((i + 1))
done

set +e
OUTD1=$(run_linter "$FIXD1" 2>&1)
CODED1=$?
set -e

if [ "$CODED1" -eq 0 ] && echo "$OUTD1" | grep -q "^OK:"; then
  ok "fixture D1 — 350 signature lines WITH @large-module marker -> PASS"
else
  bad "fixture D1 — expected exit 0 (350 signature lines, marker present, under 500 hard limit); got exit=$CODED1 output=<<$OUTD1>>"
fi

FIXD2="${BASE_DIR}/fixD2"
make_fixture_trading_dir "$FIXD2"
{
  i=1
  while [ "$i" -le 350 ]; do
    echo "val f${i} : int"
    i=$((i + 1))
  done
} > "${FIXD2}/lib/unmarked_large.mli"

set +e
OUTD2=$(run_linter "$FIXD2" 2>&1)
CODED2=$?
set -e

if [ "$CODED2" -ne 0 ] && echo "$OUTD2" | grep -q "unmarked_large.mli.*350 signature lines"; then
  ok "fixture D2 — identical 350 signature lines WITHOUT @large-module marker -> FAIL"
else
  bad "fixture D2 — expected non-zero exit naming unmarked_large.mli (350 signature lines, no marker, over 300 soft limit); got exit=$CODED2 output=<<$OUTD2>>"
fi

# =============================================================================
# Fixture E: the 11% declared-large cap is applied PER POPULATION, so one
# population's clean files cannot subsidize the other's opt-out budget.
# Both halves are built so the pooled count (2 large / 19 total = 10.5%)
# sits UNDER the cap while the offending population's own share (2/10 =
# 20%) sits over it -- the fixture is red only under separate tracking.
# =============================================================================

# Writes $2 tiny `@large-module`-marked and $3 tiny unmarked files with
# extension $4 into $1/lib. 5 signature lines each: far under the 300 soft
# limit, so only the cap check can fire.
write_marked_population() {
  fixture_root=$1
  marked=$2
  unmarked=$3
  ext=$4
  i=1
  while [ "$i" -le "$marked" ]; do
    {
      echo "(* @large-module: fixture pins the per-population opt-out cap *)"
      echo "val a : int"
      echo "val b : int"
      echo "val c : int"
      echo "val d : int"
      echo "val e : int"
    } > "${fixture_root}/lib/marked${i}.${ext}"
    i=$((i + 1))
  done
  i=1
  while [ "$i" -le "$unmarked" ]; do
    echo "val small${i} : int" > "${fixture_root}/lib/clean${i}.${ext}"
    i=$((i + 1))
  done
}

FIXE1="${BASE_DIR}/fixE1"
make_fixture_trading_dir "$FIXE1"
write_marked_population "$FIXE1" 2 8 mli
write_marked_population "$FIXE1" 0 9 ml

set +e
OUTE1=$(run_linter "$FIXE1" 2>&1)
CODEE1=$?
set -e

if [ "$CODEE1" -ne 0 ] && echo "$OUTE1" | grep -q "Too many declared-large .mli files: 2/10"; then
  ok "fixture E1 — 2/10 declared-large .mli (20%) trips the .mli cap even though pooled with 9 clean .ml it would be 2/19 = 10.5%, under the 11% cap"
else
  bad "fixture E1 — expected non-zero exit naming the .mli cap (2/10 over 11%); got exit=$CODEE1 output=<<$OUTE1>>"
fi

FIXE2="${BASE_DIR}/fixE2"
make_fixture_trading_dir "$FIXE2"
write_marked_population "$FIXE2" 2 8 ml
write_marked_population "$FIXE2" 0 9 mli

set +e
OUTE2=$(run_linter "$FIXE2" 2>&1)
CODEE2=$?
set -e

if [ "$CODEE2" -ne 0 ] && echo "$OUTE2" | grep -q "Too many declared-large files: 2/10"; then
  ok "fixture E2 — the mirror: 2/10 declared-large .ml (20%) trips the .ml cap despite 9 clean .mli making the pooled share 10.5%"
else
  bad "fixture E2 — expected non-zero exit naming the .ml cap (2/10 over 11%); got exit=$CODEE2 output=<<$OUTE2>>"
fi

cleanup
trap - EXIT INT TERM

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: linter_file_length_test — ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi

echo "OK: linter_file_length_test — ${PASS} assertion(s) passed, 0 failed."
