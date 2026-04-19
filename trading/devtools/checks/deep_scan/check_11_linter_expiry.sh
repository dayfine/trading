#!/bin/sh
# Check 11: Linter Exception Expiry vs milestone/date (T1-K).
#
# Usage: sh check_11_linter_expiry.sh <report_file> [findings_file]
#
# linter_exceptions.conf entries carry "# review_at: <value>" annotations.
# This check surfaces entries whose review point has passed so they can
# be retired or re-evaluated.
#
# Two kinds of review_at values:
#   Milestone (M1..M7): surface if <= current milestone from
#     docs/design/weinstein-trading-system-v2.md.
#     If that doc has no current-milestone marker, emit a parse warning
#     and surface all milestone-pinned entries for manual review.
#   Date (YYYY-MM-DD): surface if the date < today.
#
# Entries with no review_at annotation are a policy violation (T1-K) —
# flagged separately as "Missing review_at".
#
# Severity: WARNING (human reviews; not a blocking failure).
# The ## Linter Exception Expiry section is always emitted in the report.

set -e

REPORT_FILE="${1:?Usage: check_11_linter_expiry.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 11: Linter Exception Expiry
# ────────────────────────────────────────────────────────────────

EXPIRY_CONF="${TRADING_DIR}/devtools/checks/linter_exceptions.conf"
EXPIRY_DETAILS=""
EXPIRY_MISSING=""
EXPIRY_COUNT=0
EXPIRY_MISSING_COUNT=0

# Determine the current milestone from the design doc.
# Look for lines like "**Current milestone:** M3" or "Current milestone: M4".
# If absent, CURRENT_MILESTONE is empty — we treat that as "unknown".
SYSTEM_DESIGN="${REPO_ROOT}/docs/design/weinstein-trading-system-v2.md"
CURRENT_MILESTONE=""
MILESTONE_PARSE_WARN=""

if [ -f "$SYSTEM_DESIGN" ]; then
  # Try several patterns, take the first match.
  for pattern in \
      'current milestone:' \
      '\*\*current milestone:\*\*' \
      '## current milestone' \
      'current_milestone:'; do
    line="$(grep -i "$pattern" "$SYSTEM_DESIGN" 2>/dev/null | head -1 || true)"
    if [ -n "$line" ]; then
      # Extract the milestone token (M1..M7)
      milestone_tok="$(echo "$line" | grep -o 'M[1-7]' | head -1 || true)"
      if [ -n "$milestone_tok" ]; then
        CURRENT_MILESTONE="$milestone_tok"
        break
      fi
    fi
  done

  if [ -z "$CURRENT_MILESTONE" ]; then
    MILESTONE_PARSE_WARN="Could not determine current milestone from docs/design/weinstein-trading-system-v2.md (no 'Current milestone:' line found). Milestone-pinned exceptions cannot be evaluated automatically — listing all of them for manual review."
    add_warning "Linter exception expiry: $MILESTONE_PARSE_WARN"
  fi
else
  MILESTONE_PARSE_WARN="Design doc docs/design/weinstein-trading-system-v2.md not found — cannot evaluate milestone-pinned exceptions."
  add_warning "Linter exception expiry: $MILESTONE_PARSE_WARN"
fi

# Numeric milestone value for comparisons (M1=1 .. M7=7).
# 0 = unknown (parse failed).
_milestone_num() {
  case "$1" in
    M1) echo 1 ;; M2) echo 2 ;; M3) echo 3 ;; M4) echo 4 ;;
    M5) echo 5 ;; M6) echo 6 ;; M7) echo 7 ;; *) echo 0 ;;
  esac
}

CURRENT_MILESTONE_NUM="$(_milestone_num "$CURRENT_MILESTONE")"

