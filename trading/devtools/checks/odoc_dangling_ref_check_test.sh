#!/bin/sh
# Fixture-driven self-test for odoc_dangling_ref_check.sh (dangling
# odoc-reference check, filed by qc-behavioral on PR #2542 finding B1; see
# dev/status/cleanup.md `linter_candidate` entry and the linter's own header
# for the full design rationale).
#
# Builds private throwaway "trading dirs" under `mktemp -d` (same pattern as
# linter_file_length_test.sh / tracked_artifact_linter_test.sh: a copy of
# the checked script + _check_lib.sh two directory levels below the fixture
# root, so trading_dir()'s `$(dirname "$0")/../..` resolves to the fixture
# root) so this test never depends on the real repo's current population of
# dangling/live doc references -- it pins the detector's logic against known
# fixtures, independent of whatever main's own residual count happens to be
# on any given day.
#
# Assertions:
#
#   A. Clean fixture: a real `let _bar` binding plus a `[Foo._bar]` doc
#      citation of it -> OK, "1 candidate ... scanned; 0 dangling".
#
#   B. Regression fixture -- reproduces PR #2542's EXACT instance shape: a
#      `[Simulator._settle_rejected_fills]` doc-comment code span with NO
#      matching `_settle_rejected_fills` binding anywhere in the fixture
#      tree (the function was deleted, the doc comment was not) -> WARN,
#      "1 candidate ... scanned; 1 dangling", naming
#      `Simulator._settle_rejected_fills` and the citing file:line. This is
#      the check going RED on the real regression it exists to catch.
#
#   C. Binding-site regex robustness: two real bugs found by hand while
#      measuring this check against the live repo (see the check's own
#      header) -- `let rec _walk_up ...` (an ad-hoc "let|and|val directly
#      followed by identifier" regex misses `rec`) and
#      `let[@inline never] _extract_fold ...` (misses a ppx attribute glued
#      directly to `let` with no space). Both are cited via a doc reference
#      in the same fixture and must resolve as PRESENT, not dangling --
#      pins the shipped regex against regressing to either bug.
#
#   D. Fails-closed / vacuity backstop (required by this check's own
#      dispatch brief): copy the REAL, unmutated `odoc_dangling_ref_check.sh`
#      and confirm it reports fixture B's dangling reference (sanity — this
#      is what all the assertions above already exercise indirectly, stated
#      explicitly here as the baseline for D2). Then D2: take a SEPARATE
#      copy and mutate CANDIDATE_RE (via `sed`) to a pattern that cannot
#      match anything in fixture B's content -- the mutant must report "0
#      candidate ... scanned" (not "... scanned; 0 dangling", which is what
#      a genuinely clean tree reports). The two messages are deliberately
#      different sentences so a broken-pattern run is distinguishable from
#      a clean tree by grepping the output, not just by an eyeballed number
#      -- this is what "fails closed, not vacuously" means for this check.
#
#   E. STRICT-mode toggle: fixture B with `ODOC_DANGLING_REF_CHECK_STRICT=1`
#      exits 1 (opt-in promotion path, documented in the script header, not
#      yet wired into the dune rule); the same fixture with the env var
#      unset (default) exits 0. Pins that the non-gating default and the
#      opt-in strict path both work, so a future promotion PR can flip the
#      dune wiring with confidence the underlying toggle is load-bearing.
#
# How to re-verify by hand:
#   sh trading/devtools/checks/odoc_dangling_ref_check_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

CHECK="$(dirname "$0")/odoc_dangling_ref_check.sh"
LIB="$(dirname "$0")/_check_lib.sh"
[ -f "$CHECK" ] || die "odoc_dangling_ref_check_test: $CHECK not found"

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

# Private fixture "trading dir": a copy of the check + _check_lib.sh two
# directory levels below the fixture root (mirrors the real
# trading/devtools/checks/ layout), so trading_dir()'s `$(dirname "$0")/../..`
# resolves to the fixture root. $1 = fixture root to create.
make_fixture_trading_dir() {
  mkdir -p "$1/devtools/checks"
  cp "$CHECK" "$1/devtools/checks/odoc_dangling_ref_check.sh"
  cp "$LIB" "$1/devtools/checks/_check_lib.sh"
}

run_check() {
  # $1 = fixture root
  sh "$1/devtools/checks/odoc_dangling_ref_check.sh"
}

