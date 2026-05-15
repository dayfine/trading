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
#   _build/       Dune build artifacts — pruned by NAME, not by path, so all
#                 nested _build dirs (e.g. trading/_build) are covered.
#                 Path-anchored prunes (e.g. -path "$REPO_ROOT/_build") fail
#                 when _build is nested below the repo root (common in CI where
#                 $REPO_ROOT is the repo root but _build is inside
#                 trading/_build). A mid-walk sandbox cleanup then causes find
#                 to exit non-zero, killing the script via set -e with no
#                 error message.  See PR #1108 / #1115 for CI failure evidence.
#   node_modules/ Front-end dependencies (not present; excluded defensively)
#   vendor/       Third-party vendored code (not present; excluded defensively)
#   .devcontainer/ Docker image build context (may include Python install steps)
#   worktrees/    .claude/worktrees/ agent checkouts (may contain any language)
#
# Output:
#   OK: no-python check -- no *.py files found.
#   FAIL: lists each offending file; exits 1.

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"

# Collect *.py files, excluding generated/non-source directories.
# Name-anchored prunes (-name X -prune) match at any depth in the tree, so
# all _build dirs are pruned regardless of nesting level.  This avoids the CI
# race where a path-anchored prune misses a nested _build and find descends
# into a dune sandbox that dune is simultaneously cleaning up.
# The trailing "|| true" is belt-and-suspenders: if find still exits non-zero
# due to a transient TOCTOU deletion, we treat it as "no .py files found"
# rather than crashing the script via set -e.
FOUND=$(find "$REPO_ROOT" \
  \( -name '.git' -o -name '_build' -o -name 'node_modules' \
     -o -name 'vendor' -o -name '.devcontainer' -o -name 'worktrees' \) -prune -o \
  -name '*.py' -print \
  2>/dev/null || true)

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
