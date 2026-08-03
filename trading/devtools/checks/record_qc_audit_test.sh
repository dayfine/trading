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
# Scenario 9 — legacy-record crash regression (F1 rework-2 fix): a prior
# audit record with NO "recorded_at_ns" field (i.e. written before that
# field existed, or by any tool that doesn't set it) must NOT abort the
# script when the current call is on the NEEDS_REWORK path. Pre-fix, the
# `grep -o ... | head -1 | sed ...` pipeline extracting recorded_at_ns
# exited 1 (no match) under `set -euo pipefail`, which killed the whole
# script before it ever wrote the current record -- silently, with no
# error message, destroying exactly the write that was supposed to extend
# the consecutive_rework_count streak. This seeds a legacy-shaped record
# (no recorded_at_ns key at all) and asserts the current call still
# succeeds, still writes its own record, and still counts the legacy
# record into the streak (defaulting its write-order to 0 / oldest, per
# the docstring above the extraction).
# ---------------------------------------------------------------------------
FEATURE9="legacy-no-recorded-at-ns"
mkdir -p "${TMP_REPO}/dev/audit"
cat > "${TMP_REPO}/dev/audit/2026-07-20-harness-old-${FEATURE9}.json" <<EOF
{
  "date": "2026-07-20",
  "feature": "${FEATURE9}",
  "branch": "harness/old",
  "structural_qc": "APPROVED",
  "behavioral_qc": "NEEDS_REWORK",
  "overall_qc": "NEEDS_REWORK",
  "harness_gap": "",
  "quality_score": null,
  "findings_count": { "PASS": 1, "FAIL": 1, "FLAG": 0 },
  "consecutive_rework_count": 1,
  "notes": ""
}
EOF

out9=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=4000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-27 --feature "${FEATURE9}" --branch "harness/new" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK 2>&1) && rc9=0 || rc9=$?
JSON9="${TMP_REPO}/dev/audit/2026-07-27-harness-new-${FEATURE9}.json"

if (( rc9 == 0 )) && [[ -f "${JSON9}" ]] \
   && grep -q '"consecutive_rework_count": *2' "${JSON9}" \
   && echo "${out9}" | grep -q 'consecutive_rework_count=2'; then
  pass "scenario 9 — legacy record with no recorded_at_ns does not abort the script (F1 rework-2 fix)"
else
  fail "scenario 9 — expected rc=0, record written, consecutive_rework_count=2; got rc=${rc9}"
  echo "${out9}" | sed 's/^/      /'
  [[ -f "${JSON9}" ]] && echo "      json: $(cat "${JSON9}")"
fi

# ---------------------------------------------------------------------------
# Scenario 10 — N2 rework-2 fix: a non-numeric WRITE_AUDIT_RECORDED_AT_NS
# override must never reach the JSON body unquoted (which would write
# invalid JSON straight into a committed audit record). The override is a
# test-only knob, so a bad value is treated as a caller/fixture bug: hard
# fail with a clear message and write nothing, rather than silently
# substituting some other value.
# ---------------------------------------------------------------------------
FEATURE10="bad-override-rejected"
audit_count_before_10="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE10}.json" | wc -l | tr -d ' ')"

out10=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=oops \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-27 --feature "${FEATURE10}" --branch "harness/x" \
    --structural APPROVED --behavioral APPROVED --overall APPROVED 2>&1) && rc10=0 || rc10=$?
audit_count_after_10="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE10}.json" | wc -l | tr -d ' ')"

if (( rc10 == 1 )) && [[ "${audit_count_before_10}" == "0" ]] && [[ "${audit_count_after_10}" == "0" ]] \
   && echo "${out10}" | grep -q 'must be a nonnegative integer'; then
  pass "scenario 10 — non-numeric WRITE_AUDIT_RECORDED_AT_NS rejected, no record written (N2 fix)"
else
  fail "scenario 10 — expected rc=1, no file written, 'must be a nonnegative integer' message; got rc=${rc10}, before=${audit_count_before_10}, after=${audit_count_after_10}"
  echo "${out10}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 11 — N3 rework-2 fix: a BSD/macOS-style `date` that does not
