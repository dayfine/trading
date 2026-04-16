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

set -euo pipefail

TRADING_ROOT="/workspaces/trading-1/trading"
CONTAINER_NAME="${TRADING_CONTAINER_NAME:-trading-1-dev}"

if [ $# -eq 0 ]; then
  echo "Usage: dev/lib/run-in-env.sh <command> [args...]" >&2
  exit 1
fi

if [ -n "${TRADING_IN_CONTAINER:-}" ]; then
  cd "$TRADING_ROOT"
  eval "$(opam env)"
  exec "$@"
else
  # Build a single string for bash -c inside docker.
  # Forward EODHD_API_KEY if set.
  DOCKER_ENV_FLAGS=""
  if [ -n "${EODHD_API_KEY:-}" ]; then
    DOCKER_ENV_FLAGS="-e EODHD_API_KEY"
  fi
  exec docker exec $DOCKER_ENV_FLAGS "$CONTAINER_NAME" bash -c \
    "cd $TRADING_ROOT && eval \$(opam env) && $*"
fi
