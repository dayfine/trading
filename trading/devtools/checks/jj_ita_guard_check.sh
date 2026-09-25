#!/bin/sh
# Regression test for the jj-colocation intent-to-add guard
# (jj_ita_guard_snapshot / jj_ita_guard_restore in _check_lib.sh, applied
# in jj_workspace_smoke.sh).
#
# The bug (found 2026-09-25, harness item T3-ITA / dev/daily/2026-09-24-run2.md
# escalations): jj_workspace_smoke.sh runs `jj -R "$REPO" workspace add/list/
# forget` against the REAL repo root whenever the repo happens to be
# jj-colocated -- which it is in every container image this suite runs in,
# not just interactive dev sessions. Every one of those `jj` invocations
# resolves the DEFAULT workspace's working-copy commit as a side effect
# (even `workspace list`, which looks read-only, and `workspace add`, which
# targets a *different* workspace). In a colocated repo that resolution
# exports any untracked file sitting in "$REPO" into the git index as an
# intent-to-add (` A`) entry. `git ls-files` counts intent-to-add entries as
# tracked, which silently corrupted
# `orchestrator_fastexit_gate.sh _current_summary_path`'s run-count: an
# in-progress, not-yet-committed `dev/daily/<date>*.md` flipped from
# untracked to "tracked", shifting `-run2` to `-run3`.
#
# This test proves three things against HERMETIC sandbox repos (never the
# real checkout dune invoked this script from):
#
#   1. NEGATIVE CONTROL: the underlying jj mechanism is real -- a bare,
#      unguarded `jj -R <repo> workspace add ...` against a colocated repo
#      does turn an untracked file into an intent-to-add entry. This pins
#      the mechanism so that if a future jj version stops doing this, the
#      test says so explicitly instead of silently "passing" for the wrong
#      reason.
#   2. THE FIX, happy path: jj_workspace_smoke.sh's current logic (guard
#      snapshot before, guard restore after Step 3, guard restore in the
#      trap) leaves a fresh sandbox's untracked file exactly as it found it
#      -- still plain `??`, never ` A` -- after a full successful run.
#   3. THE FIX, failure path: when `jj workspace add` itself fails (no
#      `main@origin` to resolve), the trap-driven restore still fires and
#      the sandbox is left clean, proving the guard isn't only reachable
#      from the success-path call site.
#
# Each phase gets ITS OWN fresh sandbox. Reusing one sandbox across phases
# is unsound: once jj has snapshotted a file's current content into its own
# tracked tree state, a `git reset` on the GIT side does not un-teach jj
# that fact, and a later `jj` call on the SAME unchanged file may see
# "nothing new to export" and skip re-touching the git index -- which would
# make phase 2 look like a false-positive pass for the wrong reason (the
# guard never got exercised, not because it worked). Fresh sandboxes avoid
# this ambiguity entirely.

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="jj_ita_guard_check"
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

# --- Skip cleanly if jj is not available (GHA runners without jj) ---
if ! command -v jj >/dev/null 2>&1; then
  echo "OK: ${LABEL} — SKIPPED (jj not on PATH)."
  exit 0
fi

REPO_ROOT_REAL="$(repo_root)"
JJ_SMOKE="${REPO_ROOT_REAL}/trading/devtools/checks/jj_workspace_smoke.sh"
[ -f "$JJ_SMOKE" ] || die "${LABEL}: $JJ_SMOKE does not exist"

# Isolated jj user config -- never touch the real ~/.config/jj/config.toml
# or emit "Name and email not configured" noise. JJ_CONFIG is additive/
# env-scoped (unlike `jj config set --user`, which writes global state).
JJ_CFG_DIR="$(mktemp -d)"
cat >"${JJ_CFG_DIR}/config.toml" <<'EOF'
[user]
name = "jj_ita_guard_check"
email = "jj-ita-guard-check@example.invalid"
EOF

SANDBOXES=""
cleanup_all() {
  for _sbx in $SANDBOXES; do
    rm -rf "$_sbx"
  done
  rm -rf "$JJ_CFG_DIR"
}
trap cleanup_all EXIT INT TERM

# _new_sandbox
# Create a fresh colocated git+jj repo with an empty init commit and a
# `main@origin` remote-tracking ref (mirrors production: agents resolve
# `-r main@origin`). Echoes the sandbox path.
_new_sandbox() {
  _sbx="$(mktemp -d)"
  SANDBOXES="${SANDBOXES} ${_sbx}"
  ( cd "$_sbx" \
    && git init -q -b main \
    && git commit -q --allow-empty -m init \
    && git remote add origin "$_sbx" \
    && git update-ref refs/remotes/origin/main refs/heads/main \
    && JJ_CONFIG="${JJ_CFG_DIR}" jj git init --colocate . >/dev/null 2>&1 )
  echo "$_sbx"
}

