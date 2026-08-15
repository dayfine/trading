#!/bin/sh
# Change-detector test for the rework-streak escalation scan in
# check_06_qc_calibration.sh (H-REWORK-STREAK-ESCALATION-UNTESTED,
# dev/status/harness.md).
#
# write_audit.sh computes and records "consecutive_rework_count" in every
# dev/audit/*.json record; its own docstring states the escalation policy
# this scan implements (write_audit.sh:37: "The escalation policy ...
# triggers human review when consecutive_rework_count >= 3 for any
# feature"). record_qc_audit_test.sh scenario 7e already pins that
# write_audit.sh COMPUTES the field correctly -- this test pins the
# previously-missing CONSUMER side: that check_06_qc_calibration.sh's
# threshold comparison actually fires at the right boundary and reports
# per-feature maxima, not one finding per record.
#
# Unlike the deep_scan_*_check.sh structural smoke tests elsewhere in this
# directory (which grep the check script for implementation markers and
# never execute it), this test actually INVOKES check_06_qc_calibration.sh
# against a synthetic dev/audit/ fixture, using the REPO_ROOT env-var
# override that _check_lib.sh's repo_root() supports (same pattern as
# deep_scan_followup_count_check.sh).
#
# Fixture (dev/audit/*.json records -- see _audit_record below):
#   featureA  consecutive_rework_count=3  -> must fire (>= 3 boundary)
#   featureB  consecutive_rework_count=2  -> must NOT fire (catches > vs >=)
#   featureC  consecutive_rework_count=4  -> must fire (catches == vs >=)
#   featureD  legacy record, field absent -> must NOT fire, must NOT crash
#   featureE  two records, counts 2 and 3 -> exactly ONE warning, at the
#             max (3) -- pins "report highest per feature, not one
#             finding per record"
#
# dev/reviews/ is left empty in the fixture: the pre-existing verdict/
# test-health cross-reference loop in check_06 has nothing to iterate
# over, so it contributes QC_CAL_COUNT=0 and does not interfere with the
# rework-streak assertions below. Its presence is still asserted (via the
# QC_CAL_COUNT metric line) as proof the script ran to completion past
# the new scan rather than aborting partway through.
#
# How to re-verify by hand:
#   sh trading/devtools/checks/deep_scan_rework_streak_check.sh

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT_REAL="$(repo_root)"
DEEP_SCAN_DIR="${REPO_ROOT_REAL}/trading/devtools/checks/deep_scan"
CHECK_06="${DEEP_SCAN_DIR}/check_06_qc_calibration.sh"
[ -f "$CHECK_06" ] || die "deep_scan_rework_streak_check: $CHECK_06 does not exist"

FAIL_COUNT=0

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: deep_scan_rework_streak_check — $1" >&2
}

FAKE_ROOT="$(mktemp -d)"
DETAIL_FILE="$(mktemp)"
FINDINGS_FILE="$(mktemp)"
: > "$FINDINGS_FILE"
trap 'rm -rf "$FAKE_ROOT" "$DETAIL_FILE" "$FINDINGS_FILE"' EXIT

mkdir -p "${FAKE_ROOT}/.claude" "${FAKE_ROOT}/dev/audit" "${FAKE_ROOT}/dev/reviews"

# $1=output path  $2=feature name  $3=count line (e.g. '"consecutive_rework_count": 3,')
# or empty string to omit the field entirely (legacy-shaped record).
_audit_record() {
  path="$1"
  feature="$2"
  count_line="$3"
  cat > "$path" <<EOF
{
  "date": "2026-08-01",
  "feature": "${feature}",
  "branch": "feat/${feature}",
  "sha": "sha-${feature}",
  "recorded_at_ns": 1000000000,
  "structural_qc": "APPROVED",
  "behavioral_qc": "NEEDS_REWORK",
  "overall_qc": "NEEDS_REWORK",
  "harness_gap": "",
  "quality_score": null,
  "findings_count": {
    "PASS": 5,
    "FAIL": 1,
    "FLAG": 0
  },
  ${count_line}
  "notes": ""
}
EOF
}