# support %N (emits the literal suffix "N" instead of nanoseconds, e.g.
# "1753660800N") must not let that literal "N" reach the JSON body as an
# invalid numeric literal. Simulated via a mock `date` shim prepended to
# PATH; the real `date -u +%s` (used for the graceful-degrade fallback)
# is still available on PATH under its real name via an absolute-path
# passthrough in the shim.
# ---------------------------------------------------------------------------
FEATURE11="bsd-date-no-percent-n"
S11_DIR="${TMP_REPO}/s11-bin"
mkdir -p "${S11_DIR}"
REAL_DATE="$(command -v date)"
cat > "${S11_DIR}/date" <<EOF
#!/bin/sh
if [ "\$1" = "-u" ] && [ "\$2" = "+%s%N" ]; then
  echo "\$(${REAL_DATE} -u +%s)N"
else
  exec ${REAL_DATE} "\$@"
fi
EOF
chmod +x "${S11_DIR}/date"

out11=$(REPO_ROOT="${TMP_REPO}" PATH="${S11_DIR}:${PATH}" \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-27 --feature "${FEATURE11}" --branch "harness/x" \
    --structural APPROVED --behavioral APPROVED --overall APPROVED 2>&1) && rc11=0 || rc11=$?
JSON11="${TMP_REPO}/dev/audit/2026-07-27-harness-x-${FEATURE11}.json"

if (( rc11 == 0 )) && [[ -f "${JSON11}" ]] \
   && grep -qE '"recorded_at_ns": [0-9]+,' "${JSON11}" \
   && ! grep -q 'N,' "${JSON11}"; then
  pass "scenario 11 — BSD-style date lacking %N degrades to a valid numeric timestamp, not a literal N (N3 fix)"
else
  fail "scenario 11 — expected rc=0, recorded_at_ns to be a plain integer with no literal N; got rc=${rc11}"
  echo "${out11}" | sed 's/^/      /'
  [[ -f "${JSON11}" ]] && echo "      json: $(cat "${JSON11}")"
fi

# ---------------------------------------------------------------------------
# Scenario 12 — H-QC-SCALE hardening: an out-of-range quality score parsed
# from a dev/reviews/<feature>.md file (file-mode) must be rejected loudly
# rather than silently dropped or written into a malformed audit record.
# Before this fix, the extraction regex only matched a leading [1-5] char,
# so a value like "7" simply failed to match and quality_score silently came
# out as null -- no error, no record of the fact that the review posted a
# bogus score. Now the extractor captures the full leading digit run and an
# explicit range check fails the whole script when it is out of 1..5.
# ---------------------------------------------------------------------------
FEATURE12="out-of-range-score-file-mode"
cat > "${TMP_REPO}/dev/reviews/${FEATURE12}.md" <<'EOF'
Reviewed SHA: outofrange1

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
7 — inverted or bogus score
EOF

audit_count_before_12="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE12}.json" | wc -l | tr -d ' ')"

out12=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE12}" "feat/dummy" "2026-05-25" 2>&1) && rc12=0 || rc12=$?

audit_count_after_12="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE12}.json" | wc -l | tr -d ' ')"

if (( rc12 == 1 )) && [[ "${audit_count_before_12}" == "0" ]] && [[ "${audit_count_after_12}" == "0" ]] \
   && echo "${out12}" | grep -q "quality score '7' is not an integer in 1..5"; then
  pass "scenario 12 — out-of-range quality score (file-mode) rejected with exit 1, no record written (H-QC-SCALE)"
else
  fail "scenario 12 — expected rc=1, no file written, message naming '7'; got rc=${rc12}, before=${audit_count_before_12}, after=${audit_count_after_12}"
  echo "${out12}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 13 — H-QC-SCALE hardening, second consumer: write_audit.sh itself
