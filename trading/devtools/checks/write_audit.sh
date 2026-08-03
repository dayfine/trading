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
# Usage (this script requires bash — set -o pipefail is not POSIX sh/dash;
# invoking it as `sh write_audit.sh` fails immediately with
# "set: Illegal option -o pipefail" under a dash /bin/sh, before writing
# anything; see H-WRITE-AUDIT-SHEBANG-MISMATCH, dev/status/harness.md):
#   bash write_audit.sh \
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
# field existed have no "recorded_at_ns" and sort as oldest -- the
# extraction below is written to degrade to 0 rather than abort under
# `set -euo pipefail` when grep finds no match (a bare failing `grep`
# in a pipeline makes the whole pipeline's exit status non-zero, which
# would otherwise kill the script before it ever writes the record;
# regression-tested in record_qc_audit_test.sh scenario 9).

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

# --- Validate quality score is an integer in 1..5 ---
#
# "null" / empty means "no score" and is fine (pre-T1-Q reviews, or a verdict
# path where behavioral didn't run). Anything else must be exactly one digit
# 1-5 -- fail loudly and write nothing rather than let an out-of-range value
# (or non-numeric garbage) reach the JSON body below. See H-QC-SCALE
# (dev/status/harness.md): a QC agent posted an inverted-polarity score that
# happened to be in-range and so was accepted by construction, not by luck;
# a value outside 1..5 must not be accepted the same silent way.
if [ "$QUALITY_SCORE" != "null" ] && [ -n "$QUALITY_SCORE" ]; then
  if ! echo "$QUALITY_SCORE" | grep -qE '^[1-5]$'; then
    echo "FAIL: --quality-score must be an integer 1..5 (1=worst, 5=best), got: '$QUALITY_SCORE'" >&2
    echo "  Target record: $OUTPUT_FILE" >&2
    exit 1
  fi
fi

