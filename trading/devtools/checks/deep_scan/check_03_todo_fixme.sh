#!/bin/sh
# Check 3: TODO / FIXME / HACK accumulation.
#
# Usage: sh check_03_todo_fixme.sh <report_file> [findings_file]

set -e

REPORT_FILE="${1:?Usage: check_03_todo_fixme.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 3: TODO / FIXME / HACK accumulation
# ────────────────────────────────────────────────────────────────

TODO_COUNT=0
FIXME_COUNT=0
HACK_COUNT=0

# Count across all .ml and .mli files (excluding build artifacts).
# Match uppercase markers only — these are conventional annotation tags.
# Exclude _build/ via --exclude-dir.
TODO_COUNT=$(grep -r --include="*.ml" --include="*.mli" --exclude-dir="_build" \
  -c 'TODO' "$TRADING_DIR" 2>/dev/null \
  | awk -F: '{s+=$2} END {print s+0}' || echo 0)

FIXME_COUNT=$(grep -r --include="*.ml" --include="*.mli" --exclude-dir="_build" \
  -c 'FIXME' "$TRADING_DIR" 2>/dev/null \
  | awk -F: '{s+=$2} END {print s+0}' || echo 0)

HACK_COUNT=$(grep -r --include="*.ml" --include="*.mli" --exclude-dir="_build" \
  -c 'HACK' "$TRADING_DIR" 2>/dev/null \
  | awk -F: '{s+=$2} END {print s+0}' || echo 0)

TOTAL_ANNOTATIONS=$((TODO_COUNT + FIXME_COUNT + HACK_COUNT))

if [ "$TOTAL_ANNOTATIONS" -gt 20 ]; then
  add_warning "TODO/FIXME/HACK accumulation: ${TOTAL_ANNOTATIONS} total annotations (TODO: ${TODO_COUNT}, FIXME: ${FIXME_COUNT}, HACK: ${HACK_COUNT})"
elif [ "$TOTAL_ANNOTATIONS" -gt 0 ]; then
  add_info "TODO/FIXME/HACK annotations: ${TOTAL_ANNOTATIONS} total (TODO: ${TODO_COUNT}, FIXME: ${FIXME_COUNT}, HACK: ${HACK_COUNT})"
fi

add_metric TODO_COUNT "$TODO_COUNT"
add_metric FIXME_COUNT "$FIXME_COUNT"
add_metric HACK_COUNT "$HACK_COUNT"
add_metric TOTAL_ANNOTATIONS "$TOTAL_ANNOTATIONS"
flush_findings

# Detail section: list individual TODO/FIXME/HACK locations.
TODO_DETAILS=""
for pattern in "TODO" "FIXME" "HACK"; do
  matches=$(grep -rn --include="*.ml" --include="*.mli" --exclude-dir="_build" \
    "$pattern" "$TRADING_DIR" 2>/dev/null \
    | grep -v ".formatted/" \
    | while IFS= read -r line; do
        rel="${line#"$TRADING_DIR"/}"
        echo "  - \`${rel}\`"
      done || true)
  if [ -n "$matches" ]; then
    TODO_DETAILS="${TODO_DETAILS}\n### ${pattern}\n${matches}\n"
  fi
done

if [ -n "$TODO_DETAILS" ]; then
  printf "\n## TODO/FIXME/HACK Detail\n" >> "$REPORT_FILE"
  printf '%b' "$TODO_DETAILS" >> "$REPORT_FILE"
fi
