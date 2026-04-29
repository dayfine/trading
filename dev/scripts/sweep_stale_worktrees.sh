#!/usr/bin/env bash
# sweep_stale_worktrees.sh — remove stale agent-* worktrees to reclaim disk space.
#
# Usage:
#   sweep_stale_worktrees.sh [--threshold-percent N] [--stale-hours H] [--dry-run] [--force]
#
# Flags:
#   --threshold-percent N   Only sweep when host-disk usage >= N% (default: 85).
#   --stale-hours H         Remove agent-* worktrees with mtime older than H hours (default: 24).
#   --dry-run               Print candidates, don't delete.
#   --force                 Skip the disk-threshold check; sweep stale anyway.
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
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Usage: $0 [--threshold-percent N] [--stale-hours H] [--dry-run] [--force]" >&2
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
    log "  [dry-run] would remove: ${dir}"
  done
  exit 0
fi

log "found ${CANDIDATE_COUNT} stale worktree(s) older than ${STALE_HOURS}h"

REMOVED=0

for dir in "${CANDIDATES[@]}"; do
  # First try the official git worktree remove path to keep git metadata clean.
  if git -C "${REPO_ROOT}" worktree remove --force "${dir}" 2>/dev/null; then
    log "removed (git worktree): ${dir}"
    REMOVED=$(( REMOVED + 1 ))
  elif rm -rf "${dir}"; then
    log "removed (rm -rf): ${dir}"
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

log "sweep complete — ${REMOVED} worktree(s) removed; disk ${DISK_BEFORE}% → ${DISK_AFTER}% (reclaimed ~${DISK_DELTA}pp)"
