#!/usr/bin/env bash
# sweep_disk_watcher.sh — autonomous SIGTERM for runaway sweeps.
#
# Polls host disk free + Docker.raw size + container /tmp size every 60s.
# SIGTERMs the sweep PID when a threshold is crossed (lets the BO runner
# write a final checkpoint instead of dying mid-write). Exits when the
# sweep PID itself exits.
#
# Why: dev/plans/sweep-and-qc-architecture-2026-05-26.md PR-C +
# dev/plans/safe-sweep-infrastructure-2026-05-24.md §4. The PR-A
# launch_sweep.sh wrapper verifies preconditions at launch time but
# cannot react to mid-flight disk fill — 2026-05-23..25 sweep crashes
# all came from disk filling AFTER launch (snapshot churn over hours).
#
# Usage:
#   sweep_disk_watcher.sh --sweep-pid <pid> --sweep-name <name>
#                         [--container NAME]            (default trading-1-dev)
#                         [--poll-interval SEC]         (default 60)
#                         [--log-dir DIR]               (default <repo>/.sweep-output)
#
# Exit codes:
#   0   sweep PID exited (watcher's normal end)
#   1   usage error
#   2   watcher SIGTERM'd the sweep (a threshold was crossed)
#
# Thresholds (env-var overridable):
#   DISK_WATCHER_HOST_FREE_GB_MIN   (default 20)   — host free < N GB → kill
#   DISK_WATCHER_RAW_WARN_GB        (default 50)   — Docker.raw warning
#   DISK_WATCHER_RAW_KILL_GB        (default 65)   — Docker.raw kill
#   DISK_WATCHER_TMP_WARN_GB        (default 30)   — container /tmp warning
#
# Test hooks (env-var overrides for unit tests):
#   DISK_WATCHER_DF_BIN              (default: df)
#   DISK_WATCHER_DOCKER_BIN          (default: docker)
#   DISK_WATCHER_DU_BIN              (default: du)
#   DISK_WATCHER_KILL_BIN            (default: kill)
#   DISK_WATCHER_DOCKER_RAW_PATH     (default: $HOME/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw)
#   DISK_WATCHER_MAX_ITERATIONS      (default: unlimited; tests pin to 1-3)
#
# References:
#   - .claude/rules/sweep-hygiene.md
#   - dev/plans/sweep-and-qc-architecture-2026-05-26.md (PR-C)

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

SWEEP_PID=""
SWEEP_NAME=""
CONTAINER="trading-1-dev"
POLL_INTERVAL=60
LOG_DIR="${REPO_ROOT}/.sweep-output"

DF_BIN="${DISK_WATCHER_DF_BIN:-df}"
DOCKER_BIN="${DISK_WATCHER_DOCKER_BIN:-docker}"
DU_BIN="${DISK_WATCHER_DU_BIN:-du}"
KILL_BIN="${DISK_WATCHER_KILL_BIN:-kill}"
DOCKER_RAW_PATH="${DISK_WATCHER_DOCKER_RAW_PATH:-$HOME/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw}"
MAX_ITERATIONS="${DISK_WATCHER_MAX_ITERATIONS:-0}"  # 0 means unlimited

HOST_FREE_GB_MIN="${DISK_WATCHER_HOST_FREE_GB_MIN:-20}"
RAW_WARN_GB="${DISK_WATCHER_RAW_WARN_GB:-50}"
RAW_KILL_GB="${DISK_WATCHER_RAW_KILL_GB:-65}"
TMP_WARN_GB="${DISK_WATCHER_TMP_WARN_GB:-30}"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sweep-pid)      shift; SWEEP_PID="${1:-}";;
    --sweep-name)     shift; SWEEP_NAME="${1:-}";;
    --container)      shift; CONTAINER="${1:-}";;
    --poll-interval)  shift; POLL_INTERVAL="${1:-}";;
    --log-dir)        shift; LOG_DIR="${1:-}";;
    -h|--help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "${SWEEP_PID}" || -z "${SWEEP_NAME}" ]]; then
  echo "ERROR: --sweep-pid and --sweep-name are required" >&2
  exit 1
fi

