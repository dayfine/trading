#!/bin/sh
# Check 6: QC calibration audit — verdicts vs current test health.
#
# Usage: sh check_06_qc_calibration.sh <report_file> [findings_file]
#
# For each feature with a QC review (dev/reviews/*.md), extract the
# most recent overall verdict and cross-reference against whether the
# feature's test directories currently pass `dune runtest`.
#
# This detects three classes of drift:
#   a) QC said APPROVED but tests now fail (regression since review)
#   b) Missing audit trail record for a reviewed feature
#   c) A feature has stacked >= 3 consecutive NEEDS_REWORK verdicts in
#      dev/audit/ without a human ever being flagged (see the
#      "Rework-streak escalation scan" section below)
#
# The dune check (a, b) is skipped if `dune` is not on PATH (e.g. running
# outside the dev container). The rework-streak scan (c) always runs — it
# only reads dev/audit/*.json, no dune invocation involved.

set -e

REPORT_FILE="${1:?Usage: check_06_qc_calibration.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 6: QC calibration audit
# ────────────────────────────────────────────────────────────────

QC_CAL_COUNT=0
QC_CAL_DETAILS=""
DUNE_AVAILABLE=false

if command -v dune >/dev/null 2>&1; then
  DUNE_AVAILABLE=true
fi

# Feature-name to test directory mapping.
# Each feature maps to one or more dune-runtest-able paths (relative
# to the trading/ workspace root).
_test_dirs_for_feature() {
  case "$1" in
    screener)
      echo "analysis/weinstein/stage/test analysis/weinstein/rs/test analysis/weinstein/volume/test analysis/weinstein/macro/test analysis/weinstein/sector/test analysis/weinstein/resistance/test analysis/weinstein/stock_analysis/test analysis/weinstein/screener/test"
      ;;
    data-layer)
      echo "analysis/weinstein/data_source/test"
      ;;
    portfolio-stops)
      echo "trading/weinstein/order_gen/test trading/weinstein/stops/test trading/weinstein/portfolio_risk/test trading/weinstein/trading_state/test"
      ;;
    simulation)
      echo "trading/weinstein/strategy/test"
      ;;
    *)
      echo ""
      ;;
  esac
}

