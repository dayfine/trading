#!/bin/sh
# Smoke test for check_universe_deps.sh (H-CHECK-CACHE-BLIND guard).
#
# Builds a synthetic fixture tree (REPO_ROOT override, same pattern as
# deep_scan_followup_count_check.sh / record_qc_audit_test.sh) so this
# test never depends on the real trading/devtools/checks/dune content —
# it pins the guard's PARSING + DECISION logic against known-correct
# fixtures, independent of whatever the real dune file currently says.
#
# Assertions:
#   1. A rule whose script calls repo_root() and lacks (universe) -> FAIL.
#   2. The same rule with (universe) added -> PASS.
#   3. A script listed in universe_deps_exceptions.conf is skipped even
#      without (universe) -> PASS.
#   4. A script that is only a dep (not a run-target) of another script's
#      rule is resolved via that owning rule's (universe) status.
#   5. A script that doesn't call repo_root() at all is ignored.
#   6. A SUBDIRECTORY script (not just top-level) that calls repo_root()
#      and whose owning rule lacks (universe) -> FAIL, naming it
#      path-qualified (e.g. "subdir/nested_check.sh") -- #2148 FLAG-2:
#      the candidate scan must be recursive, not top-level-only.
#   7. A universe_deps_exceptions.conf entry with no parseable
#      "# review_at: <value>" annotation -> FAIL, naming the entry --
#      #2148 FLAG-1: an unconstrained exceptions list must not silently
#      disable the guard forever.
#   8. A script whose ONLY "repo_root)" occurrence is inside a "#"
#      comment (documentation prose quoting call syntax) never becomes a
#      candidate at all -- H-CHECK-UNIVERSE-DEPS-SCANS-COMMENTS: the
#      false positive that briefly flagged record_qc_audit_test.sh.
#   9. A script whose real call-site line is preceded by a load-bearing
#      "${var#prefix}" parameter expansion (so the line's FIRST "#" is
#      not the trailing comment) and ALSO carries a trailing "#" comment
#      of its own, plus "${#arr[@]}" noise elsewhere in the file, is
#      still detected as a candidate -> FAIL without (universe) -- guards
#      against two over-eager comment-stripping shapes: (a) dropping any
#      line that merely CONTAINS a "#" (would wrongly treat this line as
#      a whole-line comment), and (b) stripping from the first "#" to
#      end-of-line unconditionally (would truncate this line before
#      "repo_root)" ever appears, since "${var#prefix}"'s "#" comes
#      first) -- only whole-comment-line stripping should pass.
#  10. Same fixture as #9 with (universe) added -> PASS, confirming the
#      true-positive path (not just the FAIL path) survives the fix.
#
# How to re-verify by hand:
#   sh trading/devtools/checks/check_universe_deps_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

CHECK="$(dirname "$0")/check_universe_deps.sh"
[ -f "$CHECK" ] || die "check_universe_deps_test: $CHECK not found"

PASS=0
FAIL=0

ok() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

bad() {
  echo "  FAIL: $1" >&2
  FAIL=$((FAIL + 1))
}

FAKE_ROOT="$(mktemp -d)"
trap 'rm -rf "$FAKE_ROOT"' EXIT

FIXTURE_CHECKS="${FAKE_ROOT}/trading/devtools/checks"
mkdir -p "$FIXTURE_CHECKS" "${FAKE_ROOT}/.claude"

# Minimal _check_lib.sh stub — check_universe_deps.sh itself sources this
# (via its own real $(dirname "$0")), NOT the fixture's copy; the fixture
# only needs to be a valid *scan target* directory. Still create one so a
# fixture script that sources it (none currently do) would not break.
cat > "${FIXTURE_CHECKS}/_check_lib.sh" <<'EOF'
repo_root() { echo "${REPO_ROOT:-/nonexistent}"; }
die() { echo "FAIL: $*" >&2; exit 1; }
EOF

# --- Assertion 1 + 2 fixture: a run-target script that calls repo_root() ---
cat > "${FIXTURE_CHECKS}/sample_check.sh" <<'EOF'
#!/bin/sh
. "$(dirname "$0")/_check_lib.sh"
REAL="$(repo_root)/dev/status/foo.md"
echo "OK: sample_check read $REAL"
EOF

# --- Assertion 4 fixture: a script that is a dep (not run-target) that
# itself calls repo_root(), governed by another script's rule ---
cat > "${FIXTURE_CHECKS}/helper_with_repo_root.sh" <<'EOF'
#!/bin/sh
_repo_root() { echo "${REPO_ROOT:-/nonexistent}"; }
echo "helper uses $(_repo_root)"
EOF
cat > "${FIXTURE_CHECKS}/wrapper_test.sh" <<'EOF'
#!/bin/sh
echo "wrapper invokes helper_with_repo_root.sh"
EOF

