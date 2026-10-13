#!/bin/sh
# wait_for_test_runner.sh -- dune-runtest shim for dev/scripts/wait_for_test.sh
# (issue #2738 Ask 2).
#
# dev/scripts/wait_for.sh is the dispatcher's background wait helper
# (.claude/rules/dispatcher-cadence.md). A wait that silently never fires, or
# fires on a zombie dune, is the stall the helper exists to prevent, so its
# conditions are pinned here. Same shim + (universe) pattern as
# dispatch_disk_guard_test_runner.sh: dev/scripts/ is outside the dune
# workspace root and is resolved via repo_root() at run time.

set -eu

. "$(dirname "$0")/_check_lib.sh"

TEST="$(repo_root)/dev/scripts/wait_for_test.sh"

if [ ! -f "$TEST" ]; then
  # FAIL, do not skip: the test ships in the same commit as the script.
  echo "FAIL: wait_for_test.sh not found at $TEST" >&2
  exit 1
fi

sh "$TEST"
