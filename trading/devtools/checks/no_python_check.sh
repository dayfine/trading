#!/bin/sh
# No-Python enforcement check.
#
# Scans the repository for any *.py files and fails if any are found.
# The codebase is OCaml + Dune only (see .claude/rules/no-python.md).
#
# Previously, two Python scripts were grandfathered under
# dev/scripts/perf_sweep_report.py and dev/scripts/perf_hypothesis_report.py.
# Both were deleted when the Legacy loader_strategy was removed (Stage 3,
# PR #575). There are no remaining exceptions.
#
# Excluded from the scan (not part of the source tree):
#   .git/         VCS internals
#   _build/       Dune build artifacts
#   node_modules/ Front-end dependencies (not present; excluded defensively)
#   vendor/       Third-party vendored code (not present; excluded defensively)
#   .devcontainer/ Docker image build context (may include Python install steps)
#
# Output:
#   OK: no-python check -- no *.py files found.
#   FAIL: lists each offending file; exits 1.

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"

# Collect *.py files, excluding generated/non-source directories.
FOUND=$(find "$REPO_ROOT" \
  -path "$REPO_ROOT/.git" -prune -o \
  -path "$REPO_ROOT/_build" -prune -o \
  -path "$REPO_ROOT/node_modules" -prune -o \
  -path "$REPO_ROOT/vendor" -prune -o \
  -path "$REPO_ROOT/.devcontainer" -prune -o \
  -name '*.py' -print \
  2>/dev/null)

if [ -n "$FOUND" ]; then
  echo "FAIL: no-python check -- unexpected *.py files found:"
  echo "$FOUND" | while IFS= read -r f; do
    echo "  $f"
  done
  echo "Fix: the codebase is OCaml + Dune only. See .claude/rules/no-python.md"
  echo "     for alternatives (OCaml exe, jq one-liner, POSIX shell)."
  exit 1
fi

echo "OK: no-python check -- no *.py files found."