# rejects an out-of-range --quality-score even when called directly (the
# fallback path documented in lead-orchestrator.md when record_qc_audit.sh
# is bypassed). This is the last line of defense before a malformed
# quality_score reaches the committed JSON body.
# ---------------------------------------------------------------------------
FEATURE13="out-of-range-score-direct"
audit_count_before_13="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE13}.json" | wc -l | tr -d ' ')"

out13=$(REPO_ROOT="${TMP_REPO}" bash "${WRITE_AUDIT}" \
  --date 2026-07-27 --feature "${FEATURE13}" --branch "harness/y" \
  --structural APPROVED --behavioral APPROVED --overall APPROVED \
  --quality-score 0 2>&1) && rc13=0 || rc13=$?

audit_count_after_13="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE13}.json" | wc -l | tr -d ' ')"

if (( rc13 == 1 )) && [[ "${audit_count_before_13}" == "0" ]] && [[ "${audit_count_after_13}" == "0" ]] \
   && echo "${out13}" | grep -q "must be an integer 1..5" \
   && echo "${out13}" | grep -q "got: '0'"; then
  pass "scenario 13 — write_audit.sh rejects out-of-range --quality-score directly, no record written (H-QC-SCALE)"
else
  fail "scenario 13 — expected rc=1, no file written, message naming '0'; got rc=${rc13}, before=${audit_count_before_13}, after=${audit_count_after_13}"
  echo "${out13}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 14 — H-AUDIT-GH-FALLBACK: a missing `gh` binary with --pr-number
# set must refuse loudly, not silently fall back to dev/reviews/<feature>.md
# (which may belong to an entirely different PR/run for the same feature
# name). Before this fix, a missing `gh` produced empty $BODIES -- identical
# in shape to "PR legitimately has no reviews yet" (scenario 6) -- and the
# script read whatever unrelated review file happened to sit at that path,
# writing its verdict as this PR's audit record with exit 0. Observed in
# production: a NEEDS_REWORK PR got recorded as APPROVED this way, resetting
# the consecutive_rework_count streak.
#
# The fixture review file below deliberately holds an APPROVED verdict (the
# WRONG answer this PR's real reviews say NEEDS_REWORK) to prove the fallback
# is refused rather than silently consumed.
# ---------------------------------------------------------------------------
FEATURE14="gh-missing-refuses-file-fallback"
cat > "${TMP_REPO}/dev/reviews/${FEATURE14}.md" <<'EOF'
Reviewed SHA: unrelatedsha

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
5 — this file belongs to a different run and must NOT be used
EOF

audit_count_before_14="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE14}.json" | wc -l | tr -d ' ')"

out14=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="/nonexistent/gh-binary-that-does-not-exist" \
  bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
  "${FEATURE14}" "feat/dummy" "2026-05-25" --pr-number 2129 2>&1) && rc14=0 || rc14=$?

audit_count_after_14="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE14}.json" | wc -l | tr -d ' ')"

if (( rc14 == 1 )) && [[ "${audit_count_before_14}" == "0" ]] && [[ "${audit_count_after_14}" == "0" ]] \
   && echo "${out14}" | grep -q "not available on PATH" \
   && echo "${out14}" | grep -q "dev/reviews/${FEATURE14}.md"; then
  pass "scenario 14 — missing gh binary with --pr-number refuses file-mode fallback, no record written (H-AUDIT-GH-FALLBACK)"
else
  fail "scenario 14 — expected rc=1, no file written, message naming missing gh + review path; got rc=${rc14}, before=${audit_count_before_14}, after=${audit_count_after_14}"
  echo "${out14}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 15 — H-QC-SCALE boundary: quality score '0' (file-mode) rejected.
# record_qc_audit.sh's own range check (`^[1-5]$`) must refuse 0, not just
# out-of-range values above 5 (scenario 12 only pins the upper side, via
# '7'). Asserts on record_qc_audit.sh's OWN failure message ("... is not an
# integer in 1..5") specifically, so a mutation that widens ITS range check
# to accept 0 (e.g. `^[0-5]$`) shows up here even though write_audit.sh's
# independent check would otherwise catch the bad value downstream with a
# different message and mask the regression.
# ---------------------------------------------------------------------------
FEATURE15="zero-score-file-mode"
cat > "${TMP_REPO}/dev/reviews/${FEATURE15}.md" <<'EOF'
Reviewed SHA: zeroscore1

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
0 — bogus zero score
EOF

