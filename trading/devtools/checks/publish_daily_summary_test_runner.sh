#!/bin/sh
# publish_daily_summary_test_runner.sh -- dune-runtest shim for
# dev/scripts/publish_daily_summary_test.sh.
#
# WHY WIRED. publish_daily_summary.sh (H-DAILY-SUMMARY-PR-LOST,
# dev/status/harness.md) exists specifically because a step that "looked
# right" silently dropped the daily summary for five consecutive
# orchestrator runs with nothing catching it. A replacement publisher whose
# own guards can rot unnoticed would repeat exactly that failure shape.
# Same precedent as prior_cell_check_test_runner.sh / prune_candidates_test_runner.sh
# (see their headers): dune wiring beats leaving a dev/scripts/ test unwired.
#
# `dev/scripts/` is outside the dune workspace root and is read via
# repo_root() at RUN TIME, so the rule needs `(universe)` -- without it,
# dune caches a pass and never re-runs when the scripts change.

set -eu

. "$(dirname "$0")/_check_lib.sh"

TEST="$(repo_root)/dev/scripts/publish_daily_summary_test.sh"

if [ ! -f "$TEST" ]; then
  # FAIL, do not skip -- same reasoning as the sibling runners' identical
  # guard: the test ships in the SAME COMMIT as the script it tests, so
  # absence only means deletion, which is exactly the rot this wiring
  # exists to catch.
  echo "FAIL: publish_daily_summary_test.sh not found at $TEST" >&2
  echo "  The test ships alongside dev/scripts/publish_daily_summary.sh; if it" >&2
  echo "  is gone, the guard is unpinned. Restore it or remove this dune rule." >&2
  exit 1
fi

# The test suite must be run with a real shell that supports its
# arithmetic/subshell usage; `sh` on this image is dash, which is fine --
# same invocation as the sibling runners.
sh "$TEST"