# ---------------------------------------------------------------------------
# Part 1 (negative control): a bare, unguarded jj call against a colocated
# repo really does turn an untracked file into an intent-to-add entry.
# ---------------------------------------------------------------------------
SBX1="$(_new_sandbox)"
mkdir -p "${SBX1}/dev/daily"
echo "in-progress summary" >"${SBX1}/dev/daily/2099-01-01-test.md"

RED_STATUS_BEFORE="$(git -C "$SBX1" status --porcelain=v1)"

JJ_CONFIG="${JJ_CFG_DIR}" jj -R "$SBX1" workspace add "${SBX1}-ws1" --name ita-red -r 'root()' >/dev/null 2>&1 || true
RED_STATUS_AFTER="$(git -C "$SBX1" status --porcelain=v1)"
rm -rf "${SBX1}-ws1"

if [ "$RED_STATUS_BEFORE" = "?? dev/" ] && printf '%s\n' "$RED_STATUS_AFTER" | grep -qF ' A dev/daily/2099-01-01-test.md'; then
  ok "${LABEL} — negative control: a bare 'jj workspace add' against a colocated repo turns an untracked dev/daily file into ' A' (intent-to-add) -- confirms the mechanism is real"
else
  bad "${LABEL} — negative control did NOT reproduce the mechanism: before='${RED_STATUS_BEFORE}' after='${RED_STATUS_AFTER}' (if jj's behaviour changed upstream, update this test's expectation rather than deleting it)"
fi

# ---------------------------------------------------------------------------
# Part 2 (the fix, happy path): a FRESH sandbox, run the real
# jj_workspace_smoke.sh end to end via REPO_ROOT, assert it both passes AND
# leaves the untracked file untouched.
# ---------------------------------------------------------------------------
SBX2="$(_new_sandbox)"
mkdir -p "${SBX2}/dev/daily"
echo "in-progress summary" >"${SBX2}/dev/daily/2099-01-01-test.md"

GREEN_OUT=$(JJ_CONFIG="${JJ_CFG_DIR}" REPO_ROOT="$SBX2" sh "$JJ_SMOKE" 2>&1) && GREEN_CODE=0 || GREEN_CODE=$?
GREEN_STATUS_AFTER="$(git -C "$SBX2" status --porcelain=v1)"

if [ "$GREEN_CODE" -eq 0 ] \
  && printf '%s' "$GREEN_OUT" | grep -q '^OK: jj_workspace_smoke' \
  && [ "$GREEN_STATUS_AFTER" = "?? dev/" ]; then
  ok "${LABEL} — fix (happy path): jj_workspace_smoke.sh passes (exit=${GREEN_CODE}) and leaves dev/daily/2099-01-01-test.md as plain untracked, not ' A'"
else
  bad "${LABEL} — happy-path fix broken: exit=${GREEN_CODE} output='${GREEN_OUT}' status-after='${GREEN_STATUS_AFTER}' (expected exit 0, an OK: line, and '?? dev/')"
fi

# ---------------------------------------------------------------------------
# Part 3 (the fix, failure path): a sandbox with NO main@origin ref, so
# jj_workspace_smoke.sh's Step 1 workspace-add fails and the script exits
# via its FAIL: path. The trap-driven guard restore must still fire.
# ---------------------------------------------------------------------------
SBX3="$(mktemp -d)"
SANDBOXES="${SANDBOXES} ${SBX3}"
( cd "$SBX3" && git init -q -b main && git commit -q --allow-empty -m init )
JJ_CONFIG="${JJ_CFG_DIR}" jj git init --colocate "$SBX3" >/dev/null 2>&1
mkdir -p "${SBX3}/dev/daily"
echo "in-progress summary" >"${SBX3}/dev/daily/2099-01-01-test.md"

FAILPATH_OUT=$(JJ_CONFIG="${JJ_CFG_DIR}" REPO_ROOT="$SBX3" sh "$JJ_SMOKE" 2>&1) && FAILPATH_CODE=0 || FAILPATH_CODE=$?
FAILPATH_STATUS_AFTER="$(git -C "$SBX3" status --porcelain=v1)"

if [ "$FAILPATH_CODE" -ne 0 ] \
  && printf '%s' "$FAILPATH_OUT" | grep -q '^FAIL: jj_workspace_smoke' \
  && [ "$FAILPATH_STATUS_AFTER" = "?? dev/" ]; then
  ok "${LABEL} — fix (failure path): jj_workspace_smoke.sh FAILs on unresolvable main@origin (exit=${FAILPATH_CODE}) but the trap-driven guard still leaves dev/daily/2099-01-01-test.md as plain untracked"
else
  bad "${LABEL} — failure-path guard broken: exit=${FAILPATH_CODE} output='${FAILPATH_OUT}' status-after='${FAILPATH_STATUS_AFTER}' (expected non-zero exit, a FAIL: jj_workspace_smoke line, and '?? dev/')"
fi

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: ${LABEL} — ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi

echo "OK: ${LABEL} — ${PASS} assertion(s) passed, 0 failed."