audit_count_before_15="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE15}.json" | wc -l | tr -d ' ')"

out15=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE15}" "feat/dummy" "2026-05-25" 2>&1) && rc15=0 || rc15=$?

audit_count_after_15="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE15}.json" | wc -l | tr -d ' ')"

if (( rc15 == 1 )) && [[ "${audit_count_before_15}" == "0" ]] && [[ "${audit_count_after_15}" == "0" ]] \
   && echo "${out15}" | grep -q "quality score '0' is not an integer in 1..5"; then
  pass "scenario 15 — zero quality score (file-mode) rejected with exit 1, no record written (H-QC-SCALE lower bound)"
else
  fail "scenario 15 — expected rc=1, no file written, message naming '0'; got rc=${rc15}, before=${audit_count_before_15}, after=${audit_count_after_15}"
  echo "${out15}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 16 — H-QC-SCALE boundary: double-digit quality score '10'
# (file-mode) rejected, AND pins that the extractor captures the FULL
# leading digit run rather than truncating to a single character. Before
# the extractor was widened (see the H-QC-SCALE comment above the
# extraction logic), a score of "10" would have been silently truncated to
# "1" -- an in-range but WRONG value, accepted with exit 0. This scenario
# is the demonstrated production-shaped escape: it fails only if BOTH the
# multi-digit capture holds AND the range check's end-anchor rejects the
# resulting "10" outright (a dropped end anchor lets "10" match a leading
# "1" and pass).
# ---------------------------------------------------------------------------
FEATURE16="ten-score-file-mode"
cat > "${TMP_REPO}/dev/reviews/${FEATURE16}.md" <<'EOF'
Reviewed SHA: tenscore1

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
10 — double-digit bogus score
EOF

audit_count_before_16="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE16}.json" | wc -l | tr -d ' ')"

out16=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE16}" "feat/dummy" "2026-05-25" 2>&1) && rc16=0 || rc16=$?

audit_count_after_16="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE16}.json" | wc -l | tr -d ' ')"

if (( rc16 == 1 )) && [[ "${audit_count_before_16}" == "0" ]] && [[ "${audit_count_after_16}" == "0" ]] \
   && echo "${out16}" | grep -q "quality score '10' is not an integer in 1..5"; then
  pass "scenario 16 — double-digit quality score '10' (file-mode) rejected, pins multi-digit capture + end-anchored range check"
else
  fail "scenario 16 — expected rc=1, no file written, message naming '10'; got rc=${rc16}, before=${audit_count_before_16}, after=${audit_count_after_16}"
  echo "${out16}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 17 — H-QC-SCALE boundary: write_audit.sh's OWN --quality-score
# range check refuses '6' when called directly (the fallback path per
# lead-orchestrator.md when record_qc_audit.sh is bypassed). Mirrors
# scenario 13 (which pins '0' on this path); this pins the upper boundary
# so a widened range (e.g. `^[1-6]$`, accepting 6 as if it were still
# "1..5") is caught even though nothing upstream calls this path with an
# already-invalid value to filter first.
# ---------------------------------------------------------------------------
FEATURE17="six-score-direct"
audit_count_before_17="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE17}.json" | wc -l | tr -d ' ')"

out17=$(REPO_ROOT="${TMP_REPO}" bash "${WRITE_AUDIT}" \
  --date 2026-07-27 --feature "${FEATURE17}" --branch "harness/y" \
  --structural APPROVED --behavioral APPROVED --overall APPROVED \
  --quality-score 6 2>&1) && rc17=0 || rc17=$?

audit_count_after_17="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE17}.json" | wc -l | tr -d ' ')"