# --- Compute this record's write-order timestamp ---
#
# epoch nanoseconds, fixed-width (19 digits until year ~2286) so plain
# lexicographic `sort` on the raw value is also a correct numeric sort.
# Override via WRITE_AUDIT_RECORDED_AT_NS for deterministic tests.
#
# RECORDED_AT_NS is interpolated unquoted into the JSON body below (it is
# a JSON number, not a string), so it MUST be validated as a plain
# nonnegative integer before use -- an unvalidated value here writes
# malformed JSON straight into a committed audit record.
_is_nonneg_int() {
  case "$1" in
    '' | *[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

if [ -n "${WRITE_AUDIT_RECORDED_AT_NS:-}" ]; then
  # Test-only override. A bad value here is a caller/fixture bug, not a
  # platform quirk -- fail loudly rather than silently substituting a
  # different value a test might not notice.
  if _is_nonneg_int "$WRITE_AUDIT_RECORDED_AT_NS"; then
    RECORDED_AT_NS="$WRITE_AUDIT_RECORDED_AT_NS"
  else
    echo "FAIL: WRITE_AUDIT_RECORDED_AT_NS must be a nonnegative integer, got: $WRITE_AUDIT_RECORDED_AT_NS" >&2
    exit 1
  fi
else
  # `date -u +%s%N` is GNU-only; BSD/macOS date does not understand %N and
  # emits it as a literal "N" (e.g. "1785315600N"), which would otherwise
  # land directly in the JSON body as an invalid numeric literal. This is
  # a platform quirk, not a caller error, so degrade gracefully instead of
  # failing: fall back to whole-second resolution scaled up to the same
  # magnitude as a real nanosecond timestamp (seconds * 10^9), which keeps
  # the "fixed-width, lexicographically sortable" property intact at the
  # cost of sub-second ordering precision on such platforms.
  RAW_NS="$(date -u +%s%N 2>/dev/null || true)"
  if _is_nonneg_int "$RAW_NS"; then
    RECORDED_AT_NS="$RAW_NS"
  else
    FALLBACK_SECONDS="$(date -u +%s)"
    RECORDED_AT_NS=$((FALLBACK_SECONDS * 1000000000))
  fi
fi

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

    # `|| true` is load-bearing: under `set -euo pipefail`, `grep` finding
    # no "recorded_at_ns" field in a legacy record (the expected case for
    # every record written before this field existed) exits 1, which makes
    # the whole pipeline's status non-zero and would otherwise abort this
    # script before it ever writes the current record. `|| true` lets the
    # pipeline fail closed into an empty $f_recorded_at instead, which the
    # next line then defaults to 0 as documented above.
    f_recorded_at=$(grep -o '"recorded_at_ns": *[0-9]*' "$f" 2>/dev/null | head -1 | sed 's/.*: *//' || true)
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
#
# The write is staged through a temp file and then renamed into place
# (H-AUDIT-ATOMIC-WRITE, dev/status/harness.md). `cat > "$OUTPUT_FILE"
# <<ENDJSON` truncates the target the moment the redirect opens, BEFORE any
# content is available -- an interruption mid-heredoc (SIGTERM on a
# cancelled CI job, ENOSPC per sweep-hygiene.md) leaves a partial or empty
# record at $OUTPUT_FILE, clobbering whatever valid record was there before.
# Writing to a temp file first and `mv`-ing it into place makes the
# replacement atomic: on any POSIX filesystem, `mv` within the same
# directory is a single rename syscall, so $OUTPUT_FILE is either the old
# content or the new content, never a partial write. This is what removes
# H-PREV-VERDICT-PIPEFAIL's trigger at the source (a truncated record with
# recorded_at_ns but no overall_qc can no longer be produced by this script).
#
# The temp file MUST be created in $AUDIT_DIR (same directory as
# $OUTPUT_FILE, hence same filesystem) -- `mv` across filesystems silently
# degrades to copy+unlink, which reintroduces the exact truncation window
# this fix exists to remove. `mktemp "${OUTPUT_FILE}.XXXXXX"` satisfies
# that and also gives a random per-invocation suffix, so concurrent
# invocations for different records never collide on the same temp path.
#
# The temp suffix deliberately does NOT end in ".json" (mktemp appends
# random chars after ".XXXXXX", replacing the literal template chars) --
# both dev/audit consumers that glob this directory
# (consecutive_rework_count above, and deep_scan/check_06_qc_calibration.sh)
# match on `*-<feature>.json`, i.e. the filename must end in ".json". A
# leftover temp file (e.g. if the process was SIGKILLed, which bypasses the
# EXIT trap below) is therefore invisible to both globs -- it cannot be
# mistaken for a real record, only left as inert disk litter for manual
# cleanup.
TMP_FILE="$(mktemp "${OUTPUT_FILE}.XXXXXX")"
# Clean up the temp file if anything below fails or the process is
# terminated by a caught signal before the `mv` completes. A no-op once the
# `mv` has succeeded, since $TMP_FILE no longer exists at that path.
trap 'rm -f "$TMP_FILE"' EXIT INT TERM

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

cat > "$TMP_FILE" <<ENDJSON
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

# Test-only hook: simulate an interruption between finishing the temp-file
# write and the atomic rename (e.g. SIGTERM landing right after the heredoc
# closes, or the process being cancelled before it gets to `mv`). Used by
# record_qc_audit_test.sh to prove the fix: with this set, $OUTPUT_FILE (if
# it already existed) must be left byte-identical -- never truncated, never
# partially overwritten. Mirrors the WRITE_AUDIT_RECORDED_AT_NS test-only
# override above.
if [ -n "${WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME:-}" ]; then
  echo "FAIL: WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME set; simulating interruption before rename; TMP_FILE=$TMP_FILE" >&2
  exit 1
fi

mv -f "$TMP_FILE" "$OUTPUT_FILE"

echo "OK: wrote $OUTPUT_FILE (consecutive_rework_count=$CONSECUTIVE)"
