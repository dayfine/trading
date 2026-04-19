#!/bin/sh
# Check 10: Status file template enforcement.
#
# Usage: sh check_10_status_template.sh <report_file> [findings_file]
#
# The dev/status/*.md template explicitly forbids a ## Recent Commits
# section — that content drifts and belongs in git log, not a status file.
# Any status file that still contains this heading is in violation.
#
# Findings are WARNINGs (template violation; easy fix: delete the section).
# The check greps for the heading anchored to the start of the line so
# it only fires on actual markdown headings, not inline mentions.
# The ## Status File Template section is always emitted in the report.

set -e

REPORT_FILE="${1:?Usage: check_10_status_template.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 10: Status file template enforcement
# ────────────────────────────────────────────────────────────────

RECENT_COMMITS_DETAILS=""
RECENT_COMMITS_COUNT=0

for status_file in "${REPO_ROOT}"/dev/status/*.md; do
  [ -f "$status_file" ] || continue
  # Grep for the forbidden heading at line start
  matches="$(grep -n '^## Recent Commits' "$status_file" 2>/dev/null || true)"
  if [ -n "$matches" ]; then
    fname="$(basename "$status_file")"
    while IFS= read -r match_line; do
      [ -z "$match_line" ] && continue
      RECENT_COMMITS_COUNT=$((RECENT_COMMITS_COUNT + 1))
      lineno="$(echo "$match_line" | cut -d: -f1)"
      add_warning "Status file template violation: \`dev/status/${fname}\` line ${lineno} contains forbidden '## Recent Commits' heading — delete this section"
      RECENT_COMMITS_DETAILS="${RECENT_COMMITS_DETAILS}  - \`dev/status/${fname}\`: line ${lineno} — forbidden '## Recent Commits' heading\n"
    done << RCEOF
${matches}
RCEOF
  fi
done

add_metric RECENT_COMMITS_COUNT "$RECENT_COMMITS_COUNT"
flush_findings

# Always emit the Status File Template section (Check 10).
{
  printf "\n## Status File Template\n\n"
  printf "Checks dev/status/*.md for the forbidden '## Recent Commits' heading.\n"
  printf "The template requires omitting this section (content drifts; use git log instead).\n\n"
  if [ "$RECENT_COMMITS_COUNT" -eq 0 ]; then
    printf "No violations found.\n"
  else
    printf "**${RECENT_COMMITS_COUNT} violation(s):**\n\n"
    printf '%b' "$RECENT_COMMITS_DETAILS"
  fi
} >> "$REPORT_FILE"
