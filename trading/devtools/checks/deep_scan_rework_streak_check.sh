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
#   featureE  two records, counts 2 and 3, SAME recorded_at_ns -> exactly
#             ONE warning, at the higher of the two (3) -- pins "report
#             one finding per feature, not per record" plus the
#             tie-break rule (same recorded_at_ns -> prefer higher count)
#   featureF  two records with DISTINCT recorded_at_ns: an earlier
#             NEEDS_REWORK at count=4, then a LATER APPROVED reset at
#             count=0 -> must NOT fire. Pins the resolved-streak case a
#             max-across-all-history reading would get wrong: the scan
#             must key on the LATEST record (write order, via
#             recorded_at_ns), not the highest count ever recorded, or a
#             resolved streak could never stop escalating (see
#             write_audit.sh's "If APPROVED, the streak resets to 0").
#   featureG  legacy record: consecutive_rework_count PRESENT (4,
#             NEEDS_REWORK) but recorded_at_ns ABSENT, then a LATER
#             modern APPROVED reset (count=0, recorded_at_ns=9e9) -> must
#             NOT fire. Pins check_06_qc_calibration.sh's
#             "recorded_at_ns absent -> defaults to 0 (oldest)" branch,
#             which is 67% of live dev/audit/ records (count present, no
#             recorded_at_ns) and was previously unexercised by any
#             fixture (2026-08-16 QC finding, rework iteration 2).
#   featureH  fire-direction mirror of featureF: an earlier APPROVED
#             reset (count=0, recorded_at_ns=1e9), then a LATER
#             NEEDS_REWORK streak (count=3, recorded_at_ns=9e9) -> MUST
#             fire, at 3. Without this, an implementation that suppresses
#             any feature ever APPROVED (rather than keying on the
#             latest record) would pass the whole suite while missing a
#             real escalation.
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
# $4=recorded_at_ns (default 1000000000; pass an EXPLICIT empty string ""
# to omit the "recorded_at_ns" field entirely -- the count-present /
# timestamp-absent legacy shape, see featureG below). Uses "${4-...}"
# (no colon) so an explicit "" is distinguished from "unset": with a
# colon, "${4:-1000000000}" would substitute the default for an explicit
# empty string too, making omission unreachable from a caller.
# $5=overall_qc (default NEEDS_REWORK)
_audit_record() {
  path="$1"
  feature="$2"
  count_line="$3"
  recorded_at_ns="${4-1000000000}"
  overall_qc="${5:-NEEDS_REWORK}"
  if [ -n "$recorded_at_ns" ]; then
    recorded_at_ns_line="\"recorded_at_ns\": ${recorded_at_ns},"
  else
    recorded_at_ns_line=""
  fi
  cat > "$path" <<EOF
{
  "date": "2026-08-01",
  "feature": "${feature}",
  "branch": "feat/${feature}",
  "sha": "sha-${feature}",
  ${recorded_at_ns_line}
  "structural_qc": "APPROVED",
  "behavioral_qc": "${overall_qc}",
  "overall_qc": "${overall_qc}",
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
# featureF: resolved streak -- an earlier NEEDS_REWORK record at
# count=4 (recorded_at_ns=1e9) followed by a LATER APPROVED reset at
# count=0 (recorded_at_ns=9e9). The latest record is the one that
# matters; a max-across-all-history reading would wrongly fire on the
# stale 4.
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-01-feat-fff-featureF-r1.json" "featureF" '"consecutive_rework_count": 4,' "1000000000" "NEEDS_REWORK"
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-02-feat-fff-featureF-r2.json" "featureF" '"consecutive_rework_count": 0,' "9000000000" "APPROVED"

# featureG: legacy record -- consecutive_rework_count PRESENT (4,
# NEEDS_REWORK) but recorded_at_ns ABSENT -- followed by a LATER modern
# APPROVED reset (count=0, recorded_at_ns=9e9). Must NOT fire. This is
# the dominant live dev/audit/ shape (81 of 121 records, 67%, as of the
# 2026-08-16 QC finding): count present, no recorded_at_ns. The absent
# timestamp must default to 0 (oldest) so the later modern reset still
# wins the latest-record comparison -- pins
# check_06_qc_calibration.sh:219's `[ -z "$streak_recorded_at" ] &&
# streak_recorded_at=0` default, which no fixture previously executed.
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-01-feat-ggg-featureG-r1.json" "featureG" '"consecutive_rework_count": 4,' "" "NEEDS_REWORK"
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-02-feat-ggg-featureG-r2.json" "featureG" '"consecutive_rework_count": 0,' "9000000000" "APPROVED"

# featureH: fire-direction mirror of featureF -- an earlier APPROVED
# reset (count=0, recorded_at_ns=1e9) followed by a LATER NEEDS_REWORK
# streak (count=3, recorded_at_ns=9e9). Must fire, at 3. Without this,
# an implementation that suppresses any feature that was EVER APPROVED
# (rather than keying on the latest record) would pass the entire
# committed fixture while producing a missed escalation -- the failure
# write_audit.sh explicitly calls the worse one.
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-01-feat-hhh-featureH-r1.json" "featureH" '"consecutive_rework_count": 0,' "1000000000" "APPROVED"
_audit_record "${FAKE_ROOT}/dev/audit/2026-08-02-feat-hhh-featureH-r2.json" "featureH" '"consecutive_rework_count": 3,' "9000000000" "NEEDS_REWORK"

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

# featureE: two records (counts 2 and 3) sharing the SAME recorded_at_ns
# must produce exactly ONE warning, reporting the higher of the two (3)
# per the tie-break rule — not one warning per record and not the lower
# of the two.
featureE_hits="$(grep -c 'Rework streak:.*`featureE`' "$FINDINGS_FILE" || true)"
if [ "$featureE_hits" != "1" ]; then
  fail "expected exactly 1 rework-streak warning for featureE (tie-break across its 2 same-timestamp records), got ${featureE_hits}"
fi
if ! grep -q 'Rework streak:.*`featureE`.*consecutive_rework_count=3' "$FINDINGS_FILE"; then
  fail "featureE's single warning must report the higher tied count (3), not the lower record's count (2)"
fi

# featureF: an earlier NEEDS_REWORK record (count=4) followed by a LATER
# APPROVED reset (count=0) must NOT fire — the scan must key on the
# LATEST record (by recorded_at_ns), not the highest count ever seen.
# This is the resolved-streak case: keying on max instead of latest
# would make the escalation permanently unclearable (write_audit.sh: "If
# APPROVED, the streak resets to 0").
if grep -q 'Rework streak:.*`featureF`' "$FINDINGS_FILE"; then
  fail "featureF (resolved: count=4 then a later APPROVED count=0) must NOT fire — scan must key on latest record, not max-ever count"
fi

# featureG: legacy record (count=4, NO recorded_at_ns -> defaults to 0,
# oldest) followed by a later modern APPROVED reset (count=0, ns=9e9)
# must NOT fire. Pins the absent-recorded_at_ns default branch
# (check_06_qc_calibration.sh:219), which is 67% of live dev/audit/
# records (2026-08-16 QC finding) and was previously unexercised by any
# fixture here.
if grep -q 'Rework streak:.*`featureG`' "$FINDINGS_FILE"; then
  fail "featureG (legacy count=4 with no recorded_at_ns, later APPROVED reset) must NOT fire — an absent timestamp must default to oldest (0), not win the latest-record comparison"
fi

# featureH: an earlier APPROVED reset (count=0) followed by a LATER
# NEEDS_REWORK streak (count=3) must fire, at 3 — the fire-direction
# mirror of featureF. Without this, an implementation that suppresses
# any feature that was ever APPROVED (instead of keying on the latest
# record) would pass the whole suite while missing a real escalation.
if ! grep -q 'Rework streak:.*`featureH`.*consecutive_rework_count=3' "$FINDINGS_FILE"; then
  fail "expected a rework-streak warning for featureH (count=3, latest record after an earlier APPROVED reset)"
fi

# Metric line: 4 features over threshold (A, C, E, H) — B, D, F, G excluded.
if ! grep -q '^M: REWORK_STREAK_COUNT=4' "$FINDINGS_FILE"; then
  fail "expected 'M: REWORK_STREAK_COUNT=4' in findings (featureA + featureC + featureE + featureH); got:"
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