# =============================================================================
# Fixture A: clean -- one real binding, one doc citation of it -> OK, 0 dangling
# =============================================================================

FIXA="${BASE_DIR}/fixA"
make_fixture_trading_dir "$FIXA"
mkdir -p "${FIXA}/lib"
cat > "${FIXA}/lib/foo.ml" <<'EOF'
let _bar x = x + 1
EOF
cat > "${FIXA}/lib/foo.mli" <<'EOF'
(** Adds one. See [Foo._bar] for the implementation. *)
val bar : int -> int
EOF

set +e
OUTA=$(run_check "$FIXA" 2>&1)
CODEA=$?
set -e

if [ "$CODEA" -eq 0 ] \
  && echo "$OUTA" | grep -q "^OK: odoc_dangling_ref_check -- 1 candidate doc-identifier reference(s) scanned; 0 dangling\.$"; then
  ok "fixture A -- clean tree, 1 candidate resolves -> OK, 0 dangling"
else
  bad "fixture A -- expected OK/0-dangling on 1 scanned candidate; got exit=$CODEA output=<<$OUTA>>"
fi

# =============================================================================
# Fixture B: PR #2542's exact regression shape -- a citation with NO
# matching binding anywhere in the tree -> WARN, 1 dangling, non-gating
# (exit 0 by default; exit 1 under STRICT, see fixture E below)
# =============================================================================

FIXB="${BASE_DIR}/fixB"
make_fixture_trading_dir "$FIXB"
mkdir -p "${FIXB}/lib" "${FIXB}/test"
cat > "${FIXB}/lib/simulator.ml" <<'EOF'
(* _settle_rejected_fills was deleted by the fixture's simulated PR #2542;
   nothing in this file defines it any more. *)
let unrelated_fn x = x
EOF
cat > "${FIXB}/test/test_cancel_handler.ml" <<'EOF'
(* See [Simulator._settle_rejected_fills] for the retry/cancel/announce/
   revert sequence this test exercises. *)
let test_placeholder () = ()
EOF

set +e
OUTB=$(run_check "$FIXB" 2>&1)
CODEB=$?
set -e

if [ "$CODEB" -eq 0 ] \
  && echo "$OUTB" | grep -q "^WARN: odoc_dangling_ref_check -- 1 candidate doc-identifier reference(s) scanned; 1 dangling reference(s) found" \
  && echo "$OUTB" | grep -q "test_cancel_handler.ml:1: \[Simulator._settle_rejected_fills\]"; then
  ok "fixture B -- PR #2542's exact regression shape goes RED (WARN, 1/1 dangling, named + located)"
else
  bad "fixture B -- expected WARN naming Simulator._settle_rejected_fills at test_cancel_handler.ml:1; got exit=$CODEB output=<<$OUTB>>"
fi

# =============================================================================
# Fixture C: binding-site regex robustness -- `let rec` and `let[@attr]`
# (glued, no space) must both resolve as PRESENT, not dangling. Both are
# real bugs an earlier ad-hoc measurement of this check's own regex hit
# against the live repo (_walk_up, _extract_fold) before the shipped
# pattern was widened to handle them.
# =============================================================================

FIXC="${BASE_DIR}/fixC"
make_fixture_trading_dir "$FIXC"
mkdir -p "${FIXC}/lib"
cat > "${FIXC}/lib/fixture_c.ml" <<'EOF'
let rec _walk_up dir tries_left =
  if tries_left <= 0 then None else Some dir

let[@inline never] _extract_fold ~fixtures_root =
  fixtures_root
EOF
cat > "${FIXC}/lib/fixture_c.mli" <<'EOF'
(** Same recursion shape as [Fixture_c._walk_up]. *)

(** Extraction helper, see {!Fixture_c._extract_fold}. *)
val noop : unit -> unit
EOF

set +e
OUTC=$(run_check "$FIXC" 2>&1)
CODEC=$?
set -e

if [ "$CODEC" -eq 0 ] \
  && echo "$OUTC" | grep -q "^OK: odoc_dangling_ref_check -- 2 candidate doc-identifier reference(s) scanned; 0 dangling\.$"; then
  ok "fixture C -- 'let rec' and glued 'let[@attr]' binding shapes both resolve -> OK, 0 dangling"