# --- Assertion 5 fixture: a script that never calls repo_root() ---
cat > "${FIXTURE_CHECKS}/no_repo_root_check.sh" <<'EOF'
#!/bin/sh
echo "OK: no repo_root here"
EOF

# --- Assertion 6 fixture: a SUBDIRECTORY script that calls repo_root()
# and is a dep (not run-target) of another rule -- pins the recursive
# candidate scan (#2148 FLAG-2). ---
mkdir -p "${FIXTURE_CHECKS}/subdir"
cat > "${FIXTURE_CHECKS}/subdir/nested_check.sh" <<'EOF'
#!/bin/sh
. "$(dirname "$0")/../_check_lib.sh"
REAL="$(repo_root)/dev/status/bar.md"
echo "OK: nested_check read $REAL"
EOF
cat > "${FIXTURE_CHECKS}/subdir_wrapper_test.sh" <<'EOF'
#!/bin/sh
echo "subdir_wrapper invokes subdir/nested_check.sh"
EOF

# --- Assertions 8-10 fixtures (H-CHECK-UNIVERSE-DEPS-SCANS-COMMENTS):
# comment_only_repo_root.sh's ONLY "repo_root)" occurrence is inside a
# "#" comment (documentation prose quoting call syntax) -- it is
# deliberately NEVER given a dune rule below, because after the fix it
# must never become a candidate at all. risky_comment_repo_root.sh has a
# real call site whose OWN line starts with a load-bearing
# "${var#prefix}" expansion (so the line's first "#" is that expansion's,
# not a comment) and ALSO carries a trailing "#" comment, plus standalone
# "${var#prefix}"/"${#arr[@]}" noise elsewhere in the file -- it must
# always still be detected as a candidate. The expansion on the call-site
# line itself is what makes assertion 9 discriminating: an implementation
# that strips from the first "#" to end-of-line (instead of whole-comment
# lines only) truncates this line before "repo_root)" is ever reached,
# so a naive fixture with the expansion only on standalone lines would
# not catch that regression -- see assertion 9's inline comment below.
cat > "${FIXTURE_CHECKS}/comment_only_repo_root.sh" <<'EOF'
#!/bin/sh
# quoted call syntax example, NOT a real call site:
#   REPO_ROOT="$(_repo_root)"
echo "prose only -- no real repo_root() call in this script"
EOF
cat > "${FIXTURE_CHECKS}/risky_comment_repo_root.sh" <<'EOF'
#!/bin/sh
# a full-line comment above must be stripped and must not itself count
SHORT="${SOME_VAR#prefix}"
COUNT="${#SOME_ARRAY[@]}"
REAL="${SOME_VAR#pre}$(repo_root)/dev/status/qux.md" # trailing comment on the real call-site line
echo "OK: $REAL count=$COUNT short=$SHORT"
EOF

write_dune() {
  # $1 = "universe" | "no-universe" for sample_check.sh's rule
  # $2 = "universe" | "no-universe" for wrapper_test.sh's rule (governs
  #      helper_with_repo_root.sh, listed only as a dep)
  # $3 = "universe" | "no-universe" for subdir_wrapper_test.sh's rule
  #      (governs subdir/nested_check.sh, listed only as a dep) --
  #      defaults to "universe" (clean) when omitted, so existing callers
  #      (assertions 1-5) don't need to pass it.
  # $4 = "universe" | "no-universe" for risky_comment_repo_root.sh's rule
  #      (assertions 8-10, H-CHECK-UNIVERSE-DEPS-SCANS-COMMENTS) --
  #      defaults to "universe" (clean) when omitted. Note:
  #      comment_only_repo_root.sh is deliberately NEVER given a rule
  #      here -- after the fix it must never become a candidate at all.
  sample_deps="_check_lib.sh"
  [ "$1" = "universe" ] && sample_deps="_check_lib.sh (universe)"
  wrapper_deps="helper_with_repo_root.sh"
  [ "$2" = "universe" ] && wrapper_deps="helper_with_repo_root.sh (universe)"
  subdir_deps="subdir/nested_check.sh"
  [ "${3:-universe}" = "universe" ] && subdir_deps="subdir/nested_check.sh (universe)"
  risky_deps="_check_lib.sh"
  [ "${4:-universe}" = "universe" ] && risky_deps="_check_lib.sh (universe)"

  cat > "${FIXTURE_CHECKS}/dune" <<EOF
(rule
 (alias runtest)
 (deps ${sample_deps})
 (action
  (run sh %{dep:sample_check.sh})))

(rule
 (alias runtest)
 (deps ${wrapper_deps})
 (action
  (run sh %{dep:wrapper_test.sh})))

(rule
 (alias runtest)
 (deps _check_lib.sh)
 (action
  (run sh %{dep:no_repo_root_check.sh})))

(rule
 (alias runtest)
 (deps ${subdir_deps})
 (action
  (run sh %{dep:subdir_wrapper_test.sh})))

(rule
 (alias runtest)
 (deps ${risky_deps})
 (action
  (run sh %{dep:risky_comment_repo_root.sh})))
EOF
}

