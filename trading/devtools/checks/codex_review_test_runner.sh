#!/bin/sh
# codex_review_test_runner.sh -- dune-runtest shim for
# dev/scripts/codex_review_test.sh (the advisory Codex review poster's report
# validator; .claude/rules/cross-agent-review.md). Same shim + (universe)
# pattern as prior_cell_check_test_runner.sh: dev/scripts/ is outside the dune
# workspace root and is read via repo_root() at run time.
set -eu

. "$(dirname "$0")/_check_lib.sh"

TEST="$(repo_root)/dev/scripts/codex_review_test.sh"

if [ ! -f "$TEST" ]; then
  # FAIL, do not skip (the vacuity argument in prior_cell_check_test_runner.sh).
  echo "FAIL: codex_review_test.sh not found at $TEST" >&2
  echo "  The test ships alongside dev/scripts/codex_review.sh; if it is gone," >&2
  echo "  the validator is unpinned. Restore it or remove this dune rule." >&2
  exit 1
fi

sh "$TEST"
