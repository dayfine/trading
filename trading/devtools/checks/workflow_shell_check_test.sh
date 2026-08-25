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
# neutralization, single-line run:, known-gap, dialect resolution) SKIP
# cleanly with a printed notice when shellcheck is absent, so this test
# passes in both worlds. The SKIP-path assertion itself (shellcheck absent
# via PATH override) does not depend on the real environment and always
# runs.

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
# SC2030/SC2031). This is a DIFFERENT shellcheck detection mechanism than
# the ce88954 defect that motivated this check -- ce88954's variable was
# lost across a *command-substitution* subshell invoking a function, which
# shellcheck 0.8.0 does not model (see workflow_shell_check.sh's header
# "IMPORTANT SCOPE LIMITATION" note and #2521 for the residual gap). This
# fixture still pins a real, useful shellcheck guard -- pipeline-subshell
# scope loss -- even though it is not the ce88954 shape itself; see the
# "known gap" fixture below for that shape. ----

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

# ---- Fixture dir: KNOWN GAP -- reconstructs the exact ce88954 shape: a
# function assigns an ALL-CAPS variable, invoked via command substitution
# (`X="$(fn)"`), and the caller reads the function-assigned variable back
# under `set -u`. Verified against shellcheck 0.8.0 (see
# workflow_shell_check.sh's header "IMPORTANT SCOPE LIMITATION"): this is
# NOT caught -- neither by SC2154 nor by the check-unassigned-uppercase
# optional rule, both of which see the assignment lexically present in
# the file and don't track which shell process performs it. This fixture
# pins that CURRENT (limited) behavior as a regression test: if a future
# shellcheck version gains this detection, the assertion below starts
# failing -- that is a signal to revisit #2521 and correct the header +
# this comment, not a bug in the test. ----

GAP_DIR="${TMPDIR_BASE}/known_gap"
mkdir -p "$GAP_DIR"
cat > "${GAP_DIR}/ce88954_shape.yml" << 'EOF'
name: Known gap
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Command-substitution-into-function scope loss (ce88954 shape)
        run: |
          set -euo pipefail
          merge_pr_when_clean() {
            local pr="$1"
            MERGE_RESPONSE="merged-${pr}"
          }
          MERGED="$(merge_pr_when_clean 123)"
          echo "result: ${MERGED}"
          echo "leaked: ${MERGE_RESPONSE}"
EOF

# ---- Fixture dirs: DIALECT RESOLUTION -- one step-level `shell: sh`
# override, one job-level `defaults: run: shell: sh`. Both bodies contain
# a bash array (`arr=(a b c)`), which shellcheck accepts under `-s bash`
# (no finding) but flags under `-s sh` as SC3030/SC3054 ("In POSIX sh,
# arrays [references] are undefined") -- verified directly. So a PASS
# here proves the resolved dialect actually reached shellcheck as `sh`,
# not that the linter silently fell back to its bash default. ----

DIALECT_STEP_DIR="${TMPDIR_BASE}/dialect_step"
mkdir -p "$DIALECT_STEP_DIR"
cat > "${DIALECT_STEP_DIR}/step_override.yml" << 'EOF'
name: Step-level shell override
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Bash-ism under a step-level sh override
        shell: sh
        run: |
          arr=(a b c)
          echo "${arr[0]}"
EOF

DIALECT_DEFAULT_DIR="${TMPDIR_BASE}/dialect_default"
mkdir -p "$DIALECT_DEFAULT_DIR"
cat > "${DIALECT_DEFAULT_DIR}/job_default.yml" << 'EOF'
name: Job-level default shell
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: sh
    steps:
      - name: Bash-ism inheriting the job-level sh default
        run: |
          arr=(a b c)
          echo "${arr[0]}"
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

  # ---- Known-gap fixture: pins the CURRENT (limited) shellcheck behavior
  # on the reconstructed ce88954 shape -- see the fixture comment above and
  # workflow_shell_check.sh's header "IMPORTANT SCOPE LIMITATION". Expected
  # exit 0 (clean) TODAY; a non-zero exit here means shellcheck gained
  # detection for this shape and #2521 + both header comments need an
  # update, not that this test is broken. ----

  GAP_OUTPUT="$(WORKFLOW_SHELL_CHECK_DIR="$GAP_DIR" sh "$LINTER" 2>&1)" && GAP_EXIT=0 || GAP_EXIT=$?

  if [ "$GAP_EXIT" -ne 0 ]; then
    echo "FAIL: workflow_shell_check_test -- known-gap fixture (ce88954 shape) now trips the linter."
    echo "  This means shellcheck may have gained command-substitution-into-function"
    echo "  scope-loss detection -- if so, this is GOOD NEWS: update #2521, remove the"
    echo "  'IMPORTANT SCOPE LIMITATION' note in workflow_shell_check.sh, and update this"
    echo "  fixture's comment. This is not a bug in the test as written."
    echo "  output: $GAP_OUTPUT"
    exit 1
  fi
  _pass

  # ---- Dialect resolution: step-level `shell: sh` override. A clean exit
  # (dialect silently defaulted to bash) would mean the override was never
  # threaded through to shellcheck -- the exact bug this fixture exists to
  # catch. ----

  DSTEP_OUTPUT="$(WORKFLOW_SHELL_CHECK_DIR="$DIALECT_STEP_DIR" sh "$LINTER" 2>&1)" && DSTEP_EXIT=0 || DSTEP_EXIT=$?

  if [ "$DSTEP_EXIT" -eq 0 ]; then
    echo "FAIL: workflow_shell_check_test -- step-level 'shell: sh' override did not reach shellcheck (linter exited 0 on a bash-only construct under sh)"
    echo "  output: $DSTEP_OUTPUT"
    exit 1
  fi
  _pass

  if ! printf '%s' "$DSTEP_OUTPUT" | grep -Eq "SC3030|SC3054"; then
    echo "FAIL: workflow_shell_check_test -- expected SC3030/SC3054 (POSIX sh array warnings) when step-level shell: sh is resolved correctly"
    echo "  output: $DSTEP_OUTPUT"
    exit 1
  fi
  _pass

  # ---- Dialect resolution: job-level `defaults: run: shell: sh`, no
  # step-level override -- same proof, different resolution path (pass 1's
  # step_idx == 0 default_shell branch). ----

  DDEFAULT_OUTPUT="$(WORKFLOW_SHELL_CHECK_DIR="$DIALECT_DEFAULT_DIR" sh "$LINTER" 2>&1)" && DDEFAULT_EXIT=0 || DDEFAULT_EXIT=$?

  if [ "$DDEFAULT_EXIT" -eq 0 ]; then
    echo "FAIL: workflow_shell_check_test -- job-level 'defaults: run: shell: sh' did not reach shellcheck (linter exited 0 on a bash-only construct under sh)"
    echo "  output: $DDEFAULT_OUTPUT"
    exit 1
  fi
  _pass

  if ! printf '%s' "$DDEFAULT_OUTPUT" | grep -Eq "SC3030|SC3054"; then
    echo "FAIL: workflow_shell_check_test -- expected SC3030/SC3054 (POSIX sh array warnings) when job-level defaults: run: shell: sh is resolved correctly"
    echo "  output: $DDEFAULT_OUTPUT"
    exit 1
  fi
  _pass

else
  echo "SKIP: workflow_shell_check_test -- shellcheck not installed; skipping fixture-based OK/FAIL/GHEXPR/known-gap/dialect assertions (see workflow_shell_check.sh header)"
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