# ============================================================
# Assertion 1: sample_check.sh's rule lacks (universe) -> FAIL
# ============================================================
write_dune "no-universe" "universe"
rm -f "${FIXTURE_CHECKS}/universe_deps_exceptions.conf"

set +e
OUT1=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE1=$?
set -e

if [ "$CODE1" -ne 0 ] && echo "$OUT1" | grep -q "sample_check.sh"; then
  ok "assertion 1 — missing (universe) on sample_check.sh's rule -> FAIL, names the script"
else
  bad "assertion 1 — expected non-zero exit naming sample_check.sh; got exit=$CODE1 output=<<$OUT1>>"
fi

# ============================================================
# Assertion 2: add (universe) to sample_check.sh's rule -> PASS
# ============================================================
write_dune "universe" "universe"

set +e
OUT2=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE2=$?
set -e

if [ "$CODE2" -eq 0 ] && ! echo "$OUT2" | grep -q "^FAIL:"; then
  ok "assertion 2 — (universe) added to sample_check.sh's rule -> PASS, no FAIL lines"
else
  bad "assertion 2 — expected exit 0 with no FAIL lines; got exit=$CODE2 output=<<$OUT2>>"
fi

# ============================================================
# Assertion 3: exceptions-list entry is skipped even without (universe)
# ============================================================
write_dune "no-universe" "universe"
echo "sample_check.sh  # review_at: never (test fixture)" > "${FIXTURE_CHECKS}/universe_deps_exceptions.conf"

set +e
OUT3=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE3=$?
set -e

if [ "$CODE3" -eq 0 ] && echo "$OUT3" | grep -q "SKIP (exceptions list): sample_check.sh"; then
  ok "assertion 3 — exceptions-listed script skipped, overall PASS"
else
  bad "assertion 3 — expected exit 0 with a SKIP line for sample_check.sh; got exit=$CODE3 output=<<$OUT3>>"
fi

rm -f "${FIXTURE_CHECKS}/universe_deps_exceptions.conf"

# ============================================================
# Assertion 4: wrapper_test.sh's rule lacks (universe); the rule governs
# helper_with_repo_root.sh (a dep, not a run-target, but it itself calls
# repo_root()) -> FAIL naming helper_with_repo_root.sh
# ============================================================
write_dune "universe" "no-universe"

set +e
OUT4=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE4=$?
set -e

if [ "$CODE4" -ne 0 ] && echo "$OUT4" | grep -q "helper_with_repo_root.sh"; then
  ok "assertion 4 — dep-only repo_root() caller resolved via its owning (dep-list) rule -> FAIL"
else
  bad "assertion 4 — expected non-zero exit naming helper_with_repo_root.sh; got exit=$CODE4 output=<<$OUT4>>"
fi

# ============================================================
# Assertion 5: no_repo_root_check.sh never appears in any FAIL/OK line
# (it doesn't call repo_root(), so it's not a candidate at all)
# ============================================================
if ! echo "$OUT4" | grep -q "no_repo_root_check.sh"; then
  ok "assertion 5 — script without repo_root() is not treated as a candidate"
else
  bad "assertion 5 — no_repo_root_check.sh should never appear in guard output; got: $OUT4"
fi

# ============================================================
# Assertion 6 (#2148 FLAG-2): a SUBDIRECTORY script that calls
# repo_root() (subdir/nested_check.sh, a dep of subdir_wrapper_test.sh's
# rule) whose owning rule lacks (universe) -> FAIL, naming it
# path-qualified. Pins that the candidate scan is recursive, not
# top-level-only.
# ============================================================
write_dune "universe" "universe" "no-universe"

set +e
OUT6=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE6=$?
set -e

if [ "$CODE6" -ne 0 ] && echo "$OUT6" | grep -q "subdir/nested_check.sh"; then
  ok "assertion 6 — subdirectory repo_root() caller found by the recursive scan -> FAIL, path-qualified name"
else
  bad "assertion 6 — expected non-zero exit naming subdir/nested_check.sh; got exit=$CODE6 output=<<$OUT6>>"
fi

