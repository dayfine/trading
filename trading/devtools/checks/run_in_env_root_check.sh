#!/bin/sh
# run_in_env_root_check.sh — regression test for H-RUNENV-WORKTREE-BLIND.
#
# dev/lib/run-in-env.sh's in-container (TRADING_IN_CONTAINER) path used to
# pin PROJECT_ROOT to ${GITHUB_WORKSPACE}/trading unconditionally, ignoring
# the invoker's cwd entirely. An agent working inside a git worktree would
# run `dune build && dune runtest`, silently build+test the MAIN checkout
# instead of its own tree, and report a false green for code it never
# compiled (see dev/status/harness.md "H-RUNENV-WORKTREE-BLIND"; PR #2139
# shipped this exact signature).
#
# This test builds two throwaway git trees, each with its own trading/
# dune-workspace and its own copy of run-in-env.sh, and asserts:
#   1. THE BUG: invoking the script from inside tree A, with
#      GITHUB_WORKSPACE pointed at tree B (the "fake main checkout"),
#      resolves to tree A — never silently falls back to tree B.
#   2. The normal GHA case (cwd == GITHUB_WORKSPACE) still resolves
#      correctly.
#   3. The devcontainer fallback (no GITHUB_WORKSPACE, cwd outside any git
#      tree) still resolves relative to the script's own location.
#   4. The disagreement case: cwd is inside tree A, but the invoked script
#      is tree B's copy (invoked by absolute path) — the two independent
#      derivations disagree, and the script must fail loudly (non-zero
#      exit, both candidate paths named in stderr) rather than silently
#      picking one.
#   5. A resolved root that itself lacks a dune-workspace still fails
#      loudly (pre-existing behavior, must not regress).
#   6. The GITHUB_WORKSPACE last-resort fallback (cwd outside any git tree
#      with trading/dune-workspace, GITHUB_WORKSPACE set) resolves to
#      ${GITHUB_WORKSPACE}/trading. This branch bypasses the disagreement
#      guard, so it is exercised explicitly rather than left as a gap.
#
# Uses RUN_IN_ENV_PRINT_ROOT=1 (a seam added alongside the fix) to observe
# the resolved PROJECT_ROOT without requiring a real dune workspace / opam
# environment.
#
# Requires bash (run-in-env.sh's shebang) and git. Skips cleanly if either
# is unavailable.

set -eu

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
SCRIPT="${REPO_ROOT}/dev/lib/run-in-env.sh"

[ -f "$SCRIPT" ] || die "run_in_env_root_check: $SCRIPT does not exist"

if ! command -v bash >/dev/null 2>&1; then
  echo "OK: run_in_env_root_check — SKIPPED (bash not on PATH)."
  exit 0
fi
if ! command -v git >/dev/null 2>&1; then
  echo "OK: run_in_env_root_check — SKIPPED (git not on PATH)."
  exit 0
fi

PASS=0
FAIL=0

