# Pre-flight checks for any script that invokes the lead-orchestrator via
# `claude -p`. Source this; on failure it prints `FAIL: ...` to stderr and
# exits non-zero so the caller dies at the shell, not silently inside the
# orchestrator.
#
# Required environment when sourcing:
#   REPO_ROOT — absolute path to the repo root (the script's caller sets this).
#
# Checks:
#   1. claude binary on PATH
#   2. lead-orchestrator agent definition exists at the expected location
#   3. agent definition has a ## Allowed Tools section
#   4. that section mentions the Agent tool (catches silent toolset drift)

: "${REPO_ROOT:?preflight.sh: REPO_ROOT must be set by the caller}"

_orch_def="$REPO_ROOT/.claude/agents/lead-orchestrator.md"

command -v claude >/dev/null \
  || { echo "FAIL: claude CLI not found on PATH" >&2; exit 1; }

[ -f "$_orch_def" ] \
  || { echo "FAIL: agent definition missing at $_orch_def" >&2; exit 1; }

grep -q '^## Allowed Tools' "$_orch_def" \
  || { echo "FAIL: lead-orchestrator missing '## Allowed Tools' section" >&2; exit 1; }

awk '/^## Allowed Tools/{f=1; next} /^## /{f=0} f' "$_orch_def" \
  | grep -q 'Agent' \
  || { echo "FAIL: lead-orchestrator '## Allowed Tools' does not list Agent" >&2; exit 1; }

if ! command -v jq >/dev/null; then
  echo "WARN: jq not found — stream events will pass through unformatted" >&2
fi
