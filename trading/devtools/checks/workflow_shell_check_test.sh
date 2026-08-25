#!/bin/sh
# Fixture-driven smoke test for workflow_shell_check.sh.
#
# Builds throwaway workflow YAML fixtures under a temp dir and points the
# linter at them via WORKFLOW_SHELL_CHECK_DIR, so this test never depends
# on the real .github/workflows/*.yml content (that content changes over
# time; the fixtures here pin the extractor's contract independently).
#
# shellcheck itself is not guaranteed to be on PATH in every environment
# this test runs in (it is not yet in the trading-devcontainer base image
# as of #2521 -- see workflow_shell_check.sh's own header). The
# shellcheck-dependent assertions (OK-fixture, FAIL-fixture, GH-expression
# neutralization, single-line run:) SKIP cleanly with a printed notice when
# shellcheck is absent, so this test passes in both worlds. The SKIP-path
# assertion itself (shellcheck absent via PATH override) does not depend on
# the real environment and always runs.

set -e

. "$(dirname "$0")/_check_lib.sh"

LINTER="$(dirname "$0")/workflow_shell_check.sh"
[ -f "$LINTER" ] || die "workflow_shell_check_test: linter not found at $LINTER"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

PASS_COUNT=0
_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
}

HAVE_SHELLCHECK=1
if ! command -v shellcheck >/dev/null 2>&1; then
  HAVE_SHELLCHECK=0
fi

# ---- Fixture dir: OK -- a clean block-scalar step, a clean single-line
# step, and a step using a GH ${{ }} expression (proves neutralization). ----

OK_DIR="${TMPDIR_BASE}/ok"
mkdir -p "$OK_DIR"
cat > "${OK_DIR}/clean.yml" << 'EOF'
name: Clean
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Clean block-scalar step
        run: |
          set -e
          echo "hello world"
      - name: Clean single-line step
        run: echo "single line"
EOF
cat > "${OK_DIR}/ghexpr.yml" << 'EOF'
name: GH expression
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Uses a GH Actions expression
        run: |
          set -e
          cd "${{ github.workspace }}/trading"
          echo "hi"
EOF

# ---- Fixture dir: FAIL -- a step whose variable is modified only inside a
# pipeline subshell then read back in the caller scope (shellcheck
# SC2030/SC2031 -- the same "assignment invisible outside its subshell"
# shape as the ce88954 defect that motivated this check, #2521). ----

FAIL_DIR="${TMPDIR_BASE}/fail"
mkdir -p "$FAIL_DIR"
cat > "${FAIL_DIR}/defect.yml" << 'EOF'
name: Defect
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Subshell-scoped counter
        run: |
          set -euo pipefail
          COUNT=0
          find . -maxdepth 1 -name '*.sh' | while read -r f; do
            COUNT=$((COUNT + 1))
          done
          echo "Count: ${COUNT}"
EOF

if [ "$HAVE_SHELLCHECK" = "1" ]; then

  # ---- Assertions a/c/e: OK fixture -- clean block-scalar + single-line +
  # neutralized GH expression, all in one pass. ----

  OK_OUTPUT="$(WORKFLOW_SHELL_CHECK_DIR="$OK_DIR" sh "$LINTER" 2>&1)" && OK_EXIT=0 || OK_EXIT=$?

  if [ "$OK_EXIT" -ne 0 ]; then
    echo "FAIL: workflow_shell_check_test -- linter failed on clean fixtures (expected exit 0)"
    echo "  output: $OK_OUTPUT"
    exit 1
  fi
  _pass

  if ! printf '%s' "$OK_OUTPUT" | grep -q "^OK: workflow-shell linter -- 3 run: block(s) clean\."; then
    echo "FAIL: workflow_shell_check_test -- expected '3 run: block(s) clean' in OK-fixture output"
    echo "  output: $OK_OUTPUT"
    exit 1
  fi
  _pass

  # Assertion c: the GH ${{ }} expression must not surface as a shellcheck
  # finding (SC2296 "Parameter expansions can't start with {" is exactly
  # what raw, unneutralized `${{ ... }}` triggers -- verified directly
  # against shellcheck while building this test).
  if printf '%s' "$OK_OUTPUT" | grep -q "SC2296"; then
    echo "FAIL: workflow_shell_check_test -- GH \${{ }} expression leaked into shellcheck as SC2296 (neutralization broken)"
    echo "  output: $OK_OUTPUT"
    exit 1
  fi
  _pass

  # ---- Assertion b: FAIL fixture -- names both the file and the step. ----

  FAIL_OUTPUT="$(WORKFLOW_SHELL_CHECK_DIR="$FAIL_DIR" sh "$LINTER" 2>&1)" && FAIL_EXIT=0 || FAIL_EXIT=$?

  if [ "$FAIL_EXIT" -eq 0 ]; then
    echo "FAIL: workflow_shell_check_test -- linter exited 0 on defect fixture (expected non-zero)"
    echo "  output: $FAIL_OUTPUT"
    exit 1
  fi
  _pass

  if ! printf '%s' "$FAIL_OUTPUT" | grep -q "FAIL: defect\.yml__s1"; then
    echo "FAIL: workflow_shell_check_test -- defect fixture's file+step marker not in linter output"
    echo "  output: $FAIL_OUTPUT"
    exit 1
  fi
  _pass

  if ! printf '%s' "$FAIL_OUTPUT" | grep -Eq "SC2030|SC2031"; then
    echo "FAIL: workflow_shell_check_test -- expected SC2030/SC2031 (subshell-scope finding) in defect fixture output"
    echo "  output: $FAIL_OUTPUT"
    exit 1
  fi
  _pass

else
  echo "SKIP: workflow_shell_check_test -- shellcheck not installed; skipping fixture-based OK/FAIL/GHEXPR assertions (see workflow_shell_check.sh header)"
fi

# ---- Assertion d: shellcheck absent (PATH override) -> SKIP, exit 0.
# Independent of whether shellcheck is actually installed -- always runs. ----

SKIP_OUTPUT="$(WORKFLOW_SHELL_CHECK_DIR="$OK_DIR" SHELLCHECK="workflow_shell_check_nonexistent_binary_xyz" sh "$LINTER" 2>&1)" && SKIP_EXIT=0 || SKIP_EXIT=$?

if [ "$SKIP_EXIT" -ne 0 ]; then
  echo "FAIL: workflow_shell_check_test -- linter did not exit 0 when shellcheck is absent"
  echo "  output: $SKIP_OUTPUT"
  exit 1
fi
_pass

if ! printf '%s' "$SKIP_OUTPUT" | grep -q "^SKIP: workflow_shell_check"; then
  echo "FAIL: workflow_shell_check_test -- expected 'SKIP: workflow_shell_check' when shellcheck is absent"
  echo "  output: $SKIP_OUTPUT"
  exit 1
fi
_pass

echo "OK: workflow_shell_check_test -- ${PASS_COUNT} assertion(s) passed."
