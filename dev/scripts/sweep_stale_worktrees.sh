#!/usr/bin/env bash
# sweep_stale_worktrees.sh — remove stale agent-* worktrees to reclaim disk space.
#
# Usage:
#   sweep_stale_worktrees.sh [--threshold-percent N] [--stale-hours H] [--dry-run] [--force]
#                            [--include-active]
#
# Flags:
#   --threshold-percent N   Only sweep when host-disk usage >= N% (default: 85).
#   --stale-hours H         Remove agent-* worktrees with mtime older than H hours (default: 24).
#                           Must be >= 1; use of 0 is rejected to prevent accidental active sweep.
#   --dry-run               Print candidates, don't delete.
#   --force                 Skip the disk-threshold check; sweep stale anyway.
#   --include-active        Also remove locked (active) worktrees. Emergency-only override.
#                           Must be combined with --stale-hours >= 1.
#
# Lock honoring:
#   Claude Code marks active agent worktrees as locked via `git worktree add --lock`.
#   By default, locked worktrees are ALWAYS skipped regardless of other flags.
#   Pass --include-active to override this protection (emergency use only).
#   `git worktree remove` (no --force) is used so git's own lock check is also preserved.
#
# Exit codes:
#   0  success or skipped (below threshold and --force not set)
#   1  usage error
#
# Logs to: dev/logs/worktree-sweep-YYYY-MM-DD.log (appended)

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate repo root from script path (works when invoked as an absolute path or
# relative path from any directory).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
THRESHOLD_PERCENT=85
STALE_HOURS=24
DRY_RUN=0
FORCE=0
INCLUDE_ACTIVE=0

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold-percent)
      shift
      if [[ $# -eq 0 || ! "$1" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --threshold-percent requires a numeric argument" >&2
        exit 1
      fi
      THRESHOLD_PERCENT="$1"
      ;;
    --stale-hours)
      shift
      if [[ $# -eq 0 || ! "$1" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --stale-hours requires a numeric argument" >&2
        exit 1
      fi
      STALE_HOURS="$1"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --force)
      FORCE=1
      ;;
    --include-active)
      INCLUDE_ACTIVE=1
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Usage: $0 [--threshold-percent N] [--stale-hours H] [--dry-run] [--force] [--include-active]" >&2
      exit 1
      ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Validate --stale-hours: reject 0 to prevent "sweep everything" accidents.
# Active worktrees are locked, and a stale-hours of 0 by definition captures
# everything — including worktrees created moments ago by a live agent.
# Operators who truly need emergency removal should use --include-active with
# a real --stale-hours value.
# ---------------------------------------------------------------------------
if [[ "${STALE_HOURS}" -lt 1 ]]; then
  echo "ERROR: --stale-hours must be >= 1 (got ${STALE_HOURS})." >&2
  echo "  Rationale: stale-hours 0 would sweep all worktrees, including active agents." >&2
  echo "  Use --include-active with --stale-hours 1+ for emergency removal of active worktrees." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------
LOG_DATE="$(date +%Y-%m-%d)"
LOG_DIR="${REPO_ROOT}/dev/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/worktree-sweep-${LOG_DATE}.log"

log() {
  local msg="$(date '+%Y-%m-%d %H:%M:%S') [worktree-sweep] $*"
  echo "${msg}"
  echo "${msg}" >> "${LOG_FILE}"
}

# ---------------------------------------------------------------------------
# Disk usage probe — percentage of used space on the filesystem containing REPO_ROOT
# ---------------------------------------------------------------------------
disk_percent() {
  # df -h output:  Filesystem  Size  Used  Avail  Use%  MountedOn
  # We want the "Use%" column (field 5), strip the % sign.
  df -h "${REPO_ROOT}" | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

DISK_BEFORE="$(disk_percent)"

# ---------------------------------------------------------------------------
# Threshold check
# ---------------------------------------------------------------------------
if [[ "${FORCE}" -eq 0 ]]; then
  if [[ "${DISK_BEFORE}" -lt "${THRESHOLD_PERCENT}" ]]; then
    log "disk at ${DISK_BEFORE}% — below threshold ${THRESHOLD_PERCENT}%; skipping sweep (use --force to override)"
    exit 0
  fi
fi

if [[ "${FORCE}" -eq 1 ]]; then
  log "force mode — sweeping stale worktrees regardless of disk usage"
else
  log "disk at ${DISK_BEFORE}% — at or above threshold ${THRESHOLD_PERCENT}%; starting sweep"
fi

# ---------------------------------------------------------------------------
# Build set of locked worktree paths from git metadata.
# Parse `git worktree list --porcelain` once, collect paths of locked entries.
# Format:
#   worktree <path>
#   HEAD <sha>
#   branch <ref>       (or "detached")
#   locked [reason]    (present only when locked)
#
# We collect the current worktree path and set a flag when "locked" appears.
# ---------------------------------------------------------------------------
declare -A LOCKED_WORKTREES  # path -> 1 if locked

_current_wt_path=""
while IFS= read -r _line; do
  if [[ "${_line}" == worktree\ * ]]; then
    _current_wt_path="${_line#worktree }"
  elif [[ "${_line}" == locked* ]]; then
    if [[ -n "${_current_wt_path}" ]]; then
      LOCKED_WORKTREES["${_current_wt_path}"]=1
    fi
  elif [[ -z "${_line}" ]]; then
    _current_wt_path=""
  fi
done < <(git -C "${REPO_ROOT}" worktree list --porcelain 2>/dev/null)

LOCKED_COUNT="${#LOCKED_WORKTREES[@]}"
log "found ${LOCKED_COUNT} locked (active) worktree(s)"
if [[ "${INCLUDE_ACTIVE}" -eq 1 ]]; then
  log "WARNING: --include-active set — locked worktrees will NOT be skipped"
fi

# ---------------------------------------------------------------------------
# Find stale worktrees
# ---------------------------------------------------------------------------
WORKTREES_DIR="${REPO_ROOT}/.claude/worktrees"

if [[ ! -d "${WORKTREES_DIR}" ]]; then
  log "worktrees dir not found: ${WORKTREES_DIR} — nothing to do"
  exit 0
fi

STALE_MMIN=$(( STALE_HOURS * 60 ))

# Collect candidates: agent-* dirs older than STALE_HOURS hours
mapfile -t CANDIDATES < <(
  find "${WORKTREES_DIR}" -maxdepth 1 -type d -name 'agent-*' \
    ! -newer "${WORKTREES_DIR}" \
    -mmin "+${STALE_MMIN}" 2>/dev/null | sort
)

CANDIDATE_COUNT="${#CANDIDATES[@]}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  log "dry-run mode — found ${CANDIDATE_COUNT} stale worktree(s) older than ${STALE_HOURS}h; no deletions"
  for dir in "${CANDIDATES[@]}"; do
    if [[ -n "${LOCKED_WORKTREES[${dir}]+x}" && "${INCLUDE_ACTIVE}" -eq 0 ]]; then
      log "  [dry-run] would skip (locked/active): ${dir}"
    else
      log "  [dry-run] would remove: ${dir}"
    fi
  done
  exit 0
fi

log "found ${CANDIDATE_COUNT} stale worktree(s) older than ${STALE_HOURS}h"

REMOVED=0
SKIPPED_LOCKED=0

for dir in "${CANDIDATES[@]}"; do
  # Skip locked (active) worktrees unless --include-active was explicitly set.
  if [[ -n "${LOCKED_WORKTREES[${dir}]+x}" && "${INCLUDE_ACTIVE}" -eq 0 ]]; then
    log "skipping locked worktree: ${dir} (active subagent)"
    SKIPPED_LOCKED=$(( SKIPPED_LOCKED + 1 ))
    continue
  fi

  # Use plain `git worktree remove` (no --force) so git's own lock check fires.
  # If the worktree is locked, git refuses — and we want that.
  # Fall back to rm -rf only for corrupt worktrees (HEAD missing, etc.)
  # that are NOT locked (already checked above).
  if git -C "${REPO_ROOT}" worktree remove "${dir}" 2>/dev/null; then
    log "removed (git worktree): ${dir}"
    REMOVED=$(( REMOVED + 1 ))
  elif rm -rf "${dir}"; then
    log "removed (rm -rf fallback — corrupt worktree): ${dir}"
    REMOVED=$(( REMOVED + 1 ))
  else
    log "WARNING: could not remove: ${dir}"
  fi
done

# ---------------------------------------------------------------------------
# Prune dangling worktree metadata
# ---------------------------------------------------------------------------
git -C "${REPO_ROOT}" worktree prune 2>/dev/null && log "git worktree prune — done" || true

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
DISK_AFTER="$(disk_percent)"
DISK_DELTA=$(( DISK_BEFORE - DISK_AFTER ))

log "sweep complete — ${REMOVED} worktree(s) removed; ${SKIPPED_LOCKED} locked worktree(s) skipped; disk ${DISK_BEFORE}% → ${DISK_AFTER}% (reclaimed ~${DISK_DELTA}pp)"