# Restore all rules to clean (universe) state for assertion 7 below, so
# the only FAIL that can fire there is the review_at one under test.
write_dune "universe" "universe" "universe"

# ============================================================
# Assertion 7 (#2148 FLAG-1): a universe_deps_exceptions.conf entry with
# no parseable "# review_at: <value>" annotation -> FAIL, naming the
# entry. Covers both a bare entry with no comment at all, and one whose
# comment isn't a review_at annotation.
# ============================================================
cat > "${FIXTURE_CHECKS}/universe_deps_exceptions.conf" <<'EOF'
sample_check.sh
EOF

set +e
OUT7=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE7=$?
set -e

if [ "$CODE7" -ne 0 ] && echo "$OUT7" | grep -q "sample_check.sh" && echo "$OUT7" | grep -qi "review_at"; then
  ok "assertion 7 — exceptions entry with no review_at annotation -> FAIL, naming the entry"
else
  bad "assertion 7 — expected non-zero exit naming sample_check.sh with a review_at complaint; got exit=$CODE7 output=<<$OUT7>>"
fi

rm -f "${FIXTURE_CHECKS}/universe_deps_exceptions.conf"

# ============================================================
# Assertions 8-10 (H-CHECK-UNIVERSE-DEPS-SCANS-COMMENTS): the candidate
# scan strips whole-line "#" comments before matching "repo_root)", so a
# comment merely quoting call syntax as documentation prose is NOT
# mistaken for a real call site (false positive, the bug that motivated
# this fix -- record_qc_audit_test.sh briefly got flagged this way while
# authoring a comment quoting `REPO_ROOT="$(_repo_root)"`) -- while a
# real call site sharing a line with a trailing "#" comment, or a file
# that also contains "${var#prefix}" / "${#arr[@]}" parameter-expansion
# syntax elsewhere, is STILL detected (guards against an over-eager fix
# that strips to end-of-line unconditionally instead of whole-comment
# lines only).
# ============================================================
# All prior rules ((universe)-clean) plus risky_comment_repo_root.sh's
# rule -- see write_dune's $4.

# --- Assertion 8: comment-only mention never becomes a candidate -> the
# script must never appear anywhere in the guard's output, and the run
# must stay green (comment_only_repo_root.sh has no dune rule at all, so
# if it were wrongly treated as a candidate it would fail as "not
# referenced by any runtest rule").
write_dune "universe" "universe" "universe" "universe"

set +e
OUT8=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE8=$?
set -e

if [ "$CODE8" -eq 0 ] && ! echo "$OUT8" | grep -q "comment_only_repo_root.sh"; then
  ok "assertion 8 — comment-only repo_root() mention is stripped and never becomes a candidate"
else
  bad "assertion 8 — expected comment_only_repo_root.sh to never appear in output with exit 0; got exit=$CODE8 output=<<$OUT8>>"
fi

# --- Assertion 9: real call site survives comment-stripping despite (a)
# a load-bearing "${var#prefix}" expansion earlier on its OWN line, (b) a
# trailing "#" comment on that same line, and (c) "${#arr[@]}" noise
# elsewhere in the file -> still detected as a candidate, and FAILs when
# its owning rule lacks (universe). The expansion on the call-site line
# is what makes this assertion actually discriminate a strip-to-end-of-
# line regression: it puts a "#" character BEFORE "repo_root)" on the
# same line, so an implementation that truncates at the first "#" instead
# of only stripping whole-comment lines would cut the match away.
write_dune "universe" "universe" "universe" "no-universe"

set +e
OUT9=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE9=$?
set -e

if [ "$CODE9" -ne 0 ] && echo "$OUT9" | grep -q "risky_comment_repo_root.sh"; then
  ok "assertion 9 — real call site with trailing comment + \${var#...}/\${#arr} noise still detected -> FAIL without (universe)"
else
  bad "assertion 9 — expected non-zero exit naming risky_comment_repo_root.sh; got exit=$CODE9 output=<<$OUT9>>"
fi

# --- Assertion 10: same fixture with (universe) declared -> PASS, proving
# the true-positive path (not just the FAIL path) survives the fix.
write_dune "universe" "universe" "universe" "universe"

set +e
OUT10=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE10=$?
set -e

if [ "$CODE10" -eq 0 ] && echo "$OUT10" | grep -q "OK: risky_comment_repo_root.sh"; then
  ok "assertion 10 — risky_comment_repo_root.sh's rule declares (universe) -> PASS"
else
  bad "assertion 10 — expected exit 0 with an OK line for risky_comment_repo_root.sh; got exit=$CODE10 output=<<$OUT10>>"
fi

echo ""
echo "check_universe_deps_test: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
