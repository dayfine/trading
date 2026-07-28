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
#   Two INDEPENDENT candidates are derived and cross-checked — H-RUNENV-WORKTREE-BLIND
#   (fixed 2026-07-27): a prior version pinned PROJECT_ROOT to
#   ${GITHUB_WORKSPACE}/trading unconditionally in GHA mode, ignoring the
#   invoker's cwd entirely. An agent working inside a git worktree (e.g. a
#   feat-agent or harness-maintainer checked out at /tmp/agent-XYZ) would run
#   `dune build && dune runtest`, silently build+test the MAIN checkout instead
#   of its own tree, and report a false green for code it never compiled. See
#   dev/status/harness.md "H-RUNENV-WORKTREE-BLIND" for the incident record
#   (PR #2139 shipped with this exact signature: PR body claimed "green",
#   CI was red on the same SHA).
#
#   cwd candidate:    `git rev-parse --show-toplevel` from the invoker's
#                     current directory, +/trading. Correct whenever the
#                     invoker's shell is actually positioned inside the tree
#                     they mean to build — the normal case for every agent,
#                     worktree or not.
#   script candidate: resolved relative to this script's own on-disk location
#                     (the script lives at <repo-root>/dev/lib/; climb two
#                     levels to the repo root, then descend into trading/).
#                     Correct for the devcontainer fallback and the ordinary
#                     GHA case (invoker's cwd IS the main checkout) — but
#                     WRONG if an agent working in a worktree invokes the
#                     MAIN checkout's copy of this script by absolute path:
#                     cwd is the worktree, yet the script resolves to main.
#
#   Resolution: prefer the cwd candidate when it names a valid dune workspace.
#   ${GITHUB_WORKSPACE}/trading is used only as a last-resort fallback when
#   cwd isn't inside any git tree with a trading/dune-workspace (e.g. an
#   unusual invocation cwd). If the cwd candidate AND the script candidate
#   both resolve to a valid dune workspace but DISAGREE, the script refuses to
#   guess: it prints both candidates to stderr and exits non-zero. A loud
#   failure here is strictly better than a silent false green.
#
# The in-container path verifies dune-workspace exists at the resolved root and
# fails loudly if it doesn't — catches path mismatches rather than silently
# running dune in the wrong directory. The local docker-exec path delegates
# path resolution to a docker-inspect query against the container's mount table
# (see "Worktree path resolution" below), with a fallback that emits a stderr
# warning if the inspect returns empty.
#
# Testability seam: set RUN_IN_ENV_PRINT_ROOT=1 to print the resolved
# PROJECT_ROOT and exit 0 (or the disagreement error and exit 1), without
# cd'ing, sourcing opam env, or exec'ing a command. Used only by
# trading/devtools/checks/run_in_env_root_check.sh — never set this in normal
# operation.
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
  # See "Project root resolution (in-container path)" in the header comment
  # for the full rationale (H-RUNENV-WORKTREE-BLIND).

  _cwd_git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  _cwd_candidate=""
  if [ -n "$_cwd_git_root" ] && [ -f "${_cwd_git_root}/trading/dune-workspace" ]; then
    _cwd_candidate="${_cwd_git_root}/trading"
  fi

  _script_dir="$(cd "$(dirname "$0")" && pwd)"
  _script_candidate="$(cd "${_script_dir}/../.." && pwd)/trading"

  if [ -n "$_cwd_candidate" ]; then
    PROJECT_ROOT="$_cwd_candidate"

    # Disagreement check: only meaningful if the script-location candidate
    # ALSO resolves to a real dune workspace (otherwise it's just "this
    # script's own tree has no trading/ yet", not a genuine second answer).
    if [ -f "${_script_candidate}/dune-workspace" ] && [ "$_cwd_candidate" != "$_script_candidate" ]; then
      echo "run-in-env.sh: PROJECT_ROOT is ambiguous — refusing to guess." >&2
      echo "  cwd-derived root:             ${_cwd_candidate}" >&2
      echo "  script-location-derived root: ${_script_candidate}" >&2
      echo "  This usually means you invoked a DIFFERENT checkout's copy of" >&2
      echo "  run-in-env.sh (e.g. the main checkout's absolute path) while" >&2
      echo "  your cwd is inside a worktree. Invoke the copy that lives" >&2
      echo "  inside the tree you intend to build/test." >&2
      exit 1
    fi
  elif [ -n "${GITHUB_WORKSPACE:-}" ]; then
    # Last-resort fallback: cwd isn't inside a git tree with a trading/
    # dune-workspace. Use GHA's known checkout location.
    PROJECT_ROOT="${GITHUB_WORKSPACE}/trading"
  else
    # Devcontainer / final fallback: resolve relative to this script's own
    # on-disk location.
    PROJECT_ROOT="$_script_candidate"
  fi

  if [ -n "${RUN_IN_ENV_PRINT_ROOT:-}" ]; then
    echo "$PROJECT_ROOT"
    exit 0
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