_audit_record "${FAKE_ROOT}/dev/audit/2026-08-01-feat-aaa-featureA.json" "featureA" '"consecutive_rework_count": 3,'
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-01-feat-bbb-featureB.json" "featureB" '"consecutive_rework_count": 2,'
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-01-feat-ccc-featureC.json" "featureC" '"consecutive_rework_count": 4,'
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-01-feat-ddd-featureD.json" "featureD" ''
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-01-feat-eee-featureE-r1.json" "featureE" '"consecutive_rework_count": 2,'
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-01-feat-eee-featureE-r2.json" "featureE" '"consecutive_rework_count": 3,'

REPO_ROOT="$FAKE_ROOT" sh "$CHECK_06" "$DETAIL_FILE" "$FINDINGS_FILE"

# featureA (count=3) must fire — the >= 3 boundary itself.
if ! grep -q 'Rework streak:.*`featureA`.*consecutive_rework_count=3' "$FINDINGS_FILE"; then
  fail "expected a rework-streak warning for featureA (count=3); findings file:"
  sed 's/^/      /' "$FINDINGS_FILE" >&2
fi

# featureB (count=2) must NOT fire — catches a > vs >= off-by-one.
if grep -q 'Rework streak:.*`featureB`' "$FINDINGS_FILE"; then
  fail "featureB (count=2) must NOT fire a rework-streak warning (off-by-one: > vs >=)"
fi

# featureC (count=4) must fire — catches an == 3 implementation (which
# would fire on featureA but NOT on featureC).
if ! grep -q 'Rework streak:.*`featureC`.*consecutive_rework_count=4' "$FINDINGS_FILE"; then
  fail "expected a rework-streak warning for featureC (count=4); catches an == 3 implementation instead of >= 3"
fi

# featureD (legacy record, no consecutive_rework_count field at all) must
# NOT fire, and must not have aborted the scan.
if grep -q 'Rework streak:.*`featureD`' "$FINDINGS_FILE"; then
  fail "featureD (legacy record, field absent) must NOT fire"
fi

# featureE: two records (counts 2 and 3) must produce exactly ONE
# warning, reporting the MAX (3) — not one warning per record and not
# the lower of the two.
featureE_hits="$(grep -c 'Rework streak:.*`featureE`' "$FINDINGS_FILE" || true)"
if [ "$featureE_hits" != "1" ]; then
  fail "expected exactly 1 rework-streak warning for featureE (max across its 2 records), got ${featureE_hits}"
fi
if ! grep -q 'Rework streak:.*`featureE`.*consecutive_rework_count=3' "$FINDINGS_FILE"; then
  fail "featureE's single warning must report the MAX count (3), not the lower record's count (2)"
fi

# Metric line: 3 features over threshold (A, C, E) — B and D excluded.
if ! grep -q '^M: REWORK_STREAK_COUNT=3' "$FINDINGS_FILE"; then
  fail "expected 'M: REWORK_STREAK_COUNT=3' in findings (featureA + featureC + featureE); got:"
  grep '^M: REWORK_STREAK_COUNT' "$FINDINGS_FILE" >&2 || echo "      <missing>" >&2
fi

# Proof the scan did not abort check_06 partway through: the pre-existing
# verdict/test-health cross-reference logic still ran and emitted its
# metric (0, since dev/reviews/ is empty in this fixture).
if ! grep -q '^M: QC_CAL_COUNT=0' "$FINDINGS_FILE"; then
  fail "check_06 did not complete normally (missing/wrong QC_CAL_COUNT metric) — rework-streak scan may have aborted the script"
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL: deep_scan_rework_streak_check — ${FAIL_COUNT} assertion(s) failed" >&2
  exit 1
fi

echo "OK: rework-streak escalation scan (H-REWORK-STREAK-ESCALATION-UNTESTED) change-detector test passed."
