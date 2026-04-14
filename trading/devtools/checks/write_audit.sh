#!/usr/bin/env bash
# write_audit.sh — Audit trail writer for QC review outcomes (T3-D).
#
# Writes a structured JSON record to dev/audit/YYYY-MM-DD-<feature>.json.
# Designed to be called by the lead-orchestrator after QC agents complete,
# or manually during development.
#
# Usage:
#   sh write_audit.sh \
#     --date       2026-04-14 \
#     --feature    screener \
#     --branch     feat/screener \
#     --structural APPROVED \
#     --behavioral APPROVED \
#     --overall    APPROVED \
#     [--harness-gap "description of what the harness missed"] \
#     [--quality-score 4] \
#     [--pass-count 8] \
#     [--fail-count 0] \
#     [--flag-count 1] \
#     [--notes "optional notes"]
#
# Integration:
#   The lead-orchestrator should call this script in Step 5 (after QC
#   agents return their verdicts) to record each review outcome. The
#   health-scanner deep scan reads dev/audit/ to perform QC calibration
#   audits and track consecutive NEEDS_REWORK counts for escalation.
#
#   The escalation policy (harness-engineering-plan.md) triggers human
#   review when consecutive_rework_count >= 3 for any feature.
#
# This script is idempotent: re-running with the same --date and
# --feature overwrites the previous record.

set -euo pipefail

# --- Argument parsing ---

DATE=""
FEATURE=""
BRANCH=""
STRUCTURAL="SKIPPED"
BEHAVIORAL="SKIPPED"
OVERALL=""
HARNESS_GAP=""
QUALITY_SCORE="null"
PASS_COUNT=0
FAIL_COUNT=0
FLAG_COUNT=0
NOTES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --date)        DATE="$2";          shift 2 ;;
    --feature)     FEATURE="$2";       shift 2 ;;
    --branch)      BRANCH="$2";        shift 2 ;;
    --structural)  STRUCTURAL="$2";    shift 2 ;;
    --behavioral)  BEHAVIORAL="$2";    shift 2 ;;
    --overall)     OVERALL="$2";       shift 2 ;;
    --harness-gap) HARNESS_GAP="$2";   shift 2 ;;
    --quality-score) QUALITY_SCORE="$2"; shift 2 ;;
    --pass-count)  PASS_COUNT="$2";    shift 2 ;;
    --fail-count)  FAIL_COUNT="$2";    shift 2 ;;
    --flag-count)  FLAG_COUNT="$2";    shift 2 ;;
    --notes)       NOTES="$2";         shift 2 ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# --- Validation ---

if [ -z "$DATE" ] || [ -z "$FEATURE" ] || [ -z "$OVERALL" ]; then
  echo "FAIL: --date, --feature, and --overall are required." >&2
  echo "Usage: write_audit.sh --date YYYY-MM-DD --feature <name> --overall APPROVED|NEEDS_REWORK [...]" >&2
  exit 1
fi

# Validate date format
if ! echo "$DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  echo "FAIL: --date must be YYYY-MM-DD, got: $DATE" >&2
  exit 1
fi

# Validate verdict values
for verdict_name in structural behavioral overall; do
  eval "val=\$$( echo "$verdict_name" | tr '[:lower:]' '[:upper:]' )"
  case "$val" in
    APPROVED|NEEDS_REWORK|SKIPPED) ;;
    *)
      echo "FAIL: --$verdict_name must be APPROVED, NEEDS_REWORK, or SKIPPED, got: $val" >&2
      exit 1
      ;;
  esac
done

# harness_gap is only meaningful on NEEDS_REWORK
if [ "$OVERALL" = "APPROVED" ] && [ -n "$HARNESS_GAP" ]; then
  echo "WARNING: --harness-gap is only meaningful when --overall is NEEDS_REWORK; ignoring." >&2
  HARNESS_GAP=""
fi

# --- Locate repo root ---

_repo_root() {
  dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -d "$dir/.git" ] || [ -d "$dir/.claude" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  # Fallback: try REPO_ROOT env var
  if [ -n "${REPO_ROOT:-}" ] && [ -d "$REPO_ROOT" ]; then
    echo "$REPO_ROOT"
    return 0
  fi
  echo "FAIL: could not locate repo root" >&2
  exit 1
}

REPO_ROOT="$(_repo_root)"
AUDIT_DIR="$REPO_ROOT/dev/audit"

# Create audit directory if it does not exist
mkdir -p "$AUDIT_DIR"

# --- Compute consecutive_rework_count ---
#
# Look at prior audit records for this feature, sorted by date descending.
# Count how many consecutive NEEDS_REWORK verdicts precede this one.
# If the current verdict is NEEDS_REWORK, the count includes this record.
# If APPROVED, the streak resets to 0.

CONSECUTIVE=0

if [ "$OVERALL" = "NEEDS_REWORK" ]; then
  # Start at 1 (this record is itself a NEEDS_REWORK)
  CONSECUTIVE=1

  # Find prior audit files for this feature, sorted newest-first
  prior_files=$(ls -1 "$AUDIT_DIR"/*-"$FEATURE".json 2>/dev/null | sort -r || true)

  for f in $prior_files; do
    # Skip the file we are about to write (same date+feature)
    basename_f="$(basename "$f")"
    if [ "$basename_f" = "${DATE}-${FEATURE}.json" ]; then
      continue
    fi

    # Extract overall_qc from the JSON (simple grep — no jq dependency)
    prev_verdict=$(grep -o '"overall_qc": *"[^"]*"' "$f" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"//')

    if [ "$prev_verdict" = "NEEDS_REWORK" ]; then
      CONSECUTIVE=$((CONSECUTIVE + 1))
    else
      # Streak broken
      break
    fi
  done
fi

# --- Write JSON ---

OUTPUT_FILE="$AUDIT_DIR/${DATE}-${FEATURE}.json"

# Escape strings for JSON (handle double quotes and backslashes)
_json_str() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# quality_score: integer or null
if [ "$QUALITY_SCORE" = "null" ] || [ -z "$QUALITY_SCORE" ]; then
  QS_JSON="null"
else
  QS_JSON="$QUALITY_SCORE"
fi

cat > "$OUTPUT_FILE" <<ENDJSON
{
  "date": "$DATE",
  "feature": "$(_json_str "$FEATURE")",
  "branch": "$(_json_str "$BRANCH")",
  "structural_qc": "$STRUCTURAL",
  "behavioral_qc": "$BEHAVIORAL",
  "overall_qc": "$OVERALL",
  "harness_gap": "$(_json_str "$HARNESS_GAP")",
  "quality_score": $QS_JSON,
  "findings_count": {
    "PASS": $PASS_COUNT,
    "FAIL": $FAIL_COUNT,
    "FLAG": $FLAG_COUNT
  },
  "consecutive_rework_count": $CONSECUTIVE,
  "notes": "$(_json_str "$NOTES")"
}
ENDJSON

echo "OK: wrote $OUTPUT_FILE (consecutive_rework_count=$CONSECUTIVE)"
