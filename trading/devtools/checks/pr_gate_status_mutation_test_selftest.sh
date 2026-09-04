#!/bin/sh
# pr_gate_status_mutation_test_selftest.sh -- proves
# pr_gate_status_mutation_test.sh's own non-vacuity guard actually fires.
#
# A mutation harness that silently reports "all clean" when its own sed
# edit failed to apply is the exact failure mode
# H-GATEPARSER-NO-MUTATION-COVERAGE exists to close -- and it is not
# hypothetical: the 2026-09-03 orchestrator run hit it first-hand in an
# unrelated harness (a str.replace silently matched nothing; the suite ran
# unmutated and came back green, indistinguishable from "the guard is
# unpinned"). This file drives the REAL harness script (not a duplicate of
# its logic) with a deliberately-unmatchable sed injected via its
# PR_GATE_STATUS_MUTATION_SELFTEST_NOOP hook, and asserts the harness
# reports the DISTINCT "MUTATION DID NOT APPLY" message and exits non-zero
# -- so a future broken harness can never be mistaken for a clean sweep.
#
# PR_GATE_STATUS_MUTATION_SELFTEST_ONLY=1 skips the 16 real mutations in
# that run (this test only cares about the injected no-op), keeping this
# self-test fast rather than paying the full ~45s sweep twice per
# `dune runtest`.

set -eu
. "$(dirname "$0")/_check_lib.sh"

HARNESS="$(dirname "$0")/pr_gate_status_mutation_test.sh"
[ -f "$HARNESS" ] || die "pr_gate_status_mutation_test_selftest: missing $HARNESS"

out=$(PR_GATE_STATUS_MUTATION_SELFTEST_NOOP=1 PR_GATE_STATUS_MUTATION_SELFTEST_ONLY=1 \
  sh "$HARNESS" 2>&1) && rc=0 || rc=$?

if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'MUTATION DID NOT APPLY'; then
  echo "OK: pr_gate_status_mutation_test_selftest -- non-vacuity guard fires on an unmatchable mutation (rc=$rc)."
else
  echo "FAIL: pr_gate_status_mutation_test_selftest -- expected non-zero exit + 'MUTATION DID NOT APPLY'; got rc=${rc}, output:" >&2
  printf '%s\n' "$out" | sed 's/^/      /' >&2
  exit 1
fi

# Deliberately does NOT also re-run the harness's normal (all-16-mutations)
# mode: that exact invocation is already the separate pr_gate_status_mutation_test.sh
# dune rule, gated independently. Duplicating it here would double the ~45s
# sweep cost every `dune runtest` for zero additional coverage.
