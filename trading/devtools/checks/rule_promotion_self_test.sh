#!/bin/sh
# Self-test for rule_promotion_check.sh (T3-F).
#
# Verifies four behaviours:
#   1. PASS — all enforced rules are wired correctly (implicit check).
#   2. FAIL — enforced rule with nonexistent check script exits non-zero.
#   3. FAIL — enforced rule where script exists but is not in dune exits non-zero.
#   4. PASS — enforced rule marked "implicit" is accepted without a real script.
#   5. PASS — a "monitored" rule with no check is accepted.
#
# The REPO_ROOT environment variable is used to redirect the check script to a
# temporary directory containing synthetic rules/dune files. Each scenario
# creates: $TMPDIR/docs/design/dependency-rules.md and
#          $TMPDIR/trading/devtools/checks/dune
# to satisfy both lookup paths in rule_promotion_check.sh.

set -e

. "$(dirname "$0")/_check_lib.sh"

PASS=0
FAIL=1
total=0
failed=0
CHECK_SCRIPT="$(dirname "$0")/rule_promotion_check.sh"

_assert() {
  label="$1"
  expected_exit="$2"
  actual_exit="$3"
  total=$((total + 1))
  if [ "$actual_exit" = "$expected_exit" ]; then
    printf 'PASS: %s\n' "$label"
  else
    printf 'FAIL: %s — expected exit %d, got %d\n' "$label" "$expected_exit" "$actual_exit"
    failed=$((failed + 1))
  fi
}

# Helper: create a minimal fake repo tree under a temp dir.
# Usage: _make_tree <base> <rules_content> <dune_content>
# Returns the base dir path (already created).
_make_tree() {
  base="$1"
  rules_content="$2"
  dune_content="$3"
  mkdir -p "$base/docs/design"
  mkdir -p "$base/trading/devtools/checks"
  printf '%s\n' "$rules_content" > "$base/docs/design/dependency-rules.md"
  printf '%s\n' "$dune_content"  > "$base/trading/devtools/checks/dune"
}

TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT

# -----------------------------------------------------------------------
# Scenario 1: PASS — enforced rule, script exists, referenced in dune.
# We use the real check script itself as the check path since it always exists.
# -----------------------------------------------------------------------

S1="$TMPROOT/s1"
_make_tree "$S1" \
  "### R1 — test enforced rule

| Field | Value |
|---|---|
| Lifecycle | \`enforced\` |
| Check | \`trading/devtools/checks/rule_promotion_check.sh\` |

Test rule." \
  "; dune with the script referenced
; rule_promotion_check.sh"

# The check script looks for the file at $REPO_ROOT/$check_path.
# Create a stub so the existence check passes.
cp "$CHECK_SCRIPT" "$S1/trading/devtools/checks/rule_promotion_check.sh"

actual=0
REPO_ROOT="$S1" sh "$CHECK_SCRIPT" > /dev/null 2>&1 || actual=$?
_assert "enforced rule with valid script and dune wiring passes" "$PASS" "$actual"

# -----------------------------------------------------------------------
# Scenario 2: FAIL — enforced rule, script does NOT exist.
# -----------------------------------------------------------------------

S2="$TMPROOT/s2"
_make_tree "$S2" \
  "### R2 — missing script rule

| Field | Value |
|---|---|
| Lifecycle | \`enforced\` |
| Check | \`trading/devtools/checks/no_such_script_xyz.sh\` |

Test rule." \
  "; dune that references the script
; no_such_script_xyz.sh"

actual=0
REPO_ROOT="$S2" sh "$CHECK_SCRIPT" > /dev/null 2>&1 || actual=$?
_assert "enforced rule with missing check script exits non-zero" "$FAIL" "$actual"

# -----------------------------------------------------------------------
# Scenario 3: FAIL — enforced rule, script exists, NOT in dune.
# -----------------------------------------------------------------------

S3="$TMPROOT/s3"
_make_tree "$S3" \
  "### R3 — missing dune wiring

| Field | Value |
|---|---|
| Lifecycle | \`enforced\` |
| Check | \`trading/devtools/checks/rule_promotion_check.sh\` |

Test rule." \
  "; dune that does NOT reference the script"

actual=0
REPO_ROOT="$S3" sh "$CHECK_SCRIPT" > /dev/null 2>&1 || actual=$?
_assert "enforced rule with missing dune wiring exits non-zero" "$FAIL" "$actual"

# -----------------------------------------------------------------------
# Scenario 4: PASS — enforced rule with "implicit" check.
# -----------------------------------------------------------------------

S4="$TMPROOT/s4"
_make_tree "$S4" \
  "### R4 — implicit enforcement

| Field | Value |
|---|---|
| Lifecycle | \`enforced\` |
| Check | \`implicit (dune structure: only core dep)\` |

Enforced by dune structure." \
  "; empty dune"

actual=0
REPO_ROOT="$S4" sh "$CHECK_SCRIPT" > /dev/null 2>&1 || actual=$?
_assert "enforced implicit rule passes" "$PASS" "$actual"

# -----------------------------------------------------------------------
# Scenario 5: PASS — monitored and proposed rules with no check.
# -----------------------------------------------------------------------

S5="$TMPROOT/s5"
_make_tree "$S5" \
  "### R5 — monitored rule

| Field | Value |
|---|---|
| Lifecycle | \`monitored\` |
| Check | \`none\` |

Not yet enforced.

### R6 — proposed rule

| Field | Value |
|---|---|
| Lifecycle | \`proposed\` |
| Check | \`none\` |

Under discussion." \
  "; empty dune"

actual=0
REPO_ROOT="$S5" sh "$CHECK_SCRIPT" > /dev/null 2>&1 || actual=$?
_assert "monitored/proposed rules with no check pass" "$PASS" "$actual"

# -----------------------------------------------------------------------
# Scenario 6: PASS — current real repo state.
# -----------------------------------------------------------------------

actual=0
sh "$CHECK_SCRIPT" > /dev/null 2>&1 || actual=$?
_assert "current repo state passes" "$PASS" "$actual"

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------

echo ""
printf 'rule_promotion_self_test: %d/%d assertions passed\n' \
  "$((total - failed))" "$total"

if [ "$failed" -gt 0 ]; then
  exit 1
fi

echo "OK: rule_promotion_self_test — all assertions passed."
exit 0
