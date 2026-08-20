#!/bin/sh
# prune_candidates_test_runner.sh -- dune-runtest shim for
# dev/scripts/prune_candidates_test.sh.
#
# WHY WIRED. dev/plans/arc-readiness-2026-08-20.md Axis 3 asks specifically
# for prune_candidates.sh's sanity probes to be "exercised in CI rather than
# only on the cron" -- the whole point of the script is that it must never
# silently report a false-clean result, and that property can rot the same
# way any other code can. Same precedent as prior_cell_check_test_runner.sh
# (see its header): dune wiring beats leaving a dev/scripts/ test unwired.
#
# `dev/scripts/` is outside the dune workspace root and is read via
# repo_root() at RUN TIME, so the rule needs `(universe)` -- without it,
# dune caches a pass and never re-runs when the scripts change.

set -eu

. "$(dirname "$0")/_check_lib.sh"

TEST="$(repo_root)/dev/scripts/prune_candidates_test.sh"

if [ ! -f "$TEST" ]; then
  # FAIL, do not skip -- same reasoning as prior_cell_check_test_runner.sh's
  # identical guard: the test ships in the SAME COMMIT as the script it
  # tests, so absence only means deletion, which is exactly the rot this
  # wiring exists to catch.
  echo "FAIL: prune_candidates_test.sh not found at $TEST" >&2
  echo "  The test ships alongside dev/scripts/prune_candidates.sh; if it is" >&2
  echo "  gone, the guard is unpinned. Restore it or remove this dune rule." >&2
  exit 1
fi

sh "$TEST"
