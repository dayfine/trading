#!/usr/bin/env bash
# write_audit.sh — Audit trail writer for QC review outcomes (T3-D).
#
# Writes a structured JSON record to
# dev/audit/<date>-<branch-sanitized>-<feature>.json (or
# dev/audit/YYYY-MM-DD-<feature>.json when --branch is omitted/empty --
# see the H-AUDIT-COLLISION note below). Designed to be called by the
# lead-orchestrator after QC agents complete, or manually during
# development.
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
# This script is idempotent: re-running with the same --date, --branch,
# and --feature overwrites the previous record (see H-AUDIT-COLLISION,
# dev/status/harness.md).
#
# Filename key: dev/audit/<date>-<branch-sanitized>-<feature>.json. The
# branch segment exists because <date>-<feature>.json alone collided
# whenever a track got a second QC review on the same day (a second PR,
# a -v2 branch, 2-4 orchestrator runs/day) -- the second write silently
# clobbered the first. --branch is always supplied by the orchestrator's
# record_qc_audit.sh call; when it is omitted (bare direct invocation)
# the filename falls back to the original <date>-<feature>.json shape.
# The branch segment sits BETWEEN date and feature (not appended after)
# so the filename still ENDS with "-<feature>.json" -- both dev/audit
# consumers (the consecutive_rework_count scan below and
# deep_scan/check_06_qc_calibration.sh) glob on that suffix and must not
# need to change shape.
#
# Chronological ordering (recorded_at_ns): allowing multiple same-day
# records per feature (above) means the consecutive_rework_count scan
# below can no longer assume "one file per day == one record per day
# in write order". Each record embeds "recorded_at_ns" (epoch
# nanoseconds at write time) so the scan can sort candidates by true
# write order. This is deliberately NOT derived from the filename
# (lexicographic sort orders same-day records by branch name, which is
# unrelated to write order) nor from file mtime (dev/audit/*.json files
# are committed to git; a fresh checkout stamps every file with
# checkout time, not original write time -- mtime-based ordering is
# unreliable across a checkout boundary). Records written before this
# field existed have no "recorded_at_ns" and sort as oldest.

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

# --- Compute output filename ---
#
# Sanitize the branch for filesystem safety (git branch names commonly
# contain "/", e.g. "feat/picks-phase-c"; replace with "-").
if [ -n "$BRANCH" ]; then
  BRANCH_SAFE="$(printf '%s' "$BRANCH" | tr '/' '-')"
  OUTPUT_FILE="$AUDIT_DIR/${DATE}-${BRANCH_SAFE}-${FEATURE}.json"
else
  OUTPUT_FILE="$AUDIT_DIR/${DATE}-${FEATURE}.json"
fi
OUTPUT_BASENAME="$(basename "$OUTPUT_FILE")"

# --- Compute this record's write-order timestamp ---
#
# epoch nanoseconds, fixed-width (19 digits until year ~2286) so plain
# lexicographic `sort` on the raw value is also a correct numeric sort.
# Override via WRITE_AUDIT_RECORDED_AT_NS for deterministic tests.
RECORDED_AT_NS="${WRITE_AUDIT_RECORDED_AT_NS:-$(date -u +%s%N)}"

# --- Compute consecutive_rework_count ---
#
# Look at prior audit records for this feature, sorted by write order
# (recorded_at_ns) descending -- NOT by filename or mtime; see the
# "Chronological ordering" note near the top of this file for why.
# Count how many consecutive NEEDS_REWORK verdicts precede this one.
# If the current verdict is NEEDS_REWORK, the count includes this record.
# If APPROVED, the streak resets to 0.

CONSECUTIVE=0

if [ "$OVERALL" = "NEEDS_REWORK" ]; then
  # Start at 1 (this record is itself a NEEDS_REWORK)
  CONSECUTIVE=1

  # Build "<recorded_at_ns>\t<file>" pairs for every prior audit file of
  # this feature, then sort by recorded_at_ns descending (true write
  # order). Records predating this field have no recorded_at_ns and
  # default to 0 (oldest).
  candidate_pairs=""
  for f in $(ls -1 "$AUDIT_DIR"/*-"$FEATURE".json 2>/dev/null || true); do
    # Skip the file we are about to write (same date+branch+feature --
    # this is what makes re-running for the SAME review idempotent
    # rather than counting itself as a prior NEEDS_REWORK).
    basename_f="$(basename "$f")"
    if [ "$basename_f" = "$OUTPUT_BASENAME" ]; then
      continue
    fi

    f_recorded_at=$(grep -o '"recorded_at_ns": *[0-9]*' "$f" 2>/dev/null | head -1 | sed 's/.*: *//')
    [ -z "$f_recorded_at" ] && f_recorded_at=0
    candidate_pairs="${candidate_pairs}${f_recorded_at}	${f}
"
  done

  ordered_files=$(printf '%s' "$candidate_pairs" | sort -rn | cut -f2-)

  for f in $ordered_files; do
    [ -n "$f" ] || continue

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
#
# OUTPUT_FILE was computed earlier (before the consecutive_rework_count
# scan) so that scan could skip its own about-to-be-written record.

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
  "recorded_at_ns": $RECORDED_AT_NS,
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
