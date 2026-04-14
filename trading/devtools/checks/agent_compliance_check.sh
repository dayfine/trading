#!/bin/sh
# Agent definition compliance check.
#
# Rule: every feat-*.md agent definition (except the template) must contain
# the three required structural sections defined in feat-agent-template.md:
#   - ## Acceptance Checklist
#   - ## Max-Iterations Policy
#   - ## Allowed Tools
#
# This check is fast (grep-only, no build) and runs as part of dune runtest.

set -e

# Resolve the repo root via git. Works from dune's sandboxed copy of this
# script because git walks up from cwd (which is inside the repo) regardless
# of where the script file itself lives. The previous `$(dirname "$0")/...`
# path expression was brittle — three levels up was correct when the script
# ran in-place but wrong from dune's sandbox, and the silent-zero result
# meant the compliance check passed vacuously for its entire lifetime.
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "FAIL: agent_compliance_check could not locate repo root (git rev-parse failed)"
  exit 1
}

AGENTS_DIR="$REPO_ROOT/.claude/agents"
[ -d "$AGENTS_DIR" ] || {
  echo "FAIL: agent_compliance_check: $AGENTS_DIR does not exist"
  exit 1
}

GLOB_MATCHED=0
CHECKED=0
VIOLATIONS=""

for f in "$AGENTS_DIR"/feat-*.md; do
  [ -f "$f" ] || continue
  GLOB_MATCHED=$((GLOB_MATCHED + 1))
  name=$(basename "$f")
  # Skip the template itself — it describes the required sections, not an agent
  [ "$name" = "feat-agent-template.md" ] && continue
  CHECKED=$((CHECKED + 1))

  for section in "## Acceptance Checklist" "## Max-Iterations Policy" "## Allowed Tools"; do
    if ! grep -qF "$section" "$f"; then
      VIOLATIONS="${VIOLATIONS}${f}: missing section '${section}'\n"
    fi
  done
done

# Defensive: if the glob matched zero feat-*.md files, something is wrong
# with the directory resolution — fail loud rather than pass vacuously.
if [ "$GLOB_MATCHED" -eq 0 ]; then
  echo "FAIL: agent_compliance_check found zero feat-*.md files at $AGENTS_DIR"
  exit 1
fi

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: agent definition compliance check — required sections missing."
  echo "See .claude/agents/feat-agent-template.md for the required structure."
  echo ""
  printf '%b' "$VIOLATIONS"
  exit 1
fi

echo "OK: all feat-*.md agent definitions contain required sections (checked $CHECKED)."
