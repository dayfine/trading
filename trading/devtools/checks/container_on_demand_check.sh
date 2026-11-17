#!/bin/sh
# container_on_demand_check.sh -- pin the on-demand dev container (user decision 2026-11-16).
#
# The local container is stopped when idle: scripts that RUN work in it start it first
# (dev/lib/ensure_container.sh), and a dispatcher stops it when nothing runs
# (dev/lib/container_idle_stop.sh). Scripts that only OBSERVE it must never start it and must read a
# stopped container as idle.
#
# No docker needed: a fake `docker` (plus `ps`, `open`, `uname`, `gh`) goes first on PATH and keeps its
# state in files, so `docker start` really flips "running" and every call lands in calls.log. Pins:
#   ensure_container.sh  started when stopped; silent no-op when running; no-op under TRADING_IN_CONTAINER
#                        and inside a container; error when the container does not exist, docker is
#                        missing, the daemon never comes up, or the container never answers; Docker Desktop
#                        started with `open -a Docker` on macOS only; DOCKER_CONTAINER honoured.
#   container_idle_stop.sh  refuses while a dune process (or any non-init process) runs inside, while a host
#                        `docker exec` targets it, or while a host driver script runs; stops only the one
#                        container when idle; --dry-run stops nothing; a zombie is not "busy".
#   observers            wait_for.sh proc fires on a stopped container (and on a down daemon), where_is_work.sh
#                        reports it stopped, sweep_disk_watcher.sh exits cleanly: none of them starts it.
#   wiring               run-in-env.sh starts the container in local mode; every script that runs work in it
#                        calls ensure_container.sh, and no observer does.
set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="container_on_demand_check"
PASS=0
FAIL=0
ok() { printf 'OK: %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

ROOT="$(repo_root)"
ENSURE="$ROOT/dev/lib/ensure_container.sh"
IDLE_STOP="$ROOT/dev/lib/container_idle_stop.sh"
WAIT_FOR="$ROOT/dev/scripts/wait_for.sh"
WHERE="$ROOT/dev/scripts/where_is_work.sh"
WATCHER="$ROOT/dev/scripts/sweep_disk_watcher.sh"
RUN_IN_ENV="$ROOT/dev/lib/run-in-env.sh"
for f in "$ENSURE" "$IDLE_STOP" "$WAIT_FOR" "$WHERE" "$WATCHER" "$RUN_IN_ENV"; do
  [ -f "$f" ] || die "${LABEL}: $f does not exist"
done

WORK="$(mktemp -d)"
FAKE_BIN="$WORK/bin"
mkdir -p "$FAKE_BIN"
trap 'rm -rf "$WORK"' EXIT INT TERM
NOFILE="$WORK/no-such-file"

# --- Fake docker: state lives in $FAKE_STATE, one file per fact.
#   daemon   the daemon answers (absent: every call fails, like a Docker Desktop that is not running)
#   exists   the container exists (absent: `inspect` fails)
#   running  the container is running (`docker start` creates it, `docker stop` removes it)
#   start_noop  `docker start` succeeds but the container never comes up
#   ps       the process table served for `docker exec <c> ps ...`
#   ps_fail  `docker exec <c> ps ...` fails although the container is running
cat > "$FAKE_BIN/docker" <<'FAKE_DOCKER_EOF'
#!/bin/sh
echo "$*" >> "$FAKE_STATE/calls.log"
[ -f "$FAKE_STATE/daemon" ] || { echo "Cannot connect to the Docker daemon" >&2; exit 1; }
case "$1" in
  info) exit 0 ;;
  ps) [ -f "$FAKE_STATE/running" ] && echo trading-1-dev; exit 0 ;;
  inspect)
    [ -f "$FAKE_STATE/exists" ] || { echo "Error: No such object" >&2; exit 1; }
    case "$*" in
      *State.Running*) if [ -f "$FAKE_STATE/running" ]; then echo true; else echo false; fi ;;
    esac
    exit 0 ;;
  start)
    [ -f "$FAKE_STATE/exists" ] || exit 1
    [ -f "$FAKE_STATE/start_noop" ] || : > "$FAKE_STATE/running"
    exit 0 ;;
  stop) rm -f "$FAKE_STATE/running"; exit 0 ;;
  exec)
    [ -f "$FAKE_STATE/running" ] || { echo "Error response from daemon: container is not running" >&2; exit 1; }
    shift # exec
    while :; do
      case "$1" in
        -e|-w|-u) shift 2 ;;
        -*) shift ;;
        *) break ;;
      esac
    done
    shift # the container
    case "$1" in
      true) exit 0 ;;
      ps) [ ! -f "$FAKE_STATE/ps_fail" ] || exit 1; cat "$FAKE_STATE/ps" 2>/dev/null; exit 0 ;;
      kill) exit 1 ;;
      *) echo "ran: $*"; exit 0 ;;
    esac ;;
