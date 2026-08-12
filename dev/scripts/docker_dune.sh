#!/bin/sh
# docker_dune.sh -- run a dune command inside the dev container without wedging.
#
# WHY THIS EXISTS
#   `docker exec trading-1-dev bash -c '... dune build ...'` run in the
#   foreground wedges whenever the caller's stdout pipe dies (a tool-output
#   timeout, a killed poll loop, a closed terminal): dune blocks on the dead
#   pipe forever, holding the `_build/.db` lock, and every later dune command
#   in the container hangs. It recurred three times in the 2026-08-11 session,
#   including in a sweep-launch script written AFTER the memory note about it
#   was updated. Prose does not prevent it; this wrapper does.
#
#   The fix is structural: ALWAYS run detached (`docker exec -d`), redirect
#   both streams to a log file inside the container, append an `exit=<code>`
#   sentinel, and poll the log from outside. No pipe exists to die, so there
#   is nothing to wedge on. The exit code is recovered from the sentinel
#   rather than from `docker exec`, whose status is meaningless when detached.
#
# USAGE
#   dev/scripts/docker_dune.sh [--dir SUBDIR] [--log PATH] [--timeout SECS]
#                              [--poll SECS] [--quiet] -- <dune args...>
#
#   dev/scripts/docker_dune.sh -- build
#   dev/scripts/docker_dune.sh --timeout 3600 -- runtest trading/orders/test
#   dev/scripts/docker_dune.sh --dir .claude/worktrees/jjws-x/trading -- build @fmt
#
# FLAGS
#   --dir SUBDIR     Dune root, RELATIVE TO THE REPO ROOT inside the container
#                    (default: trading). Point this at an agent workspace so
#                    you build YOUR edits and not the parent tree -- the
#                    2026-06-07 contamination bug.
#   --log PATH       Container-side log path (default: a unique /tmp path).
#   --timeout SECS   Give up waiting after SECS (default: 7200). The command
#                    keeps running in the container; only the wait stops.
#   --poll SECS      Seconds between sentinel checks (default: 10).
#   --quiet          Do not stream the log tail while waiting.
#
# ENV
#   CONTAINER        Container name (default: trading-1-dev).
#   REPO_IN_CONTAINER  Repo root inside the container
#                    (default: /workspaces/trading-1).
#
# EXIT STATUS
#   The dune command's own exit code, recovered from the sentinel.
#   124 if --timeout elapsed first. 125 if the container is not running.
#
# OUTPUT
#   Streams new log lines while waiting (unless --quiet), then prints the
#   resolved log path so a failure can be re-read in full.

set -e

CONTAINER="${CONTAINER:-trading-1-dev}"
REPO_IN_CONTAINER="${REPO_IN_CONTAINER:-/workspaces/trading-1}"
DUNE_SUBDIR="trading"
LOG=""
TIMEOUT=7200
POLL=10
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DUNE_SUBDIR="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --poll) POLL="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    --) shift; break ;;
    *) echo "docker_dune: unknown flag '$1'" >&2; exit 2 ;;
  esac
done

if [ $# -eq 0 ]; then
  echo "docker_dune: no dune arguments given (expected e.g. '-- build')" >&2
  exit 2
fi

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
  echo "docker_dune: container '$CONTAINER' is not running." >&2
  exit 125
fi

if [ -z "$LOG" ]; then
  LOG="/tmp/docker_dune-$(date +%Y%m%d-%H%M%S)-$$.log"
fi

# Quote every dune argument so paths with spaces survive the trip through
# `bash -c`. Built as a single string because POSIX sh has no arrays.
DUNE_ARGS=""
for arg in "$@"; do
  DUNE_ARGS="$DUNE_ARGS '$(printf '%s' "$arg" | sed "s/'/'\\\\''/g")'"
done

# The sentinel is appended by the SAME shell that ran dune, so it is written
# whether dune succeeded, failed, or was killed by a signal -- the waiter
# below can therefore always distinguish "still running" from "finished".
docker exec -d "$CONTAINER" bash -c \
  "cd '${REPO_IN_CONTAINER}/${DUNE_SUBDIR}' && eval \$(opam env) && \
   dune${DUNE_ARGS} > '${LOG}' 2>&1; echo \"exit=\$?\" >> '${LOG}'"

echo "docker_dune: running 'dune$DUNE_ARGS' in ${DUNE_SUBDIR} (log: ${LOG})"

ELAPSED=0
SHOWN=0
STATUS=""
while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  STATUS="$(docker exec "$CONTAINER" sh -c \
    "grep -m1 '^exit=' '${LOG}' 2>/dev/null || true")"
  if [ -n "$STATUS" ]; then
    break
  fi
  if [ "$QUIET" -eq 0 ]; then
    # `cat | wc -l` rather than `wc -l < file`: the redirect is opened by the
    # shell, so it prints its own "cannot open" during the window before the
    # detached command has created the log.
    TOTAL="$(docker exec "$CONTAINER" sh -c "cat '${LOG}' 2>/dev/null | wc -l")"
    if [ "$TOTAL" -gt "$SHOWN" ]; then
      docker exec "$CONTAINER" sh -c "tail -n +$((SHOWN + 1)) '${LOG}'"
      SHOWN="$TOTAL"
    fi
  fi
  sleep "$POLL"
  ELAPSED=$((ELAPSED + POLL))
done

if [ -z "$STATUS" ]; then
  echo "docker_dune: TIMEOUT after ${TIMEOUT}s; command still running in the container."
  echo "docker_dune: log = ${LOG}"
  exit 124
fi

# Print whatever arrived after the last poll so the tail is never truncated.
if [ "$QUIET" -eq 0 ]; then
  docker exec "$CONTAINER" sh -c "tail -n +$((SHOWN + 1)) '${LOG}'" || true
fi

CODE="${STATUS#exit=}"
echo "docker_dune: exit=${CODE} (log: ${LOG})"
exit "$CODE"
