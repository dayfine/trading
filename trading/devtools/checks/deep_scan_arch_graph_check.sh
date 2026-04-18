#!/bin/sh
# Structural smoke test for the deep-scan Architecture Graph section (T3-F).
#
# Does NOT invoke deep_scan.sh from dune runtest because:
#   - deep_scan.sh runs weekly (not on every PR) and writes outside the
#     dune sandbox (dev/health/).
#
# Instead, this verifies two things:
#   1. deep_scan.sh contains the required Check 9 implementation markers
#      (both R2 and R3 sub-sections).
#   2. The most-recent dev/health/*-deep.md report contains a
#      ## Architecture Graph section, confirming the script has been run
#      at least once successfully.
#
# How to re-verify the output by hand:
#   sh trading/devtools/checks/deep_scan.sh
#   grep '## Architecture Graph' dev/health/$(date +%Y-%m-%d)-deep.md

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
DEEP_SCAN="${REPO_ROOT}/trading/devtools/checks/deep_scan.sh"
[ -f "$DEEP_SCAN" ] || die "deep_scan_arch_graph_check: $DEEP_SCAN does not exist"

fail() {
  echo "FAIL: deep_scan_arch_graph_check — $1" >&2
  exit 1
}

# ── Part 1: structural check of deep_scan.sh ─────────────────────

# Check 9 header
grep -qF 'Check 9: Architecture graph' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing 'Check 9: Architecture graph' header"

# R2 implementation markers
grep -qF 'ANALYSIS_OPEN_PATTERN' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing ANALYSIS_OPEN_PATTERN variable (R2 check)"
grep -qF 'R2 — trading/trading/weinstein/ must not import analysis modules' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing R2 section header"
grep -qF 'WEINSTEIN_TRADING_DIR' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing WEINSTEIN_TRADING_DIR scan loop (R2)"

# R3 implementation markers
grep -qF 'R3 — trading.simulation must not be imported by live execution paths' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing R3 section header"
grep -qF 'ARCH_GRAPH_VIOLATION_COUNT' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing ARCH_GRAPH_VIOLATION_COUNT accumulator"

# Report emits ## Architecture Graph section
grep -qF '## Architecture Graph' "$DEEP_SCAN" \
  || fail "deep_scan.sh does not emit '## Architecture Graph' section in report"

# ── Part 2: most-recent deep report has ## Architecture Graph ────

HEALTH_DIR="${REPO_ROOT}/dev/health"
LATEST_DEEP=""
for f in $(ls -1 "${HEALTH_DIR}"/*-deep.md 2>/dev/null | sort); do
  LATEST_DEEP="$f"
done

if [ -z "$LATEST_DEEP" ]; then
  # No deep report exists yet — acceptable if deep_scan.sh has never run.
  echo "INFO: no dev/health/*-deep.md found; skipping report content check."
else
  grep -qF '## Architecture Graph' "$LATEST_DEEP" \
    || fail "$(basename "$LATEST_DEEP") does not contain '## Architecture Graph' section — run: sh trading/devtools/checks/deep_scan.sh"
  grep -qF '### R2' "$LATEST_DEEP" \
    || fail "$(basename "$LATEST_DEEP") ## Architecture Graph section missing R2 sub-section"
  grep -qF '### R3' "$LATEST_DEEP" \
    || fail "$(basename "$LATEST_DEEP") ## Architecture Graph section missing R3 sub-section"
fi

echo "OK: deep scan Architecture Graph section (T3-F) structural check passed."
