#!/usr/bin/env bash
# Daily lead-orchestrator run.
#
# Usage:
#   ./dev/run.sh             — full run (dispatches subagents)
#   ./dev/run.sh --plan      — dry run (read state + print plan, no dispatch;
#                              see lead-orchestrator.md `## Plan Mode`)
#   via cron: 0 7 * * * /home/user/trading/dev/run.sh
#
# The script keeps you informed during long quiet stretches:
#   - intermediate tool calls + subagent dispatches stream live
#   - a heartbeat prints elapsed time every 30s
# Raw stream-json goes to dev/logs/<date>.jsonl for forensics; the
# human-readable view also lands in dev/logs/<date>.log.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_ROOT/dev/lib/preflight.sh"
. "$REPO_ROOT/dev/lib/heartbeat.sh"

PLAN_FLAG=""
for arg in "$@"; do
  case "$arg" in
    --plan) PLAN_FLAG=" --plan" ;;
    *) echo "Usage: $0 [--plan]" >&2; exit 1 ;;
  esac
done

DATE="$(date +%Y-%m-%d)"
LOG_DIR="$REPO_ROOT/dev/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$DATE.log"
JSONL_FILE="$LOG_DIR/$DATE.jsonl"
SUMMARY_FILE="$REPO_ROOT/dev/daily/$DATE${PLAN_FLAG:+-plan}.md"
JQ_FILTER="$REPO_ROOT/dev/lib/format-event.jq"

# GH_TOKEN is required so subagents (feat-*, harness-maintainer) can run
# `jst submit` to open PRs at session end. If the user has gh credentials
# cached, harvest the token; otherwise warn and continue (the orchestrator
# will surface "no PR opened" in the daily summary's escalations).
if [ -z "${GH_TOKEN:-}" ]; then
  GH_TOKEN=$(echo -e "protocol=https\nhost=github.com" \
    | git credential fill 2>/dev/null \
    | grep ^password | cut -d= -f2 || true)
  if [ -z "$GH_TOKEN" ]; then
    echo "WARN: GH_TOKEN unset and not derivable from git credentials." >&2
    echo "WARN: subagents will push branches but cannot open PRs via jst." >&2
  fi
  export GH_TOKEN
fi

# EODHD_API_KEY is optional; ops-data uses it for fetches (sector ETF bars,
# symbol updates) but can still do a lot without it (scrape-source validation,
# sector-data-plan execution, inventory rebuilds, coverage checks). Forward
# explicitly so the orchestrator subprocess + downstream `docker exec -e ...`
# all see the same value.
if [ -n "${EODHD_API_KEY:-}" ]; then
  export EODHD_API_KEY
else
  echo "NOTE: EODHD_API_KEY not set — ops-data will skip API-dependent fetches" >&2
fi

PROMPT="Run the daily development session for the Weinstein Trading System.
Today's date is $DATE.${PLAN_FLAG}

Follow your instructions in .claude/agents/lead-orchestrator.md exactly."

PIPE_FILTER='cat'
command -v jq >/dev/null && PIPE_FILTER="jq -r --unbuffered -f $JQ_FILTER"

echo "[$(date '+%H:%M:%S')] Starting daily run${PLAN_FLAG:+ (plan mode)}" \
  | tee -a "$LOG_FILE"
echo "[$(date '+%H:%M:%S')] Log: $LOG_FILE  Stream: $JSONL_FILE" \
  | tee -a "$LOG_FILE"

cd "$REPO_ROOT"
heartbeat_start "$LOG_FILE"

set +e
claude -p \
  --output-format stream-json \
  --verbose \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --agent lead-orchestrator \
  "$PROMPT" \
  2> >(tee -a "$LOG_FILE" >&2) \
| tee -a "$JSONL_FILE" \
| eval "$PIPE_FILTER" \
| tee -a "$LOG_FILE"
RC=${PIPESTATUS[0]}
set -e

heartbeat_stop

ELAPSED=$SECONDS
echo "[$(date '+%H:%M:%S')] Daily run complete in ${ELAPSED}s (rc=$RC)" \
  | tee -a "$LOG_FILE"
if [ -f "$SUMMARY_FILE" ]; then
  echo "[$(date '+%H:%M:%S')] Summary: $SUMMARY_FILE" | tee -a "$LOG_FILE"
else
  echo "[$(date '+%H:%M:%S')] WARN: no summary written at $SUMMARY_FILE" \
    | tee -a "$LOG_FILE"
fi

exit $RC
