#!/usr/bin/env bash
# qc_score_lexicon_check_test.sh — fixture-driven self-test for
# qc_score_lexicon_check.sh (H-QC-SCORE-ADJECTIVE-LEXICON).
#
# Exercises the two sourced functions directly (qc_score_lexicon_warn,
# qc_score_lexicon_extract_rationale_line) rather than going through
# record_qc_audit.sh's full extraction pipeline — that pipeline already has
# its own 50+-scenario regression suite (record_qc_audit_test.sh), which
# also carries two lightweight end-to-end integration scenarios proving
# this check is actually wired into it (see that file's scenarios naming
# H-QC-SCORE-ADJECTIVE-LEXICON).
#
# Run:
#   bash trading/devtools/checks/qc_score_lexicon_check_test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${SCRIPT_DIR}/qc_score_lexicon_check.sh"

if [[ ! -f "${LIB}" ]]; then
  echo "FAIL: library not found: ${LIB}" >&2
  exit 1
fi

# shellcheck source=trading/devtools/checks/qc_score_lexicon_check.sh
. "${LIB}"

PASS_COUNT=0
FAIL_COUNT=0
pass() { echo "  PASS: $*"; PASS_COUNT=$(( PASS_COUNT + 1 )); }
fail() { echo "  FAIL: $*" >&2; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }

# ---------------------------------------------------------------------------
# Scenario 1 — non-vacuity: a genuine mismatch (low digit, positive word)
# actually fires a warning. Reproduces the #2115 shape verbatim (score 1
# captioned "Excellent").
# ---------------------------------------------------------------------------
out1=$(qc_score_lexicon_warn "1" "1 — Excellent implementation, no changes needed." 2>&1) && rc1=0 || rc1=$?
if (( rc1 == 0 )) && grep -q "WARN:" <<<"${out1}" && grep -qi "excellent" <<<"${out1}"; then
  pass "scenario 1 — digit 1 + 'Excellent' fires WARN (the #2115 shape), rc=0 (non-vacuity proof: the warning DOES fire on a real mismatch)"
else
  fail "scenario 1 — expected rc=0 + WARN mentioning 'excellent'; got rc=${rc1}, output:"
  echo "${out1}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 2 — silent on correct polarity: low digit + negative word (the
# CORRECT pairing per qc-behavioral.md's own rubric labels for score 1:
# "Significant issues" / "Fundamental domain logic errors").
# ---------------------------------------------------------------------------
out2=$(qc_score_lexicon_warn "1" "1 — Fundamental domain logic errors throughout the stage classifier." 2>&1) && rc2=0 || rc2=$?
if (( rc2 == 0 )) && [[ -z "${out2}" ]]; then
  pass "scenario 2 — digit 1 + 'Fundamental' (correct polarity per the rubric's own score-1 label) stays silent, rc=0 (non-vacuity proof: the check does NOT fire on every lexicon word, only on a mismatch)"
else
  fail "scenario 2 — expected rc=0 + empty output; got rc=${rc2}, output:"
  echo "${out2}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 3 — silent on correct polarity: high digit + positive word.
# ---------------------------------------------------------------------------
out3=$(qc_score_lexicon_warn "5" "5 — Exemplary implementation, could serve as reference." 2>&1) && rc3=0 || rc3=$?
if (( rc3 == 0 )) && [[ -z "${out3}" ]]; then
  pass "scenario 3 — digit 5 + 'Exemplary' (correct polarity) stays silent, rc=0"
else
  fail "scenario 3 — expected rc=0 + empty output; got rc=${rc3}, output:"
  echo "${out3}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 4 — mismatch the other direction: high digit + negative word.
# ---------------------------------------------------------------------------
out4=$(qc_score_lexicon_warn "5" "5 — Wrong assumption baked into the core loop, otherwise fine." 2>&1) && rc4=0 || rc4=$?
if (( rc4 == 0 )) && grep -q "WARN:" <<<"${out4}" && grep -qi "wrong" <<<"${out4}"; then
  pass "scenario 4 — digit 5 + 'Wrong' fires WARN, rc=0 (mismatch detected in the high-digit direction too)"
else
  fail "scenario 4 — expected rc=0 + WARN mentioning 'wrong'; got rc=${rc4}, output:"
  echo "${out4}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 5 — the middle digit (3) never warns, even with both lexicon
# words present in the same rationale (no polarity expectation to violate).
# ---------------------------------------------------------------------------
out5=$(qc_score_lexicon_warn "3" "3 — Fundamentally clean structure, one flag, otherwise excellent." 2>&1) && rc5=0 || rc5=$?
if (( rc5 == 0 )) && [[ -z "${out5}" ]]; then
  pass "scenario 5 — digit 3 stays silent regardless of lexicon word presence (no polarity expectation for a middling score)"
