#!/bin/sh
# Structural smoke test for the deep-scan Linter Exception Expiry section
# (sub-item 3 of "Deep scan heuristic gaps" in dev/status/harness.md).
#
# Does NOT invoke deep_scan.sh from dune runtest because:
#   - deep_scan.sh runs weekly (not on every PR) and writes outside the
#     dune sandbox (dev/health/).
#
# Instead, this verifies two things:
#   1. deep_scan.sh contains the required Check 11 implementation markers
#      (the ## Linter Exception Expiry detection logic and section emission).
#   2. The most-recent dev/health/*-deep.md report contains a
#      ## Linter Exception Expiry section, confirming the script has been
#      run at least once successfully.
#
# How to re-verify the output by hand:
#   sh trading/devtools/checks/deep_scan.sh
#   grep '## Linter Exception Expiry' dev/health/$(date +%Y-%m-%d)-deep.md

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
DEEP_SCAN_DIR="${REPO_ROOT}/trading/devtools/checks/deep_scan"
CHECK_11="${DEEP_SCAN_DIR}/check_11_linter_expiry.sh"
[ -f "$CHECK_11" ] || die "deep_scan_linter_expiry_check: $CHECK_11 does not exist"

fail() {
  echo "FAIL: deep_scan_linter_expiry_check — $1" >&2
  exit 1
}

# ── Part 1: structural check of check_11_linter_expiry.sh ────────

# Check 11 header
grep -qF 'Check 11: Linter Exception Expiry' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh missing 'Check 11: Linter Exception Expiry' header"

# Reads linter_exceptions.conf
grep -qF 'linter_exceptions.conf' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh does not reference linter_exceptions.conf"

# Detects review_at annotation
grep -qF 'review_at:' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh missing review_at detection logic"

# Accumulator variables for expiry tracking
grep -qF 'EXPIRY_COUNT' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh missing EXPIRY_COUNT accumulator"

grep -qF 'EXPIRY_MISSING_COUNT' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh missing EXPIRY_MISSING_COUNT accumulator (missing review_at tracking)"

# Report emits ## Linter Exception Expiry section
grep -qF '## Linter Exception Expiry' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh does not emit '## Linter Exception Expiry' section in report"

# ── Part 2: most-recent deep report has ## Linter Exception Expiry ──

HEALTH_DIR="${REPO_ROOT}/dev/health"
LATEST_DEEP=""
for f in $(ls -1 "${HEALTH_DIR}"/*-deep.md 2>/dev/null | sort); do
  LATEST_DEEP="$f"
done

if [ -z "$LATEST_DEEP" ]; then
  # No deep report exists yet — acceptable if deep_scan.sh has never run.
  echo "INFO: no dev/health/*-deep.md found; skipping report content check."
else
  grep -qF '## Linter Exception Expiry' "$LATEST_DEEP" \
    || fail "$(basename "$LATEST_DEEP") does not contain '## Linter Exception Expiry' section — run: sh trading/devtools/checks/deep_scan.sh"
fi

echo "OK: deep scan Linter Exception Expiry section (T1-K) structural check passed."
