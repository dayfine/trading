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

cleanup
trap - EXIT INT TERM

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: linter_file_length_test — ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi

echo "OK: linter_file_length_test — ${PASS} assertion(s) passed, 0 failed."
