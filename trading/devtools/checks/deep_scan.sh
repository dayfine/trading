#!/bin/sh
# Deep scan for health-scanner agent (T3-A).
#
# Runs weekly (not on every PR). Performs four read-only analyses:
#   1. Dead code detection — .ml files not referenced in any dune file
#   2. Design doc drift — module structure vs eng-design docs
#   3. TODO/FIXME/HACK accumulation
#   4. Size violations — files >300 lines without @large-module
#
# Output: dev/health/YYYY-MM-DD-deep.md
#
# Usage:
#   sh trading/devtools/checks/deep_scan.sh
#   # or from Docker:
#   docker exec trading-1-dev bash -c \
#     'cd /workspaces/trading-1 && sh trading/devtools/checks/deep_scan.sh'
#
# This script is read-only — it never modifies source files.

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
TRADING_DIR="${REPO_ROOT}/trading"
TODAY="$(date +%Y-%m-%d)"
OUTPUT_DIR="${REPO_ROOT}/dev/health"
OUTPUT_FILE="${OUTPUT_DIR}/${TODAY}-deep.md"

mkdir -p "$OUTPUT_DIR"

# Accumulators for findings
CRITICAL=""
WARNINGS=""
INFO=""
CRITICAL_COUNT=0
WARNING_COUNT=0
INFO_COUNT=0

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

# ────────────────────────────────────────────────────────────────
# Check 1: Dead code — .ml files in lib/ not referenced by dune
# ────────────────────────────────────────────────────────────────

DEAD_CODE_COUNT=0

# Build set of modules listed in dune files (library stanzas implicitly
# include all .ml files in their directory, so a file is "referenced" if
# it lives in a directory that has a dune file with a library stanza).
# Files outside any library directory are dead code candidates.
for ml_file in $(find "$TRADING_DIR" -path "*/lib/*.ml" \
    -not -path "*/_build/*" \
    -not -path "*/.formatted/*" \
    -not -name "*.pp.ml"); do
  lib_dir="$(dirname "$ml_file")"
  dune_file="${lib_dir}/dune"
  if [ ! -f "$dune_file" ]; then
    DEAD_CODE_COUNT=$((DEAD_CODE_COUNT + 1))
    rel_path="${ml_file#"$TRADING_DIR"/}"
    add_info "Dead code candidate: \`${rel_path}\` — no dune file in its lib/ directory"
  fi
done

