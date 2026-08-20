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
  # Degrade gracefully rather than reddening CI on a checkout that legitimately
  # lacks dev/ (same posture as rule_promotion_check.sh's missing-doc path).
  echo "WARNING: prior_cell_check_test.sh not found at $TEST -- skipping."
  exit 0
fi

sh "$TEST"
