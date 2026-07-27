#!/usr/bin/env bash
# record_qc_audit_test.sh — fixture-driven smoke test for record_qc_audit.sh.
#
# Verifies both modes:
#   file-mode    — dev/reviews/<feature>.md contains the structured verdicts
#                  (legacy path, transitional during PR-D' cutover)
#   pr-mode      — `gh pr view <N> --json reviews` returns the verdicts
#                  (new path, follows the PR-D agent-prompt cutover)
#
# Uses a mock `gh` binary injected via `RECORD_QC_AUDIT_GH_BIN` env hook.
#
# Run:
#   bash trading/devtools/checks/record_qc_audit_test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/record_qc_audit.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

if [[ ! -x "${SCRIPT}" ]]; then
  echo "FAIL: script not executable: ${SCRIPT}" >&2
  exit 1
fi

# write_audit.sh writes the audit JSON to dev/audit/. We don't want test runs
# to pollute that dir; the test uses a temp REPO_ROOT override.
TMP_REPO="$(mktemp -d -t record_qc_audit_test.XXXXXX)"
trap 'rm -rf "${TMP_REPO}"' EXIT

mkdir -p "${TMP_REPO}/dev/reviews" "${TMP_REPO}/dev/audit" \
         "${TMP_REPO}/trading/devtools/checks" "${TMP_REPO}/.claude"

cp "${SCRIPT}" "${TMP_REPO}/trading/devtools/checks/"
cp "${SCRIPT_DIR}/write_audit.sh" "${TMP_REPO}/trading/devtools/checks/"
chmod +x "${TMP_REPO}/trading/devtools/checks/"*.sh

PASS_COUNT=0
FAIL_COUNT=0
pass() { echo "  PASS: $*"; PASS_COUNT=$(( PASS_COUNT + 1 )); }
fail() { echo "  FAIL: $*" >&2; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }

# Mock-gh factory. Emits a tiny shell script that responds to
# `gh pr view N --json reviews [--jq '.reviews[]...']` with canned JSON
# or canned `STATE:/body/ENDBODY` framed output.
make_gh_mock() {
  local dir="$1" reviews_json_path="$2"
  mkdir -p "${dir}"
  cat > "${dir}/gh" <<EOF
#!/bin/sh
# Mock gh — only handles 'pr view <N> --json reviews [--jq ...]'.
case "\$1 \$2" in
  "pr view")
    # \$3 is PR number; \$4 is "--json"; \$5 is "reviews"; \$6 maybe "--jq"
    if [ "\$6" = "--jq" ]; then
      # Emulate jq extraction: '.reviews[] | "STATE:\(.state)\n\(.body)\nENDBODY"'
      # The fixture file is already in that format.
      cat "${reviews_json_path}"
    else
      # Bare JSON. Wrap each body into a minimal JSON shape.
      cat "${reviews_json_path}"
    fi
    ;;
  *) exit 1;;
esac
EOF
  chmod +x "${dir}/gh"
}

# ---------------------------------------------------------------------------
# Scenario 1 — file-mode regression: structural_qc + behavioral_qc fields
# in dev/reviews/<feature>.md (no PR number)
# ---------------------------------------------------------------------------
FEATURE1="file-mode-feature"
cat > "${TMP_REPO}/dev/reviews/${FEATURE1}.md" <<'EOF'
Reviewed SHA: abc123

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Structural Checklist
| ... |

## Quality Score
4 — clean implementation
EOF

out=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE1}" "feat/dummy" "2026-05-25" 2>&1) && rc=0 || rc=$?
JSON1="${TMP_REPO}/dev/audit/2026-05-25-feat-dummy-${FEATURE1}.json"
if (( rc == 0 )) && [[ -f "${JSON1}" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${JSON1}" \
   && grep -q '"behavioral_qc": *"APPROVED"' "${JSON1}" \
   && grep -q '"quality_score": *4' "${JSON1}"; then
  pass "scenario 1 — file-mode regression: APPROVED+APPROVED+score 4 extracted"
else
  fail "scenario 1 — file-mode regression: expected APPROVED+APPROVED+4; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
  [[ -f "${JSON1}" ]] && \
    echo "      json: $(cat "${JSON1}")"
fi

# ---------------------------------------------------------------------------
# Scenario 2 — PR-mode: both APPROVED states
# ---------------------------------------------------------------------------
FEATURE2="pr-mode-both-approved"
S2_DIR="${TMP_REPO}/s2"
mkdir -p "${S2_DIR}"
cat > "${S2_DIR}/reviews.jsonl" <<'EOF'
STATE:APPROVED
Reviewed SHA: def456

## Structural QC — pr-mode-both-approved

## Verdict
APPROVED
ENDBODY
STATE:APPROVED
Reviewed SHA: def456

## Behavioral QC — pr-mode-both-approved

## Quality Score
5 — exemplary

## Verdict
APPROVED
ENDBODY
EOF
make_gh_mock "${S2_DIR}" "${S2_DIR}/reviews.jsonl"

out=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S2_DIR}/gh" \
        bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE2}" "feat/dummy" "2026-05-25" --pr-number 1234 2>&1) && rc=0 || rc=$?
