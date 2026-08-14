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
#  11. A PATH-QUALIFIED run-target -- (run sh %{dep:subdir/foo.sh}) --
#      whose own rule declares (universe) resolves via the RUN-TARGET
#      branch -> PASS, even when an earlier rule lists the same script as
#      a plain dep WITHOUT (universe) (H-CHECK-RUNTARGET-PATHQUAL: the
#      run-target regex's character class must admit '/').
#  12. The mirror image of #11 -- the path-qualified run-target's own rule
#      LACKS (universe) while the earlier dep-listing rule HAS it -> FAIL,
#      attributed to the run-target. This is the false GREEN that the
#      H-CHECK-RUNTARGET-PATHQUAL fix closes: with a '/'-excluding class
#      the run-target is invisible, so the script is misattributed to the
#      other rule and its real cache-blindness is reported as OK.
#  13. A path-qualified script whose ONLY dune mention is inside a ";"
#      whole-line comment is NOT resolved -> FAIL "not referenced by any
#      runtest rule". This pins RECORD CLASSIFICATION -- the "/^\(rule/"
#      paragraph guard plus strip_comments() -- and NOT the character
#      class. Measured: assertion 13 is invariant under every mutation of
#      the run-target class (narrow "[A-Za-z0-9_.]", this file's
#      "[A-Za-z0-9_./-]", and an unbounded "[^}]" all leave it green),
#      because its fixture record starts with ";" and is discarded by the
#      paragraph guard before the run-target regex is ever consulted. It
#      DOES go red when the record classifier is broken (a botched
#      glued-rule fix that strips the ";" leader but keeps the line
#      content makes #13 the sole failure), which is the invariant it
#      actually guards -- H-CHECK-DUNE-COMMENT-GLUED-RULE. The
#      class-containment guard is assertion 14, not this one.
#  14. The over-match direction of the widened class: a "%{dep:...}" blob
#      that is NOT a plain script name ("$LEGACY_DIR/old check.sh" --
#      contains "$" and a space) sitting in LIVE rule text (an "(echo
#      ...)" argument, so strip_comments() cannot remove it) EARLIER in
#      the same record than the real run-target must be SKIPPED by the
#      class, so the real run-target is still the one matched. awk
#      match() returns the FIRST match in the record, so a class wide
#      enough to swallow the blob hijacks attribution and the real script
#      falls through to the dep-list branch -- reported against the wrong
#      rule. Measured three states: narrow "[A-Za-z0-9_.]" -> FAIL (no
#      '/', the pre-fix bug), "[A-Za-z0-9_./-]" -> PASS, unbounded
#      "[^}]" -> FAIL (hijacked). Unlike a ";"-comment fixture, this one
#      does not depend on strip_comments()'s whole-line-only behaviour,
#      so it keeps discriminating once H-CHECK-DUNE-COMMENT-GLUED-RULE
#      is fixed.
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

# --- Assertions 11-12 fixtures (H-CHECK-RUNTARGET-PATHQUAL): a
# SUBDIRECTORY script that calls repo_root() and is the RUN-TARGET of its
# own rule, written path-qualified as %{dep:subdir/runtarget_check.sh}.
# It is ALSO listed as a plain dep of an earlier rule (the shape the real
# dune file uses for check_universe_deps.sh: its own rule runs it, and
# check_universe_deps_test.sh's rule deps it). The two rules carry
# INDEPENDENT (universe) flags, so the guard's answer differs depending on
# which rule it attributes the script to -- that is what makes assertions
# 11 and 12 discriminating.
mkdir -p "${FIXTURE_CHECKS}/subdir"
cat > "${FIXTURE_CHECKS}/subdir/runtarget_check.sh" <<'EOF'
#!/bin/sh
. "$(dirname "$0")/../_check_lib.sh"
REAL="$(repo_root)/dev/status/baz.md"
echo "OK: runtarget_check read $REAL"
EOF
cat > "${FIXTURE_CHECKS}/runtarget_wrapper_test.sh" <<'EOF'
#!/bin/sh
echo "runtarget_wrapper deps subdir/runtarget_check.sh"
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
  # $5 = "universe" | "no-universe" for the rule whose RUN-TARGET is the
  #      path-qualified %{dep:subdir/runtarget_check.sh} (assertions
  #      11-12) -- defaults to "universe" (clean) when omitted.
  # $6 = "universe" | "no-universe" for runtarget_wrapper_test.sh's rule,
  #      which lists subdir/runtarget_check.sh as a plain DEP (assertions
  #      11-12) -- defaults to "universe" (clean) when omitted.
  sample_deps="_check_lib.sh"
  [ "$1" = "universe" ] && sample_deps="_check_lib.sh (universe)"
  wrapper_deps="helper_with_repo_root.sh"
  [ "$2" = "universe" ] && wrapper_deps="helper_with_repo_root.sh (universe)"
  subdir_deps="subdir/nested_check.sh"
  [ "${3:-universe}" = "universe" ] && subdir_deps="subdir/nested_check.sh (universe)"
  risky_deps="_check_lib.sh"
  [ "${4:-universe}" = "universe" ] && risky_deps="_check_lib.sh (universe)"
  runtarget_deps="_check_lib.sh"
  [ "${5:-universe}" = "universe" ] && runtarget_deps="_check_lib.sh (universe)"
  rtwrapper_deps="subdir/runtarget_check.sh"
  [ "${6:-universe}" = "universe" ] && rtwrapper_deps="subdir/runtarget_check.sh (universe)"

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

