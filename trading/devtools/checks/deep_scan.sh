#!/bin/sh
# Deep scan for health-scanner agent (T3-A).
#
# Runs weekly (not on every PR). Performs nine read-only analyses:
#   1. Dead code detection — .ml files not referenced in any dune file
#   2. Design doc drift — module structure vs eng-design docs
#   3. TODO/FIXME/HACK accumulation
#   4. Size violations — files >300 lines without @large-module
#   5. Follow-up item count (from status files)
#   6. QC calibration audit — verdicts vs current test health
#   7. Harness scaffolding review — flag unused or broken harness components
#   8. Trends — followup-item delta + CC distribution delta (T3-G)
#   9. Architecture graph — import edges vs dependency-rules.md (T3-F)
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
# FOLLOWUP_PER_FILE accumulates lines of the form "file:count" for Check 8 Trends.
FOLLOWUP_PER_FILE=""
for status_file in "${REPO_ROOT}"/dev/status/*.md; do
  [ -f "$status_file" ] || continue
  file_count=0
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
          file_count=$((file_count + 1))
          ;;
      esac
    fi
  done < "$status_file"
  if [ "$file_count" -gt 0 ]; then
    fname="$(basename "$status_file")"
    FOLLOWUP_PER_FILE="${FOLLOWUP_PER_FILE}${fname}:${file_count}\n"
  fi
done

if [ "$FOLLOWUP_COUNT" -gt 10 ]; then
  add_warning "Follow-up accumulation: ${FOLLOWUP_COUNT} open items across status files (threshold: 10)"
elif [ "$FOLLOWUP_COUNT" -gt 0 ]; then
  add_info "Follow-up items: ${FOLLOWUP_COUNT} total across status files"
fi

# ────────────────────────────────────────────────────────────────
# Check 6: QC calibration audit — verdicts vs current test health
# ────────────────────────────────────────────────────────────────
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
# Check 7: Harness scaffolding review
#
# Three heuristics (all advisory — WARNING or PASS, no FAIL):
#
#   H1: Shell script in trading/devtools/checks/ not referenced from any
#       dune file, GitHub workflow YAML, other *.sh in the same dir, or
#       any .claude/agents/*.md.  Exemptions: _check_lib.sh (library),
#       deep_scan.sh (run manually/by agent), write_audit.sh (run by
#       humans / ops-data agent, no dune rule).
#
#   H2: OCaml linter binary (fn_length_linter, cc_linter, nesting_linter)
#       whose %{exe:...} reference does not appear in
#       trading/devtools/checks/dune — built but never wired into runtest.
#
#   H3: .claude/agents/*.md references a harness script path
#       (matching "devtools/checks/*.sh" pattern) that does not exist
#       in the repo — broken reference in an agent definition.
# ────────────────────────────────────────────────────────────────

SCAFFOLD_DETAILS=""

# Exempt scripts: library helper, the deep scan itself, audit writer.
_is_exempt_script() {
  case "$(basename "$1")" in
    _check_lib.sh|deep_scan.sh|write_audit.sh) return 0 ;;
    *) return 1 ;;
  esac
}

# H1: shell scripts not referenced anywhere meaningful
CHECKS_DIR="${TRADING_DIR}/devtools/checks"
AGENTS_DIR="${REPO_ROOT}/.claude/agents"
WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"
CHECKS_DUNE="${CHECKS_DIR}/dune"

for sh_file in "${CHECKS_DIR}"/*.sh; do
  [ -f "$sh_file" ] || continue
  _is_exempt_script "$sh_file" && continue

  script_name="$(basename "$sh_file")"
  found=false

  # Check in dune file
  if [ -f "$CHECKS_DUNE" ] && grep -q "$script_name" "$CHECKS_DUNE" 2>/dev/null; then
    found=true
  fi

  # Check in GitHub workflow YAMLs
  if ! $found && [ -d "$WORKFLOWS_DIR" ]; then
    if grep -rl "$script_name" "$WORKFLOWS_DIR" 2>/dev/null | grep -q .; then
      found=true
    fi
  fi

  # Check in other *.sh files in the same directory (source/call chain)
  if ! $found; then
    for other_sh in "${CHECKS_DIR}"/*.sh; do
      [ -f "$other_sh" ] || continue
      [ "$other_sh" = "$sh_file" ] && continue
      if grep -q "$script_name" "$other_sh" 2>/dev/null; then
        found=true
        break
      fi
    done
  fi

  # Check in agent definitions
  if ! $found && [ -d "$AGENTS_DIR" ]; then
    if grep -rl "$script_name" "$AGENTS_DIR" 2>/dev/null | grep -q .; then
      found=true
    fi
  fi

  if $found; then
    SCAFFOLD_DETAILS="${SCAFFOLD_DETAILS}PASS: \`${script_name}\` — referenced\n"
  else
    add_warning "Harness scaffolding: \`${script_name}\` not referenced in dune, workflows, other scripts, or agent definitions"
    SCAFFOLD_DETAILS="${SCAFFOLD_DETAILS}WARNING: \`${script_name}\` — not referenced in dune, workflows, other scripts, or agent definitions\n"
  fi
done

# H2: OCaml linter binaries not wired into dune runtest
for linter_dir in "${TRADING_DIR}/devtools"/*/; do
  [ -d "$linter_dir" ] || continue
  linter_name="$(basename "$linter_dir")"
  # Only check directories with an OCaml executable (has a dune file with "executable")
  linter_dune="${linter_dir}dune"
  [ -f "$linter_dune" ] || continue
  grep -q '(executable' "$linter_dune" 2>/dev/null || continue

  # Extract the executable name from the dune file
  exe_name="$(grep '(name ' "$linter_dune" 2>/dev/null | head -1 | sed 's/.*name[[:space:]]*//' | tr -d '()[:space:]')"
  [ -z "$exe_name" ] && continue

  # Skip the checks dir itself (it has no executables, only shell scripts)
  [ "$linter_name" = "checks" ] && continue

  # Check if %{exe:../<linter_name>/<exe_name>.exe} appears in the checks dune
  if [ -f "$CHECKS_DUNE" ] && grep -q "${exe_name}[.]exe" "$CHECKS_DUNE" 2>/dev/null; then
    SCAFFOLD_DETAILS="${SCAFFOLD_DETAILS}PASS: \`${linter_name}/${exe_name}.exe\` — wired into dune runtest\n"
  else
    add_warning "Harness scaffolding: \`${linter_name}/${exe_name}.exe\` built but not referenced in \`devtools/checks/dune\`"
    SCAFFOLD_DETAILS="${SCAFFOLD_DETAILS}WARNING: \`${linter_name}/${exe_name}.exe\` — built but not referenced in devtools/checks/dune\n"
  fi
