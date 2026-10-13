#!/bin/sh
# agent_standing_rules_check_test.sh -- the check passes on the real
# .claude/agents/ and fails, naming the agent and the rule, when one rule is
# deleted from one definition (issue #2738). Runs against a temp copy.
set -eu
. "$(dirname "$0")/_check_lib.sh"
ROOT="$(repo_root)"
CHECK="$(dirname "$0")/agent_standing_rules_check.sh"
sh "$CHECK" "$ROOT" >/dev/null || { echo "FAIL: check fails on the real agents" >&2; exit 1; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude"
cp -R "$ROOT/.claude/agents" "$TMP/.claude/agents"
grep -vF 'Never end with an unpushed commit.' "$ROOT/.claude/agents/feat-data.md" >"$TMP/.claude/agents/feat-data.md"
if OUT=$(sh "$CHECK" "$TMP" 2>&1); then
  echo "FAIL: check passed with a rule deleted from feat-data.md" >&2; exit 1
fi
case "$OUT" in
  *"FAIL: feat-data: standing rule missing: Never end with an unpushed commit."*) ;;
  *) echo "FAIL: check did not name the agent and rule: $OUT" >&2; exit 1 ;;
esac
echo "agent_standing_rules_check_test: all passed"
