#!/bin/sh
# Check 2: Design doc drift — actual modules vs eng-design docs.
#
# Usage: sh check_02_design_doc_drift.sh <report_file> [findings_file]

set -e

REPORT_FILE="${1:?Usage: check_02_design_doc_drift.sh <report_file> [findings_file]}"
FINDINGS_FILE="${2:-}"

. "$(dirname "$0")/_lib.sh"

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

# backtest-scale-optimization plan covers trading/trading/backtest/ subsystems
# TRADING_DIR = <repo_root>/trading ; backtest lives at trading/trading/backtest
# relative to repo root, so the full path is TRADING_DIR/trading/backtest.
BACKTEST_PLAN="${REPO_ROOT}/dev/plans/backtest-scale-optimization-2026-04-17.md"
BACKTEST_DIR="${TRADING_DIR}/trading/backtest"
if [ -f "$BACKTEST_PLAN" ] && [ -d "$BACKTEST_DIR" ]; then
  for d in "${BACKTEST_DIR}"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    case "$name" in
      _build|test|.formatted) continue ;;
    esac
    if ! grep -qi "$name" "$BACKTEST_PLAN" 2>/dev/null; then
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
      add_warning "Design doc drift: \`trading/trading/backtest/${name}/\` exists on disk but not mentioned in \`backtest-scale-optimization-2026-04-17.md\`"
    fi
  done
fi

add_metric DRIFT_COUNT "$DRIFT_COUNT"
flush_findings
