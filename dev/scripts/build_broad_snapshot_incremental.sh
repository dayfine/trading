#!/usr/bin/env bash
# build_broad_snapshot_incremental.sh — incremental snapshot rebuild wrapper.
#
# Wraps build_snapshots.exe with:
#   - --incremental (always)
#   - per-host wall-clock budget (--max-wall <duration>) so a cron tick
#     terminates after a bounded window even if the universe is huge
#   - flock on <output-dir>/.build.lock to prevent two concurrent runs
#     racing on the manifest
#   - --dry-run to preview the invocation
#
# After PR 1 of dev/plans/data-pipeline-automation-2026-05-03.md,
# build_snapshots.exe writes the manifest atomically per symbol AND
# emits progress.sexp every N symbols. So this wrapper safely supports
# checkpoint-resume across invocations: a 2-hour rebuild can be split
# into N ~30min cron windows, each picking up where the previous left
# off.
#
# Usage:
#   build_broad_snapshot_incremental.sh \
#     --universe <path>         (required) Pinned universe sexp
#     --output-dir <path>       (required) Snapshot warehouse output
#     --csv-data-dir <path>     (default: data)
#     --benchmark-symbol <sym>  (optional) e.g. SPY
#     --progress-every <N>      (default: 50) progress.sexp cadence
#     --max-wall <duration>     (default: 60m) wall-clock budget;
#                                accepts e.g. 30m, 1h, 90m, 7200s
#     --dry-run                 Print the underlying invocation, do not run
#     --build-target <path>     (default: built target under _build)
#
# Exit codes:
#   0    completed within budget
#   1    setup error / build_snapshots.exe error
#   75   another instance holds the lock (POSIX EX_TEMPFAIL)
#   124  killed by --max-wall timeout (per coreutils `timeout` convention)
#
# Logs to: dev/logs/snapshot-build-YYYY-MM-DD.log (appended).

set -euo pipefail

# ---------------------------------------------------------------------------
# Repo root from script path
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
UNIVERSE=""
OUTPUT_DIR=""
CSV_DATA_DIR="${REPO_ROOT}/data"
BENCHMARK_SYMBOL=""
PROGRESS_EVERY=50
MAX_WALL="60m"
DRY_RUN=0
BUILD_TARGET="${REPO_ROOT}/trading/_build/default/analysis/scripts/build_snapshots/build_snapshots.exe"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --universe)         UNIVERSE="$2";         shift 2 ;;
    --output-dir)       OUTPUT_DIR="$2";       shift 2 ;;
    --csv-data-dir)     CSV_DATA_DIR="$2";     shift 2 ;;
    --benchmark-symbol) BENCHMARK_SYMBOL="$2"; shift 2 ;;
    --progress-every)   PROGRESS_EVERY="$2";   shift 2 ;;
    --max-wall)         MAX_WALL="$2";         shift 2 ;;
    --build-target)     BUILD_TARGET="$2";     shift 2 ;;
    --dry-run)          DRY_RUN=1;             shift ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Usage: $0 --universe <path> --output-dir <path> [--csv-data-dir <path>] [--benchmark-symbol <sym>] [--progress-every <N>] [--max-wall <dur>] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [[ -z "${UNIVERSE}" ]]; then
  echo "ERROR: --universe is required" >&2
  exit 1
fi
if [[ -z "${OUTPUT_DIR}" ]]; then
  echo "ERROR: --output-dir is required" >&2
  exit 1
fi
if [[ ! -f "${UNIVERSE}" ]]; then
  echo "ERROR: universe sexp not found: ${UNIVERSE}" >&2
  exit 1
fi
if [[ ! -d "${CSV_DATA_DIR}" ]]; then
  echo "ERROR: csv data dir not found: ${CSV_DATA_DIR}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
LOG_DATE="$(date +%Y-%m-%d)"
LOG_DIR="${REPO_ROOT}/dev/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/snapshot-build-${LOG_DATE}.log"

log() {
  local msg="$(date '+%Y-%m-%d %H:%M:%S') [snapshot-build] $*"
  echo "${msg}"
  echo "${msg}" >> "${LOG_FILE}"
}

# ---------------------------------------------------------------------------
# Build invocation
# ---------------------------------------------------------------------------
INVOKE_ARGS=(
  --universe-path "${UNIVERSE}"
  --csv-data-dir  "${CSV_DATA_DIR}"
  --output-dir    "${OUTPUT_DIR}"
  --incremental
  --progress-every "${PROGRESS_EVERY}"
)
if [[ -n "${BENCHMARK_SYMBOL}" ]]; then
  INVOKE_ARGS+=( --benchmark-symbol "${BENCHMARK_SYMBOL}" )
fi

CMD_PREVIEW="timeout ${MAX_WALL} ${BUILD_TARGET} ${INVOKE_ARGS[*]}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[dry-run] would invoke: ${CMD_PREVIEW}"
  exit 0
fi

if [[ ! -x "${BUILD_TARGET}" ]]; then
  echo "ERROR: build target not found or not executable: ${BUILD_TARGET}" >&2
  echo "       Run: dune build analysis/scripts/build_snapshots/" >&2
  exit 1
fi

log "starting incremental snapshot rebuild"
log "  universe=${UNIVERSE}"
log "  output_dir=${OUTPUT_DIR}"
log "  csv_data_dir=${CSV_DATA_DIR}"
log "  benchmark_symbol=${BENCHMARK_SYMBOL:-(none)}"
log "  progress_every=${PROGRESS_EVERY}"
log "  max_wall=${MAX_WALL}"

# ---------------------------------------------------------------------------
# flock-protected invocation
# ---------------------------------------------------------------------------
LOCK_FILE="${OUTPUT_DIR}/.build.lock"

# We use a subshell + flock fd 9. -n: nonblocking; exits 1 if held → re-map
# to POSIX EX_TEMPFAIL (75). flock is BSD-flavored on macOS via util-linux's
# port (`flock`); fall back to a presence-test on hosts without flock.
if command -v flock >/dev/null 2>&1; then
  (
    if ! flock -n 9; then
      log "another instance holds the lock at ${LOCK_FILE}; exiting EX_TEMPFAIL"
      exit 75
    fi
    set +e
    timeout "${MAX_WALL}" "${BUILD_TARGET}" "${INVOKE_ARGS[@]}"
    rc=$?
    set -e
    log "build_snapshots.exe exited with rc=${rc}"
    exit "${rc}"
  ) 9>"${LOCK_FILE}"
else
  log "WARN: flock not available; skipping concurrent-run guard"
  set +e
  timeout "${MAX_WALL}" "${BUILD_TARGET}" "${INVOKE_ARGS[@]}"
  rc=$?
  set -e
  log "build_snapshots.exe exited with rc=${rc}"
  exit "${rc}"
fi
