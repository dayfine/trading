#!/bin/bash
# SessionStart hook for Claude Code on the web (remote sessions only).
#
# The OCaml toolchain lives in the published CI image, not on the host, so
# this hook: starts dockerd (not running by default in the cloud container),
# pulls ghcr.io/dayfine/trading-ci:latest, and starts a long-lived container
# named trading-1-dev with the repo bind-mounted at /workspaces/trading-1 —
# the same name/path CLAUDE.md's `docker exec trading-1-dev ...` commands use.
#
# Network requirement: the image layers are served from
# pkg-containers.githubusercontent.com, which must be allowed by the
# environment's network policy.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

IMAGE="ghcr.io/dayfine/trading-ci:latest"
CONTAINER="trading-1-dev"
REPO_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

log() { echo "[session-start] $*" >&2; }

if ! docker info >/dev/null 2>&1; then
  log "starting dockerd"
  nohup dockerd >/tmp/dockerd.log 2>&1 &
  for _ in $(seq 1 30); do
    docker info >/dev/null 2>&1 && break
    sleep 1
  done
  docker info >/dev/null 2>&1 || { log "dockerd failed to start; see /tmp/dockerd.log"; exit 1; }
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  log "pulling $IMAGE"
  docker pull "$IMAGE"
fi

if [ -z "$(docker ps -q -f name="^${CONTAINER}$")" ]; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  log "starting container $CONTAINER"
  docker run -d --name "$CONTAINER" \
    -v "$REPO_DIR:/workspaces/trading-1" \
    -w /workspaces/trading-1/trading \
    "$IMAGE" sleep infinity >/dev/null
fi

log "ready: docker exec $CONTAINER bash -c 'cd /workspaces/trading-1/trading && eval \$(opam env) && dune build'"