esac
exit 0
FAKE_DOCKER_EOF
# --- Fake `open`: Docker Desktop comes up at once unless open_noop exists.
cat > "$FAKE_BIN/open" <<'FAKE_OPEN_EOF'
#!/bin/sh
echo "$*" >> "$FAKE_STATE/open.log"
[ -f "$FAKE_STATE/open_noop" ] || : > "$FAKE_STATE/daemon"
exit 0
FAKE_OPEN_EOF
# --- Fake `uname -s`, so the macOS branch is exercised on Linux too (FAKE_UNAME, default Darwin).
cat > "$FAKE_BIN/uname" <<'FAKE_UNAME_EOF'
#!/bin/sh
echo "${FAKE_UNAME:-Darwin}"
FAKE_UNAME_EOF
# --- Fake host `ps`: the host process table is whatever the case wrote to $FAKE_STATE/hostps.
cat > "$FAKE_BIN/ps" <<'FAKE_PS_EOF'
#!/bin/sh
cat "$FAKE_STATE/hostps" 2>/dev/null
exit 0
FAKE_PS_EOF
# --- Fake `gh`: where_is_work.sh asks it for PRs, issues and runs; there are none.
cat > "$FAKE_BIN/gh" <<'FAKE_GH_EOF'
#!/bin/sh
exit 0
FAKE_GH_EOF
chmod +x "$FAKE_BIN/docker" "$FAKE_BIN/open" "$FAKE_BIN/uname" "$FAKE_BIN/ps" "$FAKE_BIN/gh"

# --- Case plumbing.
N=0
S=""
# new_state [fact...]: a fresh state dir holding the named facts (daemon exists running ...).
new_state() {
  N=$((N + 1))
  S="$WORK/state.$N"
  mkdir -p "$S"
  : > "$S/calls.log"
  for fact in "$@"; do : > "$S/$fact"; done
}
INIT_PS='Ss   /sbin/docker-init -- opam exec -- tail -f /dev/null
S    tail -f /dev/null
Rs   ps -eo stat=,args='
# with_env CMD...: run CMD with the fakes first on PATH and the in-container guards off.
with_env() {
  env -u TRADING_IN_CONTAINER FAKE_STATE="$S" PATH="$FAKE_BIN:$PATH" \
    ENSURE_CONTAINER_ENV_FILES="$NOFILE" ENSURE_CONTAINER_POLL=1 \
    ENSURE_CONTAINER_START_TIMEOUT=2 ENSURE_CONTAINER_DOCKER_TIMEOUT=2 "$@"
}
# run_ensure: OUT and RC from ensure_container.sh under with_env.
run_ensure() { OUT=$(with_env sh "$ENSURE" 2>&1) && RC=0 || RC=$?; }
# run_idle [args]: OUT and RC from container_idle_stop.sh under with_env.
run_idle() { OUT=$(with_env sh "$IDLE_STOP" "$@" 2>&1) && RC=0 || RC=$?; }
logged() { grep -q -- "$1" "$S/calls.log"; }
has_out() { printf '%s' "$OUT" | grep -qF -- "$1"; }
# expect LABEL RC-WANTED: RC must equal RC-WANTED.
expect_rc() {
  if [ "$RC" -eq "$2" ]; then ok "${LABEL} -- $1: exit $2"; else bad "${LABEL} -- $1: exit $RC, wanted $2; output='$OUT'"; fi
}
expect_out() { # label, fixed string the output must hold
  if has_out "$2"; then ok "${LABEL} -- $1: output names '$2'"; else bad "${LABEL} -- $1: output lacks '$2'; got '$OUT'"; fi
}
expect_logged() { # label, regex that must be in calls.log
  if logged "$2"; then ok "${LABEL} -- $1"; else bad "${LABEL} -- $1: no docker call matching '$2'; calls: $(tr '\n' ';' < "$S/calls.log")"; fi
}
expect_not_logged() { # label, regex that must NOT be in calls.log
  if logged "$2"; then bad "${LABEL} -- $1: unexpected docker call matching '$2'; calls: $(tr '\n' ';' < "$S/calls.log")"; else ok "${LABEL} -- $1"; fi
}

