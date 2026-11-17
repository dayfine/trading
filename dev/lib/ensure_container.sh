#!/bin/sh
# ensure_container.sh -- bring the local dev container up before a `docker exec`.
#
# The container (trading-1-dev) is on-demand (user decision 2026-11-16): the 16 GB host swapped 13 GB because
# the Docker Desktop VM held 5.2 GB while the container sat idle for days, and backtests run in the cloud and
# tests on CI. So it is stopped when idle (dev/lib/container_idle_stop.sh) and every script that RUNS work in
# it calls this first. Scripts that only OBSERVE it must not: they read a stopped container as idle.
#
# usage: sh dev/lib/ensure_container.sh
#
# Does nothing (exit 0, silent) when TRADING_IN_CONTAINER is set (GHA, devcontainer) or when this shell is
# already inside a container (/.dockerenv, /run/.containerenv). Otherwise:
#   1. container answers `docker exec <c> true`  -> exit 0, silent (the common case; idempotent).
#   2. Docker daemon down                        -> macOS: `open -a Docker`, wait for `docker info`.
#                                                   elsewhere: error (start the daemon yourself).
#   3. container does not exist                  -> error, exit 1.
#   4. container stopped                         -> `docker start`, wait until `docker exec <c> true` works.
# Progress and errors go to stderr, one line each, so a caller's stdout is untouched. Every wait is bounded, and
# so is every single `docker` call (dev/lib/bounded_call.sh: a hung CLI is killed): a timeout, or a call that
# does not return, is a one-line `ensure_container: FAIL: ...` and exit 1. A wait can overrun its limit by at
# most one call's limit, because the deadline is checked between calls.
#
# Env: DOCKER_CONTAINER (trading-1-dev), ENSURE_CONTAINER_DOCKER_TIMEOUT (180 s for Docker Desktop),
#      ENSURE_CONTAINER_START_TIMEOUT (60 s for the container; also the limit on the `docker start` call),
#      ENSURE_CONTAINER_CALL_TIMEOUT (30 s per other docker call, whole seconds), ENSURE_CONTAINER_POLL (2 s).
# Test seams: ENSURE_CONTAINER_DOCKER_BIN (docker), ENSURE_CONTAINER_ENV_FILES ("/.dockerenv /run/.containerenv").
set -u

CONTAINER="${DOCKER_CONTAINER:-trading-1-dev}"
DOCKER="${ENSURE_CONTAINER_DOCKER_BIN:-docker}"
DOCKER_TIMEOUT="${ENSURE_CONTAINER_DOCKER_TIMEOUT:-180}"
START_TIMEOUT="${ENSURE_CONTAINER_START_TIMEOUT:-60}"
CALL_TIMEOUT="${ENSURE_CONTAINER_CALL_TIMEOUT:-30}"
POLL="${ENSURE_CONTAINER_POLL:-2}"
ENV_FILES="${ENSURE_CONTAINER_ENV_FILES:-/.dockerenv /run/.containerenv}"

_say() { echo "ensure_container: $*" >&2; }
_fail() { echo "ensure_container: FAIL: $*" >&2; exit 1; }

[ -z "${TRADING_IN_CONTAINER:-}" ] || exit 0
for f in $ENV_FILES; do
  [ ! -e "$f" ] || exit 0
done

command -v "$DOCKER" >/dev/null 2>&1 || _fail "'$DOCKER' not found on PATH"

. "$(dirname "$0")/bounded_call.sh"

_hung() { _fail "docker $1 did not return within ${2}s"; }

# _docker <seconds> <docker-args...>: docker under a time limit, output discarded. A call that does not return
# is a FAIL (exit 1) naming its subcommand; any other status is returned. Call it from the main shell, not from
# a `$(...)`, where the exit would only leave the substitution.
_docker() {
  _t=$1
  shift
  _bounded "$_t" "$DOCKER" "$@" >/dev/null 2>&1
  _rc=$?
  [ "$_rc" -ne 124 ] || _hung "$1" "$_t"
  return "$_rc"
}

_exec_ok() { _docker "$CALL_TIMEOUT" exec "$CONTAINER" true; }
_daemon_up() { _docker "$CALL_TIMEOUT" info; }

# _wait_for <predicate> <timeout-seconds>: poll until the predicate holds; 1 on timeout.
_wait_for() {
  deadline=$(($(date +%s) + $2))
  while ! "$1"; do
    [ "$(date +%s)" -lt "$deadline" ] || return 1
    sleep "$POLL"
  done
}

_exec_ok && exit 0
begin=$(date +%s)

if ! _daemon_up; then
  if [ "$(uname -s)" = Darwin ] && command -v open >/dev/null 2>&1; then
    _say "Docker is not running; starting Docker Desktop (up to ${DOCKER_TIMEOUT}s)"
    open -a Docker >/dev/null 2>&1 || _fail "'open -a Docker' failed (is Docker Desktop installed?)"
    _wait_for _daemon_up "$DOCKER_TIMEOUT" || _fail "Docker daemon not reachable after ${DOCKER_TIMEOUT}s"
  else
    _fail "Docker daemon not reachable (start it, e.g. 'systemctl start docker')"
  fi
fi

state=$(_bounded "$CALL_TIMEOUT" "$DOCKER" inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null) && _rc=0 || _rc=$?
[ "$_rc" -ne 124 ] || _hung inspect "$CALL_TIMEOUT"
[ "$_rc" -eq 0 ] || _fail "container '$CONTAINER' does not exist (create it: .devcontainer/setup.sh start)"

if [ "$state" != true ]; then
  _say "starting '$CONTAINER'"
  _docker "$START_TIMEOUT" start "$CONTAINER" || _fail "'docker start $CONTAINER' failed"
fi
_wait_for _exec_ok "$START_TIMEOUT" ||
  _fail "container '$CONTAINER' did not answer 'docker exec' within ${START_TIMEOUT}s"
_say "'$CONTAINER' is up ($(($(date +%s) - begin))s)"