done

# H3: agent definitions referencing a harness script path that no longer exists.
# Only fires when the agent file explicitly mentions a devtools/checks/*.sh
# path.  Relative paths used in code-block examples (e.g. ../devtools/…)
# are normalised before the existence check so they don't produce noise.
if [ -d "$AGENTS_DIR" ]; then
  for agent_file in "${AGENTS_DIR}"/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name="$(basename "$agent_file")"
    # Extract paths matching *devtools/checks/*.sh from the agent definition.
    # grep -o emits one match per line; filter empty lines defensively.
    ref_paths="$(grep -o '[a-zA-Z0-9_./]*devtools/checks/[a-zA-Z0-9_.-]*\.sh' \
      "$agent_file" 2>/dev/null | sort -u || true)"
    [ -z "$ref_paths" ] && continue

    while IFS= read -r ref_path; do
      # Skip empty lines (defensive)
      [ -z "$ref_path" ] && continue
      # Normalize: strip leading "../" sequences and "trading/" prefix so
      # paths like "../devtools/checks/foo.sh" resolve from TRADING_DIR.
      norm_path="$ref_path"
      while echo "$norm_path" | grep -q '^\.\./' 2>/dev/null; do
        norm_path="${norm_path#../}"
      done
      norm_path="${norm_path#trading/}"
      # Try resolving from TRADING_DIR and from REPO_ROOT
      if [ -f "${TRADING_DIR}/${norm_path}" ] || \
         [ -f "${REPO_ROOT}/${norm_path}" ] || \
         [ -f "${REPO_ROOT}/trading/${norm_path}" ]; then
        : # path exists — no finding
      else
        add_warning "Harness scaffolding: \`${agent_name}\` references \`${ref_path}\` which does not exist on disk"
        SCAFFOLD_DETAILS="${SCAFFOLD_DETAILS}WARNING: \`${agent_name}\` — references missing path \`${ref_path}\`\n"
      fi
    done << EOF
${ref_paths}
EOF
  done
fi

