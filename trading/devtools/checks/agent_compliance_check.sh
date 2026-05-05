#!/bin/sh
# Agent definition compliance check.
#
# Rule 1: every feat-*.md agent definition (except the template) must contain
# the three required structural sections defined in feat-agent-template.md:
#   - ## Acceptance Checklist
#   - ## Max-Iterations Policy
#   - ## Allowed Tools
#
# Rule 2: every jj-writing agent (feat-*.md except template, harness-maintainer.md,
# ops-data.md) must also contain:
#   - ## Pre-Work Setup
#
# Read-only agents (qc-structural, qc-behavioral, health-scanner, track-pacer,
# lead-orchestrator, code-health) are exempt from Rule 2 — they never write to
# the VCS so workspace isolation is not required.
#
# This check is fast (grep-only, no build) and runs as part of dune runtest.

set -e

. "$(dirname "$0")/_check_lib.sh"

AGENTS_DIR="$(repo_root)/.claude/agents"
[ -d "$AGENTS_DIR" ] || die "agent_compliance_check: $AGENTS_DIR does not exist"

# --- Rule 1: feat-* agents (three core sections) ---

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
# (This was the exact bug the pre-library version had: \$(dirname \$0)/../../../
# resolved to a non-existent directory under dune's sandbox, the glob never
# matched, and the check printed OK forever.)
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

# --- Rule 2: jj-writing agents must have ## Pre-Work Setup ---
# Agents that write to the VCS need workspace isolation boilerplate.
# Skip list: read-only QC and orchestration agents.

SKIP_PREWORK="qc-structural.md qc-behavioral.md health-scanner.md track-pacer.md lead-orchestrator.md code-health.md"

PREWORK_CHECKED=0
PREWORK_VIOLATIONS=""

# Check feat-*.md (excluding template — already skipped above)
for f in "$AGENTS_DIR"/feat-*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  [ "$name" = "feat-agent-template.md" ] && continue

  # skip read-only agents (none expected to match feat-*, but guard anyway)
  skip=0
  for s in $SKIP_PREWORK; do [ "$name" = "$s" ] && skip=1 && break; done
  [ "$skip" -eq 1 ] && continue

  PREWORK_CHECKED=$((PREWORK_CHECKED + 1))
  if ! grep -qF "## Pre-Work Setup" "$f"; then
    PREWORK_VIOLATIONS="${PREWORK_VIOLATIONS}${f}: missing section '## Pre-Work Setup'\n"
  fi
done

# Check harness-maintainer.md and ops-data.md explicitly
for name in harness-maintainer.md ops-data.md; do
  f="$AGENTS_DIR/$name"
  [ -f "$f" ] || continue
  PREWORK_CHECKED=$((PREWORK_CHECKED + 1))
  if ! grep -qF "## Pre-Work Setup" "$f"; then
    PREWORK_VIOLATIONS="${PREWORK_VIOLATIONS}${f}: missing section '## Pre-Work Setup'\n"
  fi
done

if [ -n "$PREWORK_VIOLATIONS" ]; then
  echo "FAIL: jj-writing agent compliance check — ## Pre-Work Setup section missing."
  echo "See .claude/agents/feat-agent-template.md §\"Pre-Work Setup\" for the required boilerplate."
  echo ""
  printf '%b' "$PREWORK_VIOLATIONS"
  exit 1
fi

echo "OK: agent compliance — ${PREWORK_CHECKED} feat-* / harness / ops-data files have ## Pre-Work Setup."