if (( rc17 == 1 )) && [[ "${audit_count_before_17}" == "0" ]] && [[ "${audit_count_after_17}" == "0" ]] \
   && echo "${out17}" | grep -q "must be an integer 1..5" \
   && echo "${out17}" | grep -q "got: '6'"; then
  pass "scenario 17 — write_audit.sh rejects --quality-score 6 directly, no record written (H-QC-SCALE upper bound)"
else
  fail "scenario 17 — expected rc=1, no file written, message naming '6'; got rc=${rc17}, before=${audit_count_before_17}, after=${audit_count_after_17}"
  echo "${out17}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 18 — H-QC-SCALE boundary: write_audit.sh's OWN --quality-score
# range check refuses non-integer garbage ('3.5') on the direct path,
# independent of record_qc_audit.sh's extraction (bypassed entirely here).
# The end-anchored `^[1-5]$` is what rejects this -- a mutation that drops
# the end anchor lets "3.5" match a leading "3" and pass through as a
# non-integer value baked into the committed audit JSON.
# ---------------------------------------------------------------------------
FEATURE18="decimal-score-direct"
audit_count_before_18="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE18}.json" | wc -l | tr -d ' ')"

out18=$(REPO_ROOT="${TMP_REPO}" bash "${WRITE_AUDIT}" \
  --date 2026-07-27 --feature "${FEATURE18}" --branch "harness/y" \
  --structural APPROVED --behavioral APPROVED --overall APPROVED \
  --quality-score 3.5 2>&1) && rc18=0 || rc18=$?

audit_count_after_18="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE18}.json" | wc -l | tr -d ' ')"

if (( rc18 == 1 )) && [[ "${audit_count_before_18}" == "0" ]] && [[ "${audit_count_after_18}" == "0" ]] \
   && echo "${out18}" | grep -q "must be an integer 1..5" \
   && echo "${out18}" | grep -q "got: '3.5'"; then
  pass "scenario 18 — write_audit.sh rejects --quality-score 3.5 directly, no record written (H-QC-SCALE non-integer)"
else
  fail "scenario 18 — expected rc=1, no file written, message naming '3.5'; got rc=${rc18}, before=${audit_count_before_18}, after=${audit_count_after_18}"
  echo "${out18}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 19 — H-AUDIT-ATOMIC-WRITE: an interruption between finishing the
# temp-file write and the atomic rename must leave a pre-existing target
# record BYTE-IDENTICAL, never truncated or partially overwritten. Before
# this fix, `cat > "$OUTPUT_FILE" <<ENDJSON` truncated the target the
# instant the redirect opened -- an interruption at that point (SIGTERM on
# a cancelled CI job, ENOSPC) left a partial/empty record with
# recorded_at_ns but no overall_qc, which is exactly the trigger
# H-PREV-VERDICT-PIPEFAIL describes. This scenario:
#   1. Writes a real record (rc=0, content A).
#   2. Re-invokes write_audit.sh for the SAME date/branch/feature (so it
#      targets the SAME $OUTPUT_FILE) with a different quality-score
#      (content B) AND WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME=1 set, which
#      makes the script exit 1 right after finishing the temp file but
#      before the `mv`.
#   3. Asserts the second call failed (rc=1) AND the target file on disk is
#      still byte-identical to content A -- proving the interrupted write
#      never touched the committed record. A test that only checked "a
#      valid record is produced" on the happy path would not distinguish
#      this fix from the pre-fix truncate-on-open bug; this scenario
#      specifically exercises the failure window the fix closes.
#   4. Asserts no stray temp file is left in dev/audit/ matching the
#      *-<feature>.json glob both dev/audit consumers use (the
#      consecutive_rework_count scan in write_audit.sh itself, and
#      deep_scan/check_06_qc_calibration.sh) -- the EXIT trap must have
#      cleaned it up.
# ---------------------------------------------------------------------------
FEATURE19="atomic-write-interrupted"

