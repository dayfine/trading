#!/bin/sh
# Deep scan orchestrator — calls each per-check script in order,
# collects findings, and assembles the final report.
#
# Usage: sh main.sh
#   (also invoked via the deep_scan.sh shim at trading/devtools/checks/deep_scan.sh)
#
# Output: dev/health/YYYY-MM-DD-deep.md
#
# Each per-check script:
#   - Appends its detail section to a temp detail file.
#   - Writes severity findings + metrics to a temp findings file.
# This script collects all findings, writes the consolidated header,
# then appends the detail sections to produce the final report.

set -e

CHECKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEEP_SCAN_DIR="$(cd "$(dirname "$0")" && pwd)"

. "${CHECKS_DIR}/_check_lib.sh"

REPO_ROOT="$(repo_root)"
TODAY="$(date +%Y-%m-%d)"
OUTPUT_DIR="${REPO_ROOT}/dev/health"
OUTPUT_FILE="${OUTPUT_DIR}/${TODAY}-deep.md"

mkdir -p "$OUTPUT_DIR"

# Temp files for this run (cleaned up on exit).
DETAIL_FILE="$(mktemp -t deep-scan-detail-XXXXXX.md)"
FINDINGS_DIR="$(mktemp -d -t deep-scan-findings-XXXXXX)"
trap 'rm -f "$DETAIL_FILE"; rm -rf "$FINDINGS_DIR"' EXIT

# ── Run all checks ────────────────────────────────────────────────
#
# Each check receives:
#   $1  DETAIL_FILE  — appends its section header + body here
#   $2  FINDINGS_DIR/NN.findings  — writes severity lines + metric lines here
#
# Ordering matters for Check 8 Trends, which reads the sidecar file
# produced by Check 5.  All other checks are order-independent.

_run_check() {
  num="$1"
  script="${DEEP_SCAN_DIR}/$2"
  findings_file="${FINDINGS_DIR}/${num}.findings"
  : > "$findings_file"
  sh "$script" "$DETAIL_FILE" "$findings_file"
}

# Run checks in the order that matches the expected report section layout.
# Checks 1-7 write the numbered detail sections (TODO detail, Size detail, etc.)
# Checks 10, 12, 9, 8, 11 write the "always-emit" sections in the original order:
#   ## Status File Template → ## Stale Local Bookmarks → ## Architecture Graph
#   → ## Trends → ## Linter Exception Expiry
#
# Check 5 (followup) must run before Check 8 (trends) because Check 8 reads
# the sidecar file produced by Check 5.

_run_check "01" "check_01_dead_code.sh"
_run_check "02" "check_02_design_doc_drift.sh"
_run_check "03" "check_03_todo_fixme.sh"
_run_check "04" "check_04_size_violations.sh"
_run_check "05" "check_05_followup_items.sh"
_run_check "06" "check_06_qc_calibration.sh"
_run_check "07" "check_07_harness_scaffolding.sh"
_run_check "10" "check_10_status_template.sh"
_run_check "12" "check_12_stale_bookmarks.sh"
_run_check "09" "check_09_arch_graph.sh"
_run_check "08" "check_08_trends.sh"
_run_check "11" "check_11_linter_expiry.sh"

# ── Aggregate findings from all checks ──────────────────────────

CRITICAL=""
WARNINGS=""
INFO=""
CRITICAL_COUNT=0
WARNING_COUNT=0
INFO_COUNT=0

# Metric accumulators (read from "M: KEY=value" lines in findings files).
DEAD_CODE_COUNT=0
DRIFT_COUNT=0
TOTAL_ANNOTATIONS=0
TODO_COUNT=0
FIXME_COUNT=0
HACK_COUNT=0
SIZE_VIOLATION_COUNT=0
FOLLOWUP_COUNT=0
QC_CAL_COUNT=0
DUNE_AVAILABLE=false
ARCH_GRAPH_VIOLATION_COUNT=0
RECENT_COMMITS_COUNT=0
EXPIRY_COUNT=0
EXPIRY_MISSING_COUNT=0