JSON2="${TMP_REPO}/dev/audit/2026-05-25-feat-dummy-${FEATURE2}.json"
if (( rc == 0 )) && [[ -f "${JSON2}" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${JSON2}" \
   && grep -q '"behavioral_qc": *"APPROVED"' "${JSON2}" \
   && grep -q '"overall_qc": *"APPROVED"' "${JSON2}" \
   && grep -q '"quality_score": *5' "${JSON2}"; then
  pass "scenario 2 — pr-mode both APPROVED → APPROVED overall + score 5"
else
  fail "scenario 2 — expected APPROVED+APPROVED+5; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
  [[ -f "${JSON2}" ]] && echo "      json: $(cat "${JSON2}")"
fi

# ---------------------------------------------------------------------------
# Scenario 3 — PR-mode: structural APPROVED, behavioral CHANGES_REQUESTED
# → overall NEEDS_REWORK
# ---------------------------------------------------------------------------
FEATURE3="pr-mode-mixed"
S3_DIR="${TMP_REPO}/s3"
mkdir -p "${S3_DIR}"
cat > "${S3_DIR}/reviews.jsonl" <<'EOF'
STATE:APPROVED
Reviewed SHA: ghi789

## Structural QC — pr-mode-mixed

## Verdict
APPROVED
ENDBODY
STATE:CHANGES_REQUESTED
Reviewed SHA: ghi789

## Behavioral QC — pr-mode-mixed

## Quality Score
2 — wrong threshold

## Verdict
NEEDS_REWORK
ENDBODY
EOF
make_gh_mock "${S3_DIR}" "${S3_DIR}/reviews.jsonl"

out=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S3_DIR}/gh" \
        bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE3}" "feat/dummy" "2026-05-25" --pr-number 1235 2>&1) && rc=0 || rc=$?
JSON3="${TMP_REPO}/dev/audit/2026-05-25-feat-dummy-${FEATURE3}.json"
if (( rc == 0 )) && [[ -f "${JSON3}" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${JSON3}" \
   && grep -q '"behavioral_qc": *"NEEDS_REWORK"' "${JSON3}" \
   && grep -q '"overall_qc": *"NEEDS_REWORK"' "${JSON3}" \
   && grep -q '"quality_score": *2' "${JSON3}"; then
  pass "scenario 3 — pr-mode mixed → NEEDS_REWORK overall + score 2"
else
  fail "scenario 3 — expected APPROVED+NEEDS_REWORK+overall NEEDS_REWORK+2; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
  [[ -f "${JSON3}" ]] && echo "      json: $(cat "${JSON3}")"
fi

# ---------------------------------------------------------------------------
# Scenario 4 — --pr-number with numeric arg rejected if non-numeric
# ---------------------------------------------------------------------------
out=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "test" "feat/dummy" "2026-05-25" --pr-number 'oops' 2>&1) && rc=0 || rc=$?
if (( rc == 1 )) && grep -q 'numeric argument' <<< "${out}"; then
  pass "scenario 4 — non-numeric --pr-number rejected with exit 1"
else
  fail "scenario 4 — expected rc=1 + 'numeric argument'; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 5 — PR-mode: COMMENTED state → body ## Verdict parsed (CP2 fix).
# Self-approval-blocked QC agents post `--comment` reviews; the verdict
# lives in the body's ## Verdict block, not in the state field.
# ---------------------------------------------------------------------------
FEATURE5="pr-mode-commented-body-parse"
S5_DIR="${TMP_REPO}/s5"
mkdir -p "${S5_DIR}"
cat > "${S5_DIR}/reviews.jsonl" <<'EOF'
STATE:COMMENTED
Reviewed SHA: jkl012

## Structural QC — pr-mode-commented-body-parse

## Verdict
APPROVED
ENDBODY
STATE:COMMENTED
Reviewed SHA: jkl012

## Behavioral QC — pr-mode-commented-body-parse

## Quality Score
3 — acceptable

## Verdict
NEEDS_REWORK
ENDBODY
EOF
make_gh_mock "${S5_DIR}" "${S5_DIR}/reviews.jsonl"

out=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S5_DIR}/gh" \
        bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE5}" "feat/dummy" "2026-05-25" --pr-number 1236 2>&1) && rc=0 || rc=$?
