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

write_dune() {
  # $1 = "universe" | "no-universe" for sample_check.sh's rule
  # $2 = "universe" | "no-universe" for wrapper_test.sh's rule (governs
  #      helper_with_repo_root.sh, listed only as a dep)
  sample_deps="_check_lib.sh"
  [ "$1" = "universe" ] && sample_deps="_check_lib.sh (universe)"
  wrapper_deps="helper_with_repo_root.sh"
  [ "$2" = "universe" ] && wrapper_deps="helper_with_repo_root.sh (universe)"

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
echo "sample_check.sh" > "${FIXTURE_CHECKS}/universe_deps_exceptions.conf"

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

echo ""
echo "check_universe_deps_test: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
