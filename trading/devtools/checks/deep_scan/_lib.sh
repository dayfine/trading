#!/bin/sh
# Shared helpers for deep_scan/ per-check scripts.
#
# Source this file from any check script:
#   . "$(dirname "$0")/_lib.sh"
#
# After sourcing:
#   - REPO_ROOT, TRADING_DIR, TODAY are available
#   - emit_finding / emit_metric write to FINDINGS_FILE (if set) or stdout
#   - add_critical / add_warning / add_info are convenient wrappers
#
# Per-check scripts:
#   1. Source this file.
#   2. Accumulate findings via add_critical / add_warning / add_info.
#   3. Write their detail section via >> "$REPORT_FILE".
#   4. Flush findings via flush_findings (writes to FINDINGS_FILE or stdout).
#
# Calling convention (used by main.sh and for standalone runs):
#   sh check_NN_name.sh <report_file> [findings_file]
#
# When findings_file is omitted (standalone run), findings are written to
# <report_file> as a standalone section so the output is still meaningful.

# Source the repo-level check lib for repo_root() and die().
. "$(dirname "$0")/../_check_lib.sh"

# Path constants (available to all check scripts after sourcing this file).
REPO_ROOT="$(repo_root)"
TRADING_DIR="${REPO_ROOT}/trading"
TODAY="$(date +%Y-%m-%d)"
OUTPUT_DIR="${REPO_ROOT}/dev/health"

# REPORT_FILE and FINDINGS_FILE are set by each check script from its args.

# Per-process accumulators (reset to empty when _lib.sh is sourced).
CRITICAL=""
WARNINGS=""
INFO=""
CRITICAL_COUNT=0
WARNING_COUNT=0
INFO_COUNT=0

# Metric key=value pairs (newline-separated), e.g. "DEAD_CODE_COUNT=3".
METRICS_OUT=""

add_critical() {
  CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
  CRITICAL="${CRITICAL}${CRITICAL_COUNT}. $1\n"
}

add_warning() {
  WARNING_COUNT=$((WARNING_COUNT + 1))
  WARNINGS="${WARNINGS}${WARNING_COUNT}. $1\n"
}

add_info() {
  INFO_COUNT=$((INFO_COUNT + 1))
  INFO="${INFO}${INFO_COUNT}. $1\n"
}

add_metric() {
  # Usage: add_metric KEY value
  METRICS_OUT="${METRICS_OUT}$1=$2\n"
}

# flush_findings: write accumulated findings + metrics to FINDINGS_FILE.
# If FINDINGS_FILE is not set, write inline to REPORT_FILE as a standalone
# findings block (useful for standalone check runs).
flush_findings() {
  if [ -n "${FINDINGS_FILE:-}" ]; then
    # Structured format consumed by main.sh.
    # Each severity line: "C: <message>", "W: <message>", "I: <message>"
    # Each metric line:   "M: KEY=value"
    if [ "$CRITICAL_COUNT" -gt 0 ]; then
      printf '%b' "$CRITICAL" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Strip leading "N. " counter prefix from the line
        msg="$(printf '%s' "$line" | sed 's/^[0-9][0-9]*\. //')"
        printf 'C: %s\n' "$msg"
      done >> "$FINDINGS_FILE"
    fi
    if [ "$WARNING_COUNT" -gt 0 ]; then
      printf '%b' "$WARNINGS" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        msg="$(printf '%s' "$line" | sed 's/^[0-9][0-9]*\. //')"
        printf 'W: %s\n' "$msg"
      done >> "$FINDINGS_FILE"
    fi
    if [ "$INFO_COUNT" -gt 0 ]; then
      printf '%b' "$INFO" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        msg="$(printf '%s' "$line" | sed 's/^[0-9][0-9]*\. //')"
        printf 'I: %s\n' "$msg"
      done >> "$FINDINGS_FILE"
    fi
    if [ -n "$METRICS_OUT" ]; then
      printf '%b' "$METRICS_OUT" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        printf 'M: %s\n' "$line"
      done >> "$FINDINGS_FILE"
    fi
  else
    # Standalone mode: write findings directly into the report as a block.
    if [ "$CRITICAL_COUNT" -gt 0 ]; then
      printf "\n### Critical\n" >> "$REPORT_FILE"
      printf '%b' "$CRITICAL" >> "$REPORT_FILE"
    fi
    if [ "$WARNING_COUNT" -gt 0 ]; then
      printf "\n### Warnings\n" >> "$REPORT_FILE"
      printf '%b' "$WARNINGS" >> "$REPORT_FILE"
    fi
    if [ "$INFO_COUNT" -gt 0 ]; then
      printf "\n### Info\n" >> "$REPORT_FILE"
      printf '%b' "$INFO" >> "$REPORT_FILE"
    fi
  fi
}
