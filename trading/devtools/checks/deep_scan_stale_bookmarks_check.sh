#!/bin/sh
# Structural smoke test for the deep-scan Stale Local Bookmarks section
# (sub-item 4 of "Deep scan heuristic gaps" in dev/status/harness.md).
#
# Does NOT invoke deep_scan.sh from dune runtest because:
#   - deep_scan.sh runs weekly (not on every PR) and writes outside the
#     dune sandbox (dev/health/).
#
# Instead, this verifies two things:
#   1. deep_scan/check_12_stale_bookmarks.sh contains the required Check 12
#      implementation markers (the stale bookmark detection logic and
#      ## Stale Local Bookmarks section emission).
#   2. The most-recent dev/health/*-deep.md report contains a
#      ## Stale Local Bookmarks section, confirming the script has been
#      run at least once successfully.
#
# How to re-verify the output by hand:
#   sh trading/devtools/checks/deep_scan.sh
#   grep '## Stale Local Bookmarks' dev/health/$(date +%Y-%m-%d)-deep.md

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
DEEP_SCAN_DIR="${REPO_ROOT}/trading/devtools/checks/deep_scan"
CHECK_12="${DEEP_SCAN_DIR}/check_12_stale_bookmarks.sh"
[ -f "$CHECK_12" ] || die "deep_scan_stale_bookmarks_check: $CHECK_12 does not exist"

fail() {
  echo "FAIL: deep_scan_stale_bookmarks_check -- $1" >&2
  exit 1
}

# -- Part 1: structural check of check_12_stale_bookmarks.sh ----------------

# Check 12 header
grep -qF 'Check 12: Stale local jj bookmarks' "$CHECK_12" \
  || fail "check_12_stale_bookmarks.sh missing 'Check 12: Stale local jj bookmarks' header"

# jj graceful degradation
grep -qF 'jj not available' "$CHECK_12" \
  || fail "check_12_stale_bookmarks.sh missing graceful-degradation message for jj not available"

# Accumulator variables
grep -qF 'STALE_LOCAL_ONLY_COUNT' "$CHECK_12" \
  || fail "check_12_stale_bookmarks.sh missing STALE_LOCAL_ONLY_COUNT accumulator"

grep -qF 'STALE_BEHIND_COUNT' "$CHECK_12" \
  || fail "check_12_stale_bookmarks.sh missing STALE_BEHIND_COUNT accumulator"

# jj bookmark list invocation
grep -qF 'jj bookmark list' "$CHECK_12" \
  || fail "check_12_stale_bookmarks.sh missing 'jj bookmark list' invocation"

# Report emits ## Stale Local Bookmarks section
grep -qF '## Stale Local Bookmarks' "$CHECK_12" \
  || fail "check_12_stale_bookmarks.sh does not emit '## Stale Local Bookmarks' section in report"

# Section has Local-only candidates and Behind origin sub-sections
grep -qF 'Local-only candidates' "$CHECK_12" \
  || fail "check_12_stale_bookmarks.sh missing 'Local-only candidates' sub-section"

grep -qF 'Behind origin' "$CHECK_12" \
  || fail "check_12_stale_bookmarks.sh missing 'Behind origin' sub-section"

# -- Part 2: most-recent deep report has ## Stale Local Bookmarks -------------

HEALTH_DIR="${REPO_ROOT}/dev/health"
LATEST_DEEP=""
for f in $(ls -1 "${HEALTH_DIR}"/*-deep.md 2>/dev/null | sort); do
  LATEST_DEEP="$f"
done

if [ -z "$LATEST_DEEP" ]; then
  # No deep report exists yet -- acceptable if deep_scan.sh has never run.
  echo "INFO: no dev/health/*-deep.md found; skipping report content check."
else
  grep -qF '## Stale Local Bookmarks' "$LATEST_DEEP" \
    || fail "$(basename "$LATEST_DEEP") does not contain '## Stale Local Bookmarks' section -- run: sh trading/devtools/checks/deep_scan.sh"
fi

echo "OK: deep scan Stale Local Bookmarks section (harness gap sub-item 4) structural check passed."