out19_1=$(REPO_ROOT="${TMP_REPO}" bash "${WRITE_AUDIT}" \
  --date 2026-07-29 --feature "${FEATURE19}" --branch "harness/atomic" \
  --structural APPROVED --behavioral APPROVED --overall APPROVED \
  --quality-score 4 --notes "content A" 2>&1) && rc19_1=0 || rc19_1=$?
JSON19="${TMP_REPO}/dev/audit/2026-07-29-harness-atomic-${FEATURE19}.json"

if [[ ! -f "${JSON19}" ]]; then
  fail "scenario 19 — setup: first write did not produce ${JSON19} (rc=${rc19_1})"
  echo "${out19_1}" | sed 's/^/      /'
else
  CONTENT_A="$(cat "${JSON19}")"

  out19_2=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME=1 \
    bash "${WRITE_AUDIT}" \
      --date 2026-07-29 --feature "${FEATURE19}" --branch "harness/atomic" \
      --structural APPROVED --behavioral APPROVED --overall APPROVED \
      --quality-score 1 --notes "content B - must never land" 2>&1) && rc19_2=0 || rc19_2=$?

  CONTENT_AFTER="$(cat "${JSON19}" 2>/dev/null || echo "MISSING")"
  stray_tmp_count="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE19}.json.??????" | wc -l | tr -d ' ')"

  # TMP_FILE=<path> is emitted by the abort hook itself (write_audit.sh's
  # WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME branch) right before it exits, so it
  # names the exact temp path that was staged for THIS invocation -- pin two
  # invariants the write_audit.sh:320-335 comment block asserts but the
  # pre-existing scenario 19 assertions did not actually exercise:
  #   (a) same-directory/same-filesystem: the temp file's directory must be
  #       $AUDIT_DIR (${TMP_REPO}/dev/audit), not $TMPDIR or anywhere else --
  #       this is what makes the later `mv` a single rename syscall instead
  #       of degrading to copy+unlink across filesystems.
  #   (b) glob-invisible: the temp basename must NOT end in ".json", so a
  #       leftover (e.g. from a SIGKILL that bypasses the EXIT trap) can
  #       never be picked up by either dev/audit/ *.json glob consumer.
  # A test that only checks "no stray temp file was left behind" (the
  # pre-existing stray_tmp_count check) is satisfied whether the temp was
  # ever created in dev/audit/ at all -- it cannot detect a `mktemp`
  # relocated to $TMPDIR. This TMP_FILE_19 pin can.
  TMP_FILE_19="$(echo "${out19_2}" | sed -n 's/.*TMP_FILE=//p' | tail -1)"
  TMP_FILE_19_DIR="$(dirname "${TMP_FILE_19}")"
  TMP_FILE_19_BASENAME="$(basename "${TMP_FILE_19}")"

  if (( rc19_2 != 0 )) \
     && [[ "${CONTENT_AFTER}" == "${CONTENT_A}" ]] \
     && [[ "${stray_tmp_count}" == "0" ]] \
     && echo "${out19_2}" | grep -q "simulating interruption before rename" \
     && [[ -n "${TMP_FILE_19}" ]] \
     && [[ "${TMP_FILE_19_DIR}" == "${TMP_REPO}/dev/audit" ]] \
     && [[ "${TMP_FILE_19_BASENAME}" != *.json ]]; then
    pass "scenario 19 — interrupted write leaves pre-existing target byte-identical, temp file cleaned up, staged in same dir with non-.json suffix (H-AUDIT-ATOMIC-WRITE)"
  else
    fail "scenario 19 — expected rc2!=0, target unchanged (content A), no stray temp file, temp staged in ${TMP_REPO}/dev/audit with non-.json suffix; got rc2=${rc19_2}, stray_tmp_count=${stray_tmp_count}, TMP_FILE_19=${TMP_FILE_19} (dir=${TMP_FILE_19_DIR}, basename=${TMP_FILE_19_BASENAME})"
    echo "${out19_2}" | sed 's/^/      /'
    echo "      content A: ${CONTENT_A}"
    echo "      content after: ${CONTENT_AFTER}"
  fi
