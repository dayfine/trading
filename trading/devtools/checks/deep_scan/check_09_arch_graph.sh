#!/bin/sh
# Check 9: Architecture graph — import edges vs dependency-rules.md (T3-F).
#
# Usage: sh check_09_arch_graph.sh <report_file> [findings_file]
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

set -e

REPORT_FILE="${1:?Usage: check_09_arch_graph.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

# ────────────────────────────────────────────────────────────────
# Check 9: Architecture graph
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

add_metric ARCH_GRAPH_VIOLATION_COUNT "$ARCH_GRAPH_VIOLATION_COUNT"
flush_findings

# Always emit the Architecture Graph section.
# Monitored-rule violations are INFO (not failures) — human decides to promote.
printf "\n## Architecture Graph\n\n" >> "$REPORT_FILE"
printf "Import-edge violations vs \`docs/design/dependency-rules.md\` (monitored rules only).\n" >> "$REPORT_FILE"
printf "Enforced rules are checked by \`dune runtest\`; this section covers monitored rules.\n\n" >> "$REPORT_FILE"
printf '%b' "$ARCH_GRAPH_CONTENT" >> "$REPORT_FILE"
