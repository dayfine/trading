#!/usr/bin/env bash
# record_qc_audit.sh — Thin wrapper around write_audit.sh for the QC pipeline (T3-G).
#
# Extracts structural/behavioral verdicts and quality score from a completed
# dev/reviews/<feature>.md, then calls write_audit.sh to persist the record to
# dev/audit/YYYY-MM-DD-<feature>.json.
#
# Usage:
#   bash trading/devtools/checks/record_qc_audit.sh <feature> <branch> <date>
#
#   <feature>  the feature name (matches dev/reviews/<feature>.md)
#   <branch>   the branch name (e.g. feat/screener)
#   <date>     ISO-8601 date (YYYY-MM-DD)
#
# Extraction logic:
#
#   Structural verdict:
#     Last occurrence of "structural_qc: APPROVED|NEEDS_REWORK" in the file,
#     or the first "## Verdict" block value (bare or **bold** format).
#     Defaults to SKIPPED if not found.
#
#   Behavioral verdict:
#     Last occurrence of "behavioral_qc: APPROVED|NEEDS_REWORK" in the file,
#     or the last "## Verdict" block value (behavioral appends after structural).
#     Defaults to SKIPPED if not found.
#
#   Overall verdict (required):
#     "overall_qc: APPROVED|NEEDS_REWORK" field in the file.
#     Derived from structural + behavioral if not present.
#
#   Quality score:
#     The integer on the first non-blank line after "## Quality Score" or
#     "### Quality Score". The line starts with a bare digit ("5 -- ...") or
#     bold-wrapped digit ("**5 -- ..."). The LAST such section in the file is
#     used (behavioral takes precedence over structural). Defaults to null.
#
# The call is idempotent: re-running overwrites any prior record for the same
# date+feature. Errors from write_audit.sh propagate to the caller.

set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: record_qc_audit.sh <feature> <branch> <date>" >&2
  exit 1
fi

FEATURE="$1"
BRANCH="$2"
DATE="$3"

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
  if [ -n "${REPO_ROOT:-}" ] && [ -d "$REPO_ROOT" ]; then
    echo "$REPO_ROOT"
    return 0
  fi
  echo "FAIL: could not locate repo root" >&2
  exit 1
}

REPO_ROOT="$(_repo_root)"
REVIEW_FILE="$REPO_ROOT/dev/reviews/${FEATURE}.md"
WRITE_AUDIT="$REPO_ROOT/trading/devtools/checks/write_audit.sh"

# --- Validate inputs ---

if ! echo "$DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  echo "FAIL: date must be YYYY-MM-DD, got: $DATE" >&2
  exit 1
fi

if [ ! -f "$REVIEW_FILE" ]; then
  echo "FAIL: review file not found: $REVIEW_FILE" >&2
  exit 1
fi

if [ ! -f "$WRITE_AUDIT" ]; then
  echo "FAIL: write_audit.sh not found: $WRITE_AUDIT" >&2
  exit 1
fi

# --- Extract verdicts from the review file ---
#
# Primary: structured fields written by orchestrator or status update.
# Fallback: ## Verdict blocks from the review body.

_extract_verdict() {
  # $1 = field name (e.g. "overall_qc", "structural_qc", "behavioral_qc")
  # Returns the verdict (APPROVED|NEEDS_REWORK) or empty string.
  grep -oE "^$1: (APPROVED|NEEDS_REWORK)" "$REVIEW_FILE" 2>/dev/null \
    | tail -1 \
    | sed 's/.*: //' || true
}

STRUCTURAL="$(_extract_verdict "structural_qc")"
BEHAVIORAL="$(_extract_verdict "behavioral_qc")"
OVERALL="$(_extract_verdict "overall_qc")"

# Fallback: scan for overall_qc anywhere in the file
if [ -z "$OVERALL" ]; then
  OVERALL=$(grep -oE "overall_qc: (APPROVED|NEEDS_REWORK)" "$REVIEW_FILE" 2>/dev/null \
    | tail -1 | sed 's/.*: //' || true)
fi

# Fallback: parse ## Verdict blocks from the review body.
# The structural section uses the first ## Verdict; behavioral uses the last.
# Both bare (APPROVED) and bold (**APPROVED**) formats are supported.

if [ -z "$STRUCTURAL" ]; then
  STRUCTURAL=$(awk '
    /^## Verdict/{found=1; next}
    found && /^(APPROVED|NEEDS_REWORK|\*\*(APPROVED|NEEDS_REWORK)\*\*)/ {
      v=$0; gsub(/^\*\*|\*\*$/, "", v); print v; exit
    }
  ' "$REVIEW_FILE" || true)
fi

if [ -z "$BEHAVIORAL" ]; then
  BEHAVIORAL=$(awk '
    /^## Verdict/{found=1; next}
    found && /^(APPROVED|NEEDS_REWORK|\*\*(APPROVED|NEEDS_REWORK)\*\*)/ {
      v=$0; gsub(/^\*\*|\*\*$/, "", v); last=v; found=0
    }
    END { if (last != "") print last }
  ' "$REVIEW_FILE" || true)
fi

# Defaults if still empty
STRUCTURAL="${STRUCTURAL:-SKIPPED}"
BEHAVIORAL="${BEHAVIORAL:-SKIPPED}"

# Overall is required -- derive if still empty
if [ -z "$OVERALL" ]; then
  if [ "$STRUCTURAL" = "NEEDS_REWORK" ] || [ "$BEHAVIORAL" = "NEEDS_REWORK" ]; then
    OVERALL="NEEDS_REWORK"
  elif [ "$STRUCTURAL" = "APPROVED" ]; then
    OVERALL="APPROVED"
  else
    echo "FAIL: could not determine overall verdict from $REVIEW_FILE" >&2
    echo "  Tip: ensure the review file contains 'overall_qc: APPROVED|NEEDS_REWORK'" >&2
    exit 1
  fi
fi

# --- Extract quality score ---
#
# The quality score line appears after "## Quality Score" or "### Quality Score"
# (possibly followed by a blank line), in one of these forms:
#   5 -- rationale ...
#   **5 -- rationale ...**
#
# The LAST such section in the file is used (behavioral takes precedence).
#
# Note: awk {n,m} quantifiers are not portable; use explicit alternation instead.

QUALITY_SCORE=$(awk '
  /^## Quality Score|^### Quality Score/ { in_qs=1; next }
  in_qs && /^[[:space:]]*$/ { next }
  in_qs {
    line=$0
    gsub(/^\*\*/, "", line)
    if (line ~ /^[1-5]/) {
      last_score=substr(line, 1, 1)
    }
    in_qs=0
  }
  END { if (last_score != "") print last_score }
' "$REVIEW_FILE" 2>/dev/null || true)

# --- Call write_audit.sh ---

SCORE_ARG=""
if [ -n "$QUALITY_SCORE" ]; then
  SCORE_ARG="--quality-score $QUALITY_SCORE"
fi

# shellcheck disable=SC2086
bash "$WRITE_AUDIT" \
  --date "$DATE" \
  --feature "$FEATURE" \
  --branch "$BRANCH" \
  --structural "$STRUCTURAL" \
  --behavioral "$BEHAVIORAL" \
  --overall "$OVERALL" \
  $SCORE_ARG