# ===================================================================== ensure_container.sh
new_state daemon exists
run_ensure
expect_rc "stopped container" 0
expect_logged "stopped container is started (docker start)" '^start trading-1-dev$'
[ -f "$S/running" ] && ok "${LABEL} -- stopped container is running afterwards" || bad "${LABEL} -- stopped container is not running afterwards"

new_state daemon exists running
run_ensure
expect_rc "running container" 0
expect_not_logged "running container: never started" '^start '
expect_not_logged "running container: daemon not probed" '^info'
[ -z "$OUT" ] && ok "${LABEL} -- running container: silent" || bad "${LABEL} -- running container printed '$OUT'"

new_state exists
OUT=$(env FAKE_STATE="$S" PATH="$FAKE_BIN:$PATH" TRADING_IN_CONTAINER=1 ENSURE_CONTAINER_ENV_FILES="$NOFILE" sh "$ENSURE" 2>&1) && RC=0 || RC=$?
expect_rc "TRADING_IN_CONTAINER=1" 0
[ ! -s "$S/calls.log" ] && ok "${LABEL} -- TRADING_IN_CONTAINER=1: docker never called" || bad "${LABEL} -- TRADING_IN_CONTAINER=1 called docker: $(cat "$S/calls.log")"

new_state exists
: > "$WORK/dockerenv"
OUT=$(with_env env ENSURE_CONTAINER_ENV_FILES="$WORK/dockerenv" sh "$ENSURE" 2>&1) && RC=0 || RC=$?
expect_rc "already inside a container" 0
[ ! -s "$S/calls.log" ] && ok "${LABEL} -- inside a container: docker never called" || bad "${LABEL} -- inside a container called docker: $(cat "$S/calls.log")"

new_state daemon
run_ensure
expect_rc "missing container" 1
expect_out "missing container" "trading-1-dev"
expect_out "missing container" "does not exist"
expect_not_logged "missing container: nothing started" '^start '

new_state daemon exists
OUT=$(with_env env ENSURE_CONTAINER_DOCKER_BIN=no-such-docker-xyz sh "$ENSURE" 2>&1) && RC=0 || RC=$?
expect_rc "docker not installed" 1
expect_out "docker not installed" "not found"

new_state exists
run_ensure
expect_rc "daemon down (macOS)" 0
if [ -f "$S/open.log" ] && grep -q -- '-a Docker' "$S/open.log"; then ok "${LABEL} -- daemon down: Docker Desktop started with 'open -a Docker'"; else bad "${LABEL} -- daemon down: 'open -a Docker' not run"; fi
expect_logged "daemon down: container started once the daemon is up" '^start trading-1-dev$'

new_state exists open_noop
run_ensure
expect_rc "daemon never comes up" 1
expect_out "daemon never comes up" "Docker daemon not reachable after"

new_state exists
OUT=$(with_env env FAKE_UNAME=Linux sh "$ENSURE" 2>&1) && RC=0 || RC=$?
expect_rc "daemon down (Linux)" 1
[ ! -f "$S/open.log" ] && ok "${LABEL} -- daemon down on Linux: open never run" || bad "${LABEL} -- daemon down on Linux ran open"

new_state daemon exists start_noop
run_ensure
expect_rc "container never answers" 1
expect_out "container never answers" "did not answer"

