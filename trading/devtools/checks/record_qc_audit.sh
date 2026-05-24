#!/usr/bin/env bash
# record_qc_audit.sh — Thin wrapper around write_audit.sh for the QC pipeline (T3-G).
#
# Extracts structural/behavioral verdicts and quality score from a completed
# dev/reviews/<feature>.md, then calls write_audit.sh to persist the record to
# dev/audit/YYYY-MM-DD-<feature>.json.
#
# Usage:
#   bash trading/devtools/checks/record_qc_audit.sh <feature> <branch> <date> [--pr-number N]
#
#   <feature>      the feature name (matches dev/reviews/<feature>.md)
#   <branch>       the branch name (e.g. feat/screener)
#   <date>         ISO-8601 date (YYYY-MM-DD)
#   --pr-number N  (optional) — read review verdicts from `gh pr view <N> --json reviews`
#                  instead of dev/reviews/<feature>.md. This is the new path that
#                  follows the PR-D agent-prompt cutover. Falls back to file mode
#                  if no matching reviews exist (transitional dual-source).
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
  echo "Usage: record_qc_audit.sh <feature> <branch> <date> [--pr-number N]" >&2
  exit 1
fi

FEATURE="$1"
BRANCH="$2"
DATE="$3"
shift 3

PR_NUMBER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --pr-number)
      shift
      PR_NUMBER="${1:-}"
      if [ -z "$PR_NUMBER" ] || ! echo "$PR_NUMBER" | grep -qE '^[0-9]+$'; then
        echo "FAIL: --pr-number requires a numeric argument (got: '$PR_NUMBER')" >&2
        exit 1
      fi
      ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# Test hook: override the gh binary for unit tests.
GH_BIN="${RECORD_QC_AUDIT_GH_BIN:-gh}"

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

if [ -z "$PR_NUMBER" ] && [ ! -f "$REVIEW_FILE" ]; then
  echo "FAIL: review file not found: $REVIEW_FILE" >&2
  echo "  Tip: pass --pr-number N to read verdicts from GitHub PR reviews instead." >&2
  exit 1
fi

if [ ! -f "$WRITE_AUDIT" ]; then
  echo "FAIL: write_audit.sh not found: $WRITE_AUDIT" >&2
  exit 1
fi

# --- Extract verdicts ---
#
# Two paths, tried in order:
#   1. If --pr-number is set: query `gh pr view <N> --json reviews`,
#      walk reviews newest-first, infer structural/behavioral verdicts
#      from the body's "## Structural QC" / "## Behavioral QC" headers
#      + review state (APPROVED / CHANGES_REQUESTED / COMMENTED).
#   2. Fall back to the file mode below (legacy + transitional).
#
# The transition is intentional: until the lead-orchestrator + QC agents
# fully cut over to PR-comment-only review delivery, BOTH the file and
# the PR-comment may be present. PR mode wins when both exist.

_pr_to_verdict_state() {
  # $1 = GitHub review state (APPROVED|CHANGES_REQUESTED|COMMENTED|DISMISSED)
  case "$1" in
    APPROVED) echo "APPROVED";;
    CHANGES_REQUESTED) echo "NEEDS_REWORK";;
    *) echo "";;  # COMMENTED / DISMISSED → caller must body-parse
  esac
}

_extract_pr_verdict() {
  # $1 = pr_reviews_json (output of `gh pr view --json reviews`)
  # $2 = section header to match ("Structural QC" | "Behavioral QC")
  # Echoes APPROVED|NEEDS_REWORK|SKIPPED.
  echo "$1" | awk -v section="$2" '
    BEGIN { RS=""; FS="\n" }
    # GitHub returns reviews oldest-first; the last one matching the section is the freshest.
    {
      n = split($0, lines, "\n")
      for (i = 1; i <= n; i++) {
        if (lines[i] ~ ("## " section)) {
          # Track latest state seen for this section
          for (j = i; j >= 1 && j > i-20; j--) {
            if (lines[j] ~ /\"state\":/) {
              sub(/.*\"state\":[[:space:]]*\"/, "", lines[j])
              sub(/\".*/, "", lines[j])
              last_state = lines[j]
              break
            }
          }
          for (k = i; k < n && k < i+200; k++) {
            if (lines[k] ~ /^## Verdict/) {
              for (m = k+1; m < n && m < k+10; m++) {
                gsub(/^\*\*|\*\*$/, "", lines[m])
                if (lines[m] ~ /^APPROVED|^NEEDS_REWORK/) {
                  last_body_verdict = lines[m]; break
                }
              }
              break
            }
          }
        }
      }
    }
    END {
      if (last_state == "APPROVED") print "APPROVED"
      else if (last_state == "CHANGES_REQUESTED") print "NEEDS_REWORK"
      else if (last_body_verdict != "") print last_body_verdict
      else print ""
    }'
}

PR_REVIEWS_JSON=""
STRUCTURAL=""
BEHAVIORAL=""
OVERALL=""
QUALITY_SCORE=""

if [ -n "$PR_NUMBER" ]; then
  PR_REVIEWS_JSON="$("$GH_BIN" pr view "$PR_NUMBER" --json reviews 2>/dev/null || true)"
  if [ -n "$PR_REVIEWS_JSON" ]; then
    # Newline-separated review bodies, in submitted order.
    BODIES="$(echo "$PR_REVIEWS_JSON" \
      | "$GH_BIN" pr view "$PR_NUMBER" --json reviews --jq '.reviews[] | "STATE:\(.state)\n\(.body)\nENDBODY"' 2>/dev/null || true)"
    # Walk bodies; latest with each header wins.
    STRUCTURAL_STATE=""
    BEHAVIORAL_STATE=""
    while IFS= read -r line; do
      if [ "${line#STATE:}" != "$line" ]; then
        CUR_STATE="${line#STATE:}"
        continue
      fi
      if echo "$line" | grep -qE '^## (Structural QC|Structural Checklist)'; then
        STRUCTURAL_STATE="$CUR_STATE"
      fi
      if echo "$line" | grep -qE '^## (Behavioral QC|Behavioral Checklist|Contract Pinning Checklist)'; then
        BEHAVIORAL_STATE="$CUR_STATE"
      fi
    done <<EOF
$BODIES
EOF
    STRUCTURAL="$(_pr_to_verdict_state "$STRUCTURAL_STATE")"
    BEHAVIORAL="$(_pr_to_verdict_state "$BEHAVIORAL_STATE")"
    # Quality score from PR bodies (last "## Quality Score" wins).
    QUALITY_SCORE="$(echo "$BODIES" | awk '
      /^## Quality Score|^### Quality Score/ { in_qs=1; next }
      in_qs && /^[[:space:]]*$/ { next }
      in_qs {
        line=$0
        gsub(/^\*\*/, "", line)
        if (line ~ /^[1-5]/) last_score=substr(line, 1, 1)
        in_qs=0
      }
      END { if (last_score != "") print last_score }')"
  fi
fi

# Fall back to file mode if --pr-number wasn't given OR the PR query returned nothing.
if [ -z "$STRUCTURAL" ] && [ -z "$BEHAVIORAL" ]; then
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
fi

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

# Only run the file-mode quality-score extractor if PR-mode didn't already
# populate QUALITY_SCORE. Otherwise the awk would run against a missing
# review file (PR-mode skips the file existence check) and zero out the
# PR-derived value.
if [ -z "$QUALITY_SCORE" ]; then
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
fi

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
