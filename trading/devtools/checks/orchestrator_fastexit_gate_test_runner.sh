#!/bin/sh
# orchestrator_fastexit_gate_test_runner.sh -- dune-runtest shim for
# dev/scripts/orchestrator_fastexit_gate_test.sh.
#
# WHY WIRED. orchestrator_fastexit_gate.sh (issue #2579, extended for the
# FULL-mode publication check by issue #2803) is the mechanical backstop
# behind the orchestrator workflow's daily-summary sanity checks -- exactly
# the class of guard that has repeatedly rotted unnoticed in this repo (see
# publish_daily_summary_test_runner.sh's header for the sibling precedent).
# A guard whose own tests never run in CI is no better than no guard at all
# the day someone edits it without noticing a regression.
#
# `dev/scripts/` is outside the dune workspace root and is read via
# repo_root() at RUN TIME, so the rule needs `(universe)` -- without it,
# dune caches a pass and never re-runs when the scripts change.

set -eu

. "$(dirname "$0")/_check_lib.sh"

TEST="$(repo_root)/dev/scripts/orchestrator_fastexit_gate_test.sh"

if [ ! -f "$TEST" ]; then
  # FAIL, do not skip -- same reasoning as the sibling runners' identical
  # guard: the test ships in the SAME COMMIT as the script it tests, so
  # absence only means deletion, which is exactly the rot this wiring
  # exists to catch.
  echo "FAIL: orchestrator_fastexit_gate_test.sh not found at $TEST" >&2
  echo "  The test ships alongside dev/scripts/orchestrator_fastexit_gate.sh; if it" >&2
  echo "  is gone, the guard is unpinned. Restore it or remove this dune rule." >&2
  exit 1
fi

# The test suite must be run with a real shell that supports its
# arithmetic/subshell usage; `sh` on this image is dash, which is fine --
# same invocation as the sibling runners.
sh "$TEST"
