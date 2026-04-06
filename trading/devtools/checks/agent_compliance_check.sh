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

AGENTS_DIR="$(dirname "$0")/../../../.claude/agents"
VIOLATIONS=""

for f in "$AGENTS_DIR"/feat-*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  # Skip the template itself — it describes the required sections, not an agent
  [ "$name" = "feat-agent-template.md" ] && continue

  for section in "## Acceptance Checklist" "## Max-Iterations Policy" "## Allowed Tools"; do
    if ! grep -qF "$section" "$f"; then
      VIOLATIONS="${VIOLATIONS}${f}: missing section '${section}'\n"
    fi
  done
done

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: agent definition compliance check — required sections missing."
  echo "See .claude/agents/feat-agent-template.md for the required structure."
  echo ""
  printf '%b' "$VIOLATIONS"
  exit 1
fi

echo "OK: all feat-*.md agent definitions contain required sections."