# Also check for .ml files in lib/ directories whose dune file uses
# (modules ...) — files not listed in the modules stanza are dead.
for dune_file in $(find "$TRADING_DIR" -path "*/lib/dune" \
    -not -path "*/_build/*"); do
  if grep -q '(modules' "$dune_file" 2>/dev/null; then
    lib_dir="$(dirname "$dune_file")"
    # Extract module names from (modules ...) — this is a rough parse
    modules_line="$(sed -n '/(modules/,/)/p' "$dune_file" | tr '\n' ' ')"
    for ml_file in "$lib_dir"/*.ml; do
      [ -f "$ml_file" ] || continue
      basename_no_ext="$(basename "$ml_file" .ml)"
      # Skip .mli-only check; just check .ml
      if ! echo "$modules_line" | grep -qi "$basename_no_ext"; then
        DEAD_CODE_COUNT=$((DEAD_CODE_COUNT + 1))
        rel_path="${ml_file#"$TRADING_DIR"/}"
        add_info "Dead code candidate: \`${rel_path}\` — not listed in (modules ...) stanza"
      fi
    done
  fi
done

# ────────────────────────────────────────────────────────────────
# Check 2: Design doc drift — actual modules vs eng-design docs
# ────────────────────────────────────────────────────────────────

DRIFT_COUNT=0

# eng-design-2 covers analysis/weinstein modules
DESIGN_2="${REPO_ROOT}/docs/design/eng-design-2-screener-analysis.md"
if [ -f "$DESIGN_2" ]; then
  # Actual top-level directories under analysis/weinstein/
  actual_analysis=""
  for d in "$TRADING_DIR"/analysis/weinstein/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    # Skip build artifacts and test directories
    case "$name" in
      _build|test|.formatted) continue ;;
    esac
    actual_analysis="${actual_analysis} ${name}"
  done

  for mod in $actual_analysis; do
    if ! grep -qi "$mod" "$DESIGN_2" 2>/dev/null; then
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
      add_warning "Design doc drift: \`analysis/weinstein/${mod}/\` exists on disk but not mentioned in \`eng-design-2-screener-analysis.md\`"
    fi
  done
fi

# eng-design-3 covers trading/weinstein modules
DESIGN_3="${REPO_ROOT}/docs/design/eng-design-3-portfolio-stops.md"
if [ -f "$DESIGN_3" ]; then
  actual_trading=""
  for d in "$TRADING_DIR"/trading/weinstein/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    case "$name" in
      _build|test|.formatted) continue ;;
    esac
    actual_trading="${actual_trading} ${name}"
  done

  for mod in $actual_trading; do
    if ! grep -qi "$mod" "$DESIGN_3" 2>/dev/null; then
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
      add_warning "Design doc drift: \`trading/weinstein/${mod}/\` exists on disk but not mentioned in \`eng-design-3-portfolio-stops.md\`"
    fi
  done
fi

# eng-design-1 covers data layer
DESIGN_1="${REPO_ROOT}/docs/design/eng-design-1-data-layer.md"
if [ -f "$DESIGN_1" ]; then
  for d in "$TRADING_DIR"/analysis/weinstein/data_source/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    case "$name" in
      _build|test|.formatted|lib) continue ;;
    esac
    if ! grep -qi "$name" "$DESIGN_1" 2>/dev/null; then
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
      add_warning "Design doc drift: \`analysis/weinstein/data_source/${name}/\` exists on disk but not mentioned in \`eng-design-1-data-layer.md\`"
    fi
  done
fi

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

# List individual TODO/FIXME/HACK locations for the report
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

# ────────────────────────────────────────────────────────────────
# Check 5: Follow-up item count (from status files)
# ────────────────────────────────────────────────────────────────

FOLLOWUP_COUNT=0
for status_file in "${REPO_ROOT}"/dev/status/*.md; do
  [ -f "$status_file" ] || continue
  # Count lines starting with "- " under ## Follow-up or ## Followup sections
  in_followup=false
  while IFS= read -r line; do
    case "$line" in
      "## Follow-up"*|"## Followup"*)
        in_followup=true
        continue
        ;;
      "## "*)
        in_followup=false
        continue
        ;;
    esac
    if $in_followup; then
      case "$line" in
        "- "*)
          # Skip struck-through items (~~text~~)
          if echo "$line" | grep -q '^- ~~.*~~'; then
            continue
          fi
          FOLLOWUP_COUNT=$((FOLLOWUP_COUNT + 1))
          ;;
      esac
    fi
  done < "$status_file"
done

if [ "$FOLLOWUP_COUNT" -gt 10 ]; then
  add_warning "Follow-up accumulation: ${FOLLOWUP_COUNT} open items across status files (threshold: 10)"
elif [ "$FOLLOWUP_COUNT" -gt 0 ]; then
  add_info "Follow-up items: ${FOLLOWUP_COUNT} total across status files"
fi

# ────────────────────────────────────────────────────────────────
# Generate report
# ────────────────────────────────────────────────────────────────

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
METRICS_EOF

# Append detail sections if non-empty
if [ -n "$TODO_DETAILS" ]; then
  printf "\n## TODO/FIXME/HACK Detail\n" >> "$OUTPUT_FILE"
  printf '%b' "$TODO_DETAILS" >> "$OUTPUT_FILE"
fi

if [ -n "$SIZE_DETAILS" ]; then
  printf "\n## Size Violation Detail\n" >> "$OUTPUT_FILE"
  printf '%b' "$SIZE_DETAILS" >> "$OUTPUT_FILE"
fi

echo ""
echo "Deep scan complete. Report written to: ${OUTPUT_FILE}"
echo "  Findings: ${TOTAL_FINDINGS} (critical: ${CRITICAL_COUNT}, warnings: ${WARNING_COUNT}, info: ${INFO_COUNT})"
