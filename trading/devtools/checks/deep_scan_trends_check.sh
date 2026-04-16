#!/bin/sh
# Structural smoke test for the deep-scan Trends section (T3-G).
#
# This test is intentionally a structural check — it does NOT invoke
# deep_scan.sh from dune runtest because:
#   - deep_scan.sh runs weekly (not on every PR) and is not wired into
#     dune's dependency graph.
#   - It writes to dev/health/ which lives outside the dune sandbox.
#
# Instead, this verifies two things:
#   1. deep_scan.sh contains the required Check 8 implementation markers
#      (both sub-sections: followup delta and CC distribution).
#   2. The most-recent dev/health/*-deep.md report contains a ## Trends
#      section with both sub-sections, confirming the script has been
#      run at least once successfully.
#
# How to re-verify the output by hand:
#   sh trading/devtools/checks/deep_scan.sh
#   grep '## Trends' dev/health/$(date +%Y-%m-%d)-deep.md

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
DEEP_SCAN="${REPO_ROOT}/trading/devtools/checks/deep_scan.sh"
[ -f "$DEEP_SCAN" ] || die "deep_scan_trends_check: $DEEP_SCAN does not exist"

fail() {
  echo "FAIL: deep_scan_trends_check — $1" >&2
  exit 1
}

# ── Part 1: structural check of deep_scan.sh ─────────────────────

# Check 8 header
grep -qF 'Check 8: Trends' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing 'Check 8: Trends' header"

# Followup delta sub-section markers
grep -qF 'Followup items — now vs previous deep scan' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing '### Followup items — now vs previous deep scan'"
grep -qF 'FOLLOWUP_PER_FILE' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing FOLLOWUP_PER_FILE accumulator"
grep -qF 'PREV_DEEP' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing PREV_DEEP baseline detection"

# CC distribution sub-section markers
grep -qF 'CC distribution — now vs previous snapshot' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing '### CC distribution — now vs previous snapshot'"
grep -qF 'CC_LINTER_BIN' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing CC_LINTER_BIN path detection"
grep -qF 'today_buckets' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing today_buckets computation"
grep -qF 'Top-5 highest-CC' "$DEEP_SCAN" \
  || fail "deep_scan.sh missing top-5 highest-CC output"

# Report emits ## Trends section
grep -qF '## Trends' "$DEEP_SCAN" \
  || fail "deep_scan.sh does not emit '## Trends' section in report"

# ── Part 2: most-recent deep report has ## Trends ────────────────

HEALTH_DIR="${REPO_ROOT}/dev/health"
LATEST_DEEP=""
for f in $(ls -1 "${HEALTH_DIR}"/*-deep.md 2>/dev/null | sort); do
  LATEST_DEEP="$f"
done

if [ -z "$LATEST_DEEP" ]; then
  # No deep report exists yet — acceptable if deep_scan.sh has never run.
  echo "INFO: no dev/health/*-deep.md found; skipping report content check."
else
  grep -qF '## Trends' "$LATEST_DEEP" \
    || fail "$(basename "$LATEST_DEEP") does not contain '## Trends' section — run: sh trading/devtools/checks/deep_scan.sh"
  grep -qF 'Followup items' "$LATEST_DEEP" \
    || fail "$(basename "$LATEST_DEEP") ## Trends section missing 'Followup items' sub-section"
  grep -qF 'CC distribution' "$LATEST_DEEP" \
    || fail "$(basename "$LATEST_DEEP") ## Trends section missing 'CC distribution' sub-section"
fi

echo "OK: deep scan Trends section (T3-G) structural check passed."