if [[ ! "${SWEEP_PID}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --sweep-pid must be numeric (got: ${SWEEP_PID})" >&2
  exit 1
fi

if [[ ! "${SWEEP_NAME}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "ERROR: --sweep-name must match [a-zA-Z0-9._-]+ (got: ${SWEEP_NAME})" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/${SWEEP_NAME}.watcher.log"

log() {
  local msg
  msg="$(date '+%Y-%m-%d %H:%M:%S') [disk-watcher] $*"
  echo "${msg}" | tee -a "${LOG_FILE}"
}

# ---------------------------------------------------------------------------
# Probes (each returns "N" KB; "0" if unavailable)
# ---------------------------------------------------------------------------
host_free_kb() {
  "${DF_BIN}" -k / 2>/dev/null | awk 'NR==2 {print $4}'
}

docker_raw_kb() {
  if [[ -f "${DOCKER_RAW_PATH}" ]]; then
    "${DU_BIN}" -sk "${DOCKER_RAW_PATH}" 2>/dev/null | awk '{print $1}'
  else
    echo "0"
  fi
}

container_tmp_kb() {
  # `du -sk /tmp` inside the container. Failures (container down) → 0; the
  # sweep-PID liveness check will fire on the next iteration.
  "${DOCKER_BIN}" exec "${CONTAINER}" du -sk /tmp 2>/dev/null \
    | awk '{print $1}' \
    | head -1
}

kb_to_gb() {
  echo $(( ${1:-0} / 1024 / 1024 ))
}

# ---------------------------------------------------------------------------
# Threshold evaluator — returns 0 if all clear, 1 if a KILL threshold tripped.
# Always emits warnings; only ever emits one KILL line per invocation.
# ---------------------------------------------------------------------------
should_kill=0
kill_reason=""

evaluate_thresholds() {
  local host_free_gb raw_gb tmp_gb
  host_free_gb=$(kb_to_gb "$(host_free_kb)")
  raw_gb=$(kb_to_gb "$(docker_raw_kb)")
  tmp_gb=$(kb_to_gb "$(container_tmp_kb)")

  log "probes: host_free=${host_free_gb}GB docker_raw=${raw_gb}GB container_tmp=${tmp_gb}GB"

  if (( host_free_gb < HOST_FREE_GB_MIN )); then
    should_kill=1
    kill_reason="host_free=${host_free_gb}GB < ${HOST_FREE_GB_MIN}GB minimum"
    return
  fi

  if (( raw_gb >= RAW_KILL_GB )); then
    should_kill=1
    kill_reason="Docker.raw=${raw_gb}GB >= ${RAW_KILL_GB}GB kill threshold"
    return
  fi

  if (( raw_gb >= RAW_WARN_GB )); then
    log "WARNING: Docker.raw=${raw_gb}GB >= ${RAW_WARN_GB}GB warn threshold (kill at ${RAW_KILL_GB}GB)"
  fi

  if (( tmp_gb >= TMP_WARN_GB )); then
    log "WARNING: container /tmp=${tmp_gb}GB >= ${TMP_WARN_GB}GB warn threshold (likely snapshot churn)"
  fi
}

# ---------------------------------------------------------------------------
# Watch loop
# ---------------------------------------------------------------------------
log "watching sweep pid=${SWEEP_PID} name=${SWEEP_NAME} container=${CONTAINER} poll=${POLL_INTERVAL}s"
log "thresholds: host_free_min=${HOST_FREE_GB_MIN}GB raw_warn=${RAW_WARN_GB}GB raw_kill=${RAW_KILL_GB}GB tmp_warn=${TMP_WARN_GB}GB"

iteration=0
while true; do
  iteration=$(( iteration + 1 ))

  # Check sweep PID liveness first. `kill -0` returns 0 if PID exists.
  if ! "${KILL_BIN}" -0 "${SWEEP_PID}" 2>/dev/null; then
    log "sweep pid=${SWEEP_PID} exited — watcher done"
    exit 0
  fi

  evaluate_thresholds

  if (( should_kill == 1 )); then
    log "ABORT: ${kill_reason} — SIGTERM-ing pid=${SWEEP_PID} so BO can write a final checkpoint"
    "${KILL_BIN}" -TERM "${SWEEP_PID}" 2>/dev/null || true
    exit 2
  fi

  # Test-mode cap.
  if (( MAX_ITERATIONS > 0 )) && (( iteration >= MAX_ITERATIONS )); then
    log "max iterations reached (${MAX_ITERATIONS}) — exiting (test mode)"
    exit 0
  fi

  sleep "${POLL_INTERVAL}"
done
