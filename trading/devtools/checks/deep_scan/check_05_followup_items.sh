#!/bin/sh
# Check 5: Follow-up item count (from status files).
#
# Usage: sh check_05_followup_items.sh <report_file> [findings_file]
#
# This check also exports FOLLOWUP_PER_FILE data to a sidecar file
# at <findings_file>.followup so Check 8 (trends) can read it.
# When run standalone, FOLLOWUP_PER_FILE data is written to
# <report_file>.followup for downstream use.

set -e

REPORT_FILE="${1:?Usage: check_05_followup_items.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 5: Follow-up item count (from status files)
# ────────────────────────────────────────────────────────────────

FOLLOWUP_COUNT=0
# FOLLOWUP_PER_FILE accumulates lines of the form "file:count" for Check 8 Trends.
FOLLOWUP_PER_FILE=""
for status_file in "${REPO_ROOT}"/dev/status/*.md; do
  [ -f "$status_file" ] || continue
  file_count=0
  # Count lines starting with "- " under ## Follow-up or ## Followup sections
  in_followup=false
  while IFS= read -r line; do
    case "$line" in
      "## Follow-up"*|"## Followup"*)
        in_followup=true
        continue
        ;;
      "## "*)
        in_followup=false
        continue
        ;;
    esac
    if $in_followup; then
      case "$line" in
        "- "*)
          # Skip struck-through items (~~text~~)
          if echo "$line" | grep -q '^- ~~.*~~'; then
            continue
          fi
          FOLLOWUP_COUNT=$((FOLLOWUP_COUNT + 1))
          file_count=$((file_count + 1))
          ;;
      esac
    fi
  done < "$status_file"
  if [ "$file_count" -gt 0 ]; then
    fname="$(basename "$status_file")"
    FOLLOWUP_PER_FILE="${FOLLOWUP_PER_FILE}${fname}:${file_count}\n"
  fi
done

if [ "$FOLLOWUP_COUNT" -gt 10 ]; then
  add_warning "Follow-up accumulation: ${FOLLOWUP_COUNT} open items across status files (threshold: 10)"
elif [ "$FOLLOWUP_COUNT" -gt 0 ]; then
  add_info "Follow-up items: ${FOLLOWUP_COUNT} total across status files"
fi

add_metric FOLLOWUP_COUNT "$FOLLOWUP_COUNT"
flush_findings

# Export per-file data for Check 8 Trends to read.
# Written to <findings_file>.followup or <report_file>.followup.
FOLLOWUP_SIDECAR="${FINDINGS_FILE:-"$REPORT_FILE"}.followup"
if [ -n "$FOLLOWUP_PER_FILE" ]; then
  printf '%b' "$FOLLOWUP_PER_FILE" > "$FOLLOWUP_SIDECAR"
else
  : > "$FOLLOWUP_SIDECAR"
fi
