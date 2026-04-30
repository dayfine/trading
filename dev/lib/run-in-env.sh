#!/usr/bin/env bash
# Run a command in the Trading dev environment.
#
# Usage:
#   dev/lib/run-in-env.sh dune build
#   dev/lib/run-in-env.sh dune runtest trading/backtest/test/
#
# Locally (default): wraps with `docker exec` into trading-1-dev,
# cd's to the workspace, and sources opam env.
#
# In GHA / devcontainer: set TRADING_IN_CONTAINER=1 and the script
# runs natively (cd + opam env, no docker wrapping).
#
# Project root resolution (in-container path):
#   GHA:   ${GITHUB_WORKSPACE}/trading  — repo checks out at GITHUB_WORKSPACE;
#          the dune workspace root is one level deeper at trading/.
#   Local container / other: resolve relative to this script's location.
#          The script lives at <repo-root>/dev/lib/; climb two levels to reach
#          the repo root, then descend into trading/ (the dune workspace root).
#
# The in-container path verifies dune-workspace exists at the resolved root and
# fails loudly if it doesn't — catches path mismatches rather than silently
# running dune in the wrong directory. The local docker-exec path delegates
# path resolution to a docker-inspect query against the container's mount table
# (see "Worktree path resolution" below), with a fallback that emits a stderr
# warning if the inspect returns empty.
#
# Docker liveness probe (local path only):
#   Before running the user command, the script verifies the container is
#   responsive via a lightweight `docker exec <container> true`. If this
#   fails (daemon down, container stopped), the script prints a clear error
#   to stderr and exits 1. Without this probe, a dead docker daemon can
#   silently return exit 0 in some shell configurations.
#
# Worktree path resolution (local path only):
#   Isolated agent worktrees live at .claude/worktrees/agent-<ID>/ inside
#   the host repo root. The container's bind-mount covers the entire host
#   repo root, so worktree directories ARE accessible inside the container.
#   This script detects its own location relative to the bind-mount source
#   and computes the correct container-side DOCKER_TRADING_ROOT, so that
#   `dune build` inside the container operates on the worktree's tree rather
#   than the parent repo's tree.

set -euo pipefail

CONTAINER_NAME="${TRADING_CONTAINER_NAME:-trading-1-dev}"

if [ $# -eq 0 ]; then
  echo "Usage: dev/lib/run-in-env.sh <command> [args...]" >&2
  exit 1
fi

if [ -n "${TRADING_IN_CONTAINER:-}" ]; then
  # --- In-container path (GHA or devcontainer) ---

  if [ -n "${GITHUB_WORKSPACE:-}" ]; then
    # GHA: the repo is checked out at $GITHUB_WORKSPACE (e.g. /__w/trading/trading).
    # The dune workspace root is one level deeper at trading/.
    PROJECT_ROOT="${GITHUB_WORKSPACE}/trading"
  else
    # Devcontainer / fallback: resolve relative to this script's location.
    # The script lives at <repo-root>/dev/lib/run-in-env.sh.
    # Climb two levels to reach the repo root, then descend into trading/.
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    PROJECT_ROOT="$(cd "${script_dir}/../.." && pwd)/trading"
  fi

  # Fail loudly rather than run dune in the wrong directory.
  if [ ! -f "${PROJECT_ROOT}/dune-workspace" ]; then
    echo "run-in-env.sh: no dune-workspace at ${PROJECT_ROOT}" >&2
    echo "  (expected dune workspace root; check PROJECT_ROOT derivation)" >&2
    echo "  PROJECT_ROOT=${PROJECT_ROOT}" >&2
    exit 1
  fi

  cd "$PROJECT_ROOT"
  eval "$(opam env)"
  exec "$@"
else
  # --- Local path: delegate to docker exec ---

  # Bug 1 fix: liveness probe before running the user command.
  # Detects docker daemon down or container stopped; avoids silent success
  # when docker exec fails to connect. Without this probe, some shell
  # environments may observe exit code 0 from a failed docker exec invocation.
  if ! docker exec "$CONTAINER_NAME" true 2>/dev/null; then
    echo "FAIL: container '${CONTAINER_NAME}' not responsive (docker daemon down or container stopped)" >&2
    echo "  Run: docker start ${CONTAINER_NAME}" >&2
    exit 1
  fi

  # Bug 2 fix: compute the container-side path from the script's own location.
  # Isolated agent worktrees live at .claude/worktrees/agent-<ID>/ inside the
  # host repo root. The container bind-mounts the host repo root at
  # /workspaces/trading-1/, so worktrees are accessible at
  # /workspaces/trading-1/.claude/worktrees/agent-<ID>/trading/.
  #
  # Strategy: ask docker for the bind-mount source, compute the host repo root
  # (two levels up from this script's dev/lib/ location), derive the relative
  # path from mount source to repo root, and append /trading.
  _SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  _HOST_PROJECT_ROOT="$(cd "${_SCRIPT_DIR}/../.." && pwd)"

  # Query the container's bind-mount source for /workspaces/trading-1.
  # Falls back to the hardcoded default if docker inspect is unavailable or
  # returns no matching mount.
  _DOCKER_MOUNT_SRC=$(docker inspect "$CONTAINER_NAME" \
    --format '{{range .Mounts}}{{if eq .Destination "/workspaces/trading-1"}}{{.Source}}{{end}}{{end}}' \
    2>/dev/null || true)

  if [ -n "$_DOCKER_MOUNT_SRC" ]; then
    # Strip the mount source prefix from the host project root to get the
    # path fragment that exists inside the container.
    # Example (worktree case):
    #   _DOCKER_MOUNT_SRC  = /Users/difan/Projects/trading-1
    #   _HOST_PROJECT_ROOT = /Users/difan/Projects/trading-1/.claude/worktrees/agent-XYZ
    #   _REL_PATH          = /.claude/worktrees/agent-XYZ
    #   DOCKER_TRADING_ROOT = /workspaces/trading-1/.claude/worktrees/agent-XYZ/trading
    # Example (parent repo case):
    #   _DOCKER_MOUNT_SRC  = /Users/difan/Projects/trading-1
    #   _HOST_PROJECT_ROOT = /Users/difan/Projects/trading-1
    #   _REL_PATH          = (empty)
    #   DOCKER_TRADING_ROOT = /workspaces/trading-1/trading
    _REL_PATH="${_HOST_PROJECT_ROOT#${_DOCKER_MOUNT_SRC}}"
    DOCKER_TRADING_ROOT="/workspaces/trading-1${_REL_PATH}/trading"
  else
    # docker inspect failed or returned no mount — fall back to the original
    # hardcoded path (parent repo, no worktree).
    echo "WARN: docker inspect on '${CONTAINER_NAME}' returned no mount source; falling back to parent-repo path /workspaces/trading-1/trading. If running from an isolated worktree, this is wrong — check 'docker inspect ${CONTAINER_NAME} --format ...'." >&2
    DOCKER_TRADING_ROOT="/workspaces/trading-1/trading"
  fi

  # Forward EODHD_API_KEY if set.
  DOCKER_ENV_FLAGS=""
  if [ -n "${EODHD_API_KEY:-}" ]; then
    DOCKER_ENV_FLAGS="-e EODHD_API_KEY"
  fi
  exec docker exec $DOCKER_ENV_FLAGS "$CONTAINER_NAME" bash -c \
    "cd $DOCKER_TRADING_ROOT && eval \$(opam env) && $*"
fi