; The dep-listing rule is emitted BEFORE the path-qualified run-target
; rule below deliberately: the guard scans rules in file order and takes
; the FIRST dep-list match, so with the run-target branch blind to '/'
; (the H-CHECK-RUNTARGET-PATHQUAL bug) resolution lands here instead of on
; the script's own rule. Reordering these two rules would make assertions
; 11-12 stop discriminating.
;
; The blank line between this comment and the rule below is load-bearing:
; the guard parses DUNE_FILE in awk paragraph mode and only treats a
; record starting with "(rule" as a rule, so a comment glued directly onto
; a rule with no blank line makes that whole rule invisible to it. (That
; is a separate latent gap, filed as H-CHECK-DUNE-COMMENT-GLUED-RULE; the
; real dune file always separates them, as this fixture now does.)

(rule
 (alias runtest)
 (deps ${rtwrapper_deps})
 (action
  (run sh %{dep:runtarget_wrapper_test.sh})))

(rule
 (alias runtest)
 (deps ${runtarget_deps})
 (action
  (run sh %{dep:subdir/runtarget_check.sh})))
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

# ============================================================
# Assertions 11-13 (H-CHECK-RUNTARGET-PATHQUAL): the run-target regex's
# character class must admit '/', so a path-qualified run-target
# `(run sh %{dep:subdir/runtarget_check.sh})` resolves to ITS OWN rule
# rather than silently falling through to whichever other rule happens to
# list the script as a plain dep.
# ============================================================

# --- Assertion 11: the run-target's own rule declares (universe); the
# earlier dep-listing rule does NOT. Correct attribution (run-target) ->
# PASS. With a '/'-excluding class this is a false FAIL against the
# dep-listing rule.
write_dune "universe" "universe" "universe" "universe" "universe" "no-universe"

set +e
OUT11=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE11=$?
set -e

if [ "$CODE11" -eq 0 ] &&
  echo "$OUT11" | grep -q "^OK: subdir/runtarget_check.sh -- owning rule (run-target)"; then
  ok "assertion 11 — path-qualified run-target resolves to its own (universe) rule -> PASS"
else
  bad "assertion 11 — expected exit 0 with 'OK: subdir/runtarget_check.sh -- owning rule (run-target)'; got exit=$CODE11 output=<<$OUT11>>"
fi

# --- Assertion 12: mirror image -- the run-target's own rule LACKS
# (universe) while the earlier dep-listing rule HAS it. Correct
# attribution -> FAIL naming the run-target owner. With a '/'-excluding
# class this is a false GREEN: the script is credited with the OTHER
# rule's (universe) and its real cache-blindness goes unreported.
write_dune "universe" "universe" "universe" "universe" "no-universe" "universe"

set +e
OUT12=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE12=$?
set -e

if [ "$CODE12" -ne 0 ] &&
  echo "$OUT12" | grep -q "^FAIL: subdir/runtarget_check.sh calls repo_root() .*owning rule (run-target)"; then
  ok "assertion 12 — path-qualified run-target without (universe) -> FAIL, attributed to the run-target"
else
  bad "assertion 12 — expected non-zero exit with a FAIL for subdir/runtarget_check.sh naming owner (run-target); got exit=$CODE12 output=<<$OUT12>>"
fi

# --- Assertion 13 (RECORD CLASSIFICATION, not the character class): a
# path-qualified script mentioned ONLY inside a ";" whole-line dune
# comment must still be reported as unreferenced, not silently resolved
# to the commented-out rule.
#
# What this does NOT pin: the run-target character class. The commented
# fixture below is appended after a blank line, so in awk paragraph mode
# it is its own record STARTING WITH ";" -- it fails the /^\(rule/ guard
# and is discarded before the run-target regex is ever consulted.
# Measured: this assertion is green under the narrow pre-fix class
# "[A-Za-z0-9_.]", under this file's "[A-Za-z0-9_./-]", AND under an
# unbounded "[^}]" -- no class mutation can move it. The class-containment
# guard is assertion 14 below.
#
# What it DOES pin: record classification. Mutating the classifier so a
# ";"-led line is treated as rule content (a plausible botch of the
# H-CHECK-DUNE-COMMENT-GLUED-RULE fix) makes this the sole failing
# assertion.
write_dune "universe" "universe" "universe" "universe" "universe" "universe"
cat > "${FIXTURE_CHECKS}/subdir/commented_out_check.sh" <<'EOF'
#!/bin/sh
. "$(dirname "$0")/../_check_lib.sh"
echo "OK: commented_out_check read $(repo_root)/dev/status/quux.md"
EOF
cat >> "${FIXTURE_CHECKS}/dune" <<'EOF'