JSON5="${TMP_REPO}/dev/audit/2026-05-25-feat-dummy-${FEATURE5}.json"
if (( rc == 0 )) && [[ -f "${JSON5}" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${JSON5}" \
   && grep -q '"behavioral_qc": *"NEEDS_REWORK"' "${JSON5}" \
   && grep -q '"overall_qc": *"NEEDS_REWORK"' "${JSON5}" \
   && grep -q '"quality_score": *3' "${JSON5}"; then
  pass "scenario 5 — pr-mode COMMENTED state → body ## Verdict parsed (CP2 fix)"
else
  fail "scenario 5 — expected COMMENTED body-parse APPROVED+NEEDS_REWORK+3; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
  [[ -f "${JSON5}" ]] && echo "      json: $(cat "${JSON5}")"
fi

# ---------------------------------------------------------------------------
# Scenario 6 — --pr-number set BUT PR has no reviews → falls back to file mode
# (CP1 dual-source fallback test).
# ---------------------------------------------------------------------------
FEATURE6="pr-mode-empty-falls-back-to-file"
S6_DIR="${TMP_REPO}/s6"
mkdir -p "${S6_DIR}"
# Mock gh returns nothing for the --jq query (no reviews to extract).
cat > "${S6_DIR}/gh" <<'EOF'
#!/bin/sh
# Empty reviews list — the --jq filter returns nothing.
case "$1 $2" in
  "pr view") :;;
esac
EOF
chmod +x "${S6_DIR}/gh"

# Companion file-mode review file — fallback should land on this.
cat > "${TMP_REPO}/dev/reviews/${FEATURE6}.md" <<'EOF'
Reviewed SHA: mno345

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
5 — exemplary
EOF

out=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S6_DIR}/gh" \
        bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE6}" "feat/dummy" "2026-05-25" --pr-number 1237 2>&1) && rc=0 || rc=$?
JSON6="${TMP_REPO}/dev/audit/2026-05-25-feat-dummy-${FEATURE6}.json"
if (( rc == 0 )) && [[ -f "${JSON6}" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${JSON6}" \
   && grep -q '"behavioral_qc": *"APPROVED"' "${JSON6}" \
   && grep -q '"overall_qc": *"APPROVED"' "${JSON6}" \
   && grep -q '"quality_score": *5' "${JSON6}"; then
  pass "scenario 6 — pr-mode empty reviews → file-mode fallback (CP1 fix)"
else
  fail "scenario 6 — expected file-fallback APPROVED+APPROVED+5; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
  [[ -f "${JSON6}" ]] && echo "      json: $(cat "${JSON6}")"
fi

# ---------------------------------------------------------------------------
# Scenario 7 — H-AUDIT-COLLISION regression: two branches reviewing the same
# feature/track on the same date must produce two DISTINCT audit files
# (not one clobbering the other), while re-invoking for the SAME branch
# stays idempotent (overwrites its own record, does not accumulate a
# duplicate).
# ---------------------------------------------------------------------------
FEATURE7="weekly-snapshot"
cat > "${TMP_REPO}/dev/reviews/${FEATURE7}.md" <<'EOF'
Reviewed SHA: run1sha

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
4 — clean implementation
EOF

out=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE7}" "feat/picks-phase-c" "2026-07-27" 2>&1) && rc=0 || rc=$?
JSON7A="${TMP_REPO}/dev/audit/2026-07-27-feat-picks-phase-c-${FEATURE7}.json"

# Second review, different branch ("-v2"), same feature + same date.
cat > "${TMP_REPO}/dev/reviews/${FEATURE7}.md" <<'EOF'
Reviewed SHA: run2sha

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
5 — exemplary
EOF
out2=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE7}" "feat/picks-phase-c-v2" "2026-07-27" 2>&1) && rc2=0 || rc2=$?
JSON7B="${TMP_REPO}/dev/audit/2026-07-27-feat-picks-phase-c-v2-${FEATURE7}.json"

