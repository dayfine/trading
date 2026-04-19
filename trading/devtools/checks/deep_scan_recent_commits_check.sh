#!/bin/sh
# Structural smoke test for the deep-scan Status File Template section (sub-item 2
# of "Deep scan heuristic gaps" in dev/status/harness.md).
#
# Does NOT invoke deep_scan.sh from dune runtest because:
#   - deep_scan.sh runs weekly (not on every PR) and writes outside the
#     dune sandbox (dev/health/).
#
# Instead, this verifies two things:
#   1. deep_scan.sh contains the required Check 10 implementation markers
#      (the ## Recent Commits detection logic and ## Status File Template
#      section emission).
#   2. The most-recent dev/health/*-deep.md report contains a
#      ## Status File Template section, confirming the script has been run
#      at least once successfully.
#
# How to re-verify the output by hand:
#   sh trading/devtools/checks/deep_scan.sh
#   grep '## Status File Template' dev/health/$(date +%Y-%m-%d)-deep.md

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
DEEP_SCAN_DIR="${REPO_ROOT}/trading/devtools/checks/deep_scan"
CHECK_10="${DEEP_SCAN_DIR}/check_10_status_template.sh"
[ -f "$CHECK_10" ] || die "deep_scan_recent_commits_check: $CHECK_10 does not exist"

fail() {
  echo "FAIL: deep_scan_recent_commits_check — $1" >&2
  exit 1
}

# ── Part 1: structural check of check_10_status_template.sh ──────

# Check 10 header
grep -qF 'Check 10: Status file template enforcement' "$CHECK_10" \
  || fail "check_10_status_template.sh missing 'Check 10: Status file template enforcement' header"

# Detection logic: grep for the forbidden heading
grep -qF "grep -n '^## Recent Commits'" "$CHECK_10" \
  || fail "check_10_status_template.sh missing grep for '^## Recent Commits' forbidden heading detection"

# Accumulator variable
grep -qF 'RECENT_COMMITS_COUNT' "$CHECK_10" \
  || fail "check_10_status_template.sh missing RECENT_COMMITS_COUNT accumulator"

# Report emits ## Status File Template section
grep -qF '## Status File Template' "$CHECK_10" \
  || fail "check_10_status_template.sh does not emit '## Status File Template' section in report"

# ── Part 2: most-recent deep report has ## Status File Template ──

HEALTH_DIR="${REPO_ROOT}/dev/health"
LATEST_DEEP=""
for f in $(ls -1 "${HEALTH_DIR}"/*-deep.md 2>/dev/null | sort); do
  LATEST_DEEP="$f"
done

if [ -z "$LATEST_DEEP" ]; then
  # No deep report exists yet — acceptable if deep_scan.sh has never run.
  echo "INFO: no dev/health/*-deep.md found; skipping report content check."
else
  grep -qF '## Status File Template' "$LATEST_DEEP" \
    || fail "$(basename "$LATEST_DEEP") does not contain '## Status File Template' section — run: sh trading/devtools/checks/deep_scan.sh"
fi

echo "OK: deep scan Status File Template section (Recent Commits guard) structural check passed."