fi

# ---------------------------------------------------------------------------
# Scenario 20 — H-AUDIT-ATOMIC-WRITE happy path: a normal (uninterrupted)
# write still produces exactly one file at $OUTPUT_FILE with the new
# content, and no leftover ".XXXXXX"-suffixed temp file — proving the
# temp-file+rename plumbing doesn't regress the ordinary case.
# ---------------------------------------------------------------------------
FEATURE20="atomic-write-happy-path"

out20=$(REPO_ROOT="${TMP_REPO}" bash "${WRITE_AUDIT}" \
  --date 2026-07-29 --feature "${FEATURE20}" --branch "harness/atomic" \
  --structural APPROVED --behavioral APPROVED --overall APPROVED \
  --quality-score 5 2>&1) && rc20=0 || rc20=$?
JSON20="${TMP_REPO}/dev/audit/2026-07-29-harness-atomic-${FEATURE20}.json"
stray_tmp_count_20="$(find "${TMP_REPO}/dev/audit" -maxdepth 1 -name "*-${FEATURE20}.json.??????" | wc -l | tr -d ' ')"

if (( rc20 == 0 )) && [[ -f "${JSON20}" ]] \
   && grep -q '"quality_score": *5' "${JSON20}" \
   && [[ "${stray_tmp_count_20}" == "0" ]]; then
  pass "scenario 20 — uninterrupted write still produces exactly the target record, no leftover temp file"
else
  fail "scenario 20 — expected rc=0, record at ${JSON20} with score 5, no stray temp file; got rc=${rc20}, stray_tmp_count=${stray_tmp_count_20}"
  echo "${out20}" | sed 's/^/      /'
  [[ -f "${JSON20}" ]] && echo "      json: $(cat "${JSON20}")"
fi

# ---------------------------------------------------------------------------
# Scenario 21 — H-PREV-VERDICT-PIPEFAIL: a TRUNCATED prior record (has
# recorded_at_ns so it sorts correctly by write order, but is missing
# overall_qc entirely -- the exact shape a pre-H-AUDIT-ATOMIC-WRITE
# SIGTERM/ENOSPC mid-heredoc-write would have produced) must NOT abort the
# script on the NEEDS_REWORK escalation path, and must be SKIPPED rather
# than treated as breaking the streak.
#
# Three prior-record ordering, oldest to newest by recorded_at_ns:
#   1. branch "feat/old"       recorded_at_ns=1e18  NEEDS_REWORK (valid)
#   2. branch "feat/truncated" recorded_at_ns=2e18  TRUNCATED (no overall_qc)
#   current call:               recorded_at_ns=3e18  NEEDS_REWORK
#
# Pre-fix: the loop walks newest-to-oldest, hits "feat/truncated" first,
# and the unguarded `grep -o '"overall_qc"...' | head -1 | sed ...`
# pipeline exits 1 (no match) under `set -euo pipefail`, aborting the
# whole script before it ever writes the current record -- rc=1, no file,
# and (because the bad record is never removed) every future review for
# this feature fails the exact same way, permanently.
#
# Post-fix: the truncated record is skipped (neither extends nor breaks
# the streak), so the scan proceeds to "feat/old" (NEEDS_REWORK) and counts
# it. Expected consecutive_rework_count for the current record is 2 (this
# record + feat/old), NOT 1 (which is what treating the truncated record as
# "streak broken" would have produced instead -- the "unsafe direction"
# this item's own text names).
# ---------------------------------------------------------------------------
FEATURE21="truncated-record-skip"
mkdir -p "${TMP_REPO}/dev/audit"

out21_1=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=1000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-30 --feature "${FEATURE21}" --branch "feat/old" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK 2>&1) && rc21_1=0 || rc21_1=$?

