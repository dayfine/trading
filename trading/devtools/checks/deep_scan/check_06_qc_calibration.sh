#!/bin/sh
# Check 6: QC calibration audit — verdicts vs current test health.
#
# Usage: sh check_06_qc_calibration.sh <report_file> [findings_file]
#
# For each feature with a QC review (dev/reviews/*.md), extract the
# most recent overall verdict and cross-reference against whether the
# feature's test directories currently pass `dune runtest`.
#
# This detects two classes of drift:
#   a) QC said APPROVED but tests now fail (regression since review)
#   b) Missing audit trail record for a reviewed feature
#
# The dune check is skipped if `dune` is not on PATH (e.g. running
# outside the dev container).

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

add_metric QC_CAL_COUNT "$QC_CAL_COUNT"
add_metric DUNE_AVAILABLE "$DUNE_AVAILABLE"
flush_findings

if [ -n "$QC_CAL_DETAILS" ]; then
  printf "\n## QC Calibration Detail\n" >> "$REPORT_FILE"
  printf '%b' "$QC_CAL_DETAILS" >> "$REPORT_FILE"
fi
