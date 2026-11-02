#!/bin/sh
# session_brief.sh -- session ramp-up and handoff guard, run from Claude Code hooks.
#
# Usage:
#   session_brief.sh brief        SessionStart (startup|clear): prints the newest handoff
#                                 doc, main CI and the PR gate table, so a fresh session
#                                 starts briefed (.claude/rules/session-rampup.md steps 0-1).
#   session_brief.sh precompact   PreCompact: warns (never blocks) when no handoff doc is
#                                 dated today (America/Los_Angeles), so a /compact does not
#                                 stand in for the committed handoff.
#
# The newest doc is picked by the date in its file name, not by mtime: a fresh checkout,
# worktree or cloud clone stamps every file with the checkout time.
#
# Environment (for tests and offline use):
#   SESSION_BRIEF_NOTES_DIR  where the next-session-priorities-*.md docs live
#                            (default: <repo>/dev/notes)
#   SESSION_BRIEF_TODAY      YYYY-MM-DD to treat as today (default: today in Los Angeles)
#   SESSION_BRIEF_OFFLINE=1  skip the gh calls (main CI, PR gate table)
#   SESSION_BRIEF_MAX_LINES  cap on doc lines printed (default 150)
#
# Always exits 0: a hook failure must never block a session start or a compaction.

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NOTES_DIR=${SESSION_BRIEF_NOTES_DIR:-$REPO_ROOT/dev/notes}
TODAY=${SESSION_BRIEF_TODAY:-$(TZ=America/Los_Angeles date +%Y-%m-%d)}
MAX_LINES=${SESSION_BRIEF_MAX_LINES:-150}
STALE_DAYS=3

# Newest handoff doc by the date in its name; empty when there is none.
_newest_doc() {
  ls "$NOTES_DIR"/next-session-priorities-*.md 2>/dev/null | sort | tail -1
}

# YYYY-MM-DD from a doc path.
_doc_date() {
  basename "$1" .md | sed 's/^next-session-priorities-//' | cut -c1-10
}

# Whole days from date $1 to date $2 (both YYYY-MM-DD); empty if either fails to parse.
_days_between() {
  a=$(date -j -f %Y-%m-%d "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null) || return 0
  b=$(date -j -f %Y-%m-%d "$2" +%s 2>/dev/null || date -d "$2" +%s 2>/dev/null) || return 0
  echo $(( (b - a) / 86400 ))
}

_brief() {
  doc=$(_newest_doc)
  echo "=== Session brief (dev/scripts/session_brief.sh) ==="
  if [ -z "$doc" ]; then
    echo "No next-session-priorities doc found in $NOTES_DIR."
  else
    d=$(_doc_date "$doc")
    age=$(_days_between "$d" "$TODAY")
    echo "Newest handoff: ${doc#"$REPO_ROOT"/} (dated $d, ${age:-?} day(s) old)"
    if [ -n "$age" ] && [ "$age" -gt "$STALE_DAYS" ]; then
      echo "WARNING: handoff is stale (> $STALE_DAYS days). Verify its claims against main and GitHub before acting on it."
    fi
  fi
  if [ "${SESSION_BRIEF_OFFLINE:-}" != "1" ] && command -v gh >/dev/null 2>&1; then
    echo
    echo "--- main CI (latest CI run) ---"
    gh run list --branch main --workflow CI --limit 1 \
      --json status,conclusion,headSha \
      --jq '.[] | "\(.status) \(.conclusion) \(.headSha[0:9])"' 2>/dev/null \
      || echo "(gh unavailable)"
    if [ -f "$REPO_ROOT/dev/scripts/pr_gate_status.sh" ]; then
      echo
      echo "--- open PRs (pr_gate_status.sh) ---"
      sh "$REPO_ROOT/dev/scripts/pr_gate_status.sh" 2>/dev/null || echo "(pr_gate_status.sh failed)"
    fi
  fi
  if [ -n "$doc" ]; then
    echo
    echo "--- ${doc#"$REPO_ROOT"/} ---"
    head -n "$MAX_LINES" "$doc"
  fi
}

_precompact() {
  doc=$(_newest_doc)
  d=""
  [ -n "$doc" ] && d=$(_doc_date "$doc")
  if [ "$d" = "$TODAY" ]; then
    exit 0
  fi
  msg="No handoff dated $TODAY (newest: ${d:-none}). Compaction keeps this session going, but the next session reads dev/notes/next-session-priorities-<date>.md. Write it if the plan changed."
  printf '{"systemMessage": "%s"}\n' "$msg"
}

case "${1:-}" in
  brief) _brief ;;
  precompact) _precompact ;;
  *) echo "usage: session_brief.sh brief|precompact" >&2 ;;
esac
exit 0
