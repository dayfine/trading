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
#
# Also scans universe_deps_exceptions.conf (H-CHECK-CACHE-BLIND guard's
# own exceptions file, extended with a mandatory "# review_at:" field per
# the #2148 FLAG-1 residual — see .claude/rules/code-health-discipline.md)
# and adapter_effectiveness_exceptions.conf (the silent-null config-thread
# guard's own exceptions file, issue #2567 — wired in by PR #2585 rework
# after review found the file's `review_at` dates were decorative: nothing
# scanned it, so an expired date never surfaced. See BQ-1 in
# dev/reviews/harness-2567-2585.md and the corrected note in
# dev/plans/silent-null-effectiveness-2026-08-28.md §Risks). All three conf
# files share this check's date/milestone-expiry logic via the
# _scan_exceptions_conf() function below; each conf file's own per-PR guard
# (check_universe_deps.sh, adapter_effectiveness_check.sh) separately
# enforces that every entry HAS a parseable review_at at all — this check
# only asks whether an already-present one has expired. Split rationale:
# presence/parseability is cheap and belongs on the per-PR hot path that
# adds new entries; expiry (has enough time passed to warrant a look) is a
# slower-moving signal that
# matches this weekly deep-scan's existing cadence and precedent.

set -e

REPORT_FILE="${1:?Usage: check_11_linter_expiry.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 11: Linter Exception Expiry
# ────────────────────────────────────────────────────────────────

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

# Scan one review_at-annotated exceptions conf file. Populates the globals
# _SCAN_COUNT / _SCAN_MISSING_COUNT / _SCAN_DETAILS / _SCAN_MISSING (reset
# on every call) so the caller can copy them into its own per-file
# accumulators right after the call returns.
#   $1 = path to the conf file
#   $2 = human label used in add_warning text (e.g. "Linter exception expiry")
_scan_exceptions_conf() {
  conf_path="$1"
  label="$2"
  _SCAN_COUNT=0
  _SCAN_MISSING_COUNT=0
  _SCAN_DETAILS=""
  _SCAN_MISSING=""

  [ -f "$conf_path" ] || {
    add_warning "${label}: $(basename "$conf_path") not found — cannot check exception policy"
    return 0
  }

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
      _SCAN_MISSING_COUNT=$((_SCAN_MISSING_COUNT + 1))
      # Strip the trailing comment to get the exception declaration for display.
      decl="$(echo "$raw_line" | sed 's/#.*//' | sed 's/[[:space:]]*$//')"
      _SCAN_MISSING="${_SCAN_MISSING}  - Missing review_at on: ${decl}\n"
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
        _SCAN_COUNT=$((_SCAN_COUNT + 1))
        _SCAN_DETAILS="${_SCAN_DETAILS}  - [MANUAL REVIEW — milestone unknown] ${entry_label}\n"
        add_warning "${label} (milestone unknown): ${decl} pinned to ${entry_milestone} — cannot auto-compare; review manually"
      elif [ "$entry_milestone_num" -le "$CURRENT_MILESTONE_NUM" ]; then
        # Entry's milestone has landed.
        _SCAN_COUNT=$((_SCAN_COUNT + 1))
        _SCAN_DETAILS="${_SCAN_DETAILS}  - [EXPIRED] ${entry_label} — ${entry_milestone} <= current milestone ${CURRENT_MILESTONE}\n"
        add_warning "${label}: ${decl} was due for review at ${entry_milestone} (current: ${CURRENT_MILESTONE}) — retire or re-annotate"
      fi
      # else: milestone is in the future — no finding.

    elif echo "$review_at_val" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
      # Date comparison.
      review_date="$(echo "$review_at_val" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
      if [ "$review_date" \< "$TODAY" ]; then
        _SCAN_COUNT=$((_SCAN_COUNT + 1))
        _SCAN_DETAILS="${_SCAN_DETAILS}  - [EXPIRED] ${entry_label} — review date ${review_date} has passed (today: ${TODAY})\n"
        add_warning "${label}: ${decl} review date ${review_date} has passed — retire or re-annotate"
      fi
      # else: future date — no finding.

    else
      # Unrecognized review_at format — surface for manual review.
      _SCAN_COUNT=$((_SCAN_COUNT + 1))
      _SCAN_DETAILS="${_SCAN_DETAILS}  - [UNRECOGNISED format] ${entry_label} — review_at value not a milestone (M1-M7) or date (YYYY-MM-DD)\n"
      add_warning "${label}: ${decl} has unrecognised review_at format: ${review_at_val}"
    fi

  done < "$conf_path"
}

# ── linter_exceptions.conf ─────────────────────────────────────────
_scan_exceptions_conf "${TRADING_DIR}/devtools/checks/linter_exceptions.conf" "Linter exception expiry"
EXPIRY_COUNT="$_SCAN_COUNT"
EXPIRY_MISSING_COUNT="$_SCAN_MISSING_COUNT"
EXPIRY_DETAILS="$_SCAN_DETAILS"
EXPIRY_MISSING="$_SCAN_MISSING"

