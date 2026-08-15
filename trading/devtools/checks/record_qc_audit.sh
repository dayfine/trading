#!/usr/bin/env bash
# record_qc_audit.sh — Thin wrapper around write_audit.sh for the QC pipeline (T3-G).
#
# Extracts structural/behavioral verdicts and quality score from a completed
# dev/reviews/<feature>.md, then calls write_audit.sh to persist the record to
# dev/audit/<date>-<branch-sanitized>-<feature>.json (or
# dev/audit/YYYY-MM-DD-<feature>.json when <branch> is empty).
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
#   Reviewed SHA:
#     Last occurrence of "Reviewed SHA: <sha>" (the first line of every QC
#     review pass, per qc-structural.md / qc-behavioral.md), truncated to 12
#     chars. Passed to write_audit.sh as --sha so it can tell a genuine
#     rework (new sha, same branch) apart from a retried invocation of the
#     same review (same sha) -- see H-AUDIT-REWORK-COUNT-BLIND,
#     dev/status/harness.md. Empty if no such line is found anywhere.
#
# The call is idempotent for a given (date, branch, feature, reviewed sha):
# re-running with all four unchanged overwrites the prior record. A
# different branch on the same date+feature always produces a DISTINCT
# record (H-AUDIT-COLLISION); a different reviewed sha on the SAME branch
# (a rework at a new tip) also produces a DISTINCT record, preserving the
# one it followed rather than clobbering it (H-AUDIT-REWORK-COUNT-BLIND) --
# unless <branch> is empty, which still falls back to the collision-prone
# date+feature-only shape; see write_audit.sh). Errors from write_audit.sh
# propagate to the caller.

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
  # An explicitly-set REPO_ROOT takes precedence over the walk-up, matching
  # the shared repo_root() helper (trading/devtools/checks/_check_lib.sh)
  # that most other check scripts source, and matching write_audit.sh's own
  # _repo_root() (fixed for H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE). Before
  # this fix the walk-up ran FIRST and only fell back to $REPO_ROOT when it
  # found nothing -- so an ad-hoc in-place invocation (run from inside a real
  # checkout, where .git/.claude are always found a few directories up)
  # silently ignored any REPO_ROOT override. That was worse here than in
  # write_audit.sh: this script reassigns REPO_ROOT="$(_repo_root)" below
  # with a PLAIN (non-export) assignment, and bash's export attribute
  # survives plain reassignment of an already-exported variable -- so the
  # walked-up value stayed exported and silently overrode the caller's real
  # REPO_ROOT for write_audit.sh, which this script invokes as a child
  # process. See H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING (dev/status/harness.md).
  #
  # H-REPO-ROOT-SET-BUT-INVALID-SILENT-FALLTHROUGH: a REPO_ROOT that is SET
  # but fails the `[ -d ]` guard (nonexistent path, or a path that exists
  # but is a regular file, not a directory) is a hard error, not a silent
  # fallthrough to the walk-up -- same rationale as write_audit.sh's own
  # _repo_root(): a set-but-invalid override is far more likely a typo than
  # a request to fall back, and this script's plain (non-export)
  # `REPO_ROOT="$(_repo_root)"` reassignment below means a silent
  # fallthrough here ALSO clobbers the exported REPO_ROOT the
  # write_audit.sh child process sees -- the exact H-RECORD-QC-AUDIT-
  # REPO-ROOT-SIBLING shape, just triggered by malformed input instead of
  # a successful competing walk-up.
  #
  # REPO_ROOT='' (empty string) is treated the SAME as unset, matching
  # _check_lib.sh:repo_root() and write_audit.sh:_repo_root()'s identical
  # decision: `${REPO_ROOT:-}` is empty for both unset and empty-string
  # REPO_ROOT, so '' already falls into the walk-up branch below by shell
  # construction -- every existing caller relies on exactly that fallback.
  if [ -n "${REPO_ROOT:-}" ]; then
    if [ -d "$REPO_ROOT" ]; then
      echo "$REPO_ROOT"
      return 0
    fi
    echo "FAIL: REPO_ROOT is set to '$REPO_ROOT' but is not a directory" >&2
    exit 1
  fi
  dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -d "$dir/.git" ] || [ -d "$dir/.claude" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
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

# _resolve_verdict — combine GitHub review state + body-parsed ## Verdict.
#   $1 = state (APPROVED|CHANGES_REQUESTED|COMMENTED|DISMISSED|""),
#   $2 = body verdict (APPROVED|NEEDS_REWORK|"")
# Echoes APPROVED|NEEDS_REWORK|"". State wins when it's a verdict
# state; falls back to body verdict for COMMENTED/DISMISSED (which is
# what self-approval-blocked QC agents produce — they post `--comment`
# with the verdict in the body's ## Verdict block).
_resolve_verdict() {
  case "$1" in
    APPROVED) echo "APPROVED" ;;
    CHANGES_REQUESTED) echo "NEEDS_REWORK" ;;
    *) [ -n "$2" ] && echo "$2" || echo "" ;;
  esac
}