# Hand-seed a truncated record directly (write_audit.sh itself can no
# longer produce this shape post-H-AUDIT-ATOMIC-WRITE -- it must still be
# TOLERATED as a prior record possibly written before that fix, by another
# tool, or left behind by an interruption predating this codebase version).
cat > "${TMP_REPO}/dev/audit/2026-07-30-feat-truncated-${FEATURE21}.json" <<EOF
{
  "date": "2026-07-30",
  "feature": "${FEATURE21}",
  "branch": "feat/truncated",
  "recorded_at_ns": 2000000000000000000
EOF

out21_3=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=3000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-30 --feature "${FEATURE21}" --branch "feat/new" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK 2>&1) && rc21_3=0 || rc21_3=$?
JSON21="${TMP_REPO}/dev/audit/2026-07-30-feat-new-${FEATURE21}.json"

if (( rc21_1 == 0 )) && (( rc21_3 == 0 )) && [[ -f "${JSON21}" ]] \
   && grep -q '"consecutive_rework_count": *2' "${JSON21}" \
   && echo "${out21_3}" | grep -q 'consecutive_rework_count=2' \
   && ! echo "${out21_3}" | grep -q 'WARNING'; then
  pass "scenario 21 — truncated prior record (no overall_qc) does not abort the script, is skipped not counted as a streak break, and emits NO warning (silent skip, H-PREV-VERDICT-PIPEFAIL)"
else
  fail "scenario 21 — expected rc=0/0, consecutive_rework_count=2 for feat/new record, and NO 'WARNING' in output (silent skip); got rc=${rc21_1}/${rc21_3}"
  echo "${out21_1}" | sed 's/^/      /'
  echo "${out21_3}" | sed 's/^/      /'
  [[ -f "${JSON21}" ]] && echo "      json: $(cat "${JSON21}")"
fi

# ---------------------------------------------------------------------------
# Scenario 22 — H-PREV-VERDICT-PIPEFAIL, distinct failure class: a prior
# "record" that is genuinely unreadable by grep (simulated with a directory
# sitting at the glob-matched path, which GNU grep refuses with exit 2 --
# "Is a directory" -- as opposed to exit 1 for "no match") must ALSO not
# abort the script, but should be surfaced with a stderr WARNING naming the
# file, distinguishing it from the silent-skip exit-1 case in scenario 21.
# ---------------------------------------------------------------------------
FEATURE22="unreadable-record-warns"
mkdir -p "${TMP_REPO}/dev/audit"

out22_1=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=1000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-30 --feature "${FEATURE22}" --branch "feat/old" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK 2>&1) && rc22_1=0 || rc22_1=$?

# A directory at a path matching the "*-<feature>.json" glob makes grep
# exit 2 ("Is a directory") rather than 1 ("no match").
UNREADABLE_PATH_22="${TMP_REPO}/dev/audit/2026-07-30-feat-unreadable-${FEATURE22}.json"
mkdir -p "${UNREADABLE_PATH_22}"

out22_3=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=3000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-30 --feature "${FEATURE22}" --branch "feat/new" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK 2>&1) && rc22_3=0 || rc22_3=$?
JSON22="${TMP_REPO}/dev/audit/2026-07-30-feat-new-${FEATURE22}.json"

if (( rc22_1 == 0 )) && (( rc22_3 == 0 )) && [[ -f "${JSON22}" ]] \
   && grep -q '"consecutive_rework_count": *2' "${JSON22}" \
   && echo "${out22_3}" | grep -q 'WARNING: could not read prior audit record' \
   && echo "${out22_3}" | grep -qF "${UNREADABLE_PATH_22}"; then
  pass "scenario 22 — unreadable prior record (grep exit 2) does not abort the script, warns loudly naming the offending file, still skipped from the streak (H-PREV-VERDICT-PIPEFAIL)"
else
  fail "scenario 22 — expected rc=0/0, consecutive_rework_count=2, a WARNING naming ${UNREADABLE_PATH_22}; got rc=${rc22_1}/${rc22_3}"
  echo "${out22_1}" | sed 's/^/      /'
  echo "${out22_3}" | sed 's/^/      /'
  [[ -f "${JSON22}" ]] && echo "      json: $(cat "${JSON22}")"
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