# ────────────────────────────────────────────────────────────────
# Check 8: Trends — followup-item count delta + CC distribution delta
#
# Two sub-sections:
#   8a. Followup count per status file — now vs second-most-recent deep scan.
#   8b. CC (cyclomatic complexity) distribution — now vs previous cc-*.json.
#       Buckets: 1-5 / 6-10 / >10. Plus top-5 highest-CC functions today.
#
# Degrades gracefully when no baseline exists ("no baseline").
# CC JSON generation requires the cc_linter binary to be built; if not
# found, the CC sub-section reports "cc_linter binary not available".
# ────────────────────────────────────────────────────────────────

TRENDS_CONTENT=""

# ── 8a: Followup count delta ──────────────────────────────────────

# Find the second-most-recent *-deep.md (today's is already written to OUTPUT_FILE
# but hasn't been flushed yet — safe to glob all existing ones).
PREV_DEEP=""
# List all deep scan files sorted by name (date-based names sort chronologically),
# exclude today's (which may or may not exist yet).
for f in $(ls -1 "${OUTPUT_DIR}"/*-deep.md 2>/dev/null | sort); do
  case "$(basename "$f")" in
    "${TODAY}-deep.md") continue ;;
  esac
  PREV_DEEP="$f"
done
# PREV_DEEP is now the most-recent file that is NOT today's.

TRENDS_CONTENT="${TRENDS_CONTENT}### Followup items — now vs previous deep scan\n\n"

if [ -z "$PREV_DEEP" ]; then
  TRENDS_CONTENT="${TRENDS_CONTENT}No baseline (first deep scan). Current counts:\n\n"
  if [ -n "$FOLLOWUP_PER_FILE" ]; then
    TABLE=""
    while IFS=: read -r fname cnt; do
      [ -z "$fname" ] && continue
      TABLE="${TABLE}| \`${fname}\` | ${cnt} |\n"
    done << PFEOF
$(printf '%b' "$FOLLOWUP_PER_FILE")
PFEOF
    TRENDS_CONTENT="${TRENDS_CONTENT}| File | Count |\n|---|---|\n${TABLE}\n"
  else
    TRENDS_CONTENT="${TRENDS_CONTENT}No open followup items found.\n\n"
  fi
else
  prev_date="$(basename "$PREV_DEEP" -deep.md)"
  TRENDS_CONTENT="${TRENDS_CONTENT}Baseline: \`$(basename "$PREV_DEEP")\`\n\n"

  # Build today's per-file map from FOLLOWUP_PER_FILE
  # Extract per-file counts from the previous deep scan's
  # "## Followup Count Detail" section (written by Check 8 itself on that run).
  # Format in that section: "| `file.md` | prev_count | ..."
  # We parse lines matching "| \`*.md\` | <number>"

  TABLE=""
  while IFS=: read -r fname today_cnt; do
    [ -z "$fname" ] && continue
    # Look for this file in the previous report's Followup Count Detail table
    prev_cnt=""
    if grep -q "| \`${fname}\`" "$PREV_DEEP" 2>/dev/null; then
      prev_cnt="$(grep "| \`${fname}\`" "$PREV_DEEP" 2>/dev/null | head -1 \
        | awk -F'|' '{gsub(/ /,"",$3); print $3}' 2>/dev/null || true)"
    fi
    if [ -z "$prev_cnt" ]; then
      delta="(new)"
      delta_sign=""
    else
      # Compute delta
      delta=$((today_cnt - prev_cnt))
      if [ "$delta" -gt 0 ]; then
        delta_sign="+${delta}"
      elif [ "$delta" -lt 0 ]; then
        delta_sign="${delta}"
      else
        delta_sign="0"
      fi
      delta="$delta_sign"
    fi
    TABLE="${TABLE}| \`${fname}\` | ${today_cnt} | ${prev_cnt:-—} | ${delta} |\n"
  done << PFEOF
$(printf '%b' "$FOLLOWUP_PER_FILE")
PFEOF

  # Also surface files that appeared in prev but not today (all cleared)
  if [ -f "$PREV_DEEP" ] && grep -q "| \`.*\.md\`" "$PREV_DEEP" 2>/dev/null; then
    while IFS= read -r prev_line; do
      fname_raw="$(echo "$prev_line" | grep -o '\`[^|]*\.md\`' | tr -d '\`' | head -1)"
      [ -z "$fname_raw" ] && continue
      # Skip if we already processed it
      if printf '%b' "$FOLLOWUP_PER_FILE" | grep -q "^${fname_raw}:"; then
        continue
      fi
      prev_cnt="$(echo "$prev_line" | awk -F'|' '{gsub(/ /,"",$3); print $3}' 2>/dev/null || true)"
      if [ -n "$prev_cnt" ] && [ "$prev_cnt" -gt 0 ] 2>/dev/null; then
        delta="-${prev_cnt}"
        TABLE="${TABLE}| \`${fname_raw}\` | 0 | ${prev_cnt} | ${delta} |\n"
      fi
    done << PTEOF
$(grep "| \`.*\.md\`" "$PREV_DEEP" 2>/dev/null || true)
PTEOF
  fi

  if [ -n "$TABLE" ]; then
    TRENDS_CONTENT="${TRENDS_CONTENT}| File | Today | Prev (${prev_date}) | Delta |\n|---|---|---|---|\n${TABLE}\n"
  else
    TRENDS_CONTENT="${TRENDS_CONTENT}No open followup items in either scan.\n\n"
  fi
fi

# ── 8b: CC distribution delta ────────────────────────────────────

TRENDS_CONTENT="${TRENDS_CONTENT}### CC distribution — now vs previous snapshot\n\n"

METRICS_DIR="${REPO_ROOT}/dev/metrics"
mkdir -p "$METRICS_DIR"

# Find cc_linter binary (built by dune under trading/_build)
CC_LINTER_BIN=""
for candidate in \
    "${TRADING_DIR}/_build/default/devtools/cc_linter/cc_linter.exe" \
    "${TRADING_DIR}/_build/install/default/bin/cc_linter"; do
  if [ -f "$candidate" ] && [ -x "$candidate" ]; then
    CC_LINTER_BIN="$candidate"
    break
  fi
done

if [ -z "$CC_LINTER_BIN" ]; then
  TRENDS_CONTENT="${TRENDS_CONTENT}cc_linter binary not available — run \`dune build\` first.\n\n"
else
  # Single rolling snapshot cc-latest.json (version-controlled; overwritten
  # each run). Previous state comes from git HEAD so we don't accumulate
  # one JSON per run in-tree.
  TODAY_CC_JSON="${METRICS_DIR}/cc-latest.json"
  PREV_CC_JSON="$(mktemp -t cc-prev-XXXXXX.json)"
  trap 'rm -f "$PREV_CC_JSON"' EXIT
  if ! git -C "$REPO_ROOT" show "HEAD:dev/metrics/cc-latest.json" >"$PREV_CC_JSON" 2>/dev/null; then
    PREV_CC_JSON=""
  fi
  "$CC_LINTER_BIN" "$TRADING_DIR" "$TODAY_CC_JSON" >/dev/null 2>&1 || true

  if [ ! -f "$TODAY_CC_JSON" ]; then
    TRENDS_CONTENT="${TRENDS_CONTENT}cc_linter failed to write JSON output.\n\n"
  else

    # Compute bucket distribution from a JSON file using python3.
    # Outputs three numbers on one line: "low mid high" where
    #   low  = CC 1-5, mid = CC 6-10, high = CC >10
    _cc_buckets() {
      json_file="$1"
      python3 - "$json_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
fns = data.get("functions", [])
low = sum(1 for x in fns if 1 <= x["cc"] <= 5)
mid = sum(1 for x in fns if 6 <= x["cc"] <= 10)
high = sum(1 for x in fns if x["cc"] > 10)
print(low, mid, high)
PYEOF
    }

    # Top-5 highest-CC functions from today's JSON
    _cc_top5() {
      json_file="$1"
      python3 - "$json_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
fns = sorted(data.get("functions", []), key=lambda x: -x["cc"])[:5]
for fn in fns:
    print(fn["cc"], fn["file"] + ":" + str(fn["line"]), fn["name"])
PYEOF
    }

    today_buckets="$(_cc_buckets "$TODAY_CC_JSON" 2>/dev/null || echo "? ? ?")"
    today_low="$(echo "$today_buckets" | awk '{print $1}')"
    today_mid="$(echo "$today_buckets" | awk '{print $2}')"
    today_high="$(echo "$today_buckets" | awk '{print $3}')"

    if [ -n "$PREV_CC_JSON" ]; then
      prev_date_cc="$(git -C "$REPO_ROOT" log -1 --format='%h' -- dev/metrics/cc-latest.json 2>/dev/null || echo 'HEAD')"
      prev_buckets="$(_cc_buckets "$PREV_CC_JSON" 2>/dev/null || echo "? ? ?")"
      prev_low="$(echo "$prev_buckets" | awk '{print $1}')"
      prev_mid="$(echo "$prev_buckets" | awk '{print $2}')"
      prev_high="$(echo "$prev_buckets" | awk '{print $3}')"

      # Compute deltas (skip if values are "?")
      _delta() {
        a="$1"; b="$2"
        if [ "$a" = "?" ] || [ "$b" = "?" ]; then echo "?"; return; fi
        d=$((a - b))
        if [ "$d" -gt 0 ]; then echo "+${d}"
        elif [ "$d" -lt 0 ]; then echo "${d}"
        else echo "0"; fi
      }

      d_low="$(_delta "$today_low" "$prev_low")"
      d_mid="$(_delta "$today_mid" "$prev_mid")"
      d_high="$(_delta "$today_high" "$prev_high")"

      TRENDS_CONTENT="${TRENDS_CONTENT}| CC range | Today | Prev (${prev_date_cc}) | Delta |\n|---|---|---|---|\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| 1–5 (low) | ${today_low} | ${prev_low} | ${d_low} |\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| 6–10 (medium) | ${today_mid} | ${prev_mid} | ${d_mid} |\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| >10 (high) | ${today_high} | ${prev_high} | ${d_high} |\n\n"
    else
      TRENDS_CONTENT="${TRENDS_CONTENT}No baseline CC snapshot (first run). Current distribution:\n\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| CC range | Count |\n|---|---|\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| 1–5 (low) | ${today_low} |\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| 6–10 (medium) | ${today_mid} |\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| >10 (high) | ${today_high} |\n\n"
    fi

    # Top-5 highest-CC functions
    top5="$(_cc_top5 "$TODAY_CC_JSON" 2>/dev/null || true)"
    if [ -n "$top5" ]; then
      TRENDS_CONTENT="${TRENDS_CONTENT}**Top-5 highest-CC functions today:**\n\n"
      TRENDS_CONTENT="${TRENDS_CONTENT}| CC | Location | Function |\n|---|---|---|\n"
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        cc_val="$(echo "$line" | awk '{print $1}')"
        loc="$(echo "$line" | awk '{print $2}')"
        fname_fn="$(echo "$line" | awk '{$1=$2=""; print substr($0,3)}')"
        TRENDS_CONTENT="${TRENDS_CONTENT}| ${cc_val} | \`${loc}\` | \`${fname_fn}\` |\n"
      done << TOP5EOF
${top5}
TOP5EOF
      TRENDS_CONTENT="${TRENDS_CONTENT}\n"
    fi

    TRENDS_CONTENT="${TRENDS_CONTENT}CC JSON written to: \`$(basename "$TODAY_CC_JSON")\`\n"
  fi
fi

# ────────────────────────────────────────────────────────────────
# Check 9: Architecture graph — import edges vs dependency-rules.md
#
# MVP: grep-based edge detection for the two monitored rules.
#
# R2 (monitored): trading/trading/weinstein/ must not import from
#   analysis/weinstein/ modules other than weinstein.types.
#   Detects: "open <Analysis_module>" in .ml files under
#   trading/trading/weinstein/ where <Analysis_module> is one of the
#   known analysis/weinstein library top-level modules.
#   Exception: weinstein.types is allowed (stops + trading_state use it).
#
# R3 (monitored): trading/trading/simulation/ must not be imported by
#   the live execution path.
#   Detects: dune files outside simulation/ and backtest/ that list
#   trading.simulation or trading_simulation as a dependency.
#   Exemptions: simulation/ itself, simulation tests, backtest/ (backtesting
#   is not a live execution path), weinstein strategy test (integration test).
#
# Findings are INFO (monitored rules → awareness only; human decides to
# promote to enforced).  The report section is always emitted.
# ────────────────────────────────────────────────────────────────

ARCH_GRAPH_CONTENT=""
ARCH_GRAPH_VIOLATION_COUNT=0

# ── R2: trading/trading/weinstein/ must not import analysis modules ──
#
# Analysis module names as they appear after "open " in OCaml source
# (these are the top-level modules exposed by each weinstein.* library).
# weinstein.types exposes Weinstein_types — explicitly excluded from the
# violation list because stops and trading_state are allowed to use it.
#
# Known analysis module top-level names (from analysis/weinstein/*/lib/*.mli):
#   Stage, Screener, Macro, Sector, Rs, Volume, Resistance, Stock_analysis,
#   Data_source, Historical_source, Live_source, Universe, Inventory,
#   Data_path, Sector_map, Macro_types, Ad_bars_aggregation, Synthetic_adl
#
ANALYSIS_OPEN_PATTERN='open \(Stage\|Screener\|Macro\|Sector\|Rs\|Volume\|Resistance\|Stock_analysis\|Data_source\|Historical_source\|Live_source\|Universe\|Inventory\|Data_path\|Sector_map\|Macro_types\|Ad_bars_aggregation\|Synthetic_adl\)'

WEINSTEIN_TRADING_DIR="${TRADING_DIR}/trading/weinstein"
R2_FINDINGS=""
R2_COUNT=0

if [ -d "$WEINSTEIN_TRADING_DIR" ]; then
  for ml_file in $(find "$WEINSTEIN_TRADING_DIR" \
      -name "*.ml" \
      -not -path "*/_build/*" \
      -not -path "*/.formatted/*" | sort); do
    matches="$(grep -n "$ANALYSIS_OPEN_PATTERN" "$ml_file" 2>/dev/null || true)"
    if [ -n "$matches" ]; then
      rel_path="${ml_file#"$TRADING_DIR"/}"
      while IFS= read -r match_line; do
        [ -z "$match_line" ] && continue
        R2_COUNT=$((R2_COUNT + 1))
        ARCH_GRAPH_VIOLATION_COUNT=$((ARCH_GRAPH_VIOLATION_COUNT + 1))
        R2_FINDINGS="${R2_FINDINGS}  - \`${rel_path}\`: ${match_line}\n"
      done << R2EOF
${matches}
R2EOF
    fi
  done
fi

ARCH_GRAPH_CONTENT="${ARCH_GRAPH_CONTENT}### R2 — trading/trading/weinstein/ must not import analysis modules\n\n"
ARCH_GRAPH_CONTENT="${ARCH_GRAPH_CONTENT}Rule state: \`monitored\`\n\n"
if [ "$R2_COUNT" -eq 0 ]; then
  ARCH_GRAPH_CONTENT="${ARCH_GRAPH_CONTENT}No violations found.\n\n"
else
  ARCH_GRAPH_CONTENT="${ARCH_GRAPH_CONTENT}**${R2_COUNT} violation(s)** (open imports of analysis modules in trading/weinstein):\n\n"
  ARCH_GRAPH_CONTENT="${ARCH_GRAPH_CONTENT}${R2_FINDINGS}\n"
  add_info "Architecture graph (R2): ${R2_COUNT} monitored-rule violation(s) — trading/weinstein imports analysis module(s); see ## Architecture Graph"
fi

# ── R3: trading.simulation must not be used by live execution paths ──
#
# Live execution paths are modules under trading/trading/ that are NOT:
#   - simulation/ itself and its subdirectories
#   - backtest/ (purely a backtesting tool, not a live execution path)
#
# The weinstein strategy test (strategy/test/dune) uses simulation for
# integration tests — this is also excluded as a test-only usage.
#
TRADING_CORE_DIR="${TRADING_DIR}/trading"
R3_FINDINGS=""
R3_COUNT=0

if [ -d "$TRADING_CORE_DIR" ]; then
  for dune_file in $(find "$TRADING_CORE_DIR" \
      -name "dune" \
      -not -path "*/_build/*" \
      -not -path "*/simulation/*" \
      -not -path "*/backtest/*" | sort); do
    # Skip if this is a test stanza that mentions simulation
    # (test integration is acceptable; library/executable stanzas are not)
    if ! grep -q 'trading[._]simulation\|trading\.simulation' "$dune_file" 2>/dev/null; then
      continue
    fi
    # Check if any non-test stanza references simulation
    # A "test" or "tests" stanza is OK — only library/executable stanzas are flagged
    has_lib_ref=false
    in_lib_stanza=false
    while IFS= read -r dline; do
      case "$dline" in
        *'(library'*|*'(executable'*)
          in_lib_stanza=true ;;
        *'(test'*|*'(tests'*)
          in_lib_stanza=false ;;
        *')'*)
          # Closing paren — heuristic: top-level close ends a stanza
          # Only reset if at col 0 (start of line)
          case "$dline" in
            ')'*) in_lib_stanza=false ;;
          esac
          ;;
      esac
      if $in_lib_stanza && echo "$dline" | grep -q 'trading[._]simulation\|trading\.simulation' 2>/dev/null; then
        has_lib_ref=true
        break
      fi
    done < "$dune_file"

    if $has_lib_ref; then
      rel_path="${dune_file#"$TRADING_DIR"/}"
      R3_COUNT=$((R3_COUNT + 1))
      ARCH_GRAPH_VIOLATION_COUNT=$((ARCH_GRAPH_VIOLATION_COUNT + 1))
      R3_FINDINGS="${R3_FINDINGS}  - \`${rel_path}\`: depends on \`trading.simulation\`\n"
    fi
  done
fi

ARCH_GRAPH_CONTENT="${ARCH_GRAPH_CONTENT}### R3 — trading.simulation must not be imported by live execution paths\n\n"
ARCH_GRAPH_CONTENT="${ARCH_GRAPH_CONTENT}Rule state: \`monitored\`\n\n"
if [ "$R3_COUNT" -eq 0 ]; then
  ARCH_GRAPH_CONTENT="${ARCH_GRAPH_CONTENT}No violations found.\n\n"
else
  ARCH_GRAPH_CONTENT="${ARCH_GRAPH_CONTENT}**${R3_COUNT} violation(s)** (live execution dune files depending on simulation):\n\n"
  ARCH_GRAPH_CONTENT="${ARCH_GRAPH_CONTENT}${R3_FINDINGS}\n"
  add_info "Architecture graph (R3): ${R3_COUNT} monitored-rule violation(s) — live execution path imports simulation; see ## Architecture Graph"
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
- QC calibration findings: ${QC_CAL_COUNT} (dune available: ${DUNE_AVAILABLE})
- Architecture graph violations (monitored): ${ARCH_GRAPH_VIOLATION_COUNT}
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

if [ -n "$QC_CAL_DETAILS" ]; then
  printf "\n## QC Calibration Detail\n" >> "$OUTPUT_FILE"
  printf '%b' "$QC_CAL_DETAILS" >> "$OUTPUT_FILE"
fi

if [ -n "$SCAFFOLD_DETAILS" ]; then
  printf "\n## Harness Scaffolding\n" >> "$OUTPUT_FILE"
  printf "Per-component audit (PASS = referenced/wired, WARNING = unused or broken reference):\n\n" >> "$OUTPUT_FILE"
  printf '%b' "$SCAFFOLD_DETAILS" >> "$OUTPUT_FILE"
fi

# Always emit the Architecture Graph section (Check 9).
# Monitored-rule violations are INFO (not failures) — human decides to promote.
printf "\n## Architecture Graph\n\n" >> "$OUTPUT_FILE"
printf "Import-edge violations vs \`docs/design/dependency-rules.md\` (monitored rules only).\n" >> "$OUTPUT_FILE"
printf "Enforced rules are checked by \`dune runtest\`; this section covers monitored rules.\n\n" >> "$OUTPUT_FILE"
printf '%b' "$ARCH_GRAPH_CONTENT" >> "$OUTPUT_FILE"

# Always emit the Trends section (Check 8).
printf "\n## Trends\n\n" >> "$OUTPUT_FILE"
printf '%b' "$TRENDS_CONTENT" >> "$OUTPUT_FILE"

# Emit per-file followup count detail for future scans to diff against.
# The table rows use format "| `file.md` | count |" so Check 8's grep
# can extract them from the previous deep scan report.
if [ -n "$FOLLOWUP_PER_FILE" ]; then
  {
    printf "\n## Followup Count Detail\n\n"
    printf "| File | Count |\n|---|---|\n"
    while IFS=: read -r fname cnt; do
      [ -z "$fname" ] && continue
      printf "| \`%s\` | %s |\n" "$fname" "$cnt"
    done << DETEOF
$(printf '%b' "$FOLLOWUP_PER_FILE")
DETEOF
  } >> "$OUTPUT_FILE"
fi

echo ""
echo "Deep scan complete. Report written to: ${OUTPUT_FILE}"
echo "  Findings: ${TOTAL_FINDINGS} (critical: ${CRITICAL_COUNT}, warnings: ${WARNING_COUNT}, info: ${INFO_COUNT})"
