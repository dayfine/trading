#!/bin/sh
# quota_status.sh [--guard MAX] [--no-log]
#
# Reads the Claude plan quota (five-hour and seven-day windows) and suggests today's work size.
#
# How: one tiny headless Haiku call (~$0.02 notional) whose stream-json output carries a rate_limit_event with
# unifiedWindows.{five_hour,seven_day}.{utilization,resetsAt}. Each reading is appended to
# $QUOTA_LOG (default ~/.claude-quota/log.csv: utc,five_hour,seven_day,five_reset,seven_reset) so the burn rate
# can be read across the window.
#
# Budget model (all fractions of the seven-day window):
#   MGMT_RESERVE (default 0.15) is held back for managing: dispatching, reading results, QC, merges. Project work
#   (agents, batch readers, long analyses) must leave it untouched.
#   allowance today = (1 - used - MGMT_RESERVE) / days left in the window.
#
# --guard MAX: exit 3 when seven_day utilization >= MAX (e.g. 0.85 = 1 - MGMT_RESERVE). Batch jobs call this before
# each unit of work so a run stops itself instead of draining the week.
# Exit 0 ok, 3 over the guard, 4 the reading failed.
set -eu
MGMT_RESERVE=${MGMT_RESERVE:-0.15}
QUOTA_LOG=${QUOTA_LOG:-$HOME/.claude-quota/log.csv}
GUARD=""; LOG=1
while [ $# -gt 0 ]; do
  case "$1" in
    --guard) [ $# -ge 2 ] || { echo "--guard needs a value" >&2; exit 2; }; GUARD=$2; shift ;;
    --no-log) LOG=0 ;;
    *) echo "usage: $0 [--guard MAX] [--no-log]" >&2; exit 2 ;;
  esac
  shift
done
probe_dir=$(mktemp -d); trap 'rm -rf "$probe_dir"' EXIT
line=$(cd "$probe_dir" && claude -p --model claude-haiku-4-5-20251001 --output-format stream-json --verbose \
  --no-session-persistence "reply ok" 2>/dev/null | grep '"rate_limit_event"' | tail -1 || true)
[ -n "$line" ] || { echo "quota_status: no rate_limit_event in the probe output" >&2; exit 4; }
read -r five seven five_reset seven_reset <<EOF
$(printf '%s\n' "$line" | jq -r '.rate_limit_info.unifiedWindows | "\(.five_hour.utilization) \(.seven_day.utilization) \(.five_hour.resetsAt) \(.seven_day.resetsAt)"')
EOF
now=$(date -u +%s)
if [ "$LOG" = 1 ]; then
  mkdir -p "$(dirname "$QUOTA_LOG")"
  [ -f "$QUOTA_LOG" ] || echo "utc,five_hour,seven_day,five_reset,seven_reset" > "$QUOTA_LOG"
  echo "$now,$five,$seven,$five_reset,$seven_reset" >> "$QUOTA_LOG"
fi
# burn rate: seven-day use per day since the first reading in this window (same seven_reset)
first=$(awk -F, -v r="$seven_reset" 'NR > 1 && $5 == r { print $1, $3; exit }' "$QUOTA_LOG" 2>/dev/null || true)
awk -v five="$five" -v seven="$seven" -v fr="$five_reset" -v sr="$seven_reset" -v now="$now" \
    -v res="$MGMT_RESERVE" -v first="$first" '
  BEGIN {
    days = (sr - now) / 86400; if (days < 0.04) days = 0.04
    allow = (1 - seven - res) / days
    printf "seven-day: %.0f %% used, resets in %.1f days\n", 100 * seven, days
    printf "five-hour: %.0f %% used, resets in %.1f h\n", 100 * five, (fr - now) / 3600
    printf "management reserve: %.0f %% of the week\n", 100 * res
    split(first, f, " ")
    if (f[1] != "" && now - f[1] > 86400) {
      rate = (seven - f[2]) / ((now - f[1]) / 86400)
      proj = seven + rate * days
      printf "burn: %.1f %%/day since the first reading; projected at reset: %.0f %%\n", 100 * rate, 100 * proj
    }
    if (allow <= 0) {
      print "suggest: MANAGEMENT ONLY. No project work, no batch runs; keep the reserve for reviews and merges."
    } else {
      printf "allowance for project work: %.1f %% of the week per day\n", 100 * allow
      if (allow < 0.05)      print "suggest: SMALL. One agent at a time, sonnet/haiku where the routing allows, no batch runs."
      else if (allow < 0.12) print "suggest: NORMAL. Up to 3 agents; batch runs only with --guard."
      else                   print "suggest: LARGE. Room for a batch run or an opus analysis wave, still with --guard."
    }
  }'
if [ -n "$GUARD" ]; then
  max=$GUARD
  over=$(awk -v s="$seven" -v m="$max" 'BEGIN { print (s >= m) ? 1 : 0 }')
  [ "$over" = 1 ] && { echo "quota_status: seven-day $seven >= guard $max" >&2; exit 3; }
fi
exit 0