else
  bad "fixture C -- expected OK/0-dangling (both binding shapes resolve); got exit=$CODEC output=<<$OUTC>>"
fi

# =============================================================================
# Fixture D: fails-closed / vacuity backstop. D1 is the real check against
# fixture B (already proven RED above by fixture B itself; restated here as
# the explicit baseline for D2's contrast). D2 mutates a SEPARATE copy's
# CANDIDATE_RE to something that cannot match fixture B's content, and
# requires the mutant's own output to be DISTINGUISHABLE from a genuine
# clean tree: "0 candidate ... scanned" (broken pattern), never "... scanned;
# 0 dangling" (a real clean-tree message, which requires >=1 scanned).
# =============================================================================

FIXD="${BASE_DIR}/fixD"
make_fixture_trading_dir "$FIXD"
mkdir -p "${FIXD}/lib" "${FIXD}/test"
cp "${FIXB}/lib/simulator.ml" "${FIXD}/lib/simulator.ml"
cp "${FIXB}/test/test_cancel_handler.ml" "${FIXD}/test/test_cancel_handler.ml"

# D1: sanity baseline (unmutated copy) -- same shape as fixture B.
set +e
OUTD1=$(run_check "$FIXD" 2>&1)
CODED1=$?
set -e

if [ "$CODED1" -eq 0 ] && echo "$OUTD1" | grep -q "1 dangling reference(s) found"; then
  ok "fixture D1 -- unmutated check baseline confirms fixture D carries 1 real dangling reference"
else
  bad "fixture D1 setup -- expected the unmutated check to find 1 dangling reference on fixture D; got exit=$CODED1 output=<<$OUTD1>>"
fi

# D2: mutate CANDIDATE_RE to an impossible pattern in a SEPARATE copy.
MUTANT="${FIXD}/devtools/checks/odoc_dangling_ref_check.sh"
sed -i.bak "s|^CANDIDATE_RE='.*'\$|CANDIDATE_RE='this_pattern_cannot_match_anything_zzz9928'|" "$MUTANT"
rm -f "${MUTANT}.bak"

set +e
OUTD2=$(sh "$MUTANT" 2>&1)
CODED2=$?
set -e

if [ "$CODED2" -eq 0 ] \
  && echo "$OUTD2" | grep -q "^OK: odoc_dangling_ref_check -- 0 candidate doc-identifier reference(s) scanned"; then
  ok "fixture D2 -- mutated (matches-nothing) detector reports the DISTINCT '0 candidate ... scanned' message, not a clean-tree '0 dangling'"
else
  bad "fixture D2 -- expected the '0 candidate ... scanned' vacuity message from a broken-pattern mutant; got exit=$CODED2 output=<<$OUTD2>>"
fi

# =============================================================================
# Fixture E: STRICT-mode toggle. Same fixture B tree, env var only.
# =============================================================================

set +e
ODOC_DANGLING_REF_CHECK_STRICT=1 run_check "$FIXB" >/tmp/odoc_fixe_strict_out.$$ 2>&1
CODEE_STRICT=$?
set -e
OUTE_STRICT=$(cat "/tmp/odoc_fixe_strict_out.$$")
rm -f "/tmp/odoc_fixe_strict_out.$$"

if [ "$CODEE_STRICT" -eq 1 ] && echo "$OUTE_STRICT" | grep -q "1 dangling reference(s) found"; then
  ok "fixture E -- ODOC_DANGLING_REF_CHECK_STRICT=1 turns the same fixture B finding into exit 1"
else
  bad "fixture E -- expected exit 1 under STRICT mode; got exit=$CODEE_STRICT output=<<$OUTE_STRICT>>"
fi

set +e
OUTE_DEFAULT=$(run_check "$FIXB" 2>&1)
CODEE_DEFAULT=$?
set -e

if [ "$CODEE_DEFAULT" -eq 0 ]; then
  ok "fixture E -- default (STRICT unset) stays non-gating, exit 0, on the identical fixture"
else
  bad "fixture E -- expected exit 0 by default (non-gating); got exit=$CODEE_DEFAULT"
fi

cleanup
trap - EXIT INT TERM

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: odoc_dangling_ref_check_test -- ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi

echo "OK: odoc_dangling_ref_check_test -- ${PASS} assertion(s) passed, 0 failed."
