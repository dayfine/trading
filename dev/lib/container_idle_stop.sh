#!/bin/sh
# container_idle_stop.sh -- stop the local dev container when it is idle (counterpart of ensure_container.sh).
#
# The container is on-demand (user decision 2026-11-16): an idle one pins ~5 GB of Docker Desktop VM memory.
# Run this after a build or QC wave and at session end (.claude/rules/dispatcher-cadence.md).
#
# usage: sh dev/lib/container_idle_stop.sh [--dry-run]
#
# Stops ONLY the one container (DOCKER_CONTAINER, trading-1-dev), and only when all of these hold:
#   - not running -> nothing to do (a stopped container, or a daemon that is down, is already idle);
#   - every live process in it is its init (`docker-init`, `tail -f /dev/null`, `sleep infinity`) or this
#     script's own `ps` probe (zombies are ignored): a dune, a backtest, a shell all mean busy;
#   - no host `docker exec` targets it (a client waiting on output, e.g. docker_dune.sh's poll);
#   - no host driver script is mid-run (docker_dune.sh, launch_sweep.sh, build_*_warehouse*.sh, perf_pit_smoke.sh,
#     promote_config.sh, review_pack.sh, run_delisted_pipeline.sh, chain*.sh): they spend minutes on the host
#     between `docker exec` calls, and the container going away mid-script fails the next call.
# --dry-run prints the decision and stops nothing. Never touches another container, and never quits Docker
# Desktop. One line on stdout; exit 0 for any decision (including "kept"), 2 for a usage error, 1 when
# `docker stop` itself fails.
#
# Env: DOCKER_CONTAINER (trading-1-dev), CONTAINER_IDLE_DRIVERS (ERE of host driver scripts, default below).
# Test seam: CONTAINER_IDLE_DOCKER_BIN (docker).
set -u

CONTAINER="${DOCKER_CONTAINER:-trading-1-dev}"
DOCKER="${CONTAINER_IDLE_DOCKER_BIN:-docker}"
DRIVERS="${CONTAINER_IDLE_DRIVERS:-(docker_dune|launch_sweep|build_monthly_universe_warehouse|build_pit_warehouse_v12|perf_pit_smoke|promote_config|review_pack|run_delisted_pipeline|chain[^ /]*)\.sh}"
# What an idle container runs: its init, and the `ps` this script runs inside it.
IDLE_INIT='^(/sbin/docker-init( |$)|(opam exec -- )?tail -f /dev/null$|sleep infinity$|ps -eo stat=,args=$)'
PS_IN_CONTAINER='ps -eo stat=,args='

dry=0
case "${1:-}" in
  "") ;;
  --dry-run) dry=1 ;;
  *) echo "usage: container_idle_stop.sh [--dry-run]" >&2; exit 2 ;;
esac

_say() { echo "container_idle_stop: $*"; }

# _decide: sets `verdict` to "stop" or "keep" and `why`.
_decide() {
  # The host snapshot comes before any `docker exec` of ours, so our own client is not in it.
  host=$(ps -axo args= 2>/dev/null) || host=""
  if clients=$(printf '%s\n' "$host" | grep -E '^([^ ]*/)?docker (container )?exec ' | grep -E " $CONTAINER( |\$)"); then
    verdict=keep; why="a host 'docker exec' targets it: $(printf '%s\n' "$clients" | head -1 | cut -c1-100)"
    return
  fi
  if drivers=$(printf '%s\n' "$host" | grep -E "(^|[ /])($DRIVERS)( |\$)"); then
    verdict=keep; why="a host driver script is running: $(printf '%s\n' "$drivers" | head -1 | cut -c1-100)"
    return
  fi
  if ! snap=$("$DOCKER" exec "$CONTAINER" $PS_IN_CONTAINER 2>/dev/null); then
    verdict=keep; why="cannot list its processes, so cannot tell it is idle"
    return
  fi
  busy=$(printf '%s\n' "$snap" | awk 'NF && $1 !~ /^Z/' | sed 's/^[^ ]* *//' | grep -Ev "$IDLE_INIT" || true)
  if [ -n "$busy" ]; then
    verdict=keep; why="busy inside: $(printf '%s\n' "$busy" | head -1 | cut -c1-100)"
    return
  fi
  verdict=stop; why="only its init runs and nothing on the host uses it"
}

running=$("$DOCKER" inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null) || running=false
if [ "$running" != true ]; then
  _say "$CONTAINER is not running; nothing to do"
  exit 0
fi

_decide
if [ "$verdict" = keep ]; then
  _say "$CONTAINER kept: $why"
  exit 0
fi
if [ "$dry" = 1 ]; then
  _say "DRY-RUN $CONTAINER would stop: $why"
  exit 0
fi
"$DOCKER" stop -t 5 "$CONTAINER" >/dev/null 2>&1 || { _say "FAIL: 'docker stop $CONTAINER' failed"; exit 1; }
_say "$CONTAINER stopped: $why"
