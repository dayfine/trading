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

# Reap stale agent worktrees / jj workspaces > 7 days old. Cheap, runs
# in under a second, prevents .claude/worktrees + .claude/jj-ws from
# accumulating after agent sessions that didn't clean up after
# themselves. Silent unless it actually removed something.
"$REPO_ROOT/dev/lib/cleanup-stale-worktrees.sh" 2>&1 \
  | grep -v "^no stale " || true

PLAN_FLAG=""
for arg in "$@"; do
  case "$arg" in
    --plan) PLAN_FLAG=" --plan" ;;
    *) echo "Usage: $0 [--plan]" >&2; exit 1 ;;
  esac
done

DATE="$(date +%Y-%m-%d)"
LOG_DIR="$REPO_ROOT/dev/logs"
DAILY_DIR="$REPO_ROOT/dev/daily"
mkdir -p "$LOG_DIR" "$DAILY_DIR"

# Pick a same-day run suffix so multiple runs on the same date don't
# clobber one another. Plan-mode always writes to <date>-plan.md
# (overwrites on rerun — planning is idempotent anyway).
if [ -n "$PLAN_FLAG" ]; then
  RUN_SUFFIX="-plan"
else
  N=1
  while [ -f "$DAILY_DIR/$DATE-run$N.md" ]; do N=$((N+1)); done
  RUN_SUFFIX="-run$N"
fi
LOG_FILE="$LOG_DIR/$DATE$RUN_SUFFIX.log"
JSONL_FILE="$LOG_DIR/$DATE$RUN_SUFFIX.jsonl"
SUMMARY_FILE="$DAILY_DIR/$DATE$RUN_SUFFIX.md"
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
Today's date is $DATE.
Write the daily summary to: $SUMMARY_FILE
(this is run suffix \"$RUN_SUFFIX\" — pass it through to any log / artifact paths you create so same-day reruns do not overwrite earlier ones).${PLAN_FLAG}

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
