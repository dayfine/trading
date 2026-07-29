#!/bin/sh
# Regression test for H-CHECK-SETE-DIAGNOSTICS.
#
# The bug: several trading/devtools/checks/*.sh scripts run under `set -e`
# with the shape `VAR=$(cmd); CODE=$?`. Under `set -e`, a bare command-
# substitution assignment whose command fails trips `set -e` on the
# assignment itself -- the script dies BEFORE `CODE=$?` (or any FAIL:
# message) is ever reached. Detection still works from the outside (dune
# sees a non-zero exit -> CI red), but the failure surfaces as "non-zero
# exit, empty output, no source-level error" -- exactly the signature
# `.claude/rules/pr-merge-gates.md` documents as an admissible infra-flake
# exception. A real regression can get waved through triage as a sandbox
# race unless the diagnostic survives.
#
# This test proves two things using a fake `jj` binary that fails only on
# `workspace list` (simulating a real jj failure -- lock contention, a
# corrupt workspace, a version-skew syntax break):
#
#   1. NEGATIVE CONTROL: the pre-fix shape (reproduced literally below, not
#      read from git history -- see note at OLD_SCRIPT) dies with a
#      non-zero exit and ZERO diagnostic output when the underlying command
#      fails. This proves the bug is real, not theoretical.
#   2. THE FIX: jj_workspace_smoke.sh's current logic (which wraps the same
#      assignment in `&& CODE=0 || CODE=$?`, per its Step 2 comment) emits a
#      "FAIL: jj_workspace_smoke —" line naming the failure and still exits
#      non-zero. The diagnostic now survives the exact failure the negative
#      control reproduced.
#
# Why the negative control is a literal reproduction instead of `git show
# <old-sha>:...`: this test must keep working on every future commit,
# including in a shallow CI checkout that may not have the pre-fix commit
# in its fetched history. A self-contained reproduction has no such
# dependency.

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="sete_diagnostics_check"
PASS=0
FAIL=0

ok() {
  printf 'OK: %s\n' "$1"
  PASS=$((PASS + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

REPO_ROOT_REAL="$(repo_root)"
JJ_SMOKE="${REPO_ROOT_REAL}/trading/devtools/checks/jj_workspace_smoke.sh"
[ -f "$JJ_SMOKE" ] || die "sete_diagnostics_check: $JJ_SMOKE does not exist"

FAKE_BIN="$(mktemp -d)"
OLD_SCRIPT="$(mktemp)"
trap 'rm -rf "$FAKE_BIN" "$OLD_SCRIPT"' EXIT INT TERM

# --- Fake `jj`: succeeds on every subcommand except `workspace list` ---
cat > "${FAKE_BIN}/jj" <<'EOF'
#!/bin/sh
case "$*" in
  *"workspace list"*)
    echo "SIMULATED: jj workspace list failed (fake binary for sete_diagnostics_check)" >&2
    exit 1
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "${FAKE_BIN}/jj"

# ---------------------------------------------------------------------------
# Part 1 (negative control): the pre-fix shape of jj_workspace_smoke.sh's
# Step 2 --
#   WS_LIST=$(jj -R "$REPO" workspace list 2>&1)
#   if ! echo "$WS_LIST" | grep -qF "$AGENT_ID"; then ...
# reproduced literally (see the note above for why this is not `git show`).
# ---------------------------------------------------------------------------
cat > "$OLD_SCRIPT" <<'EOF'
#!/bin/sh
set -e
REPO="fake-repo"
AGENT_ID="fake-agent"
WS_LIST=$(jj -R "$REPO" workspace list 2>&1)
if ! echo "$WS_LIST" | grep -qF "$AGENT_ID"; then
  echo "FAIL: jj_workspace_smoke (old) — 'jj workspace list' does not include '$AGENT_ID'."
  exit 1
fi
echo "OK: jj_workspace_smoke (old) — unreachable if jj workspace list had failed"
EOF
chmod +x "$OLD_SCRIPT"

OLD_OUT=$(PATH="${FAKE_BIN}:${PATH}" sh "$OLD_SCRIPT" 2>&1) && OLD_CODE=0 || OLD_CODE=$?

if [ "$OLD_CODE" -ne 0 ] && ! printf '%s' "$OLD_OUT" | grep -q '^FAIL:'; then
  ok "${LABEL} — negative control: pre-fix shape dies (exit=${OLD_CODE}) with NO FAIL: line (output: '${OLD_OUT}') -- reproduces the silent-failure bug"
else
  bad "${LABEL} — negative control did NOT reproduce the bug: expected non-zero exit with no FAIL: line, got exit=${OLD_CODE} output='${OLD_OUT}'"
fi

# ---------------------------------------------------------------------------
# Part 2 (the fix): jj_workspace_smoke.sh's current Step 2 must name the
# failure instead of dying silently.
# ---------------------------------------------------------------------------
NEW_OUT=$(PATH="${FAKE_BIN}:${PATH}" REPO_ROOT="$REPO_ROOT_REAL" sh "$JJ_SMOKE" 2>&1) && NEW_CODE=0 || NEW_CODE=$?

if [ "$NEW_CODE" -ne 0 ] && printf '%s' "$NEW_OUT" | grep -q '^FAIL: jj_workspace_smoke'; then
  ok "${LABEL} — fix: jj_workspace_smoke.sh emits a FAIL: line naming the 'jj workspace list' failure (exit=${NEW_CODE})"
else
  bad "${LABEL} — expected a 'FAIL: jj_workspace_smoke' line and non-zero exit; got exit=${NEW_CODE} output='${NEW_OUT}'"
fi

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: ${LABEL} — ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi

echo "OK: ${LABEL} — ${PASS} assertion(s) passed, 0 failed."