else
  fail "scenario 5 — expected rc=0 + empty output; got rc=${rc5}, output:"
  echo "${out5}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 6 — empty / out-of-range digit never warns (record_qc_audit.sh's
# own 1..5 range validation, H-QC-SCALE, is the place that enforces range;
# this check must not duplicate that as a second, softer signal).
# ---------------------------------------------------------------------------
out6a=$(qc_score_lexicon_warn "" "Excellent." 2>&1) && rc6a=0 || rc6a=$?
out6b=$(qc_score_lexicon_warn "7" "Wrong all over." 2>&1) && rc6b=0 || rc6b=$?
if (( rc6a == 0 )) && [[ -z "${out6a}" ]] && (( rc6b == 0 )) && [[ -z "${out6b}" ]]; then
  pass "scenario 6 — empty digit and out-of-range digit '7' both stay silent, rc=0"
else
  fail "scenario 6 — expected both rc=0 + empty output; got rc6a=${rc6a} out=${out6a}, rc6b=${rc6b} out=${out6b}"
fi

# ---------------------------------------------------------------------------
# Scenario 7 — case-insensitivity: uppercase lexicon word still matches.
# ---------------------------------------------------------------------------
out7=$(qc_score_lexicon_warn "1" "1 — EXCELLENT effort, minor nits only." 2>&1) && rc7=0 || rc7=$?
if (( rc7 == 0 )) && grep -q "WARN:" <<<"${out7}"; then
  pass "scenario 7 — uppercase 'EXCELLENT' still matches case-insensitively"
else
  fail "scenario 7 — expected rc=0 + WARN; got rc=${rc7}, output:"
  echo "${out7}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 8 — word-boundary: 'unbroken' must NOT false-match the negative
# word 'broken' as a bare substring ('unbroken' genuinely contains the
# literal substring "broken" — grep -qi alone WOULD match it; only the
# word-boundary flag correctly refuses. 'brokerage' does NOT contain
# "broken" as a substring at all — b-r-o-k-e-r vs b-r-o-k-e-n diverge
# after "broke" — so it would never have exercised the -w flag either way;
# an earlier draft of this scenario used it and passed vacuously).
# ---------------------------------------------------------------------------
out8=$(qc_score_lexicon_warn "5" "5 — An unbroken chain of green runs, all good." 2>&1) && rc8=0 || rc8=$?
if (( rc8 == 0 )) && [[ -z "${out8}" ]]; then
  pass "scenario 8 — 'unbroken' does not false-match 'broken' as a bare substring (word-boundary match required and present)"
else
  fail "scenario 8 — expected rc=0 + empty output (no false substring match); got rc=${rc8}, output:"
  echo "${out8}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 9 — extraction: last "## Quality Score" section wins across a
# multi-pass (rework) blob, mirroring record_qc_audit.sh's own "last
# section wins" precedence for a rework file with two passes.
# ---------------------------------------------------------------------------
BLOB9="## Quality Score

2 — Below standard, missing coverage.

## Verdict
NEEDS_REWORK

## Quality Score

4 — Good, coverage gap addressed.

## Verdict
APPROVED"
line9="$(qc_score_lexicon_extract_rationale_line "${BLOB9}")"
if [[ "${line9}" == "4 — Good, coverage gap addressed." ]]; then
  pass "scenario 9 — extraction returns the LAST Quality Score section's line across a two-pass rework blob, not the first"
else
  fail "scenario 9 — expected '4 — Good, coverage gap addressed.'; got '${line9}'"
fi

# ---------------------------------------------------------------------------
# Scenario 10 — extraction strips bold-wrapped digit lines
# ("**5 — Exemplary.**" -> "5 — Exemplary.").
# ---------------------------------------------------------------------------
BLOB10="## Quality Score

**5 — Exemplary.**

## Verdict
APPROVED"
line10="$(qc_score_lexicon_extract_rationale_line "${BLOB10}")"
if [[ "${line10}" == "5 — Exemplary." ]]; then
  pass "scenario 10 — extraction strips leading/trailing '**' from a bold-wrapped Quality Score line"
else
  fail "scenario 10 — expected '5 — Exemplary.'; got '${line10}'"
fi

# ---------------------------------------------------------------------------
# Scenario 11 — extraction on a blob with no Quality Score heading at all
# returns empty (no crash, no stale/garbage line).
# ---------------------------------------------------------------------------
line11="$(qc_score_lexicon_extract_rationale_line "## Structural QC

## Verdict
APPROVED")"
if [[ -z "${line11}" ]]; then
  pass "scenario 11 — extraction on a blob with no Quality Score heading returns empty"
else
  fail "scenario 11 — expected empty; got '${line11}'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "qc_score_lexicon_check_test: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"

if (( FAIL_COUNT > 0 )); then
  exit 1
fi
exit 0