new_state daemon exists
OUT=$(with_env env DOCKER_CONTAINER=dev2 sh "$ENSURE" 2>&1) && RC=0 || RC=$?
expect_logged "DOCKER_CONTAINER names the container to start" '^start dev2$'

# ===================================================================== container_idle_stop.sh
new_state daemon exists running
printf '%s\n' "$INIT_PS" > "$S/ps"
run_idle --dry-run
expect_rc "idle, --dry-run" 0
expect_out "idle, --dry-run" "would stop"
expect_not_logged "idle, --dry-run: nothing stopped" '^stop '

run_idle
expect_rc "idle" 0
expect_logged "idle container is stopped, that one only" '^stop -t 5 trading-1-dev$'
[ ! -f "$S/running" ] && ok "${LABEL} -- idle container is stopped afterwards" || bad "${LABEL} -- idle container still running"

new_state daemon exists running
printf '%s\nSl   dune build @runtest\n' "$INIT_PS" > "$S/ps"
run_idle
expect_rc "dune running inside" 0
expect_out "dune running inside" "kept"
expect_out "dune running inside" "dune build"
expect_not_logged "dune running inside: NOT stopped" '^stop '

new_state daemon exists running
printf '%s\nS    bash -c cd /workspaces/trading-1/trading && eval $(opam env) && scenario_runner.exe\n' "$INIT_PS" > "$S/ps"
run_idle
expect_not_logged "a backtest shell running inside: NOT stopped" '^stop '

new_state daemon exists running
printf '%s\nS    bash\n' "$INIT_PS" > "$S/ps"
run_idle
expect_not_logged "an idle shell inside: NOT stopped (only init counts as idle)" '^stop '

new_state daemon exists running
printf '%s\nZ    [dune] <defunct>\n' "$INIT_PS" > "$S/ps"
run_idle
expect_logged "a zombie dune is not busy" '^stop '

new_state daemon exists running
printf '%s\n' "$INIT_PS" > "$S/ps"
printf '%s\n' '/usr/local/bin/docker exec trading-1-dev bash -c cd /workspaces/trading-1/trading && dune build' > "$S/hostps"
run_idle
expect_out "host docker exec client" "host 'docker exec'"
expect_not_logged "host docker exec client: NOT stopped" '^stop '

new_state daemon exists running
printf '%s\n' "$INIT_PS" > "$S/ps"
printf '%s\n' 'docker exec other-container sleep 5' > "$S/hostps"
run_idle
expect_logged "a host docker exec on ANOTHER container does not block" '^stop -t 5 trading-1-dev$'

new_state daemon exists running
printf '%s\n' "$INIT_PS" > "$S/ps"
printf '%s\n' 'sh dev/scripts/review_pack.sh --out /tmp/pack s0=run/' > "$S/hostps"
run_idle
expect_out "host driver script" "driver script"
expect_not_logged "host driver script: NOT stopped" '^stop '

new_state daemon exists running ps_fail
run_idle
expect_out "container processes unreadable" "cannot list"
expect_not_logged "container processes unreadable: NOT stopped" '^stop '

new_state daemon exists
run_idle
expect_rc "already stopped" 0
expect_out "already stopped" "not running"
expect_not_logged "already stopped: no stop call" '^stop '

new_state
run_idle
expect_rc "daemon down" 0
expect_out "daemon down" "not running"

new_state daemon exists running
OUT=$(with_env sh "$IDLE_STOP" --bogus 2>&1) && RC=0 || RC=$?
expect_rc "unknown flag" 2

# ===================================================================== observers never start it
new_state daemon exists
WAIT_OUT=$(with_env env WAIT_FOR_PS='docker exec trading-1-dev ps -eo stat=,args=' \
  sh "$WAIT_FOR" --max-seconds 5 --interval 1 proc 'dune (build|runtest)' 2>&1) && RC=0 || RC=$?
OUT="$WAIT_OUT"
expect_rc "wait_for proc on a stopped container" 0
expect_out "wait_for proc on a stopped container" "fired"
expect_not_logged "wait_for proc never starts the container" '^start '