for review_file in "${REPO_ROOT}"/dev/reviews/*.md; do
  [ -f "$review_file" ] || continue
  feature="$(basename "$review_file" .md)"

  # Extract the most recent overall verdict.
  # Review files use "overall_qc: APPROVED" or standalone "APPROVED"
  # after a "## Verdict" heading.  Take the last occurrence.
  verdict=""

  # First try "overall_qc:" lines (takes the last one in the file)
  overall_line="$(grep -i '^overall_qc:' "$review_file" 2>/dev/null | tail -1 || true)"
  if [ -n "$overall_line" ]; then
    verdict="$(echo "$overall_line" | sed 's/^overall_qc:[[:space:]]*//' | tr -d '[:space:]')"
  fi

  # Fallback: try "Status: APPROVED" (older review format)
  if [ -z "$verdict" ]; then
    status_line="$(grep -i '^Status:' "$review_file" 2>/dev/null | tail -1 || true)"
    if [ -n "$status_line" ]; then
      case "$status_line" in
        *APPROVED*) verdict="APPROVED" ;;
        *NEEDS_REWORK*) verdict="NEEDS_REWORK" ;;
      esac
    fi
  fi

  # Fallback: look for standalone verdict lines after "## Verdict"
  if [ -z "$verdict" ]; then
    verdict_line="$(grep -A1 '^## Verdict' "$review_file" 2>/dev/null | tail -1 | tr -d '[:space:]' || true)"
    case "$verdict_line" in
      APPROVED|NEEDS_REWORK) verdict="$verdict_line" ;;
    esac
  fi

  if [ -z "$verdict" ]; then
    QC_CAL_COUNT=$((QC_CAL_COUNT + 1))
    add_info "QC calibration: could not extract verdict from \`dev/reviews/${feature}.md\`"
    continue
  fi

  # Check for audit trail record
  has_audit=false
  for audit_file in "${REPO_ROOT}"/dev/audit/*-"${feature}".json; do
    if [ -f "$audit_file" ]; then
      has_audit=true
      break
    fi
  done
  if ! $has_audit; then
    QC_CAL_COUNT=$((QC_CAL_COUNT + 1))
    add_info "QC calibration: \`${feature}\` has review (verdict: ${verdict}) but no audit trail in \`dev/audit/\`"
  fi

  # Cross-reference verdict against current test health
  if $DUNE_AVAILABLE; then
    test_dirs="$(_test_dirs_for_feature "$feature")"
    if [ -z "$test_dirs" ]; then
      QC_CAL_COUNT=$((QC_CAL_COUNT + 1))
      add_info "QC calibration: no test directory mapping for feature \`${feature}\`"
      continue
    fi

    tests_pass=true
    failing_dir=""
    for tdir in $test_dirs; do
      # Check both the source and build paths
      if [ -d "${REPO_ROOT}/trading/${tdir}" ]; then
        if ! (cd "${REPO_ROOT}/trading" && dune runtest "$tdir" 2>/dev/null); then
          tests_pass=false
          failing_dir="$tdir"
          break
        fi
      fi
    done

    if [ "$verdict" = "APPROVED" ] && ! $tests_pass; then
      QC_CAL_COUNT=$((QC_CAL_COUNT + 1))
      add_warning "QC calibration mismatch: \`${feature}\` review says APPROVED but \`dune runtest ${failing_dir}\` fails — regression since review"
      QC_CAL_DETAILS="${QC_CAL_DETAILS}  - \`${feature}\`: verdict APPROVED, tests FAILING in \`${failing_dir}\`\n"
    elif [ "$verdict" = "NEEDS_REWORK" ] && $tests_pass; then
      QC_CAL_COUNT=$((QC_CAL_COUNT + 1))
      add_info "QC calibration: \`${feature}\` review says NEEDS_REWORK but all tests currently pass — review may be stale"
      QC_CAL_DETAILS="${QC_CAL_DETAILS}  - \`${feature}\`: verdict NEEDS_REWORK, tests PASSING\n"
    fi
  fi
done

# ────────────────────────────────────────────────────────────────
# Rework-streak escalation scan (H-REWORK-STREAK-ESCALATION-UNTESTED)
# ────────────────────────────────────────────────────────────────
#
# write_audit.sh (T3-D) computes and records "consecutive_rework_count"
# in every dev/audit/*.json record it writes (see that script's "Compute
# consecutive_rework_count" section). Its own docstring states the policy
# this scan implements: "The escalation policy ... triggers human review
# when consecutive_rework_count >= 3 for any feature" (write_audit.sh:37).
#
# record_qc_audit_test.sh scenario 7e already regression-tests that
# write_audit.sh COMPUTES the field correctly (three consecutive
# NEEDS_REWORK calls on one branch reach consecutive_rework_count=3). But
# until this scan existed, nothing ever READ the field back — a feature
# could stack three (or more) consecutive NEEDS_REWORK verdicts and no
# mechanical check would surface it for human review. This scan is that
# missing consumer.
#
# Scans every dev/audit/*.json record, extracts (feature,
# recorded_at_ns, consecutive_rework_count), and reports the count from
# the LATEST record per feature — NOT the highest count ever seen.
#
# This must key on recency, not magnitude, because write_audit.sh
# defines the field as a live streak that RESETS: "If the current
# verdict is NEEDS_REWORK, the count includes this record. If APPROVED,
# the streak resets to 0." (write_audit.sh, "Compute
# consecutive_rework_count"). A feature that hit consecutive_rework_count=4
# and was subsequently APPROVED has its most recent record at 0 — that
# is a RESOLVED streak. Keying on the max instead of the latest would
# make the escalation permanently unclearable: dev/audit/*.json records
# are committed and never pruned, so a resolved feature's old high-water
# mark would warn forever, on every future run, with no action able to
# silence it (H-REWORK-STREAK-ESCALATION-UNTESTED rework, 2026-08-16 QC
# finding). This mirrors the pre-existing verdict-extraction logic
# earlier in this same file, which already keys on recency ("Take the
# last occurrence").
#
# Tie-break when two records for one feature share the same
# recorded_at_ns: prefer the HIGHER count. Ties are NOT limited to
# legacy records predating the field — write_audit.sh itself falls back
# to whole-second resolution (scaled to ns) on any platform without GNU
# `date +%s%N`, so two MODERN records written in the same second can tie
# too, and WRITE_AUDIT_RECORDED_AT_NS can set the value directly. This
# tie-break favors escalating over silently dropping a real streak when
# write order can't be determined, consistent with write_audit.sh's own
# stated preference (see its H-PREV-VERDICT-PIPEFAIL discussion: "a
# missed escalation is a much worse failure than an occasional
# over-sensitive one"). Within an all-legacy tie set (every record for a
# feature lacks recorded_at_ns and so defaults to 0 — see below), this
# rule degenerates to max-across-history: the same semantics this scan
# otherwise avoids by keying on the latest record, restricted to frozen
# history that can no longer change. That degeneration has no live
# impact today (no new zero-timestamp records can be created, and the
# live scan currently reports REWORK_STREAK_COUNT=0) but is stated here
# plainly rather than implying legacy ties are inert.
#
# Records written before the "consecutive_rework_count" field existed
# (legacy-shaped records; see write_audit.sh's own discussion of
# pre-field records) are skipped — neither counted nor treated as a
# malformed/crashing input. Records that have consecutive_rework_count
# but predate "recorded_at_ns" default to recorded_at_ns=0 (oldest),
# matching write_audit.sh's own convention for the same field — this
# default (line below) is pinned by the featureG fixture in
# deep_scan_rework_streak_check.sh (81 of 121 live dev/audit/ records,
# 67%, take this shape: count present, recorded_at_ns absent).

REWORK_STREAK_THRESHOLD=3  # write_audit.sh:37 — "consecutive_rework_count >= 3"
REWORK_STREAK_COUNT=0

_streak_raw="$(mktemp)"
: > "$_streak_raw"

for audit_file in "${REPO_ROOT}"/dev/audit/*.json; do
  [ -f "$audit_file" ] || continue
  streak_feature=""
  streak_count=""
  streak_recorded_at=""
  streak_feature="$(grep -o '"feature": *"[^"]*"' "$audit_file" 2>/dev/null | head -1 | sed 's/.*: *"//;s/"$//')" || true
  streak_count="$(grep -o '"consecutive_rework_count": *[0-9]*' "$audit_file" 2>/dev/null | head -1 | sed 's/.*: *//')" || true
  [ -z "$streak_feature" ] && continue
  [ -z "$streak_count" ] && continue
  streak_recorded_at="$(grep -o '"recorded_at_ns": *[0-9]*' "$audit_file" 2>/dev/null | head -1 | sed 's/.*: *//')" || true
  [ -z "$streak_recorded_at" ] && streak_recorded_at=0
  printf '%s:%s:%s\n' "$streak_feature" "$streak_recorded_at" "$streak_count" >> "$_streak_raw"
