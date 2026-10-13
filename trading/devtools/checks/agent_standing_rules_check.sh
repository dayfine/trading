#!/bin/sh
# agent_standing_rules_check.sh -- pin the "Standing rules" block in the
# dispatched agents' definitions (issue #2738).
#
# Why: dispatch briefs used to restate the same boilerplate (~3.8 KB each,
# 118 briefs in one session, dev/notes/token-usage-audit-2026-09-08.md). That
# boilerplate now lives once in each .claude/agents/<name>.md, the dispatched
# agent's system prompt, so a brief carries only the task. The move is safe
# only while every definition still carries the rules a brief no longer
# repeats; this check fails when one goes missing.
#
# usage: sh agent_standing_rules_check.sh [ROOT]   (ROOT defaults to the repo root)
set -eu
. "$(dirname "$0")/_check_lib.sh"
ROOT=${1:-$(repo_root)}
AGENTS="$ROOT/.claude/agents"

QC_BUILD="qc-structural qc-behavioral"
QC_ALL="qc-structural qc-behavioral qc-results"
FEAT="feat-backtest feat-data feat-weinstein harness-maintainer code-health feat-agent-template"

FAILED=0
need() { # agent, fixed string
  f="$AGENTS/$1.md"
  if [ ! -f "$f" ]; then
    echo "FAIL: $1: $f not found" >&2; FAILED=$((FAILED + 1)); return 0
  fi
  if ! grep -qF -- "$2" "$f"; then
    echo "FAIL: $1: standing rule missing: $2" >&2; FAILED=$((FAILED + 1))
  fi
}

for a in $QC_ALL $FEAT; do
  need "$a" "## Standing rules — the dispatch brief does not repeat these"
  need "$a" "<!-- standing-rules (#2738)"
done
for a in $QC_BUILD $FEAT; do
  need "$a" "timeout: 600000"
  need "$a" "Never background a build and end the turn"
  need "$a" 'Never `cd /workspaces/trading-1/trading`'
  need "$a" 'On GHA (`$TRADING_IN_CONTAINER=1`) you are already inside the'
done
for a in $QC_BUILD; do
  need "$a" 'git fetch origin pull/<N>/head && git worktree add --detach'
done
for a in $QC_ALL; do
  need "$a" 'Line 1 is `Reviewed SHA: <full sha>`'
  need "$a" '`## Verdict` sits on its own line'
  need "$a" "Post first, then verify"
done
need qc-results "No dune, no container."
for a in $FEAT; do
  need "$a" "Never end with an unpushed commit."
  need "$a" 'Never edit `dev/status/_index.md`'
  need "$a" "exception is the row for a brand-new tracked work item"
done

[ "$FAILED" = 0 ] || exit 1
echo "agent_standing_rules_check: all agent definitions carry their standing rules"
