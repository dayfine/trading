#!/usr/bin/env bash
# cleanup_merged_worktrees.sh — remove agent worktrees whose branch has been
# deleted from origin (indicating the PR was merged and the branch cleaned up).
#
# Usage:
#   cleanup_merged_worktrees.sh [--dry-run] [--stale-hours N]
#
# Flags:
#   --dry-run           Print what would be removed; make no deletions.
#   --stale-hours N     Only remove worktrees older than N hours (default: 0,
#                       i.e. any merged-branch worktree is eligible immediately).
#                       Use a positive value to preserve very-recent failed-push
#                       agent work for manual inspection.
#
# How it works:
#   For each .claude/worktrees/agent-*/ directory:
#     1. Determine the branch name from jj bookmarks (preferred) or git HEAD.
#     2. If the branch is still present on origin → keep (PR not yet merged).
#     3. If the branch is gone from origin → remove (PR merged, branch deleted).
#     4. If no branch can be determined → skip with a warning (can't decide).
#
# This is safe to run mid-session: live branches are always preserved.
# Failed-push agents (never pushed) have no origin branch → treated as merged
# and are removed after --stale-hours (default 0, so immediately). Pass
# --stale-hours 1 to retain them for manual inspection.
#
# Logs to: dev/logs/worktree-cleanup-YYYY-MM-DD.log (appended)

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate repo root from script path
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DRY_RUN=0
STALE_HOURS=0

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --stale-hours)
      shift
      if [[ $# -eq 0 || ! "$1" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --stale-hours requires a non-negative integer argument" >&2
        exit 1
      fi
      STALE_HOURS="$1"
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Usage: $0 [--dry-run] [--stale-hours N]" >&2
      exit 1
      ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------
LOG_DATE="$(date +%Y-%m-%d)"
LOG_DIR="${REPO_ROOT}/dev/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/worktree-cleanup-${LOG_DATE}.log"

log() {
  local msg="$(date '+%Y-%m-%d %H:%M:%S') [cleanup-merged] $*"
  echo "${msg}"
  echo "${msg}" >> "${LOG_FILE}"
}

# ---------------------------------------------------------------------------
# Fetch and prune origin refs so ls-remote reflects reality
# ---------------------------------------------------------------------------
git -C "${REPO_ROOT}" fetch origin --prune --quiet 2>/dev/null || {
  log "WARNING: git fetch failed — proceeding with stale remote refs"
}

# ---------------------------------------------------------------------------
# Helper: check whether a directory is older than STALE_HOURS hours
# Returns 0 (true) if stale enough to be eligible, 1 if too fresh.
# ---------------------------------------------------------------------------
is_old_enough() {
  local dir="$1"
  if [[ "${STALE_HOURS}" -eq 0 ]]; then
    return 0  # no age gate — always eligible
  fi
  # find returns the dir if it's older than STALE_HOURS hours (mmin = minutes)
  local stale_mmin=$(( STALE_HOURS * 60 ))
  if find "${dir}" -maxdepth 0 -mmin "+${stale_mmin}" 2>/dev/null | grep -q .; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Main sweep
# ---------------------------------------------------------------------------
WORKTREES_DIR="${REPO_ROOT}/.claude/worktrees"

if [[ ! -d "${WORKTREES_DIR}" ]]; then
  log "worktrees dir not found: ${WORKTREES_DIR} — nothing to do"
  exit 0
fi

removed=0
skipped=0
kept=0

for wt in "${WORKTREES_DIR}"/agent-*; do
  [ -d "${wt}" ] || continue

  # -- 1. Determine the branch -------------------------------------------
  branch=""

  # jj mode: read bookmark pointing at @ within this worktree
  if [ -d "${wt}/.jj" ]; then
    branch=$(cd "${wt}" 2>/dev/null && \
      jj log -r 'bookmarks() & ::@' --no-graph \
              -T 'bookmarks ++ "\n"' 2>/dev/null \
      | head -1 | tr -d ' \n' || true)
  fi

  # git fallback (worktree created in git-only mode)
  if [ -z "${branch}" ] && [ -d "${wt}/.git" -o -f "${wt}/.git" ]; then
    branch=$(cd "${wt}" 2>/dev/null && \
      git symbolic-ref --short HEAD 2>/dev/null || true)
  fi

  if [ -z "${branch}" ]; then
    log "skip: ${wt} — could not determine branch"
    skipped=$(( skipped + 1 ))
    continue
  fi

  # -- 2. Is branch still on origin? -------------------------------------
  if git -C "${REPO_ROOT}" ls-remote --heads origin "${branch}" 2>/dev/null \
      | grep -q .; then
    log "keep: ${wt} (branch '${branch}' still on origin)"
    kept=$(( kept + 1 ))
    continue
  fi

  # Branch is gone from origin — merged or abandoned.

  # -- 3. Age gate -------------------------------------------------------
  if ! is_old_enough "${wt}"; then
    log "keep: ${wt} (branch '${branch}' gone from origin but worktree is younger than ${STALE_HOURS}h)"
    kept=$(( kept + 1 ))
    continue
  fi

  # -- 4. Remove ---------------------------------------------------------
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "[dry-run] would remove: ${wt} (branch '${branch}' deleted on origin)"
    removed=$(( removed + 1 ))
    continue
  fi

  log "removing: ${wt} (branch '${branch}' deleted on origin)"
  if git -C "${REPO_ROOT}" worktree remove --force "${wt}" 2>/dev/null; then
    log "removed (git worktree): ${wt}"
  elif rm -rf "${wt}"; then
    log "removed (rm -rf): ${wt}"
  else
    log "WARNING: could not remove: ${wt}"
    skipped=$(( skipped + 1 ))
    continue
  fi
  removed=$(( removed + 1 ))
done

# Prune dangling git worktree metadata
git -C "${REPO_ROOT}" worktree prune 2>/dev/null \
  && log "git worktree prune — done" || true

if [[ "${DRY_RUN}" -eq 1 ]]; then
  log "dry-run complete — ${removed} would be removed, ${kept} kept, ${skipped} skipped"
else
  log "done — ${removed} worktree(s) removed, ${kept} kept, ${skipped} skipped"
fi