if (( rc == 0 )) && (( rc2 == 0 )) \
   && [[ -f "${JSON7A}" ]] && [[ -f "${JSON7B}" ]] \
   && [[ "${JSON7A}" != "${JSON7B}" ]] \
   && grep -q '"quality_score": *4' "${JSON7A}" \
   && grep -q '"quality_score": *5' "${JSON7B}"; then
  pass "scenario 7a — two branches, same feature+date → two distinct audit files (H-AUDIT-COLLISION fix)"
else
  fail "scenario 7a — expected two distinct files (q=4 and q=5); got rc=${rc}, rc2=${rc2}"
  echo "${out}" | sed 's/^/      /'
  echo "${out2}" | sed 's/^/      /'
  [[ -f "${JSON7A}" ]] && echo "      json A: $(cat "${JSON7A}")"
  [[ -f "${JSON7B}" ]] && echo "      json B: $(cat "${JSON7B}")"
fi

# Re-invoke for the FIRST branch again (idempotency check): must overwrite
# its own record, not create a third file, and JSON7B (the sibling branch's
# record) must survive untouched.
cat > "${TMP_REPO}/dev/reviews/${FEATURE7}.md" <<'EOF'
Reviewed SHA: run1sha-rerun

structural_qc: APPROVED
behavioral_qc: NEEDS_REWORK
overall_qc: NEEDS_REWORK

## Quality Score
2 — rerun found an issue
EOF
out3=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE7}" "feat/picks-phase-c" "2026-07-27" 2>&1) && rc3=0 || rc3=$?

audit_count="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "2026-07-27-*-${FEATURE7}.json" | wc -l | tr -d ' ')"

if (( rc3 == 0 )) && [[ -f "${JSON7A}" ]] && [[ -f "${JSON7B}" ]] \
   && [[ "${audit_count}" == "2" ]] \
   && grep -q '"quality_score": *2' "${JSON7A}" \
   && grep -q '"quality_score": *5' "${JSON7B}"; then
  pass "scenario 7b — re-invoking same branch overwrites its own record (idempotent, no duplicate)"
else
  fail "scenario 7b — expected exactly 2 audit files for ${FEATURE7} on 2026-07-27, JSON7A rewritten to q=2, JSON7B untouched at q=5; got rc=${rc3}, audit_count=${audit_count}"
  echo "${out3}" | sed 's/^/      /'
  [[ -f "${JSON7A}" ]] && echo "      json A: $(cat "${JSON7A}")"
  [[ -f "${JSON7B}" ]] && echo "      json B: $(cat "${JSON7B}")"
fi

# ---------------------------------------------------------------------------
# Scenario 7c — empty --branch fallback: `record_qc_audit.sh <feature> "" <date>`
# satisfies the 3-positional-arg arity check (an unset $BRANCH in the
# orchestrator's documented fallback invocation silently takes this path).
# write_audit.sh's `[ -n "$BRANCH" ]` guard treats "" the same as "omitted",
# falling back to the pre-fix dev/audit/<date>-<feature>.json shape, which
# DOES still clobber same-day sibling reviews of the same feature.
#
# This is a KNOWN, documented gap -- NOT fixed by this change (out of scope
# for the H-AUDIT-COLLISION fix, which requires a real branch value to
# disambiguate). This test pins the current (still-clobbering) behavior so
# a future change to this fallback path doesn't silently regress it further
# without updating this test.
# ---------------------------------------------------------------------------
FEATURE7C="empty-branch-fallback"
cat > "${TMP_REPO}/dev/reviews/${FEATURE7C}.md" <<'EOF'
Reviewed SHA: run1sha

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
4 — first run, empty branch
EOF

out7c_1=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE7C}" "" "2026-07-27" 2>&1) && rc7c_1=0 || rc7c_1=$?
JSON7C="${TMP_REPO}/dev/audit/2026-07-27-${FEATURE7C}.json"