for findings_file in "${FINDINGS_DIR}"/*.findings; do
  [ -f "$findings_file" ] || continue
  while IFS= read -r fline; do
    [ -z "$fline" ] && continue
    case "$fline" in
      "C: "*)
        msg="${fline#C: }"
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        CRITICAL="${CRITICAL}${CRITICAL_COUNT}. ${msg}\n"
        ;;
      "W: "*)
        msg="${fline#W: }"
        WARNING_COUNT=$((WARNING_COUNT + 1))
        WARNINGS="${WARNINGS}${WARNING_COUNT}. ${msg}\n"
        ;;
      "I: "*)
        msg="${fline#I: }"
        INFO_COUNT=$((INFO_COUNT + 1))
        INFO="${INFO}${INFO_COUNT}. ${msg}\n"
        ;;
      "M: "*)
        kv="${fline#M: }"
        key="${kv%%=*}"
        val="${kv#*=}"
        case "$key" in
          DEAD_CODE_COUNT)          DEAD_CODE_COUNT="$val" ;;
          DRIFT_COUNT)              DRIFT_COUNT="$val" ;;
          TOTAL_ANNOTATIONS)        TOTAL_ANNOTATIONS="$val" ;;
          TODO_COUNT)               TODO_COUNT="$val" ;;
          FIXME_COUNT)              FIXME_COUNT="$val" ;;
          HACK_COUNT)               HACK_COUNT="$val" ;;
          SIZE_VIOLATION_COUNT)     SIZE_VIOLATION_COUNT="$val" ;;
          FOLLOWUP_COUNT)           FOLLOWUP_COUNT="$val" ;;
          QC_CAL_COUNT)             QC_CAL_COUNT="$val" ;;
          DUNE_AVAILABLE)           DUNE_AVAILABLE="$val" ;;
          ARCH_GRAPH_VIOLATION_COUNT) ARCH_GRAPH_VIOLATION_COUNT="$val" ;;
          RECENT_COMMITS_COUNT)     RECENT_COMMITS_COUNT="$val" ;;
          EXPIRY_COUNT)             EXPIRY_COUNT="$val" ;;
          EXPIRY_MISSING_COUNT)     EXPIRY_MISSING_COUNT="$val" ;;
        esac
        ;;
    esac
  done < "$findings_file"
done

# ── Write final report ───────────────────────────────────────────

TOTAL_FINDINGS=$((CRITICAL_COUNT + WARNING_COUNT + INFO_COUNT))

if [ "$TOTAL_FINDINGS" -eq 0 ]; then
  ACTION="NO"
elif [ "$CRITICAL_COUNT" -gt 0 ]; then
  ACTION="YES"
else
  ACTION="NO"
fi

cat > "$OUTPUT_FILE" <<REPORT_EOF
# Health Report -- ${TODAY} -- deep

## Summary
- Findings: ${TOTAL_FINDINGS}  (critical: ${CRITICAL_COUNT}  warnings: ${WARNING_COUNT}  info: ${INFO_COUNT})
- Action required: ${ACTION}

REPORT_EOF

if [ "$CRITICAL_COUNT" -gt 0 ]; then
  printf "## Critical (requires immediate action before next orchestrator run)\n" >> "$OUTPUT_FILE"
  printf '%b' "$CRITICAL" >> "$OUTPUT_FILE"
  printf "\n" >> "$OUTPUT_FILE"
fi

if [ "$WARNING_COUNT" -gt 0 ]; then
  printf "## Warnings (should be addressed within 1 week)\n" >> "$OUTPUT_FILE"
  printf '%b' "$WARNINGS" >> "$OUTPUT_FILE"
  printf "\n" >> "$OUTPUT_FILE"
fi

if [ "$INFO_COUNT" -gt 0 ]; then
  printf "## Info (no immediate action; awareness only)\n" >> "$OUTPUT_FILE"
  printf '%b' "$INFO" >> "$OUTPUT_FILE"
  printf "\n" >> "$OUTPUT_FILE"
fi

cat >> "$OUTPUT_FILE" <<METRICS_EOF
## Metrics
- Dead code candidates: ${DEAD_CODE_COUNT}
- Design doc drift items: ${DRIFT_COUNT}
- TODO/FIXME/HACK annotations: ${TOTAL_ANNOTATIONS} (TODO: ${TODO_COUNT}, FIXME: ${FIXME_COUNT}, HACK: ${HACK_COUNT})
- Files >300 lines: ${SIZE_VIOLATION_COUNT}
- Open follow-up items: ${FOLLOWUP_COUNT} (maintenance threshold: 10)
- QC calibration findings: ${QC_CAL_COUNT} (dune available: ${DUNE_AVAILABLE})
- Architecture graph violations (monitored): ${ARCH_GRAPH_VIOLATION_COUNT}
- Status file template violations (forbidden ## Recent Commits): ${RECENT_COMMITS_COUNT}
- Linter exception expiry: ${EXPIRY_COUNT} expired/unknown, ${EXPIRY_MISSING_COUNT} missing review_at
METRICS_EOF

# Append all detail sections collected from the per-check scripts.
cat "$DETAIL_FILE" >> "$OUTPUT_FILE"

echo ""
echo "Deep scan complete. Report written to: ${OUTPUT_FILE}"
echo "  Findings: ${TOTAL_FINDINGS} (critical: ${CRITICAL_COUNT}, warnings: ${WARNING_COUNT}, info: ${INFO_COUNT})"
