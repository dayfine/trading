#!/bin/sh
# Check 4: Size violations — files >300 lines without @large-module.
#
# Usage: sh check_04_size_violations.sh <report_file> [findings_file]

set -e

REPORT_FILE="${1:?Usage: check_04_size_violations.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 4: Size violations — files >300 lines without @large-module
# ────────────────────────────────────────────────────────────────

SIZE_VIOLATION_COUNT=0
SIZE_DETAILS=""

for ml_file in $(find "$TRADING_DIR" -path "*/lib/*.ml" \
    -not -path "*/_build/*" \
    -not -path "*/.formatted/*" \
    -not -name "*.pp.ml" | sort); do
  line_count=$(wc -l < "$ml_file")
  if [ "$line_count" -gt 300 ]; then
    rel_path="${ml_file#"$TRADING_DIR"/}"
    if grep -q "@large-module" "$ml_file" 2>/dev/null; then
      # Declared large — only flag if over 500 (hard limit)
      if [ "$line_count" -gt 500 ]; then
        SIZE_VIOLATION_COUNT=$((SIZE_VIOLATION_COUNT + 1))
        add_warning "Size violation: \`${rel_path}\` — ${line_count} lines (declared-large, hard limit: 500)"
        SIZE_DETAILS="${SIZE_DETAILS}  - \`${rel_path}\`: ${line_count} lines (declared-large, over hard limit)\n"
      else
        add_info "Near size limit: \`${rel_path}\` — ${line_count} lines (declared-large, limit: 500)"
        SIZE_DETAILS="${SIZE_DETAILS}  - \`${rel_path}\`: ${line_count} lines (declared-large)\n"
      fi
    else
      SIZE_VIOLATION_COUNT=$((SIZE_VIOLATION_COUNT + 1))
      add_warning "Size violation: \`${rel_path}\` — ${line_count} lines (limit: 300, missing @large-module)"
      SIZE_DETAILS="${SIZE_DETAILS}  - \`${rel_path}\`: ${line_count} lines (over 300-line limit)\n"
    fi
  fi
done

add_metric SIZE_VIOLATION_COUNT "$SIZE_VIOLATION_COUNT"
flush_findings

if [ -n "$SIZE_DETAILS" ]; then
  printf "\n## Size Violation Detail\n" >> "$REPORT_FILE"
  printf '%b' "$SIZE_DETAILS" >> "$REPORT_FILE"
fi
