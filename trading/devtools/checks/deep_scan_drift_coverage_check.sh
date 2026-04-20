#!/bin/sh
# Structural smoke test for the deep-scan drift coverage extension
# (harness gap sub-item 1: "Drift coverage too narrow").
#
# Does NOT invoke deep_scan.sh from dune runtest because:
#   - deep_scan.sh runs weekly (not on every PR) and writes outside the
#     dune sandbox (dev/health/).
#
# Instead, this verifies two things:
#   1. check_02_design_doc_drift.sh contains the required backtest subsystem
#      drift check implementation markers (BACKTEST_PLAN and BACKTEST_DIR
#      variables, and the section that checks trading/trading/backtest/).
#   2. The most-recent dev/health/*-deep.md report contains a
#      ## Drift section (confirming the script has been run at least once
#      and the drift section exists).
#
# How to re-verify the output by hand:
#   sh trading/devtools/checks/deep_scan.sh
#   grep 'backtest' dev/health/$(date +%Y-%m-%d)-deep.md

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
DEEP_SCAN_DIR="${REPO_ROOT}/trading/devtools/checks/deep_scan"
CHECK_02="${DEEP_SCAN_DIR}/check_02_design_doc_drift.sh"
[ -f "$CHECK_02" ] || die "deep_scan_drift_coverage_check: $CHECK_02 does not exist"

fail() {
  echo "FAIL: deep_scan_drift_coverage_check — $1" >&2
  exit 1
}

# ── Part 1: structural check of check_02_design_doc_drift.sh ─────

# Backtest plan variable
grep -qF 'BACKTEST_PLAN' "$CHECK_02" \
  || fail "check_02_design_doc_drift.sh missing BACKTEST_PLAN variable (backtest subsystem drift check)"

# Backtest dir variable
grep -qF 'BACKTEST_DIR' "$CHECK_02" \
  || fail "check_02_design_doc_drift.sh missing BACKTEST_DIR variable (backtest subsystem drift check)"

# The plan filename
grep -qF 'backtest-scale-optimization-2026-04-17.md' "$CHECK_02" \
  || fail "check_02_design_doc_drift.sh missing reference to backtest-scale-optimization-2026-04-17.md"

# The subsystem path in the warning message
grep -qF 'trading/trading/backtest/' "$CHECK_02" \
  || fail "check_02_design_doc_drift.sh missing 'trading/trading/backtest/' path in drift check"

# ── Part 2: most-recent deep report has ## Drift section ─────────

HEALTH_DIR="${REPO_ROOT}/dev/health"
LATEST_DEEP=""
for f in $(ls -1 "${HEALTH_DIR}"/*-deep.md 2>/dev/null | sort); do
  LATEST_DEEP="$f"
done

if [ -z "$LATEST_DEEP" ]; then
  # No deep report exists yet — acceptable if deep_scan.sh has never run.
  echo "INFO: no dev/health/*-deep.md found; skipping report content check."
else
  grep -qF 'Design doc drift' "$LATEST_DEEP" \
    || grep -qF 'DRIFT_COUNT' "$CHECK_02" \
    || fail "$(basename "$LATEST_DEEP") does not reference drift metrics — run: sh trading/devtools/checks/deep_scan.sh"
fi

echo "OK: deep scan drift coverage extension (backtest subsystem, harness gap sub-item 1) structural check passed."
