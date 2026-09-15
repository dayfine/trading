#!/bin/sh
# dispatch_disk_guard_test_runner.sh -- dune-runtest shim for
# dev/scripts/dispatch_disk_guard_test.sh.
#
# WHY WIRED. dev/scripts/dispatch_disk_guard.sh is the mechanical
# pre-dispatch disk guard for H-AGENT-WORKTREE-DISK-16GB-EACH
# (dev/status/harness.md): a hand-held "cap agents at 2 instead of 3"
# judgment call is not a control (the orchestrator did this by hand on
# 09-14 and 09-15) -- the guard exists to make the disk ceiling mechanical.
# A guard whose own tests never run in CI is no better than no guard: the
# day someone edits PER_AGENT_WORKTREE_GB or the comparison direction
# without noticing a regression, nothing catches it.
#
# `dev/scripts/` is outside the dune workspace root and is read via
# repo_root() at RUN TIME, so the rule needs `(universe)` -- same shim +
# (universe) pattern as orchestrator_fastexit_gate_test_runner.sh and
# codex_review_test_runner.sh: without it, dune caches a pass and never
# re-runs when the scripts change.

set -eu

. "$(dirname "$0")/_check_lib.sh"

TEST="$(repo_root)/dev/scripts/dispatch_disk_guard_test.sh"

if [ ! -f "$TEST" ]; then
  # FAIL, do not skip -- same reasoning as the sibling runners' identical
  # guard: the test ships in the SAME COMMIT as the script it tests, so
  # absence only means deletion, which is exactly the rot this wiring
  # exists to catch.
  echo "FAIL: dispatch_disk_guard_test.sh not found at $TEST" >&2
  echo "  The test ships alongside dev/scripts/dispatch_disk_guard.sh; if it" >&2
  echo "  is gone, the guard is unpinned. Restore it or remove this dune rule." >&2
  exit 1
fi

sh "$TEST"
