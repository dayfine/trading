#!/usr/bin/env bash
# launch.sh — invocation script for the v7 Bayesian production sweep.
#
# Wraps dev/scripts/launch_sweep.sh with the v7-specific paths.
#
# Pre-flight (the operator's responsibility before running):
#   - Docker.raw < 30 GB (or set LAUNCH_SWEEP_DOCKER_RAW_GB_MAX=45 to bypass
#     if recompact isn't possible mid-session).
#   - Host disk free >= 50 GB.
#   - No other bayesian_runner.exe in the container.
#   - The walk-forward spec + baseline aggregate referenced below must
#     exist (produced by M4 T4.1 + M4 T4.3/T4.4 — see plan v2).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

SWEEP_NAME="${SWEEP_NAME:-11knob-v7-1998-2026-top3000}"
SPEC="${SCRIPT_DIR}/spec_prod_11knob_v7.sexp"
WF_SPEC="${WF_SPEC:-/workspaces/trading-1/trading/test_data/walk_forward/cell_e_full_history_28fold_2026_05_25.sexp}"
BASELINE_AGG="${BASELINE_AGG:-/workspaces/trading-1/dev/experiments/bayesian-production-sweep-2026-05-25/baseline_aggregate_v7.sexp}"
PARALLEL="${PARALLEL:-4}"

# Docker.raw override flag — set if recompact isn't possible in this session.
DOCKER_RAW_OVERRIDE=""
if [[ -n "${LAUNCH_SWEEP_DOCKER_RAW_GB_MAX:-}" ]]; then
  DOCKER_RAW_OVERRIDE="LAUNCH_SWEEP_DOCKER_RAW_GB_MAX=${LAUNCH_SWEEP_DOCKER_RAW_GB_MAX}"
fi

echo "=== v7 sweep launch ==="
echo "Name:           ${SWEEP_NAME}"
echo "Spec:           ${SPEC}"
echo "WF spec:        ${WF_SPEC}"
echo "Baseline agg:   ${BASELINE_AGG}"
echo "Parallel:       ${PARALLEL}"
[[ -n "${DOCKER_RAW_OVERRIDE}" ]] && echo "Override:       ${DOCKER_RAW_OVERRIDE}"
echo ""

# Pre-check: refuse to launch if the baseline aggregate is missing.
# The wrapper's preconditions catch HOST issues; this catches v7-specific
# data dependencies.
if [[ ! -f "${REPO_ROOT}/${BASELINE_AGG#/workspaces/trading-1/}" ]] \
   && [[ ! -f "${BASELINE_AGG}" ]]; then
  echo "ERROR: baseline aggregate not found at ${BASELINE_AGG}" >&2
  echo "  Generate it via M4 T4.3 (BAH aggregates) + T4.4 (Cell E sanity)" >&2
  echo "  before launching the v7 sweep." >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/${WF_SPEC#/workspaces/trading-1/}" ]] \
   && [[ ! -f "${WF_SPEC}" ]]; then
  echo "ERROR: walk-forward spec not found at ${WF_SPEC}" >&2
  echo "  M4 T4.1 must merge first." >&2
  exit 1
fi

# Translate paths from host to container view.
HOST_TO_CONTAINER='/Users/difan/Projects/trading-1=/workspaces/trading-1'
HOST_PREFIX="${HOST_TO_CONTAINER%=*}"
CTR_PREFIX="${HOST_TO_CONTAINER#*=}"
SPEC_CTR="${SPEC/${HOST_PREFIX}/${CTR_PREFIX}}"
WF_SPEC_CTR="${WF_SPEC}"          # already container-style
BASELINE_AGG_CTR="${BASELINE_AGG}" # already container-style

exec env ${DOCKER_RAW_OVERRIDE} "${REPO_ROOT}/dev/scripts/launch_sweep.sh" \
  --name "${SWEEP_NAME}" \
  --spec "${SPEC_CTR}" \
  --walk-forward-spec "${WF_SPEC_CTR}" \
  --baseline-aggregate "${BASELINE_AGG_CTR}" \
  --parallel "${PARALLEL}"