new_state
OUT=$(with_env env WAIT_FOR_PS='docker exec trading-1-dev ps -eo stat=,args=' \
  sh "$WAIT_FOR" --max-seconds 5 --interval 1 proc 'dune (build|runtest)' 2>&1) && RC=0 || RC=$?
expect_rc "wait_for proc with the daemon down" 0

# control: the same wait on a RUNNING container with a dune process must not fire, or the case above proves nothing
new_state daemon exists running
printf '%s\nSl   dune build @runtest\n' "$INIT_PS" > "$S/ps"
OUT=$(with_env env WAIT_FOR_PS='docker exec trading-1-dev ps -eo stat=,args=' \
  sh "$WAIT_FOR" --max-seconds 2 --interval 1 proc 'dune (build|runtest)' 2>&1) && RC=0 || RC=$?
expect_rc "control: wait_for proc while dune runs times out" 2

# where_is_work.sh runs from a copy so its sibling pr_gate_status.sh (needs a real gh) is skipped
mkdir -p "$WORK/where"
cp "$WHERE" "$WORK/where/where_is_work.sh"
new_state daemon exists
OUT=$(with_env sh "$WORK/where/where_is_work.sh" 2>&1) && RC=0 || RC=$?
expect_rc "where_is_work on a stopped container" 0
expect_out "where_is_work on a stopped container" "(container stopped)"
expect_not_logged "where_is_work never starts the container" '^start '

new_state daemon exists running
printf '%s\n' "$INIT_PS" > "$S/ps"
OUT=$(with_env sh "$WORK/where/where_is_work.sh" 2>&1) && RC=0 || RC=$?
expect_out "where_is_work on an idle running container" "(container idle)"

if command -v bash >/dev/null 2>&1; then
  new_state daemon exists
  OUT=$(with_env bash "$WATCHER" --sweep-pid 4242 --sweep-name onDemand --log-dir "$WORK/watcher" 2>&1) && RC=0 || RC=$?
  expect_rc "sweep_disk_watcher on a stopped container" 0
  expect_out "sweep_disk_watcher on a stopped container" "exited"
  expect_not_logged "sweep_disk_watcher never starts the container" '^start '

  # run-in-env.sh, local mode: the stopped container is started, then the command runs in it
  new_state daemon exists
  OUT=$(with_env bash "$RUN_IN_ENV" dune build 2>&1) && RC=0 || RC=$?
  expect_rc "run-in-env.sh on a stopped container" 0
  expect_logged "run-in-env.sh starts the stopped container" '^start trading-1-dev$'
  expect_out "run-in-env.sh then runs the command in it" "ran: bash -c"
else
  echo "OK: ${LABEL} -- sweep_disk_watcher / run-in-env cases SKIPPED (bash not on PATH)."
fi

# ===================================================================== wiring
# A script that runs work in the container calls ensure_container.sh on a non-comment line; an observer does not.
code_lines() { grep -v '^[[:space:]]*#' "$1"; }
for s in dev/lib/run-in-env.sh dev/scripts/docker_dune.sh dev/scripts/build_monthly_universe_warehouse.sh \
  dev/scripts/build_pit_warehouse_v12.sh dev/scripts/launch_sweep.sh dev/scripts/perf_pit_smoke.sh \
  dev/scripts/promote_config.sh dev/scripts/review_pack.sh dev/scripts/run_delisted_pipeline.sh; do
  if code_lines "$ROOT/$s" | grep -q 'ensure_container\.sh'; then ok "${LABEL} -- $s calls ensure_container.sh"; else bad "${LABEL} -- $s runs work in the container but never calls ensure_container.sh"; fi
done
for s in dev/scripts/wait_for.sh dev/scripts/where_is_work.sh dev/scripts/sweep_disk_watcher.sh; do
  if code_lines "$ROOT/$s" | grep -q 'ensure_container\.sh'; then bad "${LABEL} -- $s only observes but calls ensure_container.sh"; else ok "${LABEL} -- $s (observer) does not start the container"; fi
done

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: ${LABEL} -- ${PASS} passed, ${FAIL} failed." >&2
  exit 1
fi
echo "OK: ${LABEL} -- ${PASS} assertion(s) passed, 0 failed."
