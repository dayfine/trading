#!/bin/sh
# orchestrator_merge_gate_test_runner.sh -- dune-runtest shim for
# dev/scripts/orchestrator_merge_gate_test.sh (issue #2913, PR #2939 rework).
#
# Same shape as orchestrator_fastexit_gate_test_runner.sh: the test and the
# function it pins (merge_pr_when_clean, inline shell in
# .github/workflows/orchestrator.yml) both live outside the dune workspace
# root, so the shim resolves them via repo_root() at run time and fails --
# never skips -- when the test file is missing.
set -eu

. "$(dirname "$0")/_check_lib.sh"

TEST="$(repo_root)/dev/scripts/orchestrator_merge_gate_test.sh"

if [ ! -f "$TEST" ]; then
  echo "FAIL: orchestrator_merge_gate_test.sh not found at $TEST" >&2
  echo "  The test pins merge_pr_when_clean in .github/workflows/orchestrator.yml; if it" >&2
  echo "  is gone, the #2913 update-branch bound is unpinned. Restore it or remove this dune rule." >&2
  exit 1
fi

sh "$TEST"
