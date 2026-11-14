#!/bin/sh
# agent_standing_rules_check_test.sh -- the check passes on the real
# .claude/agents/ and fails, naming the agent and the rule, when one rule is
# deleted from one definition (issue #2738), when a build agent's definition
# regains a retired local-`dune runtest` rule (user decision 2026-11-14), or
# when a rule is deleted from the one agent that owns it. It keeps passing when
# a QC agent mentions `dune runtest`: QC agents keep their own rules. Every case
# runs against a temp copy.
set -eu
. "$(dirname "$0")/_check_lib.sh"
ROOT="$(repo_root)"
CHECK="$(dirname "$0")/agent_standing_rules_check.sh"
sh "$CHECK" "$ROOT" >/dev/null || { echo "FAIL: check fails on the real agents" >&2; exit 1; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fresh_copy() { # a clean temp copy of the real agents
  rm -rf "$TMP/.claude"
  mkdir -p "$TMP/.claude"
  cp -R "$ROOT/.claude/agents" "$TMP/.claude/agents"
}

expect_fail() { # label, expected stderr line (the check must fail and print it)
  if OUT=$(sh "$CHECK" "$TMP" 2>&1); then
    echo "FAIL: check passed: $1" >&2; exit 1
  fi
  case "$OUT" in
    *"$2"*) ;;
    *) echo "FAIL: $1: expected [$2], got: $OUT" >&2; exit 1 ;;
  esac
}

# 1. A standing rule deleted from one definition is named, with its agent.
fresh_copy
grep -vF 'Never end with an unpushed commit.' "$ROOT/.claude/agents/feat-data.md" >"$TMP/.claude/agents/feat-data.md"
expect_fail "rule deleted from feat-data.md" \
  "FAIL: feat-data: standing rule missing: Never end with an unpushed commit."

# 2. The tests-on-CI rule deleted from a build agent is named.
fresh_copy
grep -vF 'Tests run on CI, not locally' "$ROOT/.claude/agents/feat-weinstein.md" >"$TMP/.claude/agents/feat-weinstein.md"
expect_fail "tests-on-CI rule deleted from feat-weinstein.md" \
  "FAIL: feat-weinstein: standing rule missing: Tests run on CI, not locally"

# 3. A retired local-runtest gate coming back is named, in each place it used to live.
for retired in \
  'Full gates (`dune build @fmt && dune build && dune runtest`) before the commit.' \
  'Run `dune runtest <dir>` before you push.' \
  '- [ ] `dune build && dune runtest` passes' \
  'If after **3 consecutive build-fix cycles** `dune build && dune runtest` is still failing' \
  'Read, Write, Edit, Glob, Grep, Bash (build/test commands only).'
do
  fresh_copy
  printf '%s\n' "$retired" >>"$TMP/.claude/agents/code-health.md"
  expect_fail "retired rule re-added to code-health.md: $retired" \
    "FAIL: code-health: retired rule still present:"
done

# 4. Rules owned by one agent are pinned in that agent.
fresh_copy
grep -vF 'run it directly with `sh <script>`' "$ROOT/.claude/agents/harness-maintainer.md" >"$TMP/.claude/agents/harness-maintainer.md"
expect_fail "script exception deleted from harness-maintainer.md" \
  "FAIL: harness-maintainer: standing rule missing: run it directly with"
fresh_copy
grep -vF 'run it directly (`sh trading/devtools/checks/<linter>.sh`' "$ROOT/.claude/agents/code-health.md" >"$TMP/.claude/agents/code-health.md"
expect_fail "linter exception deleted from code-health.md" \
  "FAIL: code-health: standing rule missing: run it directly ("

# 5. QC agents keep their own rules: a runtest mention there is not a violation.
fresh_copy
printf '%s\n' '- [ ] `dune build && dune runtest` passes' >>"$TMP/.claude/agents/qc-structural.md"
sh "$CHECK" "$TMP" >/dev/null 2>&1 || { echo "FAIL: check rejected a runtest mention in qc-structural.md" >&2; exit 1; }

echo "agent_standing_rules_check_test: all passed"
