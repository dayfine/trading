#!/bin/sh
# Regression test for check_06's noise fixes (deep scan 2026-10-26 Warning 6):
#  (1) audit-record matching: a review slug also matches an audit record via
#      the record's "branch" field ("/" -> "-") and after stripping a
#      -structural/-behavioral(-v2|-rework) suffix; genuine misses stay reported.
#  (2) reviewed features with no test-directory mapping collapse into ONE
#      aggregated info line with a count (not one line per feature).
#
# Invokes check_06_qc_calibration.sh on a synthetic repo via REPO_ROOT, with a
# stub `dune` (always succeeds) on PATH so the mapping branch runs.
set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT_REAL="$(repo_root)"
CHECK_06="${REPO_ROOT_REAL}/trading/devtools/checks/deep_scan/check_06_qc_calibration.sh"
[ -f "$CHECK_06" ] || die "deep_scan_check06_noise_check: $CHECK_06 does not exist"

FAIL_COUNT=0
fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: deep_scan_check06_noise_check — $1" >&2
}

FAKE_ROOT="$(mktemp -d)"
DETAIL_FILE="$(mktemp)"
FINDINGS_FILE="$(mktemp)"
trap 'rm -rf "$FAKE_ROOT" "$DETAIL_FILE" "$FINDINGS_FILE"' EXIT
mkdir -p "${FAKE_ROOT}/.claude" "${FAKE_ROOT}/dev/audit" "${FAKE_ROOT}/dev/reviews" "${FAKE_ROOT}/bin"
printf '#!/bin/sh\nexit 0\n' > "${FAKE_ROOT}/bin/dune"
chmod +x "${FAKE_ROOT}/bin/dune"

R="${FAKE_ROOT}/dev/reviews"
A="${FAKE_ROOT}/dev/audit"
for s in byfile viabranch base-structural base-behavioral-v2 base-structural-rework base-foo ase genuine genuine-structural screener a.b exact-slug; do
  printf '# Review\n\n## Verdict\n\nAPPROVED\n' > "$R/$s.md"
done
audit() { printf '{\n  "feature": "%s",\n  "branch": "%s"\n}\n' "$2" "$3" > "$A/$1.json"; }
audit 2026-01-01-b-byfile unrelated other/branch
audit 2026-01-02-tuning tuning feat/viabranch
audit 2026-01-03-base base fix/base
audit 2026-01-04-metachar metachar feat/axb
audit 2026-01-05-eq eq exact/slug

PATH="${FAKE_ROOT}/bin:$PATH" REPO_ROOT="$FAKE_ROOT" sh "$CHECK_06" "$DETAIL_FILE" "$FINDINGS_FILE"

expect_reported() {
  grep -q "\`$1\` has review (verdict: APPROVED) but no audit trail" "$FINDINGS_FILE" \
    || fail "$1: genuine miss must stay reported"
}
expect_matched() {
  if grep -q "\`$1\` has review (verdict: APPROVED) but no audit trail" "$FINDINGS_FILE"; then
    fail "$1: has an audit record but was reported"
  fi
}
expect_reported genuine
expect_reported genuine-structural
expect_matched byfile
expect_matched viabranch
# Exact-equality arm: branch exact/slug normalizes to exact-slug (no prefix).
expect_matched exact-slug
expect_matched base-structural
expect_matched base-behavioral-v2
expect_matched base-structural-rework
# A non-review-kind suffix must NOT be stripped, and the branch match is
# hyphen-anchored (ase is a tail of fix-base with no boundary).
expect_reported base-foo
expect_reported ase
# ERE metacharacter in a slug is literal: a.b must not match branch feat/axb.
expect_reported a.b


if grep -q 'no test directory mapping for feature' "$FINDINGS_FILE"; then
  fail "per-feature 'no test directory mapping' lines must be aggregated"
fi
# 12 reviews, 1 mapped (screener) -> 11 unmapped
grep -q '11 reviewed feature(s) have no test directory mapping' "$FINDINGS_FILE" \
  || fail "expected one aggregated line with count 11; findings:
$(sed 's/^/      /' "$FINDINGS_FILE")"
[ "$(grep -c 'have no test directory mapping' "$FINDINGS_FILE")" = 1 ] \
  || fail "expected exactly one aggregated mapping line"

# Only a mapped feature reviewed (count 0): no aggregate mapping line at all.
ONLY_ROOT="$(mktemp -d)"
ONLY_FINDINGS="$(mktemp)"
trap 'rm -rf "$FAKE_ROOT" "$ONLY_ROOT" "$DETAIL_FILE" "$FINDINGS_FILE" "$ONLY_FINDINGS"' EXIT
mkdir -p "${ONLY_ROOT}/.claude" "${ONLY_ROOT}/dev/audit" "${ONLY_ROOT}/dev/reviews"
printf '# Review\n\n## Verdict\n\nAPPROVED\n' > "${ONLY_ROOT}/dev/reviews/screener.md"
PATH="${FAKE_ROOT}/bin:$PATH" REPO_ROOT="$ONLY_ROOT" sh "$CHECK_06" "$DETAIL_FILE" "$ONLY_FINDINGS"
if grep -q 'no test directory mapping' "$ONLY_FINDINGS"; then
  fail "no aggregate mapping line when every reviewed feature is mapped"
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "deep_scan_check06_noise_check: ${FAIL_COUNT} failure(s)" >&2
  exit 1
fi
echo "OK: deep_scan_check06_noise_check"
