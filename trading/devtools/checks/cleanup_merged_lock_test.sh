#!/bin/sh
# cleanup_merged_lock_test.sh — regression test for
# dev/scripts/cleanup_merged_worktrees.sh honouring `git worktree lock`.
#
# Claude Code locks every active agent worktree, and its branch
# (worktree-agent-<id>) is never pushed, so without the lock check the script
# reads it as "deleted on origin" and removes it once the age gate passes.
# On 2026-11-02 that removed three live agents' worktrees mid-build.
#
# Builds a temp repo with no origin (so every branch reads as gone), two
# agent-* worktrees, one locked and one not, and runs the script with
# --stale-hours 0 (no age gate). Expects the locked one kept and the unlocked
# one removed (the positive control: the script still reaps).
#
# Uses only git and bash; skips if bash is not on PATH.

set -eu

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
CLEANUP_SCRIPT="${REPO_ROOT}/dev/scripts/cleanup_merged_worktrees.sh"

if ! command -v bash >/dev/null 2>&1; then
  printf 'OK: cleanup_merged_lock_test — SKIPPED (bash not on PATH)\n'
  exit 0
fi

TMP_REPO="${TMPDIR:-/tmp}/cleanup-lock-test-$$"
trap 'rm -rf "${TMP_REPO}"' EXIT

mkdir -p "${TMP_REPO}"
git -C "${TMP_REPO}" init -q
git -C "${TMP_REPO}" config user.email "test@example.com"
git -C "${TMP_REPO}" config user.name "Test"
touch "${TMP_REPO}/README"
git -C "${TMP_REPO}" add README
git -C "${TMP_REPO}" commit -q -m init

WT_DIR="${TMP_REPO}/.claude/worktrees"
mkdir -p "${WT_DIR}"
LOCKED="${WT_DIR}/agent-locked"
UNLOCKED="${WT_DIR}/agent-unlocked"
git -C "${TMP_REPO}" worktree add -q --lock -b worktree-agent-locked "${LOCKED}"
git -C "${TMP_REPO}" worktree add -q -b worktree-agent-unlocked "${UNLOCKED}"

OUT="$(REPO_ROOT="${TMP_REPO}" bash "${CLEANUP_SCRIPT}" --stale-hours 0 2>&1)" || {
  printf 'FAIL: cleanup_merged_lock_test — script exited non-zero:\n%s\n' "${OUT}" >&2
  exit 1
}

status=0
if [ -d "${LOCKED}" ]; then
  printf 'OK: cleanup_merged_lock_test — locked agent worktree kept\n'
else
  printf 'FAIL: cleanup_merged_lock_test — locked agent worktree was removed:\n%s\n' "${OUT}" >&2
  status=1
fi
if [ -d "${UNLOCKED}" ]; then
  printf 'FAIL: cleanup_merged_lock_test — unlocked worktree with no origin branch was kept:\n%s\n' "${OUT}" >&2
  status=1
else
  printf 'OK: cleanup_merged_lock_test — unlocked worktree removed (control)\n'
fi
exit "${status}"
