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

# ---------------------------------------------------------------------------
# Part 4 (the fix, pre-existing-staged-state safety): a sandbox that ALREADY
# has staged entries before the guard's snapshot runs -- an intent-to-add
# path (`git add -N`, the same shape the jj-side-effect itself produces), a
# genuinely `git add`-staged path, and a staged-THEN-edited path (`git add`
# followed by an edit, porcelain "AM") -- plus one plain untracked file (the
# thing the guard is protecting). This pins the _check_lib.sh
# jj_ita_guard_restore docstring's claim: "never touches a path that was
# already staged before the guard started (a caller's own legitimate staged
# changes survive untouched)". Parts 1-3 have no ITA/staged entry present
# BEFORE the guard's baseline snapshot, so they cannot distinguish the real
# comm-based diff from a broken restore that simply resets every currently-
# ITA path (or, equivalently, one whose "before" snapshot was accidentally
# emptied) -- both variants still leave a from-nothing sandbox spotless and
# passed Parts 1-3 undetected.
#
# The "AM" case (qc-behavioral rework iteration 2, #2956) is the sharpest of
# the three: `jj workspace forget` reshapes it into ' A' with the staged
# blob replaced by the EMPTY blob, discarding the caller's originally-staged
# content. A restore that merely re-`git add`s the path would stage the
# worktree's current (edited) content instead of what the caller staged --
# silently losing the staged diff. Only restoring the exact recorded
# mode+blob via `git update-index --add --cacheinfo` gets this right.
# ---------------------------------------------------------------------------
SBX4="$(_new_sandbox)"
mkdir -p "${SBX4}/dev/daily"

# (1) A pre-existing intent-to-add file, staged BEFORE the guard runs --
#     must survive as ' A', untouched, exactly as the caller left it.
echo "preexisting ita content" >"${SBX4}/dev/daily/preexisting-ita.md"
( cd "$SBX4" && git add -N dev/daily/preexisting-ita.md )

# (2) A genuinely `git add`-staged file, also present BEFORE the guard
#     runs -- must survive as 'A ', untouched.
echo "really staged content" >"${SBX4}/dev/daily/really-staged.md"
( cd "$SBX4" && git add dev/daily/really-staged.md )

# (3) A staged-THEN-edited new file ("AM") -- the index holds X (the first
#     line only), the worktree holds X+Y (both lines). Must survive with
#     the SAME staged blob (X) and the SAME worktree content (X+Y).
echo "staged-then-edited X" >"${SBX4}/dev/daily/am-staged.md"
( cd "$SBX4" && git add dev/daily/am-staged.md )
echo "staged-then-edited Y" >>"${SBX4}/dev/daily/am-staged.md"
AM_BLOB_BEFORE="$(git -C "$SBX4" ls-files -s -- dev/daily/am-staged.md | awk '{print $2}')"

# (4) A plain untracked file -- the guard's actual target. Must NOT be left
#     as ' A' (intent-to-add) after jj's snapshot side effect runs.
echo "in-progress summary" >"${SBX4}/dev/daily/2099-01-01-test.md"

PREEXIST_STATUS_BEFORE="$(git -C "$SBX4" status --porcelain=v1)"

PREEXIST_OUT=$(JJ_CONFIG="${JJ_CFG_DIR}" REPO_ROOT="$SBX4" sh "$JJ_SMOKE" 2>&1) && PREEXIST_CODE=0 || PREEXIST_CODE=$?
PREEXIST_STATUS_AFTER="$(git -C "$SBX4" status --porcelain=v1)"
AM_BLOB_AFTER="$(git -C "$SBX4" ls-files -s -- dev/daily/am-staged.md | awk '{print $2}')"
AM_WORKTREE_AFTER="$(cat "${SBX4}/dev/daily/am-staged.md")"

if [ "$PREEXIST_CODE" -eq 0 ] \
  && printf '%s\n' "$PREEXIST_STATUS_AFTER" | grep -qF ' A dev/daily/preexisting-ita.md' \
  && printf '%s\n' "$PREEXIST_STATUS_AFTER" | grep -qF 'A  dev/daily/really-staged.md' \
  && printf '%s\n' "$PREEXIST_STATUS_AFTER" | grep -qF 'AM dev/daily/am-staged.md' \
  && printf '%s\n' "$PREEXIST_STATUS_AFTER" | grep -qF '?? dev/daily/2099-01-01-test.md' \
  && [ "$AM_BLOB_AFTER" = "$AM_BLOB_BEFORE" ] \
  && [ "$AM_WORKTREE_AFTER" = "$(printf 'staged-then-edited X\nstaged-then-edited Y')" ]; then
  ok "${LABEL} — fix (pre-existing staged state): a pre-existing intent-to-add path, a genuinely git-add-staged path, and a staged-then-edited ('AM') path all survive the guard untouched (' A', 'A ', and 'AM' respectively, per before='${PREEXIST_STATUS_BEFORE}') -- the AM path's staged blob (${AM_BLOB_BEFORE}) and worktree content are both bit-for-bit unchanged -- while the actual untracked file is restored to plain '??' and never left as intent-to-add"