PR_REVIEWS_JSON=""
STRUCTURAL=""
BEHAVIORAL=""
OVERALL=""
QUALITY_SCORE=""

if [ -n "$PR_NUMBER" ]; then
  # --pr-number was explicitly requested, so a missing `gh` binary must be a
  # loud failure, not a silent slide into the file-mode fallback below. Before
  # this check, a missing `gh` made the query below produce empty $BODIES
  # indistinguishable from "PR legitimately has no reviews yet" (scenario 6),
  # and the fallback then read dev/reviews/<feature>.md -- which can belong to
  # an entirely different PR/run for the same feature name and silently write
  # its (wrong) verdict as this PR's audit record. Observed in production: a
  # NEEDS_REWORK PR got recorded as APPROVED this way, resetting the
  # consecutive_rework_count streak #2123 exists to protect. See H-QC-SCALE
  # follow-up (dev/status/harness.md).
  if ! command -v "$GH_BIN" >/dev/null 2>&1; then
    echo "FAIL: --pr-number $PR_NUMBER was given but '$GH_BIN' is not available on PATH." >&2
    echo "  Refusing to silently fall back to dev/reviews/${FEATURE}.md -- it may belong to a different PR/run." >&2
    echo "  Install gh, or omit --pr-number to explicitly use file mode." >&2
    exit 1
  fi

  # One gh call: render reviews into a STATE/body/ENDBODY frame, one per review.
  #
  # H-AUDIT-GH-FALLBACK-RESIDUAL: capture gh's exit code AND stderr instead of
  # discarding both. The missing-binary guard above only covers `gh` being
  # absent from PATH -- every OTHER gh failure mode (present but
  # unauthenticated, rate-limited, network error) used to hit the discarded
  # `2>/dev/null || true` and come out as the exact same empty-$BODIES shape
  # as "PR legitimately has no reviews yet" (scenario 6), so those failures
  # silently fell through to the file-mode fallback below -- the same danger
  # the missing-binary guard exists to prevent, just via a different trigger.
  # Only "exit 0, empty stdout, no stderr" is treated as a genuine
  # zero-review PR; any nonzero exit, OR any stderr output even alongside
  # exit 0 (a warning-emitting gh is not a trustworthy empty result), refuses
  # loudly instead -- mirroring the missing-binary message shape below.
  GH_STDERR_FILE="$(mktemp)"
  BODIES="$("$GH_BIN" pr view "$PR_NUMBER" --json reviews \
    --jq '.reviews[] | "STATE:\(.state)\n\(.body)\nENDBODY"' \
    2>"$GH_STDERR_FILE")" && GH_RC=0 || GH_RC=$?
  GH_STDERR="$(cat "$GH_STDERR_FILE" 2>/dev/null || true)"
  rm -f "$GH_STDERR_FILE"

  if [ "$GH_RC" -ne 0 ] || [ -n "$GH_STDERR" ]; then
    echo "FAIL: --pr-number $PR_NUMBER was given but '$GH_BIN pr view' failed (exit $GH_RC)." >&2
    if [ -n "$GH_STDERR" ]; then
      echo "  stderr: $GH_STDERR" >&2
    fi
    echo "  Refusing to silently fall back to dev/reviews/${FEATURE}.md -- it may belong to a different PR/run." >&2
    echo "  Check gh auth status / network / rate limits, or omit --pr-number to explicitly use file mode." >&2
    exit 1
  fi

  if [ -n "$BODIES" ]; then
    # Single-pass awk extracts per-section (state, body_verdict) tuples.
    # Latest match per section wins (GitHub returns reviews oldest-first).
    # Output format: "<struct_state>|<struct_body>|<behav_state>|<behav_body>"
    PARSED="$(echo "$BODIES" | awk '
      BEGIN {
        struct_state=""; struct_body=""; behav_state=""; behav_body=""
        cur_state=""; cur_section=""; in_verdict=0
      }
      /^STATE:/ {
        cur_state = $0
        sub(/^STATE:/, "", cur_state)
        cur_section = ""
        in_verdict = 0
        next
      }
      /^## (Structural QC|Structural Checklist)/ { cur_section = "structural"; in_verdict = 0; next }
      /^## (Behavioral QC|Behavioral Checklist|Contract Pinning Checklist)/ { cur_section = "behavioral"; in_verdict = 0; next }
      /^## Verdict/ { in_verdict = 1; next }
      in_verdict && /^[[:space:]]*$/ { next }
      in_verdict {
        line = $0
        gsub(/^\*\*|\*\*$/, "", line)
        if (line ~ /^APPROVED/) {
          if (cur_section == "structural") { struct_state = cur_state; struct_body = "APPROVED" }
          else if (cur_section == "behavioral") { behav_state = cur_state; behav_body = "APPROVED" }
        } else if (line ~ /^NEEDS_REWORK/) {
          if (cur_section == "structural") { struct_state = cur_state; struct_body = "NEEDS_REWORK" }
          else if (cur_section == "behavioral") { behav_state = cur_state; behav_body = "NEEDS_REWORK" }
        }
        in_verdict = 0
      }
      /^ENDBODY/ {
        # State-only signal when no ## Verdict block was present for this section.
        if (cur_section == "structural" && struct_body == "") struct_state = cur_state
        if (cur_section == "behavioral" && behav_body == "") behav_state = cur_state
        cur_section = ""; cur_state = ""
      }
      END { print struct_state "|" struct_body "|" behav_state "|" behav_body }')"

    STRUCTURAL_STATE="${PARSED%%|*}"
    REST="${PARSED#*|}"
    STRUCTURAL_BODY="${REST%%|*}"
    REST="${REST#*|}"
    BEHAVIORAL_STATE="${REST%%|*}"
    BEHAVIORAL_BODY="${REST#*|}"

    STRUCTURAL="$(_resolve_verdict "$STRUCTURAL_STATE" "$STRUCTURAL_BODY")"
    BEHAVIORAL="$(_resolve_verdict "$BEHAVIORAL_STATE" "$BEHAVIORAL_BODY")"

    # Quality score from PR bodies (last "## Quality Score" wins).
    #
    # Capture the FULL leading digit run (not just a single [1-5] char) so an
    # out-of-range value (e.g. "6", "10", "0") is captured as-is instead of
    # being silently discarded by a narrow acceptance regex -- the range check
    # below then fails loudly on it rather than the record quietly ending up
    # with no quality_score at all. See H-QC-SCALE (dev/status/harness.md).
    QUALITY_SCORE="$(echo "$BODIES" | awk '
      /^## Quality Score|^### Quality Score/ { in_qs=1; next }
      in_qs && /^[[:space:]]*$/ { next }
      in_qs {
        line=$0
        gsub(/^\*\*/, "", line)
        if (match(line, /^[0-9]+/)) last_score=substr(line, RSTART, RLENGTH)
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
#
# Capture the FULL leading digit run (not just a single [1-5] char) so an
# out-of-range value (e.g. "6", "10", "0") is captured as-is rather than
# silently discarded by a narrow acceptance regex -- the range check below
# then fails loudly on it. See H-QC-SCALE (dev/status/harness.md).

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
      if (match(line, /^[0-9]+/)) {
        last_score=substr(line, RSTART, RLENGTH)
      }
      in_qs=0
    }
    END { if (last_score != "") print last_score }
  ' "$REVIEW_FILE" 2>/dev/null || true)
