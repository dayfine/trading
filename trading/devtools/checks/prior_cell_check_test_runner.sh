#!/bin/sh
# prior_cell_check_test_runner.sh -- dune-runtest shim for
# dev/scripts/prior_cell_check_test.sh.
#
# WHY WIRED. `prior_cell_check.sh` is the mechanical form of a mistake this
# repo made on 2026-08-20: an experiment writeup claimed "no prior null exists
# for MaxDD or Sharpe" while a committed file
# (dev/experiments/nearfloor-26y-salts-2026-08-13/results.txt) already carried
# that exact cell at all three salts. A guard against a recurring interpretive
# error is only worth having if it cannot itself rot, so its test runs in CI.
#
# Precedent is split and both halves are stated honestly: docker_dune_smoke.sh
# wires a dev/scripts test into `dune runtest` through a shim like this one,
# while pr_gate_status_test.sh is not wired. Wired is the better half.
#
# `dev/scripts/` is outside the dune workspace root and is read via repo_root()
# at RUN TIME, so the rule needs `(universe)` for the same reason as its
# siblings (H-CHECK-CACHE-BLIND) -- without it, dune caches a pass and never
# re-runs when the script changes.

set -eu

. "$(dirname "$0")/_check_lib.sh"

TEST="$(repo_root)/dev/scripts/prior_cell_check_test.sh"

if [ ! -f "$TEST" ]; then
  # FAIL, do not skip. An earlier version of this shim printed a WARNING and
  # exited 0 here, citing rule_promotion_check.sh's missing-doc precedent.
  # qc-behavioral was right to call that a vacuity hole (#2437):
  #
  #   - rule_promotion_check.sh guards an OPTIONAL doc, so absence is a
  #     legitimate state. This guards a test file that ships in the SAME
  #     COMMIT, so the only way it can go missing is deletion — which is
  #     precisely the rot this dune wiring exists to catch.
  #   - And a PR whose whole thesis is "unverified absence must not read as
  #     OK" cannot itself treat absence as OK.
  #
  # repo_root() already hard-errors on a failed walk-up, so a wrong root
  # cannot reach this line silently.
  echo "FAIL: prior_cell_check_test.sh not found at $TEST" >&2
  echo "  The test ships alongside dev/scripts/prior_cell_check.sh; if it is" >&2
  echo "  gone, the guard is unpinned. Restore it or remove this dune rule." >&2
  exit 1
fi

sh "$TEST"
