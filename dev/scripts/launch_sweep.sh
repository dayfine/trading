#!/usr/bin/env bash
# launch_sweep.sh — mandatory entry point for Bayesian-sweep launches.
#
# Refuses to launch unless six preconditions are met. On success, launches
# `bayesian_runner.exe` inside the `trading-1-dev` container via
# `docker exec -d` and prints the PID + a monitor command line.
#
# Why a wrapper exists: 2026-05-23/24/25 lost ~16h of sweep wall-time to
# repeated violations of `.claude/rules/sweep-hygiene.md` preconditions
# (sweep output in a repo path, host-disk fill, Docker.raw runaway). The
# discipline doc is not enough on its own; this script is the enforcement
# layer. PR-A of `dev/plans/sweep-and-qc-architecture-2026-05-26.md`.
#
# Usage:
#   launch_sweep.sh --name <sweep-name> \
#                   --spec <runner-spec.sexp> \
#                   --walk-forward-spec <wf-spec.sexp> \
#                   --baseline-aggregate <agg.sexp> \
#                   [--parallel N]         (default 6)
#                   [--container NAME]     (default trading-1-dev)
#                   [--dry-run]
#
# Exit codes:
#   0   sweep launched (or `--dry-run` summary printed)
#   1   usage error
#   2   precondition failure (one or more of the six gates)
#
# Preconditions (all must pass — every failure is printed):
#   1. Host disk free  >= LAUNCH_SWEEP_DISK_FREE_GB_MIN (default 50 GB)
#   2. Docker.raw size <  LAUNCH_SWEEP_DOCKER_RAW_GB_MAX (default 30 GB)
#                         (skipped if Docker.raw path is absent — Linux hosts)
#   3. Container       running
#   4. /tmp/sweeps/    bind-mounted into the container
#   5. No other        `bayesian_runner.exe` already running in the container
#   6. No stale agent worktrees older than
#                      LAUNCH_SWEEP_WORKTREE_STALE_HRS (default 24 h)
#
# Test hooks (env-var overrides for `launch_sweep_test.sh`):
#   LAUNCH_SWEEP_DF_BIN              (default: df)
#   LAUNCH_SWEEP_DOCKER_BIN          (default: docker)
#   LAUNCH_SWEEP_DU_BIN              (default: du)
#   LAUNCH_SWEEP_DOCKER_RAW_PATH     (default: $HOME/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw)
#   LAUNCH_SWEEP_WORKTREES_DIR       (default: <repo-root>/.claude/worktrees)
#   LAUNCH_SWEEP_DISK_FREE_GB_MIN    (default: 50)
#   LAUNCH_SWEEP_DOCKER_RAW_GB_MAX   (default: 30)
#   LAUNCH_SWEEP_WORKTREE_STALE_HRS  (default: 24)
#
# References:
#   - .claude/rules/sweep-hygiene.md
#   - dev/plans/sweep-and-qc-architecture-2026-05-26.md (PR-A)

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

SWEEP_NAME=""
SPEC=""
WF_SPEC=""
BASELINE_AGG=""
PARALLEL="6"
CONTAINER="trading-1-dev"
DRY_RUN=0

DF_BIN="${LAUNCH_SWEEP_DF_BIN:-df}"
DOCKER_BIN="${LAUNCH_SWEEP_DOCKER_BIN:-docker}"
DU_BIN="${LAUNCH_SWEEP_DU_BIN:-du}"
DOCKER_RAW_PATH="${LAUNCH_SWEEP_DOCKER_RAW_PATH:-$HOME/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw}"
WORKTREES_DIR="${LAUNCH_SWEEP_WORKTREES_DIR:-${REPO_ROOT}/.claude/worktrees}"
DISK_FREE_GB_MIN="${LAUNCH_SWEEP_DISK_FREE_GB_MIN:-50}"
DOCKER_RAW_GB_MAX="${LAUNCH_SWEEP_DOCKER_RAW_GB_MAX:-30}"
WORKTREE_STALE_HRS="${LAUNCH_SWEEP_WORKTREE_STALE_HRS:-24}"

