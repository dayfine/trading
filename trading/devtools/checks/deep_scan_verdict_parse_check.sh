#!/bin/sh
# Regression test for check_06's review-verdict extraction (deep scan
# 2026-10-19 Warning 13: ~150 of 155 dev/reviews/*.md reported "could not
# extract verdict" because the verdict sits on a later line than the
# "## Verdict" heading).
#
# Invokes check_06_qc_calibration.sh against a synthetic dev/reviews/ via the
# REPO_ROOT override. With no dev/audit/ record, a review whose verdict was
# extracted yields "has review (verdict: X) but no audit trail"; one whose
# verdict was not yields "could not extract verdict".
#
# Fixtures: same-line heading, next line, blank-then-next, bold, NEEDS_REWORK
# next-line, a prose-only mention (must NOT parse), no verdict at all, and
# precedence (overall_qc: beats a conflicting ## Verdict section).
# Also: two headings (last wins), a later heading with no verdict (resets to
# none), backtick-wrapped token, a non-verdict first line followed by a later
# token line (must NOT parse), a "## Verdicts summary" heading (ignored), and a
# trailing empty "## Verdict" heading (reset: none, not the earlier verdict),
# a "## Verdict: APPROVED" heading-line verdict, and "APPROVEDX" (not a verdict).
set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT_REAL="$(repo_root)"
CHECK_06="${REPO_ROOT_REAL}/trading/devtools/checks/deep_scan/check_06_qc_calibration.sh"
[ -f "$CHECK_06" ] || die "deep_scan_verdict_parse_check: $CHECK_06 does not exist"

FAIL_COUNT=0
fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: deep_scan_verdict_parse_check — $1" >&2
}

FAKE_ROOT="$(mktemp -d)"
DETAIL_FILE="$(mktemp)"
FINDINGS_FILE="$(mktemp)"
: > "$FINDINGS_FILE"
trap 'rm -rf "$FAKE_ROOT" "$DETAIL_FILE" "$FINDINGS_FILE"' EXIT
mkdir -p "${FAKE_ROOT}/.claude" "${FAKE_ROOT}/dev/audit" "${FAKE_ROOT}/dev/reviews"
R="${FAKE_ROOT}/dev/reviews"

printf '# Review\n\n## Verdict APPROVED\n\nbody\n' > "$R/sameline.md"
printf '# Review\n\n## Verdict\nAPPROVED\n\n## Notes\n' > "$R/nextline.md"
printf '# Review\n\n## Verdict\n\n\nAPPROVED\n' > "$R/blankthen.md"
printf '# Review\n\n## Verdict\n\n**APPROVED**\n' > "$R/bold.md"
printf '# Review\n\n## Verdict\n\nNEEDS_REWORK\n\n## NEEDS_REWORK Items\n' > "$R/rework.md"
printf '# Review\n\n## Verdict (re-review)\n\nNEEDS_REWORK\n' > "$R/suffix.md"
printf '# Review\n\n## Verdict\n\nThe change is fine; I would say APPROVED later.\n' > "$R/prose.md"
printf '# Agreement table\n\n| PR | verdict |\n| 1 | APPROVED |\n' > "$R/noverdict.md"
printf 'overall_qc: NEEDS_REWORK\n\n## Verdict\n\nAPPROVED\n' > "$R/precedence.md"
printf '# Review\n\n## Verdict\n\nNEEDS_REWORK\n\n## Verdict\n\nAPPROVED\n' > "$R/twoheadings.md"
printf '# Review\n\n## Verdict\n\nAPPROVED\n\n## Verdict rationale\n\nprose only\n' > "$R/laterempty.md"
printf '# Review\n\n## Verdict\n\n`APPROVED`\n' > "$R/backtick.md"
printf '# Review\n\n## Verdict\n\nAPPROVED\n\n## Verdict\n' > "$R/trailinghead.md"
printf '# Review\n\n## Verdict\n\nSee the findings below.\n\nAPPROVED\n' > "$R/scanpast.md"
printf '# Review\n\n## Verdicts summary\n\nAPPROVED\n' > "$R/plural.md"
printf '# Review\n\n## Verdict: APPROVED\n\nbody\n' > "$R/colon.md"
printf '# Review\n\n## Verdict\n\nAPPROVEDX\n' > "$R/glued.md"

REPO_ROOT="$FAKE_ROOT" sh "$CHECK_06" "$DETAIL_FILE" "$FINDINGS_FILE"

expect_verdict() {
  grep -q "\`$1\` has review (verdict: $2)" "$FINDINGS_FILE" \
    || fail "$1.md: expected verdict $2 to be extracted; findings:
$(sed 's/^/      /' "$FINDINGS_FILE")"
}
expect_none() {
  grep -q "could not extract verdict from \`dev/reviews/$1.md\`" "$FINDINGS_FILE" \
    || fail "$1.md: expected 'could not extract verdict'"
}

expect_verdict sameline APPROVED
expect_verdict nextline APPROVED
expect_verdict blankthen APPROVED
expect_verdict bold APPROVED
expect_verdict rework NEEDS_REWORK
expect_verdict precedence NEEDS_REWORK
expect_verdict suffix NEEDS_REWORK
expect_none prose
expect_none noverdict
expect_verdict twoheadings APPROVED
expect_none laterempty
expect_verdict backtick APPROVED
expect_none scanpast
expect_none plural
expect_none trailinghead
expect_verdict colon APPROVED
expect_none glued

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "deep_scan_verdict_parse_check: ${FAIL_COUNT} failure(s)" >&2
  exit 1
fi
echo "OK: deep_scan_verdict_parse_check (17 fixtures)"