fi

# --- Validate quality score is an integer in 1..5 ---
#
# Both extraction paths above intentionally capture the raw leading integer
# (not restricted to 1-5) precisely so an out-of-range or malformed score is
# caught here explicitly, rather than silently discarded upstream and treated
# as "no score present". H-QC-SCALE: a QC agent posted an inverted score (1
# meaning "excellent") that happened to be in-range and so passed through
# silently; a genuinely out-of-range value must not pass through the same way.
if [ -n "$QUALITY_SCORE" ] && ! echo "$QUALITY_SCORE" | grep -qE '^[1-5]$'; then
  SCORE_SOURCE="$REVIEW_FILE"
  [ -n "$PR_NUMBER" ] && SCORE_SOURCE="PR #$PR_NUMBER review comments"
  echo "FAIL: parsed quality score '$QUALITY_SCORE' is not an integer in 1..5 (source: $SCORE_SOURCE)" >&2
  exit 1
fi

# --- Extract reviewed SHA (H-AUDIT-REWORK-COUNT-BLIND, dev/status/harness.md) ---
#
# Both QC agents' PR review comment bodies (qc-structural.md /
# qc-behavioral.md "Reviewed SHA" contract) and file-mode
# dev/reviews/<feature>.md begin EACH review pass with a
# "Reviewed SHA: <sha>" line. A rework cycle appends a NEW occurrence for
# its own pass, so -- mirroring the "last occurrence wins" convention
# already used for overall_qc/quality-score above -- the LAST occurrence
# is this call's reviewed commit. Truncated to 12 chars: enough to
# disambiguate distinct commits without an unwieldy 40-char filename
# segment.
#
# This is what lets write_audit.sh distinguish "same review, re-run" (a
# retried invocation for the same commit -- overwrite, stays idempotent)
# from "different review, same branch" (an actual rework at a new tip --
# must not clobber the record it followed). See write_audit.sh's own
# H-AUDIT-REWORK-COUNT-BLIND docstring for the write-side half. Passed
# unconditionally (both APPROVED and NEEDS_REWORK calls), same reasoning
# as the H-AUDIT-HARNESS-GAP-DROPPED-ON-APPROVED fix just above this one
# in the ledger: identity metadata should never be gated on the verdict.
SHA=""
if [ -n "${BODIES:-}" ]; then
  SHA="$(echo "$BODIES" | grep -oE '^Reviewed SHA: .*' | tail -1 | sed 's/^Reviewed SHA: *//' | cut -c1-12 || true)"
fi
if [ -z "$SHA" ] && [ -f "$REVIEW_FILE" ]; then
  SHA="$(grep -oE '^Reviewed SHA: .*' "$REVIEW_FILE" 2>/dev/null | tail -1 | sed 's/^Reviewed SHA: *//' | cut -c1-12 || true)"
fi

# --- Call write_audit.sh ---

SCORE_ARG=""
if [ -n "$QUALITY_SCORE" ]; then
  SCORE_ARG="--quality-score $QUALITY_SCORE"
fi

SHA_ARG=""
if [ -n "$SHA" ]; then
  SHA_ARG="--sha $SHA"
fi

# shellcheck disable=SC2086
bash "$WRITE_AUDIT" \
  --date "$DATE" \
  --feature "$FEATURE" \
  --branch "$BRANCH" \
  --structural "$STRUCTURAL" \
  --behavioral "$BEHAVIORAL" \
  --overall "$OVERALL" \
  $SCORE_ARG \
  $SHA_ARG