usage() {
  sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-1}"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)                shift; SWEEP_NAME="${1:-}";;
    --spec)                shift; SPEC="${1:-}";;
    --walk-forward-spec)   shift; WF_SPEC="${1:-}";;
    --baseline-aggregate)  shift; BASELINE_AGG="${1:-}";;
    --parallel)            shift; PARALLEL="${1:-}";;
    --container)           shift; CONTAINER="${1:-}";;
    --dry-run)             DRY_RUN=1;;
    -h|--help)             usage 0;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage 1
      ;;
  esac
  shift
done

if [[ -z "${SWEEP_NAME}" || -z "${SPEC}" || -z "${WF_SPEC}" || -z "${BASELINE_AGG}" ]]; then
  echo "ERROR: --name, --spec, --walk-forward-spec, --baseline-aggregate are required" >&2
  usage 1
fi

# Sweep name must be a safe single path segment.
if [[ ! "${SWEEP_NAME}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "ERROR: --name must match [a-zA-Z0-9._-]+ (got: ${SWEEP_NAME})" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log() { echo "[launch_sweep] $*"; }
err() { echo "[launch_sweep] FAIL: $*" >&2; }

# Each check returns 0 on success, 1 on failure. Failures append to FAILURES;
# we report every failure (not first-fail) so the operator can fix the host
# state in one pass.
FAILURES=()

# ---------------------------------------------------------------------------
# Check 1 — host disk free
# ---------------------------------------------------------------------------
# `df -k <path>` (POSIX) returns "Available" in 1024-byte blocks at field 4
# on row 2. Both macOS and Linux honor `-k`.
check_disk_free() {
  local avail_kb avail_gb
  avail_kb="$("${DF_BIN}" -k / 2>/dev/null | awk 'NR==2 {print $4}')"
  if [[ -z "${avail_kb}" || ! "${avail_kb}" =~ ^[0-9]+$ ]]; then
    err "could not read host disk free (${DF_BIN} -k / returned: '${avail_kb}')"
    return 1
  fi
  avail_gb=$(( avail_kb / 1024 / 1024 ))
  if (( avail_gb < DISK_FREE_GB_MIN )); then
    err "host disk free ${avail_gb} GB < ${DISK_FREE_GB_MIN} GB minimum (clean first)"
    return 1
  fi
  log "host disk free: ${avail_gb} GB (>= ${DISK_FREE_GB_MIN} GB)"
  return 0
}

# ---------------------------------------------------------------------------
# Check 2 — Docker.raw size
# ---------------------------------------------------------------------------
# Docker.raw is Docker Desktop's macOS VM disk image (sparse). When it grows
# past ~30 GB, the host runs out of free space even though `df -h /` looks OK.
# Linux hosts have no equivalent file — skip the check there.
check_docker_raw() {
  if [[ ! -f "${DOCKER_RAW_PATH}" ]]; then
    log "Docker.raw not at ${DOCKER_RAW_PATH} — skipping (non-mac host)"
    return 0
  fi
  local raw_kb raw_gb
  raw_kb="$("${DU_BIN}" -sk "${DOCKER_RAW_PATH}" 2>/dev/null | awk '{print $1}')"
  if [[ -z "${raw_kb}" || ! "${raw_kb}" =~ ^[0-9]+$ ]]; then
    err "could not read Docker.raw size (${DU_BIN} -sk ${DOCKER_RAW_PATH} returned: '${raw_kb}')"
    return 1
  fi
  raw_gb=$(( raw_kb / 1024 / 1024 ))
  if (( raw_gb >= DOCKER_RAW_GB_MAX )); then
    err "Docker.raw at ${raw_gb} GB >= ${DOCKER_RAW_GB_MAX} GB cap (recompact via Docker Desktop → Settings → Resources → Apply & restart)"
    return 1
  fi
  log "Docker.raw size: ${raw_gb} GB (< ${DOCKER_RAW_GB_MAX} GB)"
  return 0
}

# ---------------------------------------------------------------------------
# Check 3 — container running
# ---------------------------------------------------------------------------
check_container_running() {
  local state
  state="$("${DOCKER_BIN}" inspect -f '{{.State.Running}}' "${CONTAINER}" 2>/dev/null || true)"
  if [[ "${state}" != "true" ]]; then
    err "container '${CONTAINER}' is not running (docker inspect → '${state:-not-found}')"
    return 1
  fi
  log "container '${CONTAINER}' is running"
  return 0
}

# ---------------------------------------------------------------------------
# Check 4 — /tmp/sweeps/ bind-mounted
# ---------------------------------------------------------------------------
# Without a bind-mount, the sweep's output is written into the container's
# writable layer, which inflates Docker.raw and is the root cause of the
# 2026-05 disk-fill incidents.
check_bind_mount() {
  local destinations
  destinations="$("${DOCKER_BIN}" inspect -f '{{range .Mounts}}{{.Destination}}{{"\n"}}{{end}}' "${CONTAINER}" 2>/dev/null || true)"
  if ! echo "${destinations}" | grep -q '^/tmp/sweeps$'; then
    err "/tmp/sweeps is not bind-mounted into '${CONTAINER}' (run: .devcontainer/setup.sh rebuild && .devcontainer/setup.sh start)"
    return 1
  fi
  log "/tmp/sweeps bind-mount: present"
  return 0
}

# ---------------------------------------------------------------------------
# Check 5 — no other bayesian_runner.exe running
# ---------------------------------------------------------------------------
# Concurrent sweeps fight for the container's _build/ directory and writable
# layer. One sweep at a time, by hard rule.
check_no_existing_runner() {
  local hits
  hits="$("${DOCKER_BIN}" exec "${CONTAINER}" pgrep -f 'bayesian_runner\.exe' 2>/dev/null || true)"
  if [[ -n "${hits}" ]]; then
    err "another bayesian_runner.exe is already running in '${CONTAINER}' (PIDs: $(echo "${hits}" | tr '\n' ' '))"
    return 1
  fi
  log "no other bayesian_runner.exe in '${CONTAINER}'"
  return 0
}

# ---------------------------------------------------------------------------
# Check 6 — no stale agent worktrees
# ---------------------------------------------------------------------------
# A worktree older than the stale threshold is either a forgotten cleanup or
# a still-locked active agent. Either way it's blocking disk on the writable
# layer and we should not start a long sweep on top of it.
check_no_stale_worktrees() {
  if [[ ! -d "${WORKTREES_DIR}" ]]; then
    log "worktrees dir absent (${WORKTREES_DIR}) — nothing stale"
    return 0
  fi
  local stale_mmin stale_dirs
  stale_mmin=$(( WORKTREE_STALE_HRS * 60 ))
  # Avoid pipe-into-while subshell scoping; capture with mapfile.
  mapfile -t stale_dirs < <(
    find "${WORKTREES_DIR}" -maxdepth 1 -mindepth 1 -type d -name 'agent-*' \
      -mmin "+${stale_mmin}" 2>/dev/null | sort
  )
  if (( ${#stale_dirs[@]} > 0 )); then
    err "${#stale_dirs[@]} stale worktree(s) older than ${WORKTREE_STALE_HRS}h under ${WORKTREES_DIR}:"
    local d
    for d in "${stale_dirs[@]}"; do echo "    ${d}" >&2; done
    echo "    (run: bash dev/scripts/sweep_stale_worktrees.sh --force)" >&2
    return 1
  fi
  log "no agent worktrees older than ${WORKTREE_STALE_HRS}h"
  return 0
}

# ---------------------------------------------------------------------------
# Run all six checks (do NOT short-circuit — report every failure)
# ---------------------------------------------------------------------------
run_check() {
  local name="$1"; shift
  if ! "$@"; then
    FAILURES+=("${name}")
  fi
}

log "running preconditions for sweep '${SWEEP_NAME}'"
run_check disk_free            check_disk_free
run_check docker_raw           check_docker_raw
run_check container_running    check_container_running
run_check bind_mount           check_bind_mount
run_check no_existing_runner   check_no_existing_runner
run_check no_stale_worktrees   check_no_stale_worktrees

if (( ${#FAILURES[@]} > 0 )); then
  echo "" >&2
  echo "[launch_sweep] REFUSING TO LAUNCH — ${#FAILURES[@]} precondition(s) failed: ${FAILURES[*]}" >&2
  echo "[launch_sweep] see .claude/rules/sweep-hygiene.md for recovery guidance" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Build the launch command
# ---------------------------------------------------------------------------
OUT_DIR="/tmp/sweeps/${SWEEP_NAME}"
LOG_FILE="/tmp/sweeps/${SWEEP_NAME}.log"

# Single-quote the inner bash -c body so $ is interpreted inside the
# container, not the host. The outer double-quote interpolation is limited to
# the values we set on the host side (paths, parallel, sweep name).
RUNNER_CMD="mkdir -p ${OUT_DIR} && \
cd /workspaces/trading-1/trading && eval \$(opam env) && \
nohup dune exec --no-build trading/backtest/tuner/bin/bayesian_runner.exe -- \
  --spec ${SPEC} \
  --walk-forward-spec ${WF_SPEC} \
  --baseline-aggregate ${BASELINE_AGG} \
  --out-dir ${OUT_DIR} \
  --parallel ${PARALLEL} \
  > ${LOG_FILE} 2>&1 &"

# ---------------------------------------------------------------------------
# Dry-run summary
# ---------------------------------------------------------------------------
if (( DRY_RUN == 1 )); then
  log "DRY RUN — would launch the following:"
  echo ""
  echo "  ${DOCKER_BIN} exec -d ${CONTAINER} bash -c '${RUNNER_CMD}'"
  echo ""
  log "DRY RUN — out-dir:   ${OUT_DIR}"
  log "DRY RUN — log file:  ${LOG_FILE}"
  log "DRY RUN — parallel:  ${PARALLEL}"
  exit 0
fi

# ---------------------------------------------------------------------------
# Launch + report
# ---------------------------------------------------------------------------
log "launching sweep '${SWEEP_NAME}' in container '${CONTAINER}'"
"${DOCKER_BIN}" exec -d "${CONTAINER}" bash -c "${RUNNER_CMD}"

# Give the runner a moment to fork before we resolve the PID; without this
# pgrep can return empty on a slow container.
sleep 2
PID="$("${DOCKER_BIN}" exec "${CONTAINER}" pgrep -f 'bayesian_runner\.exe' 2>/dev/null | head -1 || true)"

log "launched — out-dir: ${OUT_DIR}"
log "launched — log:     ${LOG_FILE}"
if [[ -n "${PID}" ]]; then
  log "launched — pid:     ${PID}"
fi
log "monitor:    ${DOCKER_BIN} exec ${CONTAINER} pgrep -af 'bayesian_runner\\.exe.*${SWEEP_NAME}'"
log "tail log:   ${DOCKER_BIN} exec ${CONTAINER} tail -f ${LOG_FILE}"

# ---------------------------------------------------------------------------
# Spawn the disk watcher (PR-C, #1296) in the background ON THE HOST.
# Conditional: only if the script is present (older checkouts won't have it).
#
# The watcher polls host-only probes (df / Docker.raw) that aren't visible
# inside the container, so it must run host-side. The watcher's --container
# flag forwards kill -0/-TERM through `docker exec` so it can address the
# container-internal sweep PID even on macOS Docker (where the host kernel
# does NOT share a PID namespace with the container).
# ---------------------------------------------------------------------------
WATCHER="${SCRIPT_DIR}/sweep_disk_watcher.sh"
if [[ -x "${WATCHER}" && -n "${PID}" ]]; then
  nohup "${WATCHER}" \
    --sweep-pid "${PID}" \
    --sweep-name "${SWEEP_NAME}" \
    --container "${CONTAINER}" \
    >/dev/null 2>&1 &
  WATCHER_PID=$!
  log "spawned disk watcher pid=${WATCHER_PID} (log .sweep-output/${SWEEP_NAME}.watcher.log)"
fi