done

if [ -s "$_streak_raw" ]; then
  # Sort by recorded_at_ns descending (write order — latest first), then
  # by count descending as the tie-break above, then keep only the FIRST
  # line seen per feature — after the sort, that first line is the
  # latest record for that feature (ties broken toward the higher
  # count). Assumes feature names never contain ":" (true of every
  # feature slug this repo has ever used — screener, data-layer,
  # portfolio-stops, simulation, harness-<item>, etc.).
  while IFS=: read -r sf sn sc; do
    [ -z "$sf" ] && continue
    if [ "$sc" -ge "$REWORK_STREAK_THRESHOLD" ] 2>/dev/null; then
      REWORK_STREAK_COUNT=$((REWORK_STREAK_COUNT + 1))
      add_warning "Rework streak: \`${sf}\` has consecutive_rework_count=${sc} (>= ${REWORK_STREAK_THRESHOLD}) — escalation policy (write_audit.sh:37) recommends human review"
    fi
  done << STREAKEOF
$(sort -t: -k2,2rn -k3,3rn "$_streak_raw" | awk -F: '!seen[$1]++')
STREAKEOF
fi

rm -f "$_streak_raw"

add_metric QC_CAL_COUNT "$QC_CAL_COUNT"
add_metric DUNE_AVAILABLE "$DUNE_AVAILABLE"
add_metric REWORK_STREAK_COUNT "$REWORK_STREAK_COUNT"
flush_findings

if [ -n "$QC_CAL_DETAILS" ]; then
  printf "\n## QC Calibration Detail\n" >> "$REPORT_FILE"
  printf '%b' "$QC_CAL_DETAILS" >> "$REPORT_FILE"
fi