; (rule
;  (alias runtest)
;  (deps _check_lib.sh (universe))
;  (action
;   (run sh %{dep:subdir/commented_out_check.sh})))
EOF

set +e
OUT13=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE13=$?
set -e

if [ "$CODE13" -ne 0 ] &&
  echo "$OUT13" | grep -q "^FAIL: subdir/commented_out_check.sh calls repo_root() but is not referenced by any runtest rule"; then
  ok "assertion 13 — a \";\"-commented rule record is not classified as a rule, so its run-target is not resolved"
else
  bad "assertion 13 — expected non-zero exit reporting subdir/commented_out_check.sh as unreferenced; got exit=$CODE13 output=<<$OUT13>>"
fi

rm -f "${FIXTURE_CHECKS}/subdir/commented_out_check.sh"

# --- Assertion 14 (OVER-MATCH containment — the guard assertion 13 was
# mistakenly credited with): the class must admit only plain script-name
# characters, so a "%{dep:...}" blob that is not a script name is skipped
# and the REAL run-target later in the same record is the one matched.
#
# The ghost lives in LIVE rule text — an "(echo ...)" argument inside the
# action — not in a ";" comment, so strip_comments() cannot remove it and
# the character class is genuinely consulted. That is what makes this
# discriminating where assertion 13 is not, and it keeps discriminating
# after H-CHECK-DUNE-COMMENT-GLUED-RULE (whose fix changes comment
# handling only).
#
# The blob carries "$" and a space — the two characters most likely to be
# swept in by a careless future widening (e.g. relaxing to "[^}]+" to
# "just make dune variables work"). awk match() returns the FIRST match in
# the record, so the ghost is placed BEFORE the real run-target: a class
# that swallows it hijacks attribution, subdir/overmatch_check.sh falls
# through to the dep-list branch, and it is credited to
# overmatch_wrapper_test.sh's rule — which deliberately LACKS (universe),
# turning the hijack into a visible FAIL.
#
# Measured (all three states, same fixture):
#   [A-Za-z0-9_.]    (pre-fix, narrow)  -> FAIL (no '/', the #11/#12 bug)
#   [A-Za-z0-9_./-]  (this file)        -> PASS
#   [^}]             (unbounded)        -> FAIL (ghost hijacks)
write_dune "universe" "universe" "universe" "universe" "universe" "universe"
cat > "${FIXTURE_CHECKS}/subdir/overmatch_check.sh" <<'EOF'
#!/bin/sh
. "$(dirname "$0")/../_check_lib.sh"
echo "OK: overmatch_check read $(repo_root)/dev/status/corge.md"
EOF
cat > "${FIXTURE_CHECKS}/overmatch_wrapper_test.sh" <<'EOF'
#!/bin/sh
echo "overmatch_wrapper deps subdir/overmatch_check.sh"
EOF
cat >> "${FIXTURE_CHECKS}/dune" <<'EOF'

; The dep-listing rule comes FIRST (same ordering rationale as the
; assertions 11-12 pair above): it is where a hijacked run-target match
; makes the script land. It lacks (universe) so the hijack is loud.

(rule
 (alias runtest)
 (deps subdir/overmatch_check.sh)
 (action
  (run sh %{dep:overmatch_wrapper_test.sh})))

(rule
 (alias runtest)
 (deps _check_lib.sh (universe))
 (action
  (progn
   (echo "hand-run form: (run sh %{dep:$LEGACY_DIR/old check.sh})\n")
   (run sh %{dep:subdir/overmatch_check.sh}))))
EOF

set +e
OUT14=$(REPO_ROOT="$FAKE_ROOT" sh "$CHECK" 2>&1)
CODE14=$?
set -e

if [ "$CODE14" -eq 0 ] &&
  echo "$OUT14" | grep -q "^OK: subdir/overmatch_check.sh -- owning rule (run-target)"; then
  ok "assertion 14 — a non-script-name %{dep:...} blob in live rule text is skipped; the real run-target still wins"
else
  bad "assertion 14 — expected exit 0 with 'OK: subdir/overmatch_check.sh -- owning rule (run-target)'; got exit=$CODE14 output=<<$OUT14>>"
fi

rm -f "${FIXTURE_CHECKS}/subdir/overmatch_check.sh" \
  "${FIXTURE_CHECKS}/overmatch_wrapper_test.sh"

echo ""
echo "check_universe_deps_test: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