else
  bad "${LABEL} — pre-existing staged state NOT preserved: exit=${PREEXIST_CODE} output='${PREEXIST_OUT}' before='${PREEXIST_STATUS_BEFORE}' after='${PREEXIST_STATUS_AFTER}' am_blob_before='${AM_BLOB_BEFORE}' am_blob_after='${AM_BLOB_AFTER}' am_worktree_after='${AM_WORKTREE_AFTER}' (expected exit 0, the pre-existing ITA path to remain ' A', the staged path to remain 'A ', the AM path to remain 'AM' with its staged blob and worktree content unchanged, and the untracked file to remain '??')"
fi

# ---------------------------------------------------------------------------
# Part 5 (H-ITA-GUARD-QUOTED-PATHS): untracked files whose names classic
# `git status --porcelain=v1` would C-quote -- one with an embedded space,
# one with a non-ASCII byte -- must ALSO survive the guard as plain
# untracked, never left as ' A'. Parts 1-4 only ever use plain-ASCII,
# no-space filenames, so they cannot distinguish a guard that correctly
# parses `-z` (unquoted) output from one still silently broken on any path
# `cut -c4-` against classic QUOTED porcelain output would mis-parse: the
# quoted form is `"weird file.txt"` (quotes included) or
# `"\346\226\207...\.md"` (octal-escaped), neither of which is the real
# on-disk path, so a pre-fix guard would never recognize these paths as
# its own ITA pollution and would leave them polluted.
#
# The final-state assertion below deliberately reads `-z` output and
# converts NUL -> newline itself (independent of `_porcelain_lines`, which
# is the code under test) rather than matching a literal quoted-escape
# string -- hard-coding the exact octal escape sequence git's classic form
# would produce is locale/version-fragile and beside the point; what
# matters is the path is plain `??`, not ' A'.
# ---------------------------------------------------------------------------
SBX5="$(_new_sandbox)"
mkdir -p "${SBX5}/dev/daily"
echo "in-progress summary" >"${SBX5}/dev/daily/2099-01-01 run summary.md"
echo "in-progress summary" >"${SBX5}/dev/daily/2099-01-01-run-摘要.md"

QUOTED_OUT=$(JJ_CONFIG="${JJ_CFG_DIR}" REPO_ROOT="$SBX5" sh "$JJ_SMOKE" 2>&1) && QUOTED_CODE=0 || QUOTED_CODE=$?
# --untracked-files=all: without it git collapses an entirely-untracked
# directory into a single "?? dev/" line (the same collapsing Part 2's
# assertion relies on for its single test file) -- with two differently-
# named files here, per-file visibility is required to tell them apart.
QUOTED_STATUS_AFTER="$(git -C "$SBX5" status --porcelain=v1 -z --untracked-files=all | tr '\0' '\n')"

if [ "$QUOTED_CODE" -eq 0 ] \
  && printf '%s' "$QUOTED_OUT" | grep -q '^OK: jj_workspace_smoke' \
  && printf '%s\n' "$QUOTED_STATUS_AFTER" | grep -qF '?? dev/daily/2099-01-01 run summary.md' \
  && printf '%s\n' "$QUOTED_STATUS_AFTER" | grep -qF '?? dev/daily/2099-01-01-run-摘要.md'; then
  ok "${LABEL} — fix (quoted paths): jj_workspace_smoke.sh passes and leaves BOTH a space-containing path and a non-ASCII path as plain untracked ('??'), not ' A' -- proves the guard's porcelain parsing survives paths classic --porcelain=v1 would C-quote"
else
  bad "${LABEL} — quoted-path fix broken: exit=${QUOTED_CODE} output='${QUOTED_OUT}' status-after='${QUOTED_STATUS_AFTER}' (expected exit 0, an OK: line, and both paths as plain '??')"
fi