cat > "${TMP_REPO}/dev/reviews/${FEATURE7C}.md" <<'EOF'
Reviewed SHA: run2sha

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
5 — second run, different track, still empty branch
EOF
out7c_2=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE7C}" "" "2026-07-27" 2>&1) && rc7c_2=0 || rc7c_2=$?

audit_count_7c="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "2026-07-27-*${FEATURE7C}.json" | wc -l | tr -d ' ')"

if (( rc7c_1 == 0 )) && (( rc7c_2 == 0 )) && [[ -f "${JSON7C}" ]] \
   && [[ "${audit_count_7c}" == "1" ]] \
   && grep -q '"quality_score": *5' "${JSON7C}"; then
  pass "scenario 7c — empty --branch reaches the no-branch fallback and still clobbers (KNOWN gap, pinned not fixed)"
else
  fail "scenario 7c — expected exactly 1 file (second run wins, q=5); got rc=${rc7c_1}/${rc7c_2}, audit_count=${audit_count_7c}"
  echo "${out7c_1}" | sed 's/^/      /'
  echo "${out7c_2}" | sed 's/^/      /'
  [[ -f "${JSON7C}" ]] && echo "      json: $(cat "${JSON7C}")"
fi

# ---------------------------------------------------------------------------
# Scenario 8 — chronological ordering regression (F1 rework fix): the
# consecutive_rework_count scan in write_audit.sh must consult same-day
# prior records in TRUE write order (recorded_at_ns), not by filename
# (branch-name) lexicographic order. Three same-date records for one
# feature, written in this order:
#   1. branch "feat/zzz" -> NEEDS_REWORK   (oldest)
#   2. branch "feat/aaa" -> APPROVED       (breaks the streak)
#   3. branch "feat/mmm" -> NEEDS_REWORK   (current record under test)
#
# Correct consecutive_rework_count for record 3 is 1 (the streak is broken
# by the APPROVED record 2 immediately preceding it in write order). The
# pre-fix `ls | sort -r` ordered these same-date records by FILENAME
# descending -- "zzz" > "mmm" > "aaa" alphabetically -- so it consulted
# "zzz" (NEEDS_REWORK) as if it immediately preceded "mmm", overcounting
# to 2. WRITE_AUDIT_RECORDED_AT_NS pins write order deterministically
# instead of relying on real wall-clock gaps between the three calls.
# ---------------------------------------------------------------------------
FEATURE8="ordering-regression"
WRITE_AUDIT="${TMP_REPO}/trading/devtools/checks/write_audit.sh"

out8_1=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=1000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-27 --feature "${FEATURE8}" --branch "feat/zzz" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK 2>&1) && rc8_1=0 || rc8_1=$?

out8_2=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=2000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-27 --feature "${FEATURE8}" --branch "feat/aaa" \
    --structural APPROVED --behavioral APPROVED --overall APPROVED 2>&1) && rc8_2=0 || rc8_2=$?

out8_3=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=3000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-27 --feature "${FEATURE8}" --branch "feat/mmm" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK 2>&1) && rc8_3=0 || rc8_3=$?

JSON8="${TMP_REPO}/dev/audit/2026-07-27-feat-mmm-${FEATURE8}.json"

if (( rc8_1 == 0 )) && (( rc8_2 == 0 )) && (( rc8_3 == 0 )) \
   && [[ -f "${JSON8}" ]] \
   && grep -q '"consecutive_rework_count": *1' "${JSON8}" \
   && echo "${out8_3}" | grep -q 'consecutive_rework_count=1'; then
  pass "scenario 8 — same-day records consulted in write order (recorded_at_ns), not filename order (F1 rework fix)"
else
  fail "scenario 8 — expected consecutive_rework_count=1 for feat/mmm record (streak broken by feat/aaa=APPROVED immediately preceding in write order); got rc=${rc8_1}/${rc8_2}/${rc8_3}"
  echo "${out8_1}" | sed 's/^/      /'
  echo "${out8_2}" | sed 's/^/      /'
  echo "${out8_3}" | sed 's/^/      /'
  [[ -f "${JSON8}" ]] && echo "      json: $(cat "${JSON8}")"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "record_qc_audit_test: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if (( FAIL_COUNT > 0 )); then
  exit 1
fi
exit 0