# ── universe_deps_exceptions.conf (#2148 FLAG-1 residual) ──────────
_scan_exceptions_conf "${TRADING_DIR}/devtools/checks/universe_deps_exceptions.conf" "Universe-deps exception expiry"
UD_EXPIRY_COUNT="$_SCAN_COUNT"
UD_EXPIRY_MISSING_COUNT="$_SCAN_MISSING_COUNT"
UD_EXPIRY_DETAILS="$_SCAN_DETAILS"
UD_EXPIRY_MISSING="$_SCAN_MISSING"

# ── adapter_effectiveness_exceptions.conf (issue #2567 / BQ-1) ─────
_scan_exceptions_conf "${TRADING_DIR}/devtools/checks/adapter_effectiveness_exceptions.conf" "Adapter-effectiveness exception expiry"
AE_EXPIRY_COUNT="$_SCAN_COUNT"
AE_EXPIRY_MISSING_COUNT="$_SCAN_MISSING_COUNT"
AE_EXPIRY_DETAILS="$_SCAN_DETAILS"
AE_EXPIRY_MISSING="$_SCAN_MISSING"

add_metric EXPIRY_COUNT "$EXPIRY_COUNT"
add_metric EXPIRY_MISSING_COUNT "$EXPIRY_MISSING_COUNT"
add_metric UD_EXPIRY_COUNT "$UD_EXPIRY_COUNT"
add_metric UD_EXPIRY_MISSING_COUNT "$UD_EXPIRY_MISSING_COUNT"
add_metric AE_EXPIRY_COUNT "$AE_EXPIRY_COUNT"
add_metric AE_EXPIRY_MISSING_COUNT "$AE_EXPIRY_MISSING_COUNT"
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

  printf "\n## Universe-Deps Exception Expiry\n\n"
  printf "Checks trading/devtools/checks/universe_deps_exceptions.conf entries (the\n"
  printf "H-CHECK-CACHE-BLIND guard's exceptions list, #2148 FLAG-1) against current\n"
  printf "milestone and today's date, same policy and format as linter_exceptions.conf.\n"
  printf "check_universe_deps.sh (the per-PR guard) separately enforces that every\n"
  printf "entry HAS a parseable review_at at all; this section only reports whether an\n"
  printf "already-present one has expired.\n\n"

  if [ "$UD_EXPIRY_COUNT" -eq 0 ] && [ "$UD_EXPIRY_MISSING_COUNT" -eq 0 ]; then
    printf "No expired or missing review_at annotations found.\n"
  else
    if [ "$UD_EXPIRY_COUNT" -gt 0 ]; then
      printf "### Expired or due-for-review entries (%d)\n\n" "$UD_EXPIRY_COUNT"
      printf '%b' "$UD_EXPIRY_DETAILS"
      printf "\n"
    fi
    if [ "$UD_EXPIRY_MISSING_COUNT" -gt 0 ]; then
      printf "### Missing review_at annotation (%d)\n\n" "$UD_EXPIRY_MISSING_COUNT"
      printf "These entries have no '# review_at:' comment. check_universe_deps.sh\n"
      printf "should already be failing the build for these — if this section is\n"
      printf "non-empty, the per-PR guard's presence check has a bug.\n\n"
      printf '%b' "$UD_EXPIRY_MISSING"
      printf "\n"
    fi
  fi

  printf "\n## Adapter-Effectiveness Exception Expiry\n\n"
  printf "Checks trading/devtools/checks/adapter_effectiveness_exceptions.conf\n"
  printf "entries (the silent-null config-thread guard's exceptions list, issue\n"
  printf "#2567) against current milestone and today's date, same policy and\n"
  printf "format as linter_exceptions.conf. adapter_effectiveness_check.sh (the\n"
  printf "per-PR guard) separately enforces that every entry HAS a parseable\n"
  printf "review_at at all; this section only reports whether an already-present\n"
  printf "one has expired.\n\n"

  if [ "$AE_EXPIRY_COUNT" -eq 0 ] && [ "$AE_EXPIRY_MISSING_COUNT" -eq 0 ]; then
    printf "No expired or missing review_at annotations found.\n"
  else
    if [ "$AE_EXPIRY_COUNT" -gt 0 ]; then
      printf "### Expired or due-for-review entries (%d)\n\n" "$AE_EXPIRY_COUNT"
      printf '%b' "$AE_EXPIRY_DETAILS"
      printf "\n"
    fi
    if [ "$AE_EXPIRY_MISSING_COUNT" -gt 0 ]; then
      printf "### Missing review_at annotation (%d)\n\n" "$AE_EXPIRY_MISSING_COUNT"
      printf "These entries have no '# review_at:' comment. adapter_effectiveness_check.sh\n"
      printf "should already be failing the build for these — if this section is\n"
      printf "non-empty, the per-PR guard's presence check has a bug.\n\n"
      printf '%b' "$AE_EXPIRY_MISSING"
      printf "\n"
    fi
  fi
} >> "$REPORT_FILE"