# ---------------------------------------------------------------------------
# Part 6 (H-ITA-GUARD-SILENT-RESTORE-FAIL): a restore-side git failure must
# print a named WARN: line to stderr, not be swallowed silently -- while
# jj_ita_guard_restore still returns 0 (stays non-fatal, per its docstring
# contract: "Safe to call even if nothing changed"). Forced deterministically
# via a stray `.git/index.lock` file, which fails EVERY git index-writing
# command with exit 128 regardless of file permissions -- a chmod-based
# forcing approach would not survive running as root, which this suite does
# in CI.
#
# Two sub-cases, one per failing call site the docstring names:
#   6a: the plain-ITA-reset branch (`git reset -- <path>`).
#   6b: the cacheinfo-restore branch (`git update-index --add --cacheinfo`).
# Both call jj_ita_guard_snapshot/_restore DIRECTLY (available as shell
# functions via the `. _check_lib.sh` source line above) rather than going
# through jj_workspace_smoke.sh, so the forced git-level failure is
# deterministic and does not depend on jj's own behaviour.
#
# STDOUT and STDERR are captured SEPARATELY (via a temp file for stderr,
# rather than a blanket `2>&1`) so the assertions below can pin the actual
# claim -- "prints ... to stderr" -- rather than merely "prints ...
# somewhere". A `2>&1` capture cannot distinguish a WARN correctly sent to
# stderr from a regression that sends it to stdout instead (qc-behavioral
# rework iteration 1, #2991: moving the WARN to stdout still passed 7/7
# under the old `2>&1` capture).
# ---------------------------------------------------------------------------

# --- 6a: git reset -- <path> fails ---
SBX6A="$(_new_sandbox)"
mkdir -p "${SBX6A}/dev/daily"
echo "in-progress summary" >"${SBX6A}/dev/daily/2099-01-01-reset-fail.md"
BEFORE_6A=$(jj_ita_guard_snapshot "$SBX6A")
# Simulate jj's ITA side effect directly (same shape `jj workspace add/list/
# forget` produces against a colocated repo -- see Part 1's negative control).
( cd "$SBX6A" && git add -N dev/daily/2099-01-01-reset-fail.md )

touch "${SBX6A}/.git/index.lock"
RESTORE_6A_ERRFILE="$(mktemp)"
RESTORE_6A_STDOUT=$(jj_ita_guard_restore "$SBX6A" "$BEFORE_6A" 2>"$RESTORE_6A_ERRFILE") && RESTORE_6A_CODE=0 || RESTORE_6A_CODE=$?
RESTORE_6A_STDERR="$(cat "$RESTORE_6A_ERRFILE")"
rm -f "$RESTORE_6A_ERRFILE" "${SBX6A}/.git/index.lock"
STATUS_6A_AFTER="$(git -C "$SBX6A" status --porcelain=v1 --untracked-files=no)"

if [ "$RESTORE_6A_CODE" -eq 0 ] \
  && printf '%s\n' "$RESTORE_6A_STDERR" | grep -qF 'WARN: jj_ita_guard_restore: failed to reset intent-to-add entry for "dev/daily/2099-01-01-reset-fail.md"' \
  && ! printf '%s\n' "$RESTORE_6A_STDOUT" | grep -qF 'WARN: jj_ita_guard_restore' \
  && printf '%s\n' "$STATUS_6A_AFTER" | grep -qF ' A dev/daily/2099-01-01-reset-fail.md'; then
  ok "${LABEL} — forced restore failure (reset branch): jj_ita_guard_restore returns 0 (stays non-fatal) but prints a named WARN: line to STDERR (never stdout) when 'git reset -- <path>' fails, and the path is left ' A' -- proving the WARN corresponds to a real, still-polluted failure, not a false alarm"
else
  bad "${LABEL} — forced restore failure (reset branch) not surfaced: exit=${RESTORE_6A_CODE} stdout='${RESTORE_6A_STDOUT}' stderr='${RESTORE_6A_STDERR}' status-after='${STATUS_6A_AFTER}' (expected exit 0, a WARN: line naming the path on stderr only, and the path still ' A')"
fi

# --- 6b: git update-index --add --cacheinfo fails ---
SBX6B="$(_new_sandbox)"
mkdir -p "${SBX6B}/dev/daily"
echo "staged X" >"${SBX6B}/dev/daily/2099-01-01-cacheinfo-fail.md"
( cd "$SBX6B" && git add dev/daily/2099-01-01-cacheinfo-fail.md )
echo "staged X edited" >>"${SBX6B}/dev/daily/2099-01-01-cacheinfo-fail.md"
BEFORE_6B=$(jj_ita_guard_snapshot "$SBX6B")
# Simulate jj workspace forget's reshape of a staged-then-edited ("AM") path
# into ITA (empty blob) -- exactly the sequence documented above
# jj_ita_guard_snapshot: git rm --cached -f (drop the index entry) then
# git add -N (re-add as intent-to-add, empty blob), worktree left untouched.
( cd "$SBX6B" && git rm --cached -f -q dev/daily/2099-01-01-cacheinfo-fail.md && git add -N dev/daily/2099-01-01-cacheinfo-fail.md )

