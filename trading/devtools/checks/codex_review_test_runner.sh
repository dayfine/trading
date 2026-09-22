#!/bin/sh
# Runs the offline suites for dev/scripts/codex_review.sh and
# dev/scripts/codex_agreement_row.sh (issue #2905). Both live outside the dune
# workspace root and are read via repo_root() at RUN TIME ((universe) dep).
set -eu
. "$(dirname "$0")/_check_lib.sh"
for t in codex_review_test.sh codex_agreement_row_test.sh; do
  TEST="$(repo_root)/dev/scripts/$t"
  if [ ! -f "$TEST" ]; then
    echo "FAIL: $t not found at $TEST" >&2
    echo "  The test ships alongside its dev/scripts/ script; if it is gone," >&2
    echo "  the validator is unpinned. Restore it or remove this dune rule." >&2
    exit 1
  fi
  sh "$TEST"
done