# Process linter_exceptions.conf line by line.
if [ -f "$EXPIRY_CONF" ]; then
  while IFS= read -r raw_line; do
    # Skip empty lines and comment-only lines (lines starting with #)
    stripped="$(echo "$raw_line" | sed 's/^[[:space:]]*//')"
    case "$stripped" in
      ''|'#'*) continue ;;
    esac

    # This is an active exception entry. Extract the review_at annotation.
    review_at_val=""
    if echo "$raw_line" | grep -q '# review_at:'; then
      review_at_val="$(echo "$raw_line" | sed 's/.*# review_at:[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    fi

    if [ -z "$review_at_val" ]; then
      # Missing review_at annotation — policy violation.
      EXPIRY_MISSING_COUNT=$((EXPIRY_MISSING_COUNT + 1))
      # Strip the trailing comment to get the exception declaration for display.
      decl="$(echo "$raw_line" | sed 's/#.*//' | sed 's/[[:space:]]*$//')"
      EXPIRY_MISSING="${EXPIRY_MISSING}  - Missing review_at on: ${decl}\n"
      continue
    fi

    # Skip "never" review_at values — these are intentionally permanent.
    case "$review_at_val" in
      never*) continue ;;
    esac

    # Build a display-friendly label for this entry.
    decl="$(echo "$raw_line" | sed 's/#.*//' | sed 's/[[:space:]]*$//')"
    entry_label="${decl} (review_at: ${review_at_val})"

    # Check if the review_at value contains a milestone token (M1..M7).
    # This handles both bare "M5" and descriptive phrases like
    # "after simulation (M5)" — any value containing a milestone token
    # is treated as milestone-pinned.
    entry_milestone="$(echo "$review_at_val" | grep -o 'M[1-7]' | head -1 || true)"

    if [ -n "$entry_milestone" ]; then
      # Milestone comparison.
      entry_milestone_num="$(_milestone_num "$entry_milestone")"
      if [ "$CURRENT_MILESTONE_NUM" -eq 0 ]; then
        # Cannot determine current milestone — surface for manual review.
        EXPIRY_COUNT=$((EXPIRY_COUNT + 1))
        EXPIRY_DETAILS="${EXPIRY_DETAILS}  - [MANUAL REVIEW — milestone unknown] ${entry_label}\n"
        add_warning "Linter exception expiry (milestone unknown): ${decl} pinned to ${entry_milestone} — cannot auto-compare; review manually"
      elif [ "$entry_milestone_num" -le "$CURRENT_MILESTONE_NUM" ]; then
        # Entry's milestone has landed.
        EXPIRY_COUNT=$((EXPIRY_COUNT + 1))
        EXPIRY_DETAILS="${EXPIRY_DETAILS}  - [EXPIRED] ${entry_label} — ${entry_milestone} <= current milestone ${CURRENT_MILESTONE}\n"
        add_warning "Linter exception expiry: ${decl} was due for review at ${entry_milestone} (current: ${CURRENT_MILESTONE}) — retire or re-annotate"
      fi
      # else: milestone is in the future — no finding.

    elif echo "$review_at_val" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
      # Date comparison.
      review_date="$(echo "$review_at_val" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
      if [ "$review_date" \< "$TODAY" ]; then
        EXPIRY_COUNT=$((EXPIRY_COUNT + 1))
        EXPIRY_DETAILS="${EXPIRY_DETAILS}  - [EXPIRED] ${entry_label} — review date ${review_date} has passed (today: ${TODAY})\n"
        add_warning "Linter exception expiry: ${decl} review date ${review_date} has passed — retire or re-annotate"
      fi
      # else: future date — no finding.

    else
      # Unrecognized review_at format — surface for manual review.
      EXPIRY_COUNT=$((EXPIRY_COUNT + 1))
      EXPIRY_DETAILS="${EXPIRY_DETAILS}  - [UNRECOGNISED format] ${entry_label} — review_at value not a milestone (M1-M7) or date (YYYY-MM-DD)\n"
      add_warning "Linter exception expiry: ${decl} has unrecognised review_at format: ${review_at_val}"
    fi

  done < "$EXPIRY_CONF"
else
  add_warning "Linter exception expiry: trading/devtools/checks/linter_exceptions.conf not found — cannot check exception policy"
fi

add_metric EXPIRY_COUNT "$EXPIRY_COUNT"
add_metric EXPIRY_MISSING_COUNT "$EXPIRY_MISSING_COUNT"
flush_findings

# Always emit the Linter Exception Expiry section (Check 11).
{
  printf "\n## Linter Exception Expiry\n\n"
  printf "Checks trading/devtools/checks/linter_exceptions.conf entries against\n"
  printf "current milestone and today's date. Policy (T1-K): every entry must carry\n"
  printf "a '# review_at:' annotation; expired entries should be retired or re-annotated.\n\n"

  if [ -n "$MILESTONE_PARSE_WARN" ]; then
    printf "Parse warning: %s\n\n" "$MILESTONE_PARSE_WARN"
  else
    printf "Current milestone: %s  Today: %s\n\n" "$CURRENT_MILESTONE" "$TODAY"
  fi

  if [ "$EXPIRY_COUNT" -eq 0 ] && [ "$EXPIRY_MISSING_COUNT" -eq 0 ]; then
    printf "No expired or missing review_at annotations found.\n"
  else
    if [ "$EXPIRY_COUNT" -gt 0 ]; then
      printf "### Expired or due-for-review entries (%d)\n\n" "$EXPIRY_COUNT"
      printf '%b' "$EXPIRY_DETAILS"
      printf "\n"
    fi
    if [ "$EXPIRY_MISSING_COUNT" -gt 0 ]; then
      printf "### Missing review_at annotation — policy violation T1-K (%d)\n\n" "$EXPIRY_MISSING_COUNT"
      printf "These entries have no '# review_at:' comment. Add one before the next deep scan.\n\n"
      printf '%b' "$EXPIRY_MISSING"
      printf "\n"
    fi
  fi
} >> "$REPORT_FILE"
