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

write_dune() {
  # $1 = "universe" | "no-universe" for sample_check.sh's rule
  # $2 = "universe" | "no-universe" for wrapper_test.sh's rule (governs
  #      helper_with_repo_root.sh, listed only as a dep)
  # $3 = "universe" | "no-universe" for subdir_wrapper_test.sh's rule
  #      (governs subdir/nested_check.sh, listed only as a dep) --
  #      defaults to "universe" (clean) when omitted, so existing callers
  #      (assertions 1-5) don't need to pass it.
  sample_deps="_check_lib.sh"
  [ "$1" = "universe" ] && sample_deps="_check_lib.sh (universe)"
  wrapper_deps="helper_with_repo_root.sh"
  [ "$2" = "universe" ] && wrapper_deps="helper_with_repo_root.sh (universe)"
  subdir_deps="subdir/nested_check.sh"
  [ "${3:-universe}" = "universe" ] && subdir_deps="subdir/nested_check.sh (universe)"

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

echo ""
echo "check_universe_deps_test: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
