#!/bin/sh
# Findings-registry check (issue #3001, .claude/rules/findings-registry.md).
#
# Verifies dev/findings/registry.sexp: every `unit` guard's file exists and
# contains the named test, every `validator` id is registered in
# validator_checks.ml, `guard none` carries a reason, status is in the enum.
# The parsing is done by the OCaml exe (sexp in POSIX sh is fragile); this
# wrapper only resolves paths.
#
# Usage: findings_registry_check.sh [PATH_TO_findings_registry_check.exe]
#   (dune passes %{exe:...}; a bare run falls back to `dune exec`.)
#
# Test overrides (used by findings_registry_check_test.sh on fixtures):
#   FINDINGS_REPO_ROOT, FINDINGS_REGISTRY_FILE, FINDINGS_VALIDATOR_SOURCE
#
# The registry and the test files live outside the dune workspace, so this
# reads the real tree via repo_root() at RUN TIME; the dune rule therefore
# needs (universe) (H-CHECK-CACHE-BLIND, same as index_size_linter.sh).

set -e

. "$(dirname "$0")/_check_lib.sh"

EXE="${1:-}"
ROOT="${FINDINGS_REPO_ROOT:-$(repo_root)}"
REGISTRY="${FINDINGS_REGISTRY_FILE:-$ROOT/dev/findings/registry.sexp}"
VALIDATORS="${FINDINGS_VALIDATOR_SOURCE:-$ROOT/trading/trading/backtest/validation/lib/validator_checks.ml}"

if [ -z "$EXE" ]; then
  echo "usage: findings_registry_check.sh PATH_TO_EXE" >&2
  exit 2
fi

exec "$EXE" "$ROOT" "$REGISTRY" "$VALIDATORS"
