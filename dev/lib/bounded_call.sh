# bounded_call.sh -- run one command under a time limit. POSIX sh; sourced, not run.
#
# Use:
#   . "$(dirname "$0")/bounded_call.sh"
#   _bounded <whole-seconds> <command> [args...]
#
# Returns the command's own exit status, or 124 (as timeout(1) does) when it had not finished after <seconds>;
# it is then SIGKILLed, so a hung `docker` CLI cannot outlive the call. Stdin, stdout and stderr go to the
# command, so `out=$(_bounded 30 docker inspect ...)` works: the watchdog keeps no pipe open, and the
# substitution returns as soon as the command does.
#
# Why a SIGKILL watchdog and not `perl -e 'alarm N; exec @ARGV'` or timeout(1): macOS has no timeout(1), and
# docker is a Go binary, which catches SIGALRM and ignores it (measured 2026-11-16: `alarm 2; exec docker events`
# was still running after 5 s). SIGKILL cannot be caught. `docker start` / `docker stop` go on in the daemon;
# only the client is cut.
#
# The watchdog counts one-second ticks (each a background `sleep 1` it can be interrupted in), so a watchdog
# stopped at the very instant it starts can leave one `sleep 1` behind, never a long one. An asynchronous command
# has its stdin on /dev/null, which suits docker calls that read no input. Variables are global (_b_ prefix).

_bounded() {
  _b_secs=$1
  shift
  "$@" &
  _b_pid=$!
  (
    # Exit 124 only once the limit has passed and the command was killed; a TERM from the caller means "finished".
    _b_fired=""
    _b_sleep=""
    trap 'kill "$_b_sleep" 2>/dev/null; [ -z "$_b_fired" ] || exit 124; exit 0' TERM
    while [ "$_b_secs" -gt 0 ]; do
      sleep 1 &
      _b_sleep=$!
      wait "$_b_sleep"
      _b_sleep=""
      _b_secs=$((_b_secs - 1))
    done
    _b_fired=1
    kill -s KILL "$_b_pid" 2>/dev/null
    exit 124
  ) >/dev/null 2>&1 &
  _b_watch=$!
  wait "$_b_pid" 2>/dev/null
  _b_rc=$?
  kill "$_b_watch" 2>/dev/null
  wait "$_b_watch" 2>/dev/null
  [ "$?" -ne 124 ] || _b_rc=124
  return "$_b_rc"
}
