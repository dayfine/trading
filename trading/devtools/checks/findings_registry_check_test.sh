#!/bin/sh
# Fixture self-test for findings_registry_check.sh (issue #3001).
#
# Runs the check over fixtures/findings_registry/: one clean registry that
# must pass, and one RED registry per failure mode that must fail with the
# expected message. A RED case that exits 0, or fails with a different
# message, fails this test (so the check cannot go vacuous).
#
# Usage: findings_registry_check_test.sh PATH_TO_findings_registry_check.exe

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
EXE="${1:?usage: findings_registry_check_test.sh EXE}"
FX="$DIR/fixtures/findings_registry"
FAILED=0

run() {
  FINDINGS_REPO_ROOT="$FX/tree" \
  FINDINGS_REGISTRY_FILE="$FX/$1" \
  FINDINGS_VALIDATOR_SOURCE="$FX/tree/validation/validator_checks.ml" \
    sh "$DIR/findings_registry_check.sh" "$EXE" 2>&1
}

expect_pass() {
  out=$(run "$1") && rc=0 || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: $1 should pass, exit $rc: $out"; FAILED=1
  else
    echo "  PASS: $1"
  fi
}

expect_red() {
  out=$(run "$1") && rc=0 || rc=$?
  if [ "$rc" -ne 1 ]; then
    echo "FAIL: $1 should exit 1, got $rc: $out"; FAILED=1
  elif ! printf '%s' "$out" | grep -q "$2"; then
    echo "FAIL: $1 exited 1 without message '$2': $out"; FAILED=1
  else
    echo "  PASS: $1 (RED as expected)"
  fi
}

expect_pass clean.sexp
expect_red red_missing_file.sexp 'unit guard file missing'
expect_red red_missing_test_name.sexp 'not found in'
expect_red red_unknown_validator.sexp 'validator V99 is not registered'
expect_red red_none_no_reason.sexp 'guard none requires a non-empty reason'
expect_red red_bad_status.sexp 'unknown status'
expect_red red_no_issue_or_ref.sexp 'needs an issue or a ref'
expect_red red_blank_reason.sexp 'guard none requires a non-empty reason'
expect_red red_empty_test_name.sexp 'empty test name'
expect_red red_name_in_comment_only.sexp 'quoted string literal'

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "OK: findings_registry_check_test -- 10 cases."