touch "${SBX6B}/.git/index.lock"
RESTORE_6B_ERRFILE="$(mktemp)"
RESTORE_6B_STDOUT=$(jj_ita_guard_restore "$SBX6B" "$BEFORE_6B" 2>"$RESTORE_6B_ERRFILE") && RESTORE_6B_CODE=0 || RESTORE_6B_CODE=$?
RESTORE_6B_STDERR="$(cat "$RESTORE_6B_ERRFILE")"
rm -f "$RESTORE_6B_ERRFILE" "${SBX6B}/.git/index.lock"
STATUS_6B_AFTER="$(git -C "$SBX6B" status --porcelain=v1 --untracked-files=no)"

if [ "$RESTORE_6B_CODE" -eq 0 ] \
  && printf '%s\n' "$RESTORE_6B_STDERR" | grep -qF 'WARN: jj_ita_guard_restore: failed to restore staged content for "dev/daily/2099-01-01-cacheinfo-fail.md"' \
  && ! printf '%s\n' "$RESTORE_6B_STDOUT" | grep -qF 'WARN: jj_ita_guard_restore' \
  && printf '%s\n' "$STATUS_6B_AFTER" | grep -qF ' A dev/daily/2099-01-01-cacheinfo-fail.md'; then
  ok "${LABEL} — forced restore failure (cacheinfo branch): jj_ita_guard_restore returns 0 (stays non-fatal) but prints a named WARN: line to STDERR (never stdout) when 'git update-index --add --cacheinfo' fails, and the path is left ' A' with its blob NOT restored -- proving the WARN corresponds to a real, still-polluted failure"
else
  bad "${LABEL} — forced restore failure (cacheinfo branch) not surfaced: exit=${RESTORE_6B_CODE} stdout='${RESTORE_6B_STDOUT}' stderr='${RESTORE_6B_STDERR}' status-after='${STATUS_6B_AFTER}' (expected exit 0, a WARN: line naming the path on stderr only, and the path still ' A')"
fi

# ---------------------------------------------------------------------------
# Part 7 (CP4-a, qc-behavioral rework iteration 1, #2991): a staged rename
# whose ORIGIN path starts with a capital "A" must not leak its discarded
# continuation record into _porcelain_lines' output, and must not pollute
# jj_ita_guard_snapshot's grep -E '^A|^ A ' with a bogus entry.
#
# `git mv ARCH.md d/ARCH.md` (both committed first, so the rename is a real
# tracked-file move, not an add) produces, under `-z`: "R  d/ARCH.md" then a
# continuation NUL field "ARCH.md" -- an origin path that itself starts with
# "A" and would match jj_ita_guard_snapshot's grep verbatim if the
# rename/copy `skip` logic in _porcelain_lines did not discard it (this is
# exactly the `skip = 1` -> `skip = 0` mutation qc-behavioral's review
# showed surviving 7/7 against the PR as first submitted).
# ---------------------------------------------------------------------------
SBX7="$(_new_sandbox)"
mkdir -p "${SBX7}/d"
echo "content" >"${SBX7}/ARCH.md"
( cd "$SBX7" && git add ARCH.md && git commit -q -m "add ARCH.md" )
( cd "$SBX7" && git mv ARCH.md d/ARCH.md )

RENAME_LINES="$(_porcelain_lines "$SBX7")"
RENAME_SNAPSHOT="$(jj_ita_guard_snapshot "$SBX7")"

if [ "$RENAME_LINES" = "R  d/ARCH.md" ] && [ -z "$RENAME_SNAPSHOT" ]; then
  ok "${LABEL} — rename continuation discard: staging 'git mv ARCH.md d/ARCH.md' (origin path starts with 'A') makes _porcelain_lines emit exactly 'R  d/ARCH.md' with the origin-path continuation record discarded, and jj_ita_guard_snapshot sees no entries at all -- proving the discarded continuation never falsely matches the ITA/added-entry grep"
else
  bad "${LABEL} — rename continuation discard broken: _porcelain_lines='${RENAME_LINES}' jj_ita_guard_snapshot='${RENAME_SNAPSHOT}' (expected _porcelain_lines to equal exactly 'R  d/ARCH.md' and jj_ita_guard_snapshot to be empty)"
fi

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: ${LABEL} — ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi

echo "OK: ${LABEL} — ${PASS} assertion(s) passed, 0 failed."
