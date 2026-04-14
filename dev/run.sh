#!/usr/bin/env bash
# Daily development run for the Weinstein Trading System.
# Runs the lead orchestrator non-interactively.
# Usage: ./dev/run.sh
#        or via cron: 0 7 * * * /home/user/trading/dev/run.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Pre-flight: fast-fail if the invocation environment is broken.
# These checks catch common misconfigurations (missing CLI, relocated agent
# file, silently-drifted Allowed Tools section) at the shell level, before
# we burn tokens spinning up the orchestrator only for it to bail out.
_ORCH_AGENT="$REPO_ROOT/.claude/agents/lead-orchestrator.md"
command -v claude >/dev/null 2>&1 \
  || { echo "FAIL: 'claude' binary not on PATH" >&2; exit 1; }
[ -f "$_ORCH_AGENT" ] \
  || { echo "FAIL: lead-orchestrator agent definition missing at $_ORCH_AGENT" >&2; exit 1; }
# Soft grep: the Allowed Tools section must mention Agent. Plain-text match
# is sufficient — catches the drift case where someone edits the file and
# drops Agent from the tool list.
grep -q '^## Allowed Tools' "$_ORCH_AGENT" \
  || { echo "FAIL: lead-orchestrator missing '## Allowed Tools' section" >&2; exit 1; }
awk '/^## Allowed Tools/{flag=1; next} /^## /{flag=0} flag' "$_ORCH_AGENT" | grep -q 'Agent' \
  || { echo "FAIL: lead-orchestrator '## Allowed Tools' section does not list Agent" >&2; exit 1; }

LOG_DIR="$REPO_ROOT/dev/logs"
mkdir -p "$LOG_DIR"

DATE="$(date +%Y-%m-%d)"
LOG_FILE="$LOG_DIR/$DATE.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting daily run" | tee -a "$LOG_FILE"

cd "$REPO_ROOT"

claude -p \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --agent lead-orchestrator \
  "Run the daily development session for the Weinstein Trading System.
Today's date is $(date +%Y-%m-%d).

Follow your instructions exactly:
1. Read dev/decisions.md and all dev/status/*.md
2. Spawn eligible feature agents as parallel subagents (isolation: worktree)
3. Spawn QC agents for any READY_FOR_REVIEW features
4. Write dev/daily/$(date +%Y-%m-%d).md with the full status summary" \
  2>&1 | tee -a "$LOG_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daily run complete. Summary: $REPO_ROOT/dev/daily/$DATE.md" \
  | tee -a "$LOG_FILE"
