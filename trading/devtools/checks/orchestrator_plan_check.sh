#!/bin/sh
# Structural smoke test for lead-orchestrator plan mode.
#
# We deliberately do NOT invoke `claude -p` from dune runtest:
#   - `claude -p` requires credentials and network access which aren't
#     available in CI or the hermetic dune sandbox.
#   - A real invocation would be slow (tens of seconds minimum) and flaky
#     compared to the rest of the check suite.
#
# Instead, verify the agent definition itself has the plan-mode contract
# the runner relies on. If any required piece drifts out, this fails fast.
#
# Required pieces in .claude/agents/lead-orchestrator.md:
#   - a `## Plan Mode` section
#   - mentions the `--plan` trigger token
#   - mentions the `dev/daily/<YYYY-MM-DD>-plan.md` output path
#   - mentions the `(plan mode)` header marker
#   - mentions `## Harness Work` somewhere in the file (the daily-summary
#     section heading plan-mode output is expected to include)

set -e

. "$(dirname "$0")/_check_lib.sh"

AGENT="$(repo_root)/.claude/agents/lead-orchestrator.md"
[ -f "$AGENT" ] || die "orchestrator_plan_check: $AGENT does not exist"

fail() {
  echo "FAIL: orchestrator_plan_check — $1" >&2
  exit 1
}

grep -qF '## Plan Mode' "$AGENT" \
  || fail "lead-orchestrator.md missing '## Plan Mode' section"
grep -qF -- '--plan' "$AGENT" \
  || fail "lead-orchestrator.md Plan Mode does not mention '--plan' trigger"
grep -qF -- '-plan.md' "$AGENT" \
  || fail "lead-orchestrator.md Plan Mode does not document '-plan.md' output path"
grep -qF '(plan mode)' "$AGENT" \
  || fail "lead-orchestrator.md Plan Mode does not document '(plan mode)' header marker"
grep -qF '## Harness Work' "$AGENT" \
  || fail "lead-orchestrator.md missing '## Harness Work' section heading"

echo "OK: lead-orchestrator plan mode contract present."
