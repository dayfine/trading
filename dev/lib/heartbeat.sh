# Heartbeat helper for long-running scripts.
#
# Use:
#   . "$REPO_ROOT/dev/lib/heartbeat.sh"
#   heartbeat_start "$LOG_FILE"   # echoes elapsed time every 30s
#   ... long-running command ...
#   heartbeat_stop                # tear down
#
# heartbeat_start also installs an EXIT trap so the heartbeat dies even
# if the parent script crashes. Caller may override the interval via
# HEARTBEAT_INTERVAL=<seconds> before calling.

_HEARTBEAT_PID=""
_HEARTBEAT_START=0

heartbeat_start() {
  local log_file="$1"
  local interval="${HEARTBEAT_INTERVAL:-30}"
  _HEARTBEAT_START=$SECONDS
  (
    while true; do
      sleep "$interval"
      local elapsed=$(($SECONDS - _HEARTBEAT_START))
      printf '[heartbeat] still running, t+%dm%02ds\n' \
        $((elapsed / 60)) $((elapsed % 60)) | tee -a "$log_file"
    done
  ) &
  _HEARTBEAT_PID=$!
  trap 'heartbeat_stop' EXIT
}

heartbeat_stop() {
  if [ -n "$_HEARTBEAT_PID" ]; then
    kill "$_HEARTBEAT_PID" 2>/dev/null || true
    _HEARTBEAT_PID=""
  fi
  trap - EXIT
}