ok() {
  printf 'OK: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

BASE_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$BASE_DIR"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Fixture setup: two independent trees, each with trading/dune-workspace and
# its own copy of run-in-env.sh.
# ---------------------------------------------------------------------------
make_tree() {
  # $1 = tree dir
  tree_dir="$1"
  mkdir -p "${tree_dir}/trading"
  : >"${tree_dir}/trading/dune-workspace"
  mkdir -p "${tree_dir}/dev/lib"
  cp "$SCRIPT" "${tree_dir}/dev/lib/run-in-env.sh"
  git init -q "$tree_dir"
}

TREE_A="${BASE_DIR}/treeA"
TREE_B="${BASE_DIR}/treeB"
make_tree "$TREE_A"
make_tree "$TREE_B"

# ---------------------------------------------------------------------------
# Test 1 (THE BUG): cwd = treeA, GITHUB_WORKSPACE = treeB (fake main),
# invoke treeA's OWN copy of the script. Must resolve to treeA, never treeB.
# ---------------------------------------------------------------------------
OUT1=$(cd "$TREE_A" && TRADING_IN_CONTAINER=1 GITHUB_WORKSPACE="$TREE_B" \
  RUN_IN_ENV_PRINT_ROOT=1 bash "${TREE_A}/dev/lib/run-in-env.sh" true 2>&1) && CODE1=0 || CODE1=$?
if [ "$CODE1" -eq 0 ] && [ "$OUT1" = "${TREE_A}/trading" ]; then
  ok "run_in_env_root_check — worktree invocation resolves to its own tree, not \$GITHUB_WORKSPACE (H-RUNENV-WORKTREE-BLIND)"
else
  fail "run_in_env_root_check — expected PROJECT_ROOT=${TREE_A}/trading, got exit=${CODE1} output='${OUT1}'"
fi

# ---------------------------------------------------------------------------
# Test 2: normal GHA case — cwd == GITHUB_WORKSPACE. Must resolve to
# ${GITHUB_WORKSPACE}/trading, unchanged from prior behavior.
# ---------------------------------------------------------------------------
OUT2=$(cd "$TREE_B" && TRADING_IN_CONTAINER=1 GITHUB_WORKSPACE="$TREE_B" \
  RUN_IN_ENV_PRINT_ROOT=1 bash "${TREE_B}/dev/lib/run-in-env.sh" true 2>&1) && CODE2=0 || CODE2=$?
if [ "$CODE2" -eq 0 ] && [ "$OUT2" = "${TREE_B}/trading" ]; then
  ok "run_in_env_root_check — normal GHA case (cwd == GITHUB_WORKSPACE) still resolves correctly"
else
  fail "run_in_env_root_check — expected PROJECT_ROOT=${TREE_B}/trading, got exit=${CODE2} output='${OUT2}'"
fi

# ---------------------------------------------------------------------------
# Test 3: devcontainer fallback — no GITHUB_WORKSPACE, cwd outside any git
# tree. Must resolve relative to the script's own on-disk location.
# ---------------------------------------------------------------------------
OUT3=$(cd /tmp && TRADING_IN_CONTAINER=1 GITHUB_WORKSPACE="" \
  RUN_IN_ENV_PRINT_ROOT=1 bash "${TREE_A}/dev/lib/run-in-env.sh" true 2>&1) && CODE3=0 || CODE3=$?
if [ "$CODE3" -eq 0 ] && [ "$OUT3" = "${TREE_A}/trading" ]; then
  ok "run_in_env_root_check — devcontainer fallback (no GITHUB_WORKSPACE, cwd outside any git tree) unregressed"
else
  fail "run_in_env_root_check — expected PROJECT_ROOT=${TREE_A}/trading, got exit=${CODE3} output='${OUT3}'"
fi

# ---------------------------------------------------------------------------
# Test 4: disagreement — cwd is inside treeA, but the invoked script is
# treeB's copy (by absolute path). The two derivations disagree; the script
# must fail loudly (non-zero exit, both candidate paths named in stderr).
# ---------------------------------------------------------------------------
OUT4=$(cd "$TREE_A" && TRADING_IN_CONTAINER=1 GITHUB_WORKSPACE="" \
  bash "${TREE_B}/dev/lib/run-in-env.sh" true 2>&1) && CODE4=0 || CODE4=$?
if [ "$CODE4" -ne 0 ] \
  && echo "$OUT4" | grep -qF "${TREE_A}/trading" \
  && echo "$OUT4" | grep -qF "${TREE_B}/trading" \
  && echo "$OUT4" | grep -qi "ambiguous"; then
  ok "run_in_env_root_check — disagreement between cwd-derived and script-location-derived root fails loudly, naming both"
else
  fail "run_in_env_root_check — expected non-zero exit naming both ${TREE_A}/trading and ${TREE_B}/trading, got exit=${CODE4} output='${OUT4}'"
fi

# ---------------------------------------------------------------------------
# Test 5: resolved root itself lacks a dune-workspace — must still fail
# loudly (pre-existing behavior; guards against a regression introduced by
# the new resolution logic).
# ---------------------------------------------------------------------------
TREE_D="${BASE_DIR}/treeD"
mkdir -p "${TREE_D}/dev/lib"
cp "$SCRIPT" "${TREE_D}/dev/lib/run-in-env.sh"
git init -q "$TREE_D"
# Deliberately no trading/dune-workspace under treeD.

OUT5=$(cd "$TREE_D" && TRADING_IN_CONTAINER=1 GITHUB_WORKSPACE="" \
  bash "${TREE_D}/dev/lib/run-in-env.sh" true 2>&1) && CODE5=0 || CODE5=$?
if [ "$CODE5" -ne 0 ] && echo "$OUT5" | grep -qF "no dune-workspace at"; then
  ok "run_in_env_root_check — missing dune-workspace at resolved root still fails loudly"
else
  fail "run_in_env_root_check — expected non-zero exit + 'no dune-workspace at' message, got exit=${CODE5} output='${OUT5}'"
fi

# ---------------------------------------------------------------------------
# Test 6: GITHUB_WORKSPACE last-resort fallback — cwd outside any git tree
# (or inside one lacking trading/dune-workspace) AND GITHUB_WORKSPACE set.
# Must resolve to ${GITHUB_WORKSPACE}/trading, exercising the `elif`
# branch none of tests 1/2/4 (cwd branch) or 3/5 (no GITHUB_WORKSPACE)
# reach. This branch bypasses the disagreement guard, so it is the one
# remaining path that can silently resolve to a root other than the
# invoker's tree; documented here rather than left untested.
# ---------------------------------------------------------------------------
OUT6=$(cd /tmp && TRADING_IN_CONTAINER=1 GITHUB_WORKSPACE="$TREE_B" \
  RUN_IN_ENV_PRINT_ROOT=1 bash "${TREE_A}/dev/lib/run-in-env.sh" true 2>&1) && CODE6=0 || CODE6=$?
if [ "$CODE6" -eq 0 ] && [ "$OUT6" = "${TREE_B}/trading" ]; then
  ok "run_in_env_root_check — GITHUB_WORKSPACE last-resort fallback (cwd outside any git tree) resolves to \$GITHUB_WORKSPACE/trading"
else
  fail "run_in_env_root_check — expected PROJECT_ROOT=${TREE_B}/trading, got exit=${CODE6} output='${OUT6}'"
fi

cleanup
trap - EXIT INT TERM

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: run_in_env_root_check — ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi

echo "OK: run_in_env_root_check — ${PASS} assertion(s) passed, 0 failed."
