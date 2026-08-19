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

# _glob_count <dir> <name-pattern> [extra-find-predicate]
#
# Counts entries under <dir> (maxdepth 1) matching glob <name-pattern>,
# without ever aborting this suite under `set -euo pipefail`
# (H-AUDIT-TEST-FIND-PIPELINE-UNGUARDED). `find` exits 0 with empty stdout
# when nothing matches -- unlike `ls <dir>/<pattern>`, which exits non-zero
# on a no-match glob and, combined with `pipefail`, would abort the whole
# script mid-run right at the call site. The remaining risk this guards is
# narrower: if <dir> itself is missing (e.g. a hand-written `rm -rf` of the
# temp audit dir mid-suite), `find` reports the error to stderr and returns
# non-zero -- but its stdout is still empty, so `wc -l` still reports "0"
# and the caller gets the correct count.
#
# NOTE on what actually prevents the abort at call sites: every real call
# site is shaped `x="$(_glob_count ...)"`. That outer command substitution
# runs this function's body in a subshell where `errexit` is inactive
# (`shopt inherit_errexit` is off in this suite), so at those sites a
# non-zero `find`/pipeline status inside the body is NOT what aborts the
# caller -- the function-call wrapping itself already absorbs it, `|| true`
# or not. `|| true` below is load-bearing only for a DIRECT, non-command-
# substitution invocation of `_glob_count` (errexit active in the caller's
# frame) -- see scenario 42, the pin for H-AUDIT-GLOB-COUNT-GUARD-UNPINNED,
# for the call shape where removing it actually turns this suite red.
# Optional 3rd arg: an extra `find` predicate appended verbatim (e.g.
# "-type f") for call sites that also filter by entry type.
_glob_count() {
  local dir="$1" pattern="$2" extra="${3:-}"
  local n
  # shellcheck disable=SC2086  # $extra is a predicate word; must word-split
  n="$(find "${dir}" -maxdepth 1 -name "${pattern}" ${extra} 2>/dev/null | wc -l | tr -d ' ')" || true
  echo "${n}"
}

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

# Re-invoke for the FIRST branch again with the SAME reviewed sha (genuine
# idempotency check -- a retried invocation for the exact same commit, e.g.
# a transient `gh` failure retried by the orchestrator): must overwrite its
# own record in place, not create a third file, and JSON7B (the sibling
# branch's record) must survive untouched.
cat > "${TMP_REPO}/dev/reviews/${FEATURE7}.md" <<'EOF'
Reviewed SHA: run1sha

structural_qc: APPROVED
behavioral_qc: NEEDS_REWORK
overall_qc: NEEDS_REWORK

## Quality Score
2 — rerun found an issue
EOF
out3=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE7}" "feat/picks-phase-c" "2026-07-27" 2>&1) && rc3=0 || rc3=$?

audit_count="$(_glob_count "${TMP_REPO}/dev/audit" "2026-07-27-*-${FEATURE7}.json")"

if (( rc3 == 0 )) && [[ -f "${JSON7A}" ]] && [[ -f "${JSON7B}" ]] \
   && [[ "${audit_count}" == "2" ]] \
   && grep -q '"quality_score": *2' "${JSON7A}" \
   && grep -q '"quality_score": *5' "${JSON7B}"; then
  pass "scenario 7b — re-invoking same branch AND same reviewed sha overwrites its own record (idempotent, no duplicate)"
else
  fail "scenario 7b — expected exactly 2 audit files for ${FEATURE7} on 2026-07-27, JSON7A rewritten to q=2, JSON7B untouched at q=5; got rc=${rc3}, audit_count=${audit_count}"
  echo "${out3}" | sed 's/^/      /'
  [[ -f "${JSON7A}" ]] && echo "      json A: $(cat "${JSON7A}")"
  [[ -f "${JSON7B}" ]] && echo "      json B: $(cat "${JSON7B}")"
fi

# ---------------------------------------------------------------------------
# Scenario 7d — H-AUDIT-REWORK-COUNT-BLIND regression: re-invoking the SAME
# branch with a DIFFERENT reviewed sha (a genuine rework at a new commit
# tip, not a retry of the same review) must NOT clobber the record it
# followed. Both must survive: the just-preserved NEEDS_REWORK record from
# scenario 7b's call (JSON7A, q=2, sha run1sha) and a new APPROVED record
# for the rework (sha run1sha-v2). Before the fix, this collided on the
# exact same $OUTPUT_FILE as scenario 7b and the APPROVED call would have
# silently destroyed the NEEDS_REWORK record -- the actual production bug
# (demonstrated live: a NEEDS_REWORK -> fix -> APPROVED cycle on one PR
# branch, within one orchestrator run, loses the NEEDS_REWORK record and
# undercounts consecutive_rework_count for every future rework streak on
# that feature).
# ---------------------------------------------------------------------------
cat > "${TMP_REPO}/dev/reviews/${FEATURE7}.md" <<'EOF'
Reviewed SHA: run1sha-v2

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
5 — fixed after rework
EOF
out4=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE7}" "feat/picks-phase-c" "2026-07-27" 2>&1) && rc4=0 || rc4=$?

audit_count_7d="$(_glob_count "${TMP_REPO}/dev/audit" "2026-07-27-*-${FEATURE7}.json")"

if (( rc4 == 0 )) && [[ -f "${JSON7A}" ]] && [[ -f "${JSON7B}" ]] \
   && [[ "${audit_count_7d}" == "3" ]] \
   && grep -q '"quality_score": *5' "${JSON7A}" \
   && grep -q '"sha": *"run1sha-v2"' "${JSON7A}" \
   && grep -q '"quality_score": *5' "${JSON7B}"; then
  # The preserved (superseded) NEEDS_REWORK record must exist somewhere
  # under the ${FEATURE7} glob, distinct from JSON7A/JSON7B, and still show
  # the rework's own verdict/sha/score -- not silently vanished.
  preserved_found=false
  for f in "${TMP_REPO}/dev/audit/2026-07-27-"*"-${FEATURE7}.json"; do
    [[ "${f}" == "${JSON7A}" ]] && continue
    [[ "${f}" == "${JSON7B}" ]] && continue
    if grep -q '"sha": *"run1sha"' "${f}" && grep -q '"quality_score": *2' "${f}" \
       && grep -q '"overall_qc": *"NEEDS_REWORK"' "${f}"; then
      preserved_found=true
    fi
  done
  if $preserved_found; then
    pass "scenario 7d — same branch, DIFFERENT reviewed sha (rework) preserves the prior NEEDS_REWORK record instead of clobbering it (H-AUDIT-REWORK-COUNT-BLIND fix)"
  else
    fail "scenario 7d — expected the pre-rework NEEDS_REWORK record (sha run1sha, q=2) to survive under a distinct filename; not found"
    ls -la "${TMP_REPO}/dev/audit/" | sed 's/^/      /'
  fi
else
  fail "scenario 7d — expected 3 audit files for ${FEATURE7} on 2026-07-27 (JSON7A now q=5/run1sha-v2, JSON7B untouched q=5, plus a preserved record); got rc=${rc4}, audit_count=${audit_count_7d}"
  echo "${out4}" | sed 's/^/      /'
  [[ -f "${JSON7A}" ]] && echo "      json A: $(cat "${JSON7A}")"
  [[ -f "${JSON7B}" ]] && echo "      json B: $(cat "${JSON7B}")"
fi

# ---------------------------------------------------------------------------
# Scenario 7e — the streak survives the preservation: with the collision now
# preserving rather than clobbering, three CONSECUTIVE NEEDS_REWORK calls on
# one branch (three distinct reviewed shas) must produce
# consecutive_rework_count=3 on the third -- the exact escalation trigger
# (>=3) that H-AUDIT-REWORK-COUNT-BLIND documents as unreachable pre-fix
# (a same-day streak on one branch could never exceed 1, since every call
# but the first destroyed its predecessor before the scan ever saw it).
# ---------------------------------------------------------------------------
FEATURE7E="streak-survives-preservation"
WRITE_AUDIT="${TMP_REPO}/trading/devtools/checks/write_audit.sh"

out7e_1=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=5000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-28 --feature "${FEATURE7E}" --branch "feat/streaky" --sha "shaAAA" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK 2>&1) && rc7e_1=0 || rc7e_1=$?

out7e_2=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=6000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-28 --feature "${FEATURE7E}" --branch "feat/streaky" --sha "shaBBB" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK 2>&1) && rc7e_2=0 || rc7e_2=$?

out7e_3=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=7000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-28 --feature "${FEATURE7E}" --branch "feat/streaky" --sha "shaCCC" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK 2>&1) && rc7e_3=0 || rc7e_3=$?

JSON7E="${TMP_REPO}/dev/audit/2026-07-28-feat-streaky-${FEATURE7E}.json"

if (( rc7e_1 == 0 )) && (( rc7e_2 == 0 )) && (( rc7e_3 == 0 )) \
   && [[ -f "${JSON7E}" ]] \
   && grep -q '"consecutive_rework_count": *3' "${JSON7E}" \
   && echo "${out7e_3}" | grep -q 'consecutive_rework_count=3'; then
  pass "scenario 7e — 3 consecutive same-day NEEDS_REWORK calls on one branch reach consecutive_rework_count=3 (was capped at 1 pre-fix, H-AUDIT-REWORK-COUNT-BLIND)"
else
  fail "scenario 7e — expected consecutive_rework_count=3 on the third call; got rc=${rc7e_1}/${rc7e_2}/${rc7e_3}"
  echo "${out7e_1}" | sed 's/^/      /'
  echo "${out7e_2}" | sed 's/^/      /'
  echo "${out7e_3}" | sed 's/^/      /'
  [[ -f "${JSON7E}" ]] && echo "      json: $(cat "${JSON7E}")"
fi

# ---------------------------------------------------------------------------
# Scenario 7f — write_audit.sh direct callers that never pass --sha are
# completely unaffected (100% backward compatible): two direct calls for
# the identical date+branch+feature, neither with --sha, still overwrite
# exactly as before this fix (both sides' sha are unknown/empty, so the
# preserve-on-collision guard never fires -- see the "identity key"
# rationale in write_audit.sh).
# ---------------------------------------------------------------------------
FEATURE7F="no-sha-caller-unaffected"

out7f_1=$(REPO_ROOT="${TMP_REPO}" \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-29 --feature "${FEATURE7F}" --branch "feat/no-sha" \
    --structural APPROVED --behavioral APPROVED --overall APPROVED --quality-score 3 2>&1) && rc7f_1=0 || rc7f_1=$?

out7f_2=$(REPO_ROOT="${TMP_REPO}" \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-29 --feature "${FEATURE7F}" --branch "feat/no-sha" \
    --structural APPROVED --behavioral APPROVED --overall APPROVED --quality-score 4 2>&1) && rc7f_2=0 || rc7f_2=$?

JSON7F="${TMP_REPO}/dev/audit/2026-07-29-feat-no-sha-${FEATURE7F}.json"
audit_count_7f="$(_glob_count "${TMP_REPO}/dev/audit" "2026-07-29-*-${FEATURE7F}.json")"

if (( rc7f_1 == 0 )) && (( rc7f_2 == 0 )) && [[ -f "${JSON7F}" ]] \
   && [[ "${audit_count_7f}" == "1" ]] \
   && grep -q '"quality_score": *4' "${JSON7F}"; then
  pass "scenario 7f — direct callers omitting --sha still overwrite in place, no preserved-aside file (backward compatible)"
else
  fail "scenario 7f — expected exactly 1 file with q=4 (second call wins, no --sha means no preserve); got rc=${rc7f_1}/${rc7f_2}, audit_count=${audit_count_7f}"
  echo "${out7f_1}" | sed 's/^/      /'
  echo "${out7f_2}" | sed 's/^/      /'
  [[ -f "${JSON7F}" ]] && echo "      json: $(cat "${JSON7F}")"
fi

# ---------------------------------------------------------------------------
# Scenario 7c — empty --branch fallback: `record_qc_audit.sh <feature> "" <date>`
# satisfies the 3-positional-arg arity check (an unset $BRANCH in the
# orchestrator's documented fallback invocation silently takes this path).
# write_audit.sh's `[ -n "$BRANCH" ]` guard treats "" the same as "omitted",
# falling back to the pre-fix dev/audit/<date>-<feature>.json shape.
#
# The BRANCH-disambiguation gap (H-AUDIT-COLLISION) is still NOT fixed here
# -- two DIFFERENT branches that both happen to report an empty branch
# string are still indistinguishable by filename, out of scope for that
# fix. But as of H-AUDIT-REWORK-COUNT-BLIND, the sha-based preserve-on-
# collision guard is orthogonal to branch and fires here too: this fixture
# uses two DIFFERENT reviewed shas (as it always has), so the second call no
# longer clobbers the first -- it preserves it under a distinct filename.
# Updated from "KNOWN gap, pinned not fixed" (the pre-fix expectation of
# exactly 1 clobbered file) to pin the improved (2-file, nothing lost)
# outcome. The narrower remaining gap -- the preserved filename carries no
# branch identity -- is content the "notes"/"branch" fields inside each
# record still capture, so no data is actually lost, only the filename's
# ability to name which review is which at a glance.
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

audit_count_7c="$(_glob_count "${TMP_REPO}/dev/audit" "2026-07-27-*${FEATURE7C}.json")"

if (( rc7c_1 == 0 )) && (( rc7c_2 == 0 )) && [[ -f "${JSON7C}" ]] \
   && [[ "${audit_count_7c}" == "2" ]] \
   && grep -q '"quality_score": *5' "${JSON7C}"; then
  # Confirm the FIRST record (q=4) survived under a distinct (preserved)
  # filename rather than vanishing.
  preserved_7c_found=false
  for f in "${TMP_REPO}/dev/audit/2026-07-27-"*"${FEATURE7C}.json"; do
    [[ "${f}" == "${JSON7C}" ]] && continue
    grep -q '"quality_score": *4' "${f}" && preserved_7c_found=true
  done
  if $preserved_7c_found; then
    pass "scenario 7c — empty --branch fallback: sha-based identity now preserves rather than clobbers a same-day collision (gap narrowed by H-AUDIT-REWORK-COUNT-BLIND)"
  else
    fail "scenario 7c — expected the first record (q=4) to survive under a distinct filename; not found"
    ls -la "${TMP_REPO}/dev/audit/" | sed 's/^/      /'
  fi
else
  fail "scenario 7c — expected exactly 2 files (q=4 preserved, q=5 canonical); got rc=${rc7c_1}/${rc7c_2}, audit_count=${audit_count_7c}"
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
audit_count_before_10="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE10}.json")"

out10=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=oops \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-27 --feature "${FEATURE10}" --branch "harness/x" \
    --structural APPROVED --behavioral APPROVED --overall APPROVED 2>&1) && rc10=0 || rc10=$?
audit_count_after_10="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE10}.json")"

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

audit_count_before_12="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE12}.json")"

out12=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE12}" "feat/dummy" "2026-05-25" 2>&1) && rc12=0 || rc12=$?

audit_count_after_12="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE12}.json")"

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
audit_count_before_13="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE13}.json")"

out13=$(REPO_ROOT="${TMP_REPO}" bash "${WRITE_AUDIT}" \
  --date 2026-07-27 --feature "${FEATURE13}" --branch "harness/y" \
  --structural APPROVED --behavioral APPROVED --overall APPROVED \
  --quality-score 0 2>&1) && rc13=0 || rc13=$?

audit_count_after_13="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE13}.json")"

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

audit_count_before_14="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE14}.json")"

out14=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="/nonexistent/gh-binary-that-does-not-exist" \
  bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
  "${FEATURE14}" "feat/dummy" "2026-05-25" --pr-number 2129 2>&1) && rc14=0 || rc14=$?

audit_count_after_14="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE14}.json")"

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

audit_count_before_15="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE15}.json")"

out15=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE15}" "feat/dummy" "2026-05-25" 2>&1) && rc15=0 || rc15=$?

audit_count_after_15="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE15}.json")"

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

audit_count_before_16="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE16}.json")"

out16=$(REPO_ROOT="${TMP_REPO}" bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
        "${FEATURE16}" "feat/dummy" "2026-05-25" 2>&1) && rc16=0 || rc16=$?

audit_count_after_16="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE16}.json")"

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
audit_count_before_17="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE17}.json")"

out17=$(REPO_ROOT="${TMP_REPO}" bash "${WRITE_AUDIT}" \
  --date 2026-07-27 --feature "${FEATURE17}" --branch "harness/y" \
  --structural APPROVED --behavioral APPROVED --overall APPROVED \
  --quality-score 6 2>&1) && rc17=0 || rc17=$?

audit_count_after_17="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE17}.json")"

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
audit_count_before_18="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE18}.json")"

out18=$(REPO_ROOT="${TMP_REPO}" bash "${WRITE_AUDIT}" \
  --date 2026-07-27 --feature "${FEATURE18}" --branch "harness/y" \
  --structural APPROVED --behavioral APPROVED --overall APPROVED \
  --quality-score 3.5 2>&1) && rc18=0 || rc18=$?

audit_count_after_18="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE18}.json")"

if (( rc18 == 1 )) && [[ "${audit_count_before_18}" == "0" ]] && [[ "${audit_count_after_18}" == "0" ]] \
   && echo "${out18}" | grep -q "must be an integer 1..5" \
   && echo "${out18}" | grep -q "got: '3.5'"; then
  pass "scenario 18 — write_audit.sh rejects --quality-score 3.5 directly, no record written (H-QC-SCALE non-integer)"
else
  fail "scenario 18 — expected rc=1, no file written, message naming '3.5'; got rc=${rc18}, before=${audit_count_before_18}, after=${audit_count_after_18}"
  echo "${out18}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 18b — H-AUDIT-HARNESS-GAP-DROPPED-ON-APPROVED regression: a
# --harness-gap value passed alongside --overall APPROVED must survive into
# the JSON record, not be silently discarded with a WARNING. A harness gap
# is a statement about the harness ("here is a check the automation should
# have but doesn't"), not the verdict -- a real gap can be filed and the PR
# still end APPROVED after rework (demonstrated live on #2251), and the
# pre-fix behavior threw that finding away precisely in that case.
# ---------------------------------------------------------------------------
FEATURE18B="harness-gap-on-approved"

out18b=$(REPO_ROOT="${TMP_REPO}" bash "${WRITE_AUDIT}" \
  --date 2026-07-27 --feature "${FEATURE18B}" --branch "harness/z" \
  --structural APPROVED --behavioral APPROVED --overall APPROVED \
  --harness-gap "LINTER_CANDIDATE: golden scenario would have caught this" 2>&1) && rc18b=0 || rc18b=$?

JSON18B="${TMP_REPO}/dev/audit/2026-07-27-harness-z-${FEATURE18B}.json"

if (( rc18b == 0 )) && [[ -f "${JSON18B}" ]] \
   && grep -q '"harness_gap": *"LINTER_CANDIDATE: golden scenario would have caught this"' "${JSON18B}" \
   && ! echo "${out18b}" | grep -q "harness-gap is only meaningful"; then
  pass "scenario 18b — --harness-gap survives an APPROVED verdict, no longer discarded (H-AUDIT-HARNESS-GAP-DROPPED-ON-APPROVED fix)"
else
  fail "scenario 18b — expected the harness_gap text to survive in the record with no WARNING; got rc=${rc18b}"
  echo "${out18b}" | sed 's/^/      /'
  [[ -f "${JSON18B}" ]] && echo "      json: $(cat "${JSON18B}")"
fi

# ---------------------------------------------------------------------------
# Scenario 18c — control: --harness-gap on NEEDS_REWORK still works exactly
# as before (this fix only changes the APPROVED path).
# ---------------------------------------------------------------------------
FEATURE18C="harness-gap-on-needs-rework"

out18c=$(REPO_ROOT="${TMP_REPO}" bash "${WRITE_AUDIT}" \
  --date 2026-07-27 --feature "${FEATURE18C}" --branch "harness/z2" \
  --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK \
  --harness-gap "MISSING_TEST_PATTERN: no golden for this stop transition" 2>&1) && rc18c=0 || rc18c=$?

JSON18C="${TMP_REPO}/dev/audit/2026-07-27-harness-z2-${FEATURE18C}.json"

if (( rc18c == 0 )) && [[ -f "${JSON18C}" ]] \
   && grep -q '"harness_gap": *"MISSING_TEST_PATTERN: no golden for this stop transition"' "${JSON18C}"; then
  pass "scenario 18c — --harness-gap on NEEDS_REWORK unaffected by the fix (control)"
else
  fail "scenario 18c — expected the harness_gap text to survive on a NEEDS_REWORK record; got rc=${rc18c}"
  echo "${out18c}" | sed 's/^/      /'
  [[ -f "${JSON18C}" ]] && echo "      json: $(cat "${JSON18C}")"
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
  stray_tmp_count="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE19}.json.??????")"

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
stray_tmp_count_20="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE20}.json.??????")"

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
# Scenario 20b — H-AUDIT-REWORK-COUNT-BLIND, the `cp -p` preservation copy's
# OWN failure-safety claim (added on QC rework, PR #2266): the comment
# directly above the `cp -p "$OUTPUT_FILE" "$PRESERVED_FILE"` call in
# write_audit.sh says that if this copy fails under `set -euo pipefail`,
# the script aborts before $OUTPUT_FILE's original content is touched. Every
# sibling guard in this file (the mv-interruption case in scenario 19 above,
# chmod-ordering in scenario 24, etc.) has a scenario that actually forces
# the guarded-against failure; this one had none until now.
#
# This scenario forces `cp -p` to fail FOR REAL (not a synthetic `exit 1`
# like the mv-abort hooks) via WRITE_AUDIT_TEST_FORCE_PRESERVE_COPY_FAIL=1,
# which redirects the preserved-copy destination under a nonexistent
# directory -- `cp` then fails with its own ENOENT, which (unlike a
# permission-based injection such as chmod 555 on $AUDIT_DIR) still fails
# even when the test suite runs as root inside the container, where
# permission checks are bypassed.
#   1. Writes a real record (rc=0, content A, sha shaOLD).
#   2. Re-invokes write_audit.sh for the SAME branch/feature/date with a
#      DIFFERENT --sha (shaNEW, triggering the preserve-on-collision path)
#      AND the forced-failure hook set.
#   3. Asserts the second call failed (rc!=0), the target file on disk is
#      still byte-identical to content A, and no second record (preserved
#      or otherwise) was created for this feature -- proving the failed
#      copy aborted the script before the later write ever ran.
# ---------------------------------------------------------------------------
FEATURE20B="preserve-copy-forced-failure"

out20b_1=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_RECORDED_AT_NS=8000000000000000000 \
  bash "${WRITE_AUDIT}" \
    --date 2026-07-29 --feature "${FEATURE20B}" --branch "harness/preserve-fail" --sha "shaOLD" \
    --structural APPROVED --behavioral NEEDS_REWORK --overall NEEDS_REWORK \
    --quality-score 2 --notes "content A" 2>&1) && rc20b_1=0 || rc20b_1=$?
JSON20B="${TMP_REPO}/dev/audit/2026-07-29-harness-preserve-fail-${FEATURE20B}.json"

if [[ ! -f "${JSON20B}" ]]; then
  fail "scenario 20b — setup: first write did not produce ${JSON20B} (rc=${rc20b_1})"
  echo "${out20b_1}" | sed 's/^/      /'
else
  CONTENT_A_20B="$(cat "${JSON20B}")"

  out20b_2=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_TEST_FORCE_PRESERVE_COPY_FAIL=1 \
    WRITE_AUDIT_RECORDED_AT_NS=9000000000000000000 \
    bash "${WRITE_AUDIT}" \
      --date 2026-07-29 --feature "${FEATURE20B}" --branch "harness/preserve-fail" --sha "shaNEW" \
      --structural APPROVED --behavioral APPROVED --overall APPROVED \
      --quality-score 5 --notes "content B - must never land" 2>&1) && rc20b_2=0 || rc20b_2=$?

  CONTENT_AFTER_20B="$(cat "${JSON20B}" 2>/dev/null || echo "MISSING")"
  audit_count_20b="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE20B}.json")"

  if (( rc20b_2 != 0 )) \
     && [[ "${CONTENT_AFTER_20B}" == "${CONTENT_A_20B}" ]] \
     && [[ "${audit_count_20b}" == "1" ]] \
     && echo "${out20b_2}" | grep -q "nonexistent-dir-for-write-audit-test"; then
    pass "scenario 20b — forced cp -p preservation-copy failure leaves the pre-existing target byte-identical and creates no second record (H-AUDIT-REWORK-COUNT-BLIND, cp -p failure-safety)"
  else
    fail "scenario 20b — expected rc2!=0, target unchanged (content A), exactly 1 record for ${FEATURE20B}, cp error naming the injected path; got rc2=${rc20b_2}, audit_count=${audit_count_20b}"
    echo "${out20b_2}" | sed 's/^/      /'
    echo "      content A: ${CONTENT_A_20B}"
    echo "      content after: ${CONTENT_AFTER_20B}"
  fi
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
# Scenario 23 — H-AUDIT-MODE-0600: a record written via the atomic
# temp-file+rename path (H-AUDIT-ATOMIC-WRITE) must end up mode 0644, matching
# every record written before that fix. Without the `chmod 644 "$TMP_FILE"`
# guard, `mktemp` creates the temp file 0600 (by design, ignoring umask) and
# `mv` preserves that mode across the rename, so $OUTPUT_FILE would silently
# regress to 0600 -- unreadable by any user other than the one that wrote it.
#
# Portable octal-mode read: GNU `stat -c '%a'` vs BSD/macOS `stat -f '%Lp'`.
# ---------------------------------------------------------------------------
_file_mode_octal() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

FEATURE23="audit-mode-0644"

# Force a restrictive umask for this call so a passing result can't be a
# coincidence of the ambient umask already being permissive enough to
# produce 644 by default -- the assertion must depend on the chmod, not on
# the umask the test happens to run under.
out23=$(REPO_ROOT="${TMP_REPO}" bash -c 'umask 077 && exec "$0" "$@"' "${WRITE_AUDIT}" \
  --date 2026-08-04 --feature "${FEATURE23}" --branch "harness/audit-mode" \
  --structural APPROVED --behavioral APPROVED --overall APPROVED 2>&1) && rc23=0 || rc23=$?
JSON23="${TMP_REPO}/dev/audit/2026-08-04-harness-audit-mode-${FEATURE23}.json"
mode23="$(_file_mode_octal "${JSON23}" 2>/dev/null || echo 'UNKNOWN')"

if (( rc23 == 0 )) && [[ -f "${JSON23}" ]] && [[ "${mode23}" == "644" ]]; then
  pass "scenario 23 — audit record written mode 0644 (not 0600) even under a restrictive ambient umask (H-AUDIT-MODE-0600)"
else
  fail "scenario 23 — expected rc=0, record at ${JSON23} mode 644; got rc=${rc23}, mode=${mode23}"
  echo "${out23}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 24 — H-AUDIT-MODE-ORDER-UNPINNED: the chmod-before-mv placement
# (H-AUDIT-MODE-0600) is supposed to guarantee $OUTPUT_FILE already has its
# final mode (644) from the instant it first becomes visible via the rename
# -- i.e. no window in which a concurrent reader could open() it at 0600.
# That placement claim was unpinned: moving the chmod to after the `mv`
# still left the whole suite green (mutation M2, qc-behavioral PR #2199
# follow-up), because none of scenarios 1-23 observe file state at the
# instant of first visibility -- scenario 23 only checks the mode AFTER the
# script finishes normally, which the end state reaches either way.
#
# Part A (behavioral): uses the WRITE_AUDIT_TEST_ABORT_AFTER_RENAME hook
# (symmetric to WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME / scenario 19) to
# freeze execution immediately after the rename and assert $OUTPUT_FILE is
# ALREADY mode 644 at that instant. Forces a restrictive umask for the same
# reason as scenario 23: a pass must depend on the chmod, not on a
# permissive ambient umask.
#
# Part A alone is NOT sufficient (rework 2026-08-05, qc-behavioral B1): the
# hook is the literal next statement after `mv`, so anything a refactor
# inserts BETWEEN `mv` and the hook -- e.g. `chmod 644 "$OUTPUT_FILE"`
# placed directly below the `mv` line (mutation M2b) -- already ran by the
# time the hook checks, and Part A alone cannot see it: the information is
# gone by the time any post-rename hook runs, regardless of where after the
# rename that hook sits. No behavioral hook placed after the rename can ever
# close this gap.
#
# Part B (source-order, static): reads ${WRITE_AUDIT} directly and asserts
# the property no runtime hook can observe -- that the ONLY chmod call in
# the script targets $TMP_FILE, and it appears strictly before the `mv`
# line. Two checks:
#   B1. `chmod 644 "$TMP_FILE"` appears at a line number strictly less than
#       `mv -f "$TMP_FILE" "$OUTPUT_FILE"`'s line number.
#   B2. write_audit.sh contains NO `chmod ... "$OUTPUT_FILE"` anywhere, at
#       any line, in any position relative to the rename.
# B1 alone already catches M1 (chmod deleted -- grep finds no match, the
# `[[ -n "${CHMOD_TMP_LINE_24}" ]]` guard below rejects, and the order check
# therefore fails CLOSED: source_order_ok stays 0 and the scenario goes red.
# The `|| true` on the extraction keeps the missing match from aborting the
# run, it does NOT let the check pass) and, combined with B2, B1
# unconditionally catches BOTH M2 (chmod
# relocated below the hook block, retargeted to $OUTPUT_FILE) and M2b
# (chmod relocated to directly after `mv`, retargeted to $OUTPUT_FILE) --
# B2 is a source-level invariant independent of exactly where after the
# rename the mutated chmod is placed, closing the gap Part A structurally
# cannot.
# ---------------------------------------------------------------------------
FEATURE24="audit-mode-order-pinned"

out24=$(REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_TEST_ABORT_AFTER_RENAME=1 \
  bash -c 'umask 077 && exec "$0" "$@"' "${WRITE_AUDIT}" \
    --date 2026-08-05 --feature "${FEATURE24}" --branch "harness/audit-mode-order" \
    --structural APPROVED --behavioral APPROVED --overall APPROVED 2>&1) && rc24=0 || rc24=$?
JSON24="${TMP_REPO}/dev/audit/2026-08-05-harness-audit-mode-order-${FEATURE24}.json"
mode24="$(_file_mode_octal "${JSON24}" 2>/dev/null || echo 'UNKNOWN')"

# Part B: static source-order check against the actual script under test
# (the copy at $WRITE_AUDIT, identical to trading/devtools/checks/write_audit.sh).
# Whole-line comments are blanked out first (line numbers preserved via sed,
# not removed) so a docstring merely DESCRIBING the pattern (e.g. this very
# file's own comment explaining what a bad chmod placement would look like)
# can never be mistaken for the executable statement itself.
# `|| true` here (H-AUDIT-TEST-SUT-READ-UNGUARDED) is defence-in-depth: the
# suite copies write_audit.sh into $TMP_REPO during setup and fails fast if
# that copy is absent, so $WRITE_AUDIT is expected to always be readable by
# this point -- but if it were ever missing or unreadable, `sed` would exit
# non-zero and, under `set -euo pipefail`, abort the whole run right here
# instead of reporting scenario 24 as a clean FAIL. The `[[ -n ... ]]` guard
# on CODE_ONLY_24 below (mirroring the existing CHMOD_TMP_LINE_24 guard)
# makes that failure mode explicit at the read site itself, rather than
# relying solely on the downstream empty-match cascade through
# CHMOD_TMP_LINE_24/MV_LINE_24 to fail closed.
CODE_ONLY_24="$(sed -E 's/^[[:space:]]*#.*$//' "${WRITE_AUDIT}" 2>/dev/null)" || true
# `|| true` on each is load-bearing under `set -euo pipefail` (mirrors the
# established pattern in write_audit.sh's own recorded_at_ns/overall_qc
# extractions): when a mutation genuinely removes/relocates the pattern
# (e.g. mutation M1 below, which deletes the chmod line entirely), `grep`
# legitimately finds no match and exits 1 -- under pipefail that would
# otherwise propagate through `head`/`cut` and abort this whole test
# script before it can report a clean FAIL for scenario 24. Without this
# guard, M1 was observed to kill the test run silently, short-circuiting
# scenarios 24+ entirely rather than reporting a failure -- the empty
# CHMOD_TMP_LINE_24 that results after `|| true` is exactly what the
# `[[ -n ... ]]` guard below is designed to catch instead.
CHMOD_TMP_LINE_24="$(printf '%s\n' "${CODE_ONLY_24}" | grep -n 'chmod 644 "\$TMP_FILE"' | head -1 | cut -d: -f1 || true)"
MV_LINE_24="$(printf '%s\n' "${CODE_ONLY_24}" | grep -n 'mv -f "\$TMP_FILE" "\$OUTPUT_FILE"' | head -1 | cut -d: -f1 || true)"
OUTPUT_CHMOD_COUNT_24="$(printf '%s\n' "${CODE_ONLY_24}" | grep -c 'chmod [0-9]* "\$OUTPUT_FILE"' || true)"
[ -z "${OUTPUT_CHMOD_COUNT_24}" ] && OUTPUT_CHMOD_COUNT_24=0

source_order_ok=0
if [[ -n "${CODE_ONLY_24}" ]] \
   && [[ -n "${CHMOD_TMP_LINE_24}" ]] && [[ -n "${MV_LINE_24}" ]] \
   && (( CHMOD_TMP_LINE_24 < MV_LINE_24 )) \
   && (( OUTPUT_CHMOD_COUNT_24 == 0 )); then
  source_order_ok=1
fi

if (( rc24 != 0 )) \
   && [[ -f "${JSON24}" ]] \
   && [[ "${mode24}" == "644" ]] \
   && echo "${out24}" | grep -q "simulating interruption right after rename" \
   && (( source_order_ok == 1 )); then
  pass "scenario 24 — \$OUTPUT_FILE already mode 0644 at the instant of first visibility right after the rename, AND source-order check confirms chmod 644 \"\$TMP_FILE\" precedes mv with no chmod ever targeting \$OUTPUT_FILE (H-AUDIT-MODE-ORDER-UNPINNED)"
else
  fail "scenario 24 — expected rc!=0, record at ${JSON24} already mode 644 right after rename, 'simulating interruption right after rename' in output, chmod-TMP_FILE line < mv line with zero chmod-OUTPUT_FILE occurrences; got rc=${rc24}, mode=${mode24}, chmod_tmp_line=${CHMOD_TMP_LINE_24}, mv_line=${MV_LINE_24}, output_chmod_count=${OUTPUT_CHMOD_COUNT_24}"
  echo "${out24}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenarios 25 & 26 — H-AUDIT-HOOK-GATE-TRUTHY: both write_audit.sh
# test-only abort hooks must require the literal value `1` to fire. They
# previously gated on `[ -n "${VAR:-}" ]`, so the two most natural ways to
# spell "off" -- `VAR=0` and `VAR=false` -- are non-empty and therefore
# FIRED the hook, the exact opposite of the caller's intent (verified live
# in both directions, qc-behavioral PR #2211 finding F1). Nothing in
# scenarios 1-24 pinned this: they only ever set the hooks to `1` or leave
# them unset, and BOTH the `-n` form and the `= "1"` form agree on those
# two inputs.
#
# Each scenario asserts BOTH directions, because a one-sided test here is
# actively dangerous. Asserting only "VAR=0 does not fire" would be fully
# satisfied by a hook that can never fire at all (e.g. gated on a
# misspelled variable name) -- which would silently disable the atomicity
# and mode-order pins scenarios 19 and 24 are built on, a strictly worse
# outcome than the bug being fixed. So:
#   (a) DISABLE direction (the regression direction): EVERY value in
#       ${HOOK_DISABLE_VALUES[@]} must leave the hook inert -- script runs
#       to completion, rc=0, "OK:" line emitted, record on disk. Under the
#       old `-n` gate this goes red: the hook fires and the script exits 1.
#   (b) FIRE direction (the anti-over-correction guard): `VAR=1` must still
#       abort exactly as before -- rc!=0 with the hook's own "simulating
#       interruption ..." message.
#
# (a) enumerates a SET, not the two values named in the finding, because
# the contract those hooks now document is "only the literal string `1`
# enables; every other value disables" -- a claim over all values, which a
# two-value pin cannot support (qc-behavioral PR #2221 finding F1). Two
# widening mutations were live-verified to pass a `{0,false}`-only pin
# 30/30 green:
#   MW1 -- gates widened to accept `1|true|yes`. Caught here by `true`/`yes`.
#   MW5 -- gates changed to "fire on anything non-empty except 0/false",
#          which reinstates the ORIGINAL bug under a different spelling
#          (`VAR=no` fires, publishing the record and returning rc=1).
#          Caught here by `no`/`yes`/`true`.
# The list is deliberately EXACTLY the documented spellings and no more.
# Two extra values (`TRUE`, `01`) were trialled to pin the word "literal"
# against a case-folding gate and an arithmetic `(( VAR == 1 ))` gate, then
# dropped: measuring both mutations showed neither value is the sole
# detector of either. Case-insensitive widening is already caught by
# `true`/`yes`, and the arithmetic gate by `false`/`no`/`true`/`yes` (each
# is an unset name in arithmetic context, which trips `set -u`). A test
# value that detects nothing the list already detects is cost without
# coverage.
#
# On empty-vs-unset: `""` here pins the EMPTY state only. Env-assigning
# `VAR=""` sets the variable to the empty string; it does not unset it.
# The UNSET state is pinned by every other scenario in this file -- none of
# scenarios 1-24 sets either hook, and all of them require normal
# completion (scenario 20 most directly). Between the two, the docstring's
# "empty, unset" pair is fully covered. `""` is kept in the list anyway
# because it is a documented value and because it is the element a careless
# refactor drops (see the iteration-count guard below).
#
# The scenarios differ in what "inert" is observable as, because the two
# hooks sit on opposite sides of the publish:
#   25 (BEFORE_RENAME) — inert means the record gets written at all; a
#      spurious fire aborts before the `mv`, so nothing is published.
#   26 (AFTER_RENAME)  — inert means rc=0; a spurious fire aborts AFTER the
#      `mv`, so the record IS on disk either way and only the exit code and
#      the missing "OK:" line distinguish them. This is the higher-blast-
#      radius hook: a caller under `set -e` treats the audit as failed while
#      the record actually exists.
# ---------------------------------------------------------------------------
# Shared by 25a and 26a so the two hooks are pinned against the IDENTICAL
# value set -- the whole point of the fix is that they stay symmetric, and
# two hand-maintained copies of this list would be free to drift apart.
# Must be a real array, quoted "${HOOK_DISABLE_VALUES[@]}": an unquoted
# expansion (or a plain space-separated string) word-splits and silently
# DROPS the empty element, which is exactly how the empty case would stop
# being tested without anyone noticing. The iteration counters below exist
# to make that specific refactor go red rather than quietly shrink the pin.
HOOK_DISABLE_VALUES=(0 false no yes true "")

# Independent of HOOK_DISABLE_VALUES by design. The coverage checks below used
# to compare the number of values iterated against `${#HOOK_DISABLE_VALUES[@]}`
# -- i.e. the array against ITSELF. That comparison cannot detect the array
# being silently shrunk: `HOOK_DISABLE_VALUES=(0)` still satisfies
# `seen == ${#HOOK_DISABLE_VALUES[@]}` (1 == 1) and ships green while covering
# five fewer of the documented "off" spellings (H-AUDIT-TEST-DISABLE-COUNT-
# TAUTOLOGICAL). This constant is the second, independent source of truth the
# array length is checked against. Update it only when deliberately changing
# the documented "off" spelling contract -- never as a side effect of editing
# the array above.
#
# Matches BOTH hooks' documented "off" spelling set (H-AUDIT-HOOK-DISABLE-
# COUNT-DOCSTRING-DRIFT): write_audit.sh's BEFORE_RENAME and AFTER_RENAME
# ACCEPTED SPELLING blocks are kept textually identical -- `0`, `false`,
# `no`, `yes`, `true`, empty, unset all disable -- because both hooks gate
# on the exact same `= "1"` comparison. This is not a superset applied to a
# narrower hook; it is one spelling contract shared by both gates.
HOOK_DISABLE_EXPECTED_COUNT=6

# Renders HOOK_DISABLE_VALUES for the pass/fail messages below. Deriving the
# printed spelling list from the array (rather than a hardcoded literal)
# means a shrunk or padded array can never print a message that contradicts
# what was actually exercised -- the message and the count share one source.
_disable_values_repr() {
  local repr="" v
  for v in "${HOOK_DISABLE_VALUES[@]}"; do
    repr="${repr:+${repr} }'${v}'"
  done
  echo "${repr}"
}

FEATURE25="hook-gate-before-rename"
JSON25="${TMP_REPO}/dev/audit/2026-08-06-harness-hook-gate-${FEATURE25}.json"

_run_write_audit_25() {  # $1 = value for the BEFORE_RENAME hook, $2 = notes
  REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME="$1" \
    bash "${WRITE_AUDIT}" \
      --date 2026-08-06 --feature "${FEATURE25}" --branch "harness/hook-gate" \
      --structural APPROVED --behavioral APPROVED --overall APPROVED \
      --notes "$2" 2>&1
}

# (a) disable direction — every documented "off" spelling must run to
# completion. Each iteration clears the target first, so "record published"
# is proven per-value rather than inherited from an earlier iteration.
offenders25=""
seen25=0
for hookval25 in "${HOOK_DISABLE_VALUES[@]}"; do
  seen25=$(( seen25 + 1 ))
  rm -f "${JSON25}"
  out25=$(_run_write_audit_25 "${hookval25}" "gate off via [${hookval25}]") \
    && rc25=0 || rc25=$?
  present25=$([[ -f "${JSON25}" ]] && echo yes || echo no)
  if (( rc25 != 0 )) || [[ "${present25}" != "yes" ]] \
     || ! echo "${out25}" | grep -q "^OK: wrote"; then
    offenders25="${offenders25} [${hookval25}](rc=${rc25},record=${present25})"
  fi
done

if [[ -z "${offenders25}" ]] && (( seen25 == HOOK_DISABLE_EXPECTED_COUNT )); then
  pass "scenario 25a — all ${seen25} documented 'off' spellings ($(_disable_values_repr)) leave WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME disabled: write completes, record published (H-AUDIT-HOOK-GATE-TRUTHY)"
else
  fail "scenario 25a — expected rc=0 + record + 'OK: wrote' for all ${HOOK_DISABLE_EXPECTED_COUNT} documented 'off' spellings ($(_disable_values_repr)); exercised ${seen25}; offending values:${offenders25:-none}"
fi

# (b) fire direction — `1` must still abort before publishing, leaving the
# record written by (a) byte-identical.
#
# `|| echo MISSING` is load-bearing under `set -euo pipefail`, same reason
# as the `|| true` guards in scenario 24: when the gate regresses to `-n`,
# (a)'s writes above all abort before the rename, so ${JSON25} does not
# exist and a bare `cat` exits 1 -- which kills this whole test script
# before it can report 25a's failure and every scenario after it. Observed
# live while mutation-testing this very fix: the `-n` mutation produced one
# FAIL line and no summary, having aborted here. Degrading to the sentinel
# lets 25b report a clean FAIL and the run continue to scenario 26.
CONTENT_25_BEFORE="$(cat "${JSON25}" 2>/dev/null || echo MISSING)"
out25_one=$(_run_write_audit_25 1 "gate on via 1 - must never land") && rc25_one=0 || rc25_one=$?
CONTENT_25_AFTER="$(cat "${JSON25}" 2>/dev/null || echo MISSING)"

# The `!= MISSING` guard keeps the byte-identical comparison from passing
# vacuously: with no prior record on disk, MISSING == MISSING would satisfy
# "unchanged" without ever exercising the property.
if (( rc25_one != 0 )) \
   && echo "${out25_one}" | grep -q "simulating interruption before rename" \
   && [[ "${CONTENT_25_BEFORE}" != "MISSING" ]] \
   && [[ "${CONTENT_25_AFTER}" == "${CONTENT_25_BEFORE}" ]]; then
  pass "scenario 25b — WRITE_AUDIT_TEST_ABORT_BEFORE_RENAME=1 still fires: aborts before publishing, prior record untouched (hook not fixed into permanently dead)"
else
  fail "scenario 25b — expected rc!=0 + 'simulating interruption before rename' + a real prior record left unchanged; got rc=${rc25_one}, prior_record_present=$([[ "${CONTENT_25_BEFORE}" != "MISSING" ]] && echo yes || echo no), content_changed=$([[ "${CONTENT_25_AFTER}" == "${CONTENT_25_BEFORE}" ]] && echo no || echo yes)"
  echo "${out25_one}" | sed 's/^/      /'
fi

FEATURE26="hook-gate-after-rename"
JSON26="${TMP_REPO}/dev/audit/2026-08-06-harness-hook-gate-${FEATURE26}.json"

_run_write_audit_26() {  # $1 = value for the AFTER_RENAME hook
  REPO_ROOT="${TMP_REPO}" WRITE_AUDIT_TEST_ABORT_AFTER_RENAME="$1" \
    bash "${WRITE_AUDIT}" \
      --date 2026-08-06 --feature "${FEATURE26}" --branch "harness/hook-gate" \
      --structural APPROVED --behavioral APPROVED --overall APPROVED 2>&1
}

# (a) disable direction, same value set as 25a. The record lands whether or
# not the hook fires (this hook aborts after the `mv`), so rc and the "OK:"
# line -- NOT the file's existence -- are what separate inert from fired
# here.
offenders26=""
seen26=0
for hookval26 in "${HOOK_DISABLE_VALUES[@]}"; do
  seen26=$(( seen26 + 1 ))
  out26=$(_run_write_audit_26 "${hookval26}") && rc26=0 || rc26=$?
  if (( rc26 != 0 )) || ! echo "${out26}" | grep -q "^OK: wrote"; then
    offenders26="${offenders26} [${hookval26}](rc=${rc26})"
  fi
done

if [[ -z "${offenders26}" ]] && (( seen26 == HOOK_DISABLE_EXPECTED_COUNT )) \
   && [[ -f "${JSON26}" ]]; then
  pass "scenario 26a — all ${seen26} documented 'off' spellings ($(_disable_values_repr)) leave WRITE_AUDIT_TEST_ABORT_AFTER_RENAME disabled: rc=0 with the 'OK:' line, no spurious failure reported for an already-published record (H-AUDIT-HOOK-GATE-TRUTHY)"
else
  fail "scenario 26a — expected rc=0 + 'OK: wrote' for all ${HOOK_DISABLE_EXPECTED_COUNT} documented 'off' spellings ($(_disable_values_repr)); exercised ${seen26}, record_present=$([[ -f "${JSON26}" ]] && echo yes || echo no); offending values:${offenders26:-none}"
fi

# (b) fire direction — `1` must still abort right after the rename.
out26_one=$(_run_write_audit_26 1) && rc26_one=0 || rc26_one=$?

if (( rc26_one != 0 )) \
   && echo "${out26_one}" | grep -q "simulating interruption right after rename" \
   && ! echo "${out26_one}" | grep -q "^OK: wrote"; then
  pass "scenario 26b — WRITE_AUDIT_TEST_ABORT_AFTER_RENAME=1 still fires: aborts right after the rename with no 'OK:' line (hook not fixed into permanently dead; scenario 24 depends on this)"
else
  fail "scenario 26b — expected rc!=0 + 'simulating interruption right after rename' + no 'OK: wrote'; got rc=${rc26_one}"
  echo "${out26_one}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 27 (H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE): an explicitly-set
# REPO_ROOT must win over write_audit.sh's own walk-up, even when the
# walk-up would ALSO succeed -- just to a DIFFERENT root. This is the exact
# shape of the bug: a script invoked in-place from inside a real checkout
# (where a `.git`/`.claude` marker is always found a few directories up)
# silently ignored any REPO_ROOT override and published into the walked-up
# root's dev/audit/ instead of the caller's intended redirect target. Two
# people probing the hook gate by hand hit this independently on
# 2026-08-06 and leaked a stray record into the live dev/audit/.
#
# WALKUP_ROOT has its own `.claude` sentinel a few directories above the
# copied script (so the walk-up "succeeds" on its own terms) AND its own
# dev/audit/. TARGET_ROOT is a completely separate directory passed via
# REPO_ROOT. Before the fix, the record lands in WALKUP_ROOT/dev/audit/;
# after the fix it must land in TARGET_ROOT/dev/audit/ instead.
# ---------------------------------------------------------------------------
WALKUP_ROOT="$(mktemp -d -t write_audit_walkup.XXXXXX)"
TARGET_ROOT="$(mktemp -d -t write_audit_target.XXXXXX)"
mkdir -p "${WALKUP_ROOT}/.claude" "${WALKUP_ROOT}/trading/devtools/checks" \
         "${WALKUP_ROOT}/dev/audit" "${TARGET_ROOT}/dev/audit"
cp "${SCRIPT_DIR}/write_audit.sh" "${WALKUP_ROOT}/trading/devtools/checks/"
chmod +x "${WALKUP_ROOT}/trading/devtools/checks/write_audit.sh"

out27=$(REPO_ROOT="${TARGET_ROOT}" \
  bash "${WALKUP_ROOT}/trading/devtools/checks/write_audit.sh" \
    --date 2026-08-06 --feature "repo-root-override" --branch "harness/repo-root" \
    --structural APPROVED --behavioral APPROVED --overall APPROVED 2>&1) && rc27=0 || rc27=$?

# `_glob_count` (not `ls .../*.json`) deliberately: under `set -euo pipefail`,
# `ls` on a glob that matches nothing exits non-zero, and pipefail propagates
# that into this assignment's exit status, aborting the whole test script
# right here with no summary line -- exactly the zero-match case
# walkup_count27 is expected to hit on a passing run. `_glob_count` (see its
# definition near the top of this file) returns "0" with no abort in that
# case, and even if the directory itself were missing, so it can't trip -e
# this way (H-AUDIT-TEST-FIND-PIPELINE-UNGUARDED).
target_count27="$(_glob_count "${TARGET_ROOT}/dev/audit" '*.json' '-type f')"
walkup_count27="$(_glob_count "${WALKUP_ROOT}/dev/audit" '*.json' '-type f')"

if (( rc27 == 0 )) && echo "${out27}" | grep -q "^OK: wrote" \
   && [[ "${target_count27}" == "1" ]] && [[ "${walkup_count27}" == "0" ]]; then
  pass "scenario 27 — REPO_ROOT override wins over a SUCCESSFUL walk-up to a different root: record lands under \$REPO_ROOT/dev/audit only, never the walked-up root (H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE)"
else
  fail "scenario 27 — expected rc=0 + 'OK: wrote' + exactly 1 record under TARGET_ROOT and 0 under WALKUP_ROOT; got rc=${rc27}, target_count=${target_count27}, walkup_count=${walkup_count27}"
  echo "${out27}" | sed 's/^/      /'
fi
# ---------------------------------------------------------------------------
# Scenario 27b (H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE, B1 rework): the
# OTHER half of _repo_root()'s two-branch contract. 27a only pins that an
# explicit REPO_ROOT wins over a successful walk-up; every caller anywhere
# else in this file also sets REPO_ROOT explicitly, so nothing in this
# suite previously reached the walk-up branch at all -- despite it being
# the ONLY path production uses: `lead-orchestrator.md` invokes
# write_audit.sh with REPO_ROOT unset. Reuses the WALKUP_ROOT fixture from
# 27a (its dev/audit/ is empty at this point -- 27a asserted
# walkup_count27 == 0). `env -u REPO_ROOT` forces the var unset regardless
# of ambient shell state, rather than relying on this script never having
# exported it.
# ---------------------------------------------------------------------------
out27b=$(env -u REPO_ROOT \
  bash "${WALKUP_ROOT}/trading/devtools/checks/write_audit.sh" \
    --date 2026-08-06 --feature "repo-root-walkup" --branch "harness/repo-root" \
    --structural APPROVED --behavioral APPROVED --overall APPROVED 2>&1) && rc27b=0 || rc27b=$?

walkup_count27b="$(_glob_count "${WALKUP_ROOT}/dev/audit" '*.json' '-type f')"

if (( rc27b == 0 )) && echo "${out27b}" | grep -q "^OK: wrote" && [[ "${walkup_count27b}" == "1" ]]; then
  pass "scenario 27b — REPO_ROOT unset: the walk-up still locates the root and publishes the record (H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE, pins the fallback branch production actually uses)"
else
  fail "scenario 27b — expected rc=0 + 'OK: wrote' + exactly 1 record under WALKUP_ROOT; got rc=${rc27b}, walkup_count=${walkup_count27b}"
  echo "${out27b}" | sed 's/^/      /'
fi

rm -rf "${WALKUP_ROOT}" "${TARGET_ROOT}"

# ---------------------------------------------------------------------------
# Scenario 28 (H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING): record_qc_audit.sh has
# its OWN separate _repo_root(), and until this fix it had the sibling bug
# of scenario 27 -- walk-up first, REPO_ROOT fallback second. It is WORSE
# than a plain duplicate: record_qc_audit.sh reassigns its REPO_ROOT
# variable from the call's output with a PLAIN (non-export) assignment,
# and bash's export attribute survives plain reassignment of an
# already-exported variable. So a caller's REPO_ROOT override -- even after
# write_audit.sh's own #2231 fix made ITS _repo_root() prefer REPO_ROOT --
# never reaches write_audit.sh as the caller intended: record_qc_audit.sh's
# unfixed walk-up silently overwrites the exported REPO_ROOT with its own
# walked-up value before ever invoking write_audit.sh as a child process.
#
# This scenario pins the STRONGER, end-to-end claim (not just
# record_qc_audit.sh's own _repo_root() return value in isolation): invoke
# record_qc_audit.sh directly with an explicit REPO_ROOT override pointing
# at TARGET2_ROOT, from a script physically located under WALKUP2_ROOT (whose
# own .claude sentinel makes the walk-up ALSO succeed, just to the wrong
# root). The audit record produced by the write_audit.sh CHILD PROCESS must
# land under TARGET2_ROOT/dev/audit -- never WALKUP2_ROOT/dev/audit. Distinct
# quality scores in each root's dev/reviews/<feature>.md fixture (4 vs 5)
# let the assertion pin not just *that* a record landed in the right place,
# but that it is the RIGHT record (i.e. REVIEW_FILE resolution followed the
# same override, not just WRITE_AUDIT's target path).
#
# WALKUP2_ROOT and TARGET2_ROOT each carry a full copy of BOTH
# record_qc_audit.sh and write_audit.sh (not just one) because the buggy
# pre-fix path resolves REVIEW_FILE, WRITE_AUDIT, and the audit output dir
# all from whichever root _repo_root() picks -- a partial fixture would
# mask the bug behind a "file not found" error rather than a wrong-location
# write.
# ---------------------------------------------------------------------------
FEATURE28="repo-root-sibling-override"
WALKUP2_ROOT="$(mktemp -d -t record_qc_audit_walkup2.XXXXXX)"
TARGET2_ROOT="$(mktemp -d -t record_qc_audit_target2.XXXXXX)"
mkdir -p "${WALKUP2_ROOT}/.claude" "${WALKUP2_ROOT}/trading/devtools/checks" \
         "${WALKUP2_ROOT}/dev/audit" "${WALKUP2_ROOT}/dev/reviews" \
         "${TARGET2_ROOT}/trading/devtools/checks" \
         "${TARGET2_ROOT}/dev/audit" "${TARGET2_ROOT}/dev/reviews"

cp "${SCRIPT}" "${WALKUP2_ROOT}/trading/devtools/checks/"
cp "${SCRIPT_DIR}/write_audit.sh" "${WALKUP2_ROOT}/trading/devtools/checks/"
cp "${SCRIPT}" "${TARGET2_ROOT}/trading/devtools/checks/"
cp "${SCRIPT_DIR}/write_audit.sh" "${TARGET2_ROOT}/trading/devtools/checks/"
chmod +x "${WALKUP2_ROOT}/trading/devtools/checks/"*.sh "${TARGET2_ROOT}/trading/devtools/checks/"*.sh

cat > "${WALKUP2_ROOT}/dev/reviews/${FEATURE28}.md" <<'EOF'
Reviewed SHA: walkup2sha

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
4 — WRONG root; must not be the record that gets published
EOF

cat > "${TARGET2_ROOT}/dev/reviews/${FEATURE28}.md" <<'EOF'
Reviewed SHA: target2sha

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
5 — RIGHT root; this is the record that must be published
EOF

out28=$(REPO_ROOT="${TARGET2_ROOT}" \
  bash "${WALKUP2_ROOT}/trading/devtools/checks/record_qc_audit.sh" \
    "${FEATURE28}" "harness/repo-root-sibling" "2026-08-08" 2>&1) && rc28=0 || rc28=$?

target_count28="$(_glob_count "${TARGET2_ROOT}/dev/audit" '*.json' '-type f')"
walkup_count28="$(_glob_count "${WALKUP2_ROOT}/dev/audit" '*.json' '-type f')"
JSON28="${TARGET2_ROOT}/dev/audit/2026-08-08-harness-repo-root-sibling-${FEATURE28}.json"

if (( rc28 == 0 )) && [[ "${target_count28}" == "1" ]] && [[ "${walkup_count28}" == "0" ]] \
   && [[ -f "${JSON28}" ]] && grep -q '"quality_score": *5' "${JSON28}"; then
  pass "scenario 28 — REPO_ROOT override wins end-to-end through the write_audit.sh child process: record (quality_score 5, from TARGET2_ROOT's review file) lands under \$REPO_ROOT/dev/audit only, never the walked-up root (H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING)"
else
  fail "scenario 28 — expected rc=0 + exactly 1 record under TARGET2_ROOT (quality_score 5) and 0 under WALKUP2_ROOT; got rc=${rc28}, target_count=${target_count28}, walkup_count=${walkup_count28}"
  echo "${out28}" | sed 's/^/      /'
  [[ -f "${JSON28}" ]] && echo "      json: $(cat "${JSON28}")"
fi

rm -rf "${WALKUP2_ROOT}" "${TARGET2_ROOT}"

# ---------------------------------------------------------------------------
# Scenario 28b (H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING): the OTHER half of
# record_qc_audit.sh's _repo_root() contract -- with REPO_ROOT unset, the
# walk-up must still locate the root and publish correctly, exactly as
# production uses it (lead-orchestrator.md invokes record_qc_audit.sh
# without ever setting REPO_ROOT). Uses its OWN fresh fixture
# (WALKUP3_ROOT) rather than reusing scenario 28's WALKUP2_ROOT, and asserts
# an absolute post-run count rather than a delta -- deliberately avoiding
# the cumulative-count pattern in scenario 27b (H-AUDIT-27B-CUMULATIVE-COUNT
# is a known, separately-tracked residual in that scenario; this one is not
# built to inherit it).
#
# `env -u REPO_ROOT` forces the var unset regardless of ambient shell
# state, matching scenario 27b's guard -- without it, an ambient REPO_ROOT
# in the invoking shell would (a) make this scenario pass for the wrong
# reason and (b), per the H-WRITE-AUDIT-REPO-ROOT-NOT-REDIRECTABLE rework
# history, risks writing a stray record into the live dev/audit/ if the
# guard is missing and the ambient value is unset.
# ---------------------------------------------------------------------------
FEATURE28B="repo-root-sibling-walkup"
WALKUP3_ROOT="$(mktemp -d -t record_qc_audit_walkup3.XXXXXX)"
mkdir -p "${WALKUP3_ROOT}/.claude" "${WALKUP3_ROOT}/trading/devtools/checks" \
         "${WALKUP3_ROOT}/dev/audit" "${WALKUP3_ROOT}/dev/reviews"
cp "${SCRIPT}" "${WALKUP3_ROOT}/trading/devtools/checks/"
cp "${SCRIPT_DIR}/write_audit.sh" "${WALKUP3_ROOT}/trading/devtools/checks/"
chmod +x "${WALKUP3_ROOT}/trading/devtools/checks/"*.sh

cat > "${WALKUP3_ROOT}/dev/reviews/${FEATURE28B}.md" <<'EOF'
Reviewed SHA: walkup3sha

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
3 — walk-up fallback path
EOF

out28b=$(env -u REPO_ROOT \
  bash "${WALKUP3_ROOT}/trading/devtools/checks/record_qc_audit.sh" \
    "${FEATURE28B}" "harness/repo-root-sibling" "2026-08-08" 2>&1) && rc28b=0 || rc28b=$?

walkup_count28b="$(_glob_count "${WALKUP3_ROOT}/dev/audit" '*.json' '-type f')"
JSON28B="${WALKUP3_ROOT}/dev/audit/2026-08-08-harness-repo-root-sibling-${FEATURE28B}.json"

if (( rc28b == 0 )) && [[ "${walkup_count28b}" == "1" ]] \
   && [[ -f "${JSON28B}" ]] && grep -q '"quality_score": *3' "${JSON28B}"; then
  pass "scenario 28b — REPO_ROOT unset: the walk-up still locates the root and publishes the record end-to-end through write_audit.sh (H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING, own fixture, absolute count not cumulative)"
else
  fail "scenario 28b — expected rc=0 + exactly 1 record under WALKUP3_ROOT (quality_score 3); got rc=${rc28b}, walkup_count=${walkup_count28b}"
  echo "${out28b}" | sed 's/^/      /'
  [[ -f "${JSON28B}" ]] && echo "      json: $(cat "${JSON28B}")"
fi

rm -rf "${WALKUP3_ROOT}"

# ---------------------------------------------------------------------------
# Scenario 29 (H-REPO-ROOT-SET-BUT-INVALID-SILENT-FALLTHROUGH): the shared
# _check_lib.sh:repo_root() helper -- sourced by most OTHER check scripts,
# not just the audit pair -- must treat a REPO_ROOT that is SET but fails
# the `[ -d ]` guard as a hard error, not a silent fallthrough to the
# walk-up. Before this fix, `REPO_ROOT=/definitely/not/a/dir` (or any
# non-directory) fell through exactly like an unset REPO_ROOT: the walk-up
# ran, found a DIFFERENT root than the caller asked for, and returned it
# with rc=0 and no diagnostic -- the exact "audit record lands in a root
# the caller didn't choose" failure this whole H-* family exists to
# prevent, just reachable via malformed input instead of valid input.
#
# WALKUP4_ROOT carries its own `.claude` sentinel, so the walk-up branch
# would ALSO succeed here if reached -- proving a hard-error scenario
# actually stopped the walk-up, not merely that no root happened to be
# findable. _repo_root_probe.sh is a minimal wrapper that sources the
# fixture's own copy of _check_lib.sh and calls repo_root() directly:
# repo_root() itself only echoes a path or exits 1, it never writes a
# file, so a direct probe (rather than a full check script) is the
# smallest correct fixture for pinning ITS contract in isolation --
# scenarios 30/31 below separately pin the two write-side siblings
# end-to-end.
# ---------------------------------------------------------------------------
WALKUP4_ROOT="$(mktemp -d -t check_lib_walkup4.XXXXXX)"
mkdir -p "${WALKUP4_ROOT}/.claude" "${WALKUP4_ROOT}/trading/devtools/checks"
cp "${SCRIPT_DIR}/_check_lib.sh" "${WALKUP4_ROOT}/trading/devtools/checks/"
cat > "${WALKUP4_ROOT}/trading/devtools/checks/_repo_root_probe.sh" <<'EOF'
#!/usr/bin/env bash
# Minimal wrapper: source _check_lib.sh and call repo_root() directly, so
# its return value / exit code can be pinned without a full check script.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/_check_lib.sh"
repo_root
EOF
chmod +x "${WALKUP4_ROOT}/trading/devtools/checks/"*.sh
PROBE29="${WALKUP4_ROOT}/trading/devtools/checks/_repo_root_probe.sh"

# The two malformed REPO_ROOT shapes filed against this defect, plus the
# deliberate `''` no-op: a path that doesn't exist at all, and a path that
# exists but is a regular file (not a directory), are the malformed cases;
# REPO_ROOT='' (pinned separately below as scenario 29c) is NOT malformed --
# it is the documented no-op that behaves as unset. `mktemp -u` reserves a
# name without creating it, so BOGUS_MISSING29 is guaranteed absent;
# `mktemp` (no `-u`) creates BOGUS_FILE29 as a real, ordinary file.
BOGUS_MISSING29="$(mktemp -u -t repo_root_bogus_missing.XXXXXX)"
BOGUS_FILE29="$(mktemp -t repo_root_bogus_file.XXXXXX)"

# (a) nonexistent path -- must hard-error, not walk up to WALKUP4_ROOT.
out29a=$(REPO_ROOT="${BOGUS_MISSING29}" bash "${PROBE29}" 2>&1) && rc29a=0 || rc29a=$?
if (( rc29a != 0 )) \
   && [[ "${out29a}" == "FAIL: REPO_ROOT is set to '${BOGUS_MISSING29}' but is not a directory" ]]; then
  pass "scenario 29a — _check_lib.sh:repo_root(): REPO_ROOT set to a nonexistent path is a hard error (rc!=0), never silently falls through to the walk-up (H-REPO-ROOT-SET-BUT-INVALID-SILENT-FALLTHROUGH)"
else
  fail "scenario 29a — expected rc!=0 + exact FAIL message naming '${BOGUS_MISSING29}' and nothing else on stdout (i.e. no walked-up root leaked); got rc=${rc29a}"
  echo "${out29a}" | sed 's/^/      /'
fi

# (b) a REGULAR FILE, not a directory -- the `[ -d ]` guard must reject
# this too, not just a bare nonexistent path.
out29b=$(REPO_ROOT="${BOGUS_FILE29}" bash "${PROBE29}" 2>&1) && rc29b=0 || rc29b=$?
if (( rc29b != 0 )) \
   && [[ "${out29b}" == "FAIL: REPO_ROOT is set to '${BOGUS_FILE29}' but is not a directory" ]]; then
  pass "scenario 29b — _check_lib.sh:repo_root(): REPO_ROOT set to a regular file (not a directory) is a hard error (rc!=0), never silently falls through to the walk-up"
else
  fail "scenario 29b — expected rc!=0 + exact FAIL message naming '${BOGUS_FILE29}'; got rc=${rc29b}"
  echo "${out29b}" | sed 's/^/      /'
fi

# (c) REPO_ROOT='' (empty string) -- the DELIBERATE other half of this
# fix's contract: an empty override is treated the SAME as unset, so it
# must keep walking up successfully (rc=0, returns WALKUP4_ROOT), exactly
# like the unset case every existing caller depends on. This is not "not
# yet fixed" -- it is the chosen, documented behaviour (see the code
# comment in _check_lib.sh:repo_root()), and this scenario is what pins
# that choice so a future change can't silently flip it either direction.
out29c=$(REPO_ROOT="" bash "${PROBE29}" 2>&1) && rc29c=0 || rc29c=$?
if (( rc29c == 0 )) && [[ "${out29c}" == "${WALKUP4_ROOT}" ]]; then
  pass "scenario 29c — _check_lib.sh:repo_root(): REPO_ROOT='' (empty string) is treated as unset, not as set-but-invalid: the walk-up still succeeds (rc=0), matching every existing caller's expectation"
else
  fail "scenario 29c — expected rc=0 + stdout exactly '${WALKUP4_ROOT}' (empty REPO_ROOT walks up like unset); got rc=${rc29c}"
  echo "${out29c}" | sed 's/^/      /'
fi

rm -f "${BOGUS_FILE29}"
rm -rf "${WALKUP4_ROOT}"

# ---------------------------------------------------------------------------
# Scenario 30 (H-REPO-ROOT-SET-BUT-INVALID-SILENT-FALLTHROUGH): the SAME
# contract, end-to-end through write_audit.sh:_repo_root(). This is the
# script that actually WRITES the audit record, so here the assertion is
# the stronger, observable one the defect filing asked for: a malformed
# REPO_ROOT must produce rc!=0 AND zero records written anywhere -- not
# just a hard-error return value in isolation (scenario 29), but proof
# nothing landed in the walked-up root either.
#
# WALKUP5_ROOT mirrors the scenario-27 fixture shape: its own `.claude`
# sentinel plus its own dev/audit/, so a regression back to the silent
# fallthrough would publish a record there with rc=0 -- exactly what
# scenario 27 pinned for the *valid*-REPO_ROOT-wins-over-walk-up case;
# this scenario pins the malformed-REPO_ROOT-must-not-reach-the-walk-up-
# at-all case.
# ---------------------------------------------------------------------------
WALKUP5_ROOT="$(mktemp -d -t write_audit_walkup5.XXXXXX)"
mkdir -p "${WALKUP5_ROOT}/.claude" "${WALKUP5_ROOT}/trading/devtools/checks" \
         "${WALKUP5_ROOT}/dev/audit"
cp "${SCRIPT_DIR}/write_audit.sh" "${WALKUP5_ROOT}/trading/devtools/checks/"
chmod +x "${WALKUP5_ROOT}/trading/devtools/checks/write_audit.sh"

BOGUS_MISSING30="$(mktemp -u -t write_audit_bogus_missing.XXXXXX)"
BOGUS_FILE30="$(mktemp -t write_audit_bogus_file.XXXXXX)"

_run_write_audit_30() {  # $1 = REPO_ROOT value, $2 = feature suffix (for a distinct record name per sub-scenario)
  REPO_ROOT="$1" bash "${WALKUP5_ROOT}/trading/devtools/checks/write_audit.sh" \
    --date 2026-08-08 --feature "repo-root-malformed-$2" --branch "harness/repo-root-malformed" \
    --structural APPROVED --behavioral APPROVED --overall APPROVED 2>&1
}

# (a) nonexistent path
out30a=$(_run_write_audit_30 "${BOGUS_MISSING30}" "missing") && rc30a=0 || rc30a=$?
walkup_count30a="$(_glob_count "${WALKUP5_ROOT}/dev/audit" '*.json' '-type f')"
if (( rc30a != 0 )) \
   && [[ "${out30a}" == "FAIL: REPO_ROOT is set to '${BOGUS_MISSING30}' but is not a directory" ]] \
   && [[ "${walkup_count30a}" == "0" ]]; then
  pass "scenario 30a — write_audit.sh: REPO_ROOT set to a nonexistent path is a hard error, zero records written under the walked-up root either (H-REPO-ROOT-SET-BUT-INVALID-SILENT-FALLTHROUGH)"
else
  fail "scenario 30a — expected rc!=0 + exact FAIL message + 0 records under WALKUP5_ROOT; got rc=${rc30a}, walkup_count=${walkup_count30a}"
  echo "${out30a}" | sed 's/^/      /'
fi

# (b) regular file, not a directory
out30b=$(_run_write_audit_30 "${BOGUS_FILE30}" "file") && rc30b=0 || rc30b=$?
walkup_count30b="$(_glob_count "${WALKUP5_ROOT}/dev/audit" '*.json' '-type f')"
if (( rc30b != 0 )) \
   && [[ "${out30b}" == "FAIL: REPO_ROOT is set to '${BOGUS_FILE30}' but is not a directory" ]] \
   && [[ "${walkup_count30b}" == "0" ]]; then
  pass "scenario 30b — write_audit.sh: REPO_ROOT set to a regular file (not a directory) is a hard error, zero records written under the walked-up root either"
else
  fail "scenario 30b — expected rc!=0 + exact FAIL message + 0 records under WALKUP5_ROOT (cumulative with 30a); got rc=${rc30b}, walkup_count=${walkup_count30b}"
  echo "${out30b}" | sed 's/^/      /'
fi

# (c) REPO_ROOT='' -- must behave exactly like unset (scenario 27b): the
# walk-up succeeds and the record is published under WALKUP5_ROOT.
out30c=$(_run_write_audit_30 "" "empty") && rc30c=0 || rc30c=$?
walkup_count30c="$(_glob_count "${WALKUP5_ROOT}/dev/audit" '*.json' '-type f')"
if (( rc30c == 0 )) && echo "${out30c}" | grep -q "^OK: wrote" && [[ "${walkup_count30c}" == "1" ]]; then
  pass "scenario 30c — write_audit.sh: REPO_ROOT='' (empty string) is treated as unset: the walk-up still succeeds and publishes the record (deliberate, not a regression of 30a/30b)"
else
  fail "scenario 30c — expected rc=0 + 'OK: wrote' + exactly 1 record under WALKUP5_ROOT (30a/30b wrote none); got rc=${rc30c}, walkup_count=${walkup_count30c}"
  echo "${out30c}" | sed 's/^/      /'
fi

rm -f "${BOGUS_FILE30}"
rm -rf "${WALKUP5_ROOT}"

# ---------------------------------------------------------------------------
# Scenario 31 (H-REPO-ROOT-SET-BUT-INVALID-SILENT-FALLTHROUGH): the third
# implementation, record_qc_audit.sh:_repo_root(), pinned end-to-end
# through its write_audit.sh CHILD PROCESS -- mirroring scenario 28's
# two-script fixture shape. Before this fix, a malformed REPO_ROOT here
# was WORSE than in write_audit.sh alone: record_qc_audit.sh reassigns
# its own REPO_ROOT from the walked-up value with a plain (non-export)
# assignment that still carries bash's inherited export attribute, so the
# wrong root would have propagated silently into the write_audit.sh child
# too (the exact H-RECORD-QC-AUDIT-REPO-ROOT-SIBLING shape). This
# scenario proves the malformed REPO_ROOT is rejected before ever
# reaching that child, so nothing is written under the walked-up root
# through either process.
# ---------------------------------------------------------------------------
WALKUP6_ROOT="$(mktemp -d -t record_qc_audit_walkup6.XXXXXX)"
mkdir -p "${WALKUP6_ROOT}/.claude" "${WALKUP6_ROOT}/trading/devtools/checks" \
         "${WALKUP6_ROOT}/dev/audit" "${WALKUP6_ROOT}/dev/reviews"
cp "${SCRIPT}" "${WALKUP6_ROOT}/trading/devtools/checks/"
cp "${SCRIPT_DIR}/write_audit.sh" "${WALKUP6_ROOT}/trading/devtools/checks/"
chmod +x "${WALKUP6_ROOT}/trading/devtools/checks/"*.sh

# A dev/reviews/<feature>.md fixture for EACH sub-scenario's feature name
# (not just 31c's), so that if the hard-error guard regresses, 31a/31b
# reach all the way through to a successful wrong-root PUBLISH under
# WALKUP6_ROOT -- demonstrating the full H-RECORD-QC-AUDIT-REPO-ROOT-
# SIBLING blast radius this fix closes -- rather than merely tripping a
# LATER, incidental "review file not found" error that would still leave
# rc!=0 for the wrong reason and mask a real regression in the guard
# itself.
for _suffix31 in missing file empty; do
  cat > "${WALKUP6_ROOT}/dev/reviews/repo-root-sibling-malformed-${_suffix31}.md" <<EOF
Reviewed SHA: walkup6sha-${_suffix31}

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
3 — walk-up fallback fixture for sub-scenario ${_suffix31}
EOF
done

BOGUS_MISSING31="$(mktemp -u -t record_qc_audit_bogus_missing.XXXXXX)"
BOGUS_FILE31="$(mktemp -t record_qc_audit_bogus_file.XXXXXX)"

_run_record_qc_audit_31() {  # $1 = REPO_ROOT value, $2 = feature suffix
  REPO_ROOT="$1" bash "${WALKUP6_ROOT}/trading/devtools/checks/record_qc_audit.sh" \
    "repo-root-sibling-malformed-$2" "harness/repo-root-sibling-malformed" "2026-08-08" 2>&1
}

# (a) nonexistent path
out31a=$(_run_record_qc_audit_31 "${BOGUS_MISSING31}" "missing") && rc31a=0 || rc31a=$?
walkup_count31a="$(_glob_count "${WALKUP6_ROOT}/dev/audit" '*.json' '-type f')"
if (( rc31a != 0 )) \
   && echo "${out31a}" | grep -qF "FAIL: REPO_ROOT is set to '${BOGUS_MISSING31}' but is not a directory" \
   && [[ "${walkup_count31a}" == "0" ]]; then
  pass "scenario 31a — record_qc_audit.sh: REPO_ROOT set to a nonexistent path is a hard error, zero records written under the walked-up root end-to-end through the write_audit.sh child (H-REPO-ROOT-SET-BUT-INVALID-SILENT-FALLTHROUGH)"
else
  fail "scenario 31a — expected rc!=0 + FAIL message naming '${BOGUS_MISSING31}' + 0 records under WALKUP6_ROOT; got rc=${rc31a}, walkup_count=${walkup_count31a}"
  echo "${out31a}" | sed 's/^/      /'
fi

# (b) regular file, not a directory
out31b=$(_run_record_qc_audit_31 "${BOGUS_FILE31}" "file") && rc31b=0 || rc31b=$?
walkup_count31b="$(_glob_count "${WALKUP6_ROOT}/dev/audit" '*.json' '-type f')"
if (( rc31b != 0 )) \
   && echo "${out31b}" | grep -qF "FAIL: REPO_ROOT is set to '${BOGUS_FILE31}' but is not a directory" \
   && [[ "${walkup_count31b}" == "0" ]]; then
  pass "scenario 31b — record_qc_audit.sh: REPO_ROOT set to a regular file (not a directory) is a hard error, zero records written under the walked-up root end-to-end (cumulative with 31a)"
else
  fail "scenario 31b — expected rc!=0 + FAIL message naming '${BOGUS_FILE31}' + 0 records under WALKUP6_ROOT; got rc=${rc31b}, walkup_count=${walkup_count31b}"
  echo "${out31b}" | sed 's/^/      /'
fi

# (c) REPO_ROOT='' -- must behave exactly like unset (scenario 28b): the
# walk-up succeeds end-to-end and the record is published under
# WALKUP6_ROOT via the write_audit.sh child process. Its dev/reviews/
# fixture was already created in the per-sub-scenario loop above.
out31c=$(_run_record_qc_audit_31 "" "empty") && rc31c=0 || rc31c=$?
walkup_count31c="$(_glob_count "${WALKUP6_ROOT}/dev/audit" '*.json' '-type f')"
if (( rc31c == 0 )) && [[ "${walkup_count31c}" == "1" ]]; then
  pass "scenario 31c — record_qc_audit.sh: REPO_ROOT='' (empty string) is treated as unset: the walk-up still succeeds end-to-end and publishes the record (deliberate, not a regression of 31a/31b)"
else
  fail "scenario 31c — expected rc=0 + exactly 1 record under WALKUP6_ROOT (31a/31b wrote none); got rc=${rc31c}, walkup_count=${walkup_count31c}"
  echo "${out31c}" | sed 's/^/      /'
fi

rm -f "${BOGUS_FILE31}"
rm -rf "${WALKUP6_ROOT}"

# ---------------------------------------------------------------------------
# Scenario 32 — H-AUDIT-GH-FALLBACK-RESIDUAL: gh present, nonzero exit +
# stderr output (simulates unauthenticated / rate-limited gh). Before this
# fix, `2>/dev/null || true` discarded both signals and the resulting empty
# $BODIES fell straight through to the file-mode fallback -- exactly the
# danger scenario 14's missing-binary guard exists to prevent, just reached
# via a different trigger (gh present but failing, not absent). Must refuse
# loudly the same way scenario 14 does: exit 1, no record written, message
# names the PR + the refused fallback path.
# ---------------------------------------------------------------------------
FEATURE32="gh-nonzero-exit-with-stderr-refuses-fallback"
S32_DIR="${TMP_REPO}/s32"
mkdir -p "${S32_DIR}"
cat > "${S32_DIR}/gh" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "pr view")
    echo "gh: rate limit exceeded, please try again later" >&2
    exit 1
    ;;
esac
EOF
chmod +x "${S32_DIR}/gh"

# Companion file-mode review file, deliberately holding the WRONG (APPROVED)
# verdict -- proves the fallback is refused rather than silently consumed,
# same pattern as scenario 14.
cat > "${TMP_REPO}/dev/reviews/${FEATURE32}.md" <<'EOF'
Reviewed SHA: unrelatedsha32

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
5 — this file belongs to a different run and must NOT be used
EOF

audit_count_before_32="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE32}.json")"

out32=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S32_DIR}/gh" \
  bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
  "${FEATURE32}" "feat/dummy" "2026-05-25" --pr-number 3001 2>&1) && rc32=0 || rc32=$?

audit_count_after_32="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE32}.json")"

if (( rc32 == 1 )) && [[ "${audit_count_before_32}" == "0" ]] && [[ "${audit_count_after_32}" == "0" ]] \
   && echo "${out32}" | grep -q "failed (exit 1)" \
   && echo "${out32}" | grep -q "rate limit exceeded" \
   && echo "${out32}" | grep -q "dev/reviews/${FEATURE32}.md"; then
  pass "scenario 32 — gh nonzero exit + stderr (rate-limited) refuses file-mode fallback, no record written (H-AUDIT-GH-FALLBACK-RESIDUAL)"
else
  fail "scenario 32 — expected rc=1, no file written, message naming exit code + stderr + review path; got rc=${rc32}, before=${audit_count_before_32}, after=${audit_count_after_32}"
  echo "${out32}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 33 — H-AUDIT-GH-FALLBACK-RESIDUAL: gh present, nonzero exit but
# SILENT (no stderr at all). Confirms the refusal triggers on exit code
# alone -- not only when stderr happens to be non-empty.
# ---------------------------------------------------------------------------
FEATURE33="gh-nonzero-exit-silent-refuses-fallback"
S33_DIR="${TMP_REPO}/s33"
mkdir -p "${S33_DIR}"
cat > "${S33_DIR}/gh" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "pr view") exit 1;;
esac
EOF
chmod +x "${S33_DIR}/gh"

cat > "${TMP_REPO}/dev/reviews/${FEATURE33}.md" <<'EOF'
Reviewed SHA: unrelatedsha33

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
5 — this file belongs to a different run and must NOT be used
EOF

audit_count_before_33="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE33}.json")"

out33=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S33_DIR}/gh" \
  bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
  "${FEATURE33}" "feat/dummy" "2026-05-25" --pr-number 3002 2>&1) && rc33=0 || rc33=$?

audit_count_after_33="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE33}.json")"

if (( rc33 == 1 )) && [[ "${audit_count_before_33}" == "0" ]] && [[ "${audit_count_after_33}" == "0" ]] \
   && echo "${out33}" | grep -q "failed (exit 1)" \
   && echo "${out33}" | grep -q "dev/reviews/${FEATURE33}.md"; then
  pass "scenario 33 — gh nonzero exit, silent (no stderr) refuses file-mode fallback, no record written (H-AUDIT-GH-FALLBACK-RESIDUAL)"
else
  fail "scenario 33 — expected rc=1, no file written, message naming exit code + review path; got rc=${rc33}, before=${audit_count_before_33}, after=${audit_count_after_33}"
  echo "${out33}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 34 — H-AUDIT-GH-FALLBACK-RESIDUAL: gh exits 0 but emits a stderr
# warning alongside empty stdout. An exit-0 result is NOT sufficient to
# trust an empty $BODIES as "genuinely zero reviews" -- a warning on stderr
# (deprecation notice, partial-failure notice, etc.) must also refuse.
# ---------------------------------------------------------------------------
FEATURE34="gh-exit0-stderr-warning-refuses-fallback"
S34_DIR="${TMP_REPO}/s34"
mkdir -p "${S34_DIR}"
cat > "${S34_DIR}/gh" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "pr view")
    echo "gh: warning: using deprecated API version" >&2
    exit 0
    ;;
esac
EOF
chmod +x "${S34_DIR}/gh"

cat > "${TMP_REPO}/dev/reviews/${FEATURE34}.md" <<'EOF'
Reviewed SHA: unrelatedsha34

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
5 — this file belongs to a different run and must NOT be used
EOF

audit_count_before_34="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE34}.json")"

out34=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S34_DIR}/gh" \
  bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
  "${FEATURE34}" "feat/dummy" "2026-05-25" --pr-number 3003 2>&1) && rc34=0 || rc34=$?

audit_count_after_34="$(_glob_count "${TMP_REPO}/dev/audit" "*-${FEATURE34}.json")"

if (( rc34 == 1 )) && [[ "${audit_count_before_34}" == "0" ]] && [[ "${audit_count_after_34}" == "0" ]] \
   && echo "${out34}" | grep -q "returned no reviews and wrote to stderr (exit 0)" \
   && echo "${out34}" | grep -q "deprecated API version" \
   && echo "${out34}" | grep -q "dev/reviews/${FEATURE34}.md"; then
  pass "scenario 34 — gh exit 0 + stderr warning (empty stdout) refuses file-mode fallback, no record written (H-AUDIT-GH-FALLBACK-RESIDUAL)"
else
  fail "scenario 34 — expected rc=1, no file written, message naming exit code + stderr + review path; got rc=${rc34}, before=${audit_count_before_34}, after=${audit_count_after_34}"
  echo "${out34}" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# Scenario 35 — H-AUDIT-GH-FALLBACK-RESIDUAL regression pin: gh exits 0 with
# EMPTY stdout and NO stderr -- the one shape that legitimately means "PR
# has no reviews yet". Must still fall through to file mode unchanged
# (same fixture shape as scenario 6, kept independent here so a future
# tightening of the exit-code/stderr check has its own dedicated pin
# distinct from scenario 6's CP1 dual-source regression).
# ---------------------------------------------------------------------------
FEATURE35="gh-exit0-empty-no-stderr-still-falls-back"
S35_DIR="${TMP_REPO}/s35"
mkdir -p "${S35_DIR}"
cat > "${S35_DIR}/gh" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "pr view") exit 0;;
esac
EOF
chmod +x "${S35_DIR}/gh"

cat > "${TMP_REPO}/dev/reviews/${FEATURE35}.md" <<'EOF'
Reviewed SHA: genuinelyempty35

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
3 — genuine file-mode fallback, this PR really has zero reviews
EOF

out35=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S35_DIR}/gh" \
  bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
  "${FEATURE35}" "feat/dummy" "2026-05-25" --pr-number 3004 2>&1) && rc35=0 || rc35=$?
JSON35="${TMP_REPO}/dev/audit/2026-05-25-feat-dummy-${FEATURE35}.json"
if (( rc35 == 0 )) && [[ -f "${JSON35}" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${JSON35}" \
   && grep -q '"quality_score": *3' "${JSON35}"; then
  pass "scenario 35 — gh exit 0, empty stdout, no stderr: genuine zero-review PR still falls back to file mode unchanged (H-AUDIT-GH-FALLBACK-RESIDUAL regression pin)"
else
  fail "scenario 35 — expected file-fallback rc=0 + APPROVED + score 3; got rc=${rc35}, output:"
  echo "${out35}" | sed 's/^/      /'
  [[ -f "${JSON35}" ]] && echo "      json: $(cat "${JSON35}")"
fi

# ---------------------------------------------------------------------------
# Scenario 36 — H-AUDIT-GH-FALLBACK-RESIDUAL regression pin: gh exits 0 with
# non-empty stdout (the ordinary happy path, already exercised by scenario
# 2) -- confirms the new exit-code/stderr capture does not disturb the
# unchanged case where gh genuinely returns review data.
# ---------------------------------------------------------------------------
FEATURE36="gh-exit0-nonempty-stdout-happy-path-unchanged"
S36_DIR="${TMP_REPO}/s36"
mkdir -p "${S36_DIR}"
cat > "${S36_DIR}/reviews.txt" <<'EOF'
STATE:APPROVED
## Structural QC

## Verdict

APPROVED
ENDBODY
STATE:APPROVED
## Behavioral QC

## Verdict

APPROVED

## Quality Score
4 — clean
ENDBODY
EOF
make_gh_mock "${S36_DIR}" "${S36_DIR}/reviews.txt"

out36=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S36_DIR}/gh" \
  bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
  "${FEATURE36}" "feat/dummy" "2026-05-25" --pr-number 3005 2>&1) && rc36=0 || rc36=$?
JSON36="${TMP_REPO}/dev/audit/2026-05-25-feat-dummy-${FEATURE36}.json"
if (( rc36 == 0 )) && [[ -f "${JSON36}" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${JSON36}" \
   && grep -q '"behavioral_qc": *"APPROVED"' "${JSON36}" \
   && grep -q '"quality_score": *4' "${JSON36}"; then
  pass "scenario 36 — gh exit 0, non-empty stdout: happy path unchanged, record written from PR reviews (H-AUDIT-GH-FALLBACK-RESIDUAL)"
else
  fail "scenario 36 — expected rc=0 + APPROVED+APPROVED+score 4; got rc=${rc36}, output:"
  echo "${out36}" | sed 's/^/      /'
  [[ -f "${JSON36}" ]] && echo "      json: $(cat "${JSON36}")"
fi

# ---------------------------------------------------------------------------
# Scenario 37 — H-AUDIT-GH-STDERR-GATE-TOO-BROAD: gh exits 0 with a REAL
# (non-empty) review payload on stdout AND a stderr warning (e.g. an
# update-notifier line). Before this fix, the refusal condition was
# `[ "$GH_RC" -ne 0 ] || [ -n "$GH_STDERR" ]` -- $BODIES appeared nowhere in
# it, so this cell refused loudly (exit 1, no record, self-contradictory
# "failed (exit 0)" message) even though gh had already handed back a
# perfectly good, parseable review payload. Must now behave like scenario 36
# (record written from the real PR reviews) and NOT fall back to the
# companion dev/reviews/ file below, which deliberately holds a different
# (wrong) verdict+score so a silent fallback would be caught by content, not
# merely by exit code.
# ---------------------------------------------------------------------------
FEATURE37="gh-exit0-nonempty-stdout-with-stderr-not-refused"
S37_DIR="${TMP_REPO}/s37"
mkdir -p "${S37_DIR}"
cat > "${S37_DIR}/reviews.txt" <<'EOF'
STATE:APPROVED
Reviewed SHA: real37

## Structural QC — gh-exit0-nonempty-stdout-with-stderr-not-refused

## Verdict
APPROVED
ENDBODY
STATE:CHANGES_REQUESTED
Reviewed SHA: real37

## Behavioral QC — gh-exit0-nonempty-stdout-with-stderr-not-refused

## Quality Score
2 — real payload, must be used instead of the wrong fallback file

## Verdict
NEEDS_REWORK
ENDBODY
EOF
cat > "${S37_DIR}/gh" <<EOF
#!/bin/sh
case "\$1 \$2" in
  "pr view")
    echo "gh: A new release of gh is available" >&2
    cat "${S37_DIR}/reviews.txt"
    ;;
esac
EOF
chmod +x "${S37_DIR}/gh"

# Companion file-mode review file, deliberately holding the WRONG (all
# APPROVED, score 5) verdict -- proves a fix that accidentally fell back to
# file mode instead of using the real PR payload would be caught here.
cat > "${TMP_REPO}/dev/reviews/${FEATURE37}.md" <<'EOF'
Reviewed SHA: unrelatedsha37

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

## Quality Score
5 — this file belongs to a different run and must NOT be used
EOF

out37=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S37_DIR}/gh" \
  bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
  "${FEATURE37}" "feat/dummy" "2026-05-25" --pr-number 3006 2>&1) && rc37=0 || rc37=$?
JSON37="${TMP_REPO}/dev/audit/2026-05-25-feat-dummy-${FEATURE37}.json"
if (( rc37 == 0 )) && [[ -f "${JSON37}" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${JSON37}" \
   && grep -q '"behavioral_qc": *"NEEDS_REWORK"' "${JSON37}" \
   && grep -q '"overall_qc": *"NEEDS_REWORK"' "${JSON37}" \
   && grep -q '"quality_score": *2' "${JSON37}"; then
  pass "scenario 37 — gh exit 0, non-empty stdout + stderr warning: real PR payload recorded, not refused, not the wrong file-mode fallback (H-AUDIT-GH-STDERR-GATE-TOO-BROAD)"
else
  fail "scenario 37 — expected rc=0 + APPROVED/NEEDS_REWORK/NEEDS_REWORK/score 2 from the real payload (not the wrong file fixture, not a refusal); got rc=${rc37}, output:"
  echo "${out37}" | sed 's/^/      /'
  [[ -f "${JSON37}" ]] && echo "      json: $(cat "${JSON37}")"
fi

# ---------------------------------------------------------------------------
# Scenario 38 — CP4 rework: PR mode, structural-only review (behavioral not
# yet run -- a normal, caller-documented state per
# .claude/agents/lead-orchestrator.md's Stage 4 note "after Stage 1 if
# behavioral was not run"), with a companion dev/reviews/<feature>.md left
# over from an UNRELATED run carrying a conflicting ## Verdict + ## Quality
# Score. Before this fix, the ## Verdict / quality-score fallbacks
# (record_qc_audit.sh:~382-452, pre-fix unguarded) ran unconditionally
# whenever STRUCTURAL/BEHAVIORAL/QUALITY_SCORE were still empty -- including
# in PR mode with only one review resolved -- and would read the
# unrelated file's NEEDS_REWORK verdict + score 1 into the still-unresolved
# BEHAVIORAL/QUALITY_SCORE fields, flipping overall_qc from APPROVED to
# NEEDS_REWORK. The correct result leaves the unresolved fields at their
# SKIPPED/null defaults and ignores the companion file entirely, because
# this is a genuine PR-mode run (FILE_MODE must stay 0).
# ---------------------------------------------------------------------------
FEATURE38="structural-only-pr-mode-no-file-leak"
S38_DIR="${TMP_REPO}/s38"
mkdir -p "${S38_DIR}"
cat > "${S38_DIR}/reviews.txt" <<'EOF'
STATE:APPROVED
Reviewed SHA: real38

## Structural QC — structural-only-pr-mode-no-file-leak

## Verdict
APPROVED
ENDBODY
EOF
make_gh_mock "${S38_DIR}" "${S38_DIR}/reviews.txt"

# Companion file-mode review file, left over from an unrelated run, holding
# a deliberately WRONG verdict + score. Must NOT be consulted: this PR-mode
# call already resolved structural_qc for real, and per the fix,
# behavioral_qc / quality_score must fall through to their SKIPPED/null
# defaults rather than reading this file.
cat > "${TMP_REPO}/dev/reviews/${FEATURE38}.md" <<'EOF'
Reviewed SHA: unrelatedsha38

## Verdict
NEEDS_REWORK

## Quality Score
1 — this file belongs to a different run and must NOT be used
EOF

out38=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S38_DIR}/gh" \
  bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
  "${FEATURE38}" "feat/dummy" "2026-05-25" --pr-number 3007 2>&1) && rc38=0 || rc38=$?
JSON38="${TMP_REPO}/dev/audit/2026-05-25-feat-dummy-${FEATURE38}.json"
if (( rc38 == 0 )) && [[ -f "${JSON38}" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${JSON38}" \
   && grep -q '"behavioral_qc": *"SKIPPED"' "${JSON38}" \
   && grep -q '"overall_qc": *"APPROVED"' "${JSON38}" \
   && grep -q '"quality_score": *null' "${JSON38}"; then
  pass "scenario 38 — PR mode, structural-only review: unresolved behavioral_qc/quality_score fall to SKIPPED/null, not leaked from an unrelated dev/reviews/ file (CP4 rework)"
else
  fail "scenario 38 — expected rc=0 + APPROVED/SKIPPED/APPROVED/null (not leaked from the wrong file fixture); got rc=${rc38}, output:"
  echo "${out38}" | sed 's/^/      /'
  [[ -f "${JSON38}" ]] && echo "      json: $(cat "${JSON38}")"
fi

# ---------------------------------------------------------------------------
# Scenario 39 — H-AUDIT-SHA-FILE-LEAK: PR mode, structural-only review whose
# body carries NO "Reviewed SHA:" line (so $BODIES yields no match), with a
# companion dev/reviews/<feature>.md left over from an UNRELATED run
# carrying a conflicting "Reviewed SHA:" line. Before this fix, the
# "Reviewed SHA" extractor (record_qc_audit.sh:~506-507, pre-fix unguarded)
# ran unconditionally whenever BODIES yielded no "Reviewed SHA:" line --
# including in PR mode -- and would read the unrelated file's
# "Reviewed SHA: FOREIGNSHA99" into the SHA field, mis-keying
# write_audit.sh's consecutive_rework_count identity check. The correct
# result leaves sha at its "" default and ignores the companion file
# entirely, because this is a genuine PR-mode run (FILE_MODE must stay 0).
# ---------------------------------------------------------------------------
FEATURE39="structural-only-pr-mode-no-sha-file-leak"
S39_DIR="${TMP_REPO}/s39"
mkdir -p "${S39_DIR}"
cat > "${S39_DIR}/reviews.txt" <<'EOF'
STATE:APPROVED

## Structural QC — structural-only-pr-mode-no-sha-file-leak

## Verdict
APPROVED
ENDBODY
EOF
make_gh_mock "${S39_DIR}" "${S39_DIR}/reviews.txt"

# Companion file-mode review file, left over from an unrelated run, holding
# a deliberately foreign SHA. Must NOT be consulted: this PR-mode call's
# BODIES has no "Reviewed SHA:" line, and per the fix, sha must fall through
# to its "" default rather than reading this file.
cat > "${TMP_REPO}/dev/reviews/${FEATURE39}.md" <<'EOF'
Reviewed SHA: FOREIGNSHA99

## Verdict
APPROVED

## Quality Score
5 — this file belongs to a different run and must NOT be used
EOF

out39=$(REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${S39_DIR}/gh" \
  bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
  "${FEATURE39}" "feat/dummy" "2026-05-25" --pr-number 3008 2>&1) && rc39=0 || rc39=$?
JSON39="${TMP_REPO}/dev/audit/2026-05-25-feat-dummy-${FEATURE39}.json"
if (( rc39 == 0 )) && [[ -f "${JSON39}" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${JSON39}" \
   && grep -q '"sha": *""' "${JSON39}"; then
  pass "scenario 39 — PR mode, structural-only review with no Reviewed SHA line: sha stays empty, not leaked from an unrelated dev/reviews/ file (H-AUDIT-SHA-FILE-LEAK)"
else
  fail "scenario 39 — expected rc=0 + structural_qc APPROVED + sha \"\" (not leaked from the wrong file fixture); got rc=${rc39}, output:"
  echo "${out39}" | sed 's/^/      /'
  [[ -f "${JSON39}" ]] && echo "      json: $(cat "${JSON39}")"
fi

# ---------------------------------------------------------------------------
# Scenario 40 — H-AUDIT-REWORK-COUNT-COMPOSITION-UNPINNED: carries the
# H-AUDIT-SHA-FILE-LEAK guard (scenario 39) forward through write_audit.sh's
# consecutive_rework_count composition, instead of stopping at the "sha"
# field. Scenario 39 proves a single PR-mode call with no "Reviewed SHA:"
# line in $BODIES does not leak a companion dev/reviews/ file's foreign sha.
# It never checks what that empty sha then does to the streak. This scenario
# runs THREE consecutive PR-mode NEEDS_REWORK calls (same feature, branch,
# date), each with no "Reviewed SHA:" line and the same companion
# dev/reviews/<feature>.md present, and asserts the resulting
# consecutive_rework_count end to end.
#
# The honest expectation is NOT that the streak reaches 3. An empty --sha on
# both sides of write_audit.sh's identity check (the docstring's "identity
# key" paragraph, ~write_audit.sh's "The optional --sha ... is the identity
# key" comment) falls into the documented degrade-to-overwrite path SAME-DATE:
# OUTPUT_FILE is "${DATE}-${BRANCH_SAFE}-${FEATURE}.json", so all three calls
# in this scenario (same DATE40) compute the SAME $OUTPUT_FILE, no
# preserved-aside copy is ever made (mirrors scenario 7f, which pins this for
# a direct write_audit.sh caller), and the consecutive_rework_count scan
# explicitly excludes the file it is about to overwrite ("Skip the file we
# are about to write" in write_audit.sh) -- so each call's immediate
# predecessor is invisible to the scan by construction. The correct, pinned
# result is that the streak stays at 1 on every one of the three calls, even
# though all three really are consecutive NEEDS_REWORK reviews of the same
# branch. This is H-AUDIT-REWORK-COUNT-BLIND's pre-existing empty-SHA gap
# (H-AUDIT-REWORK-COUNT-BLIND's own docstring, "a deliberate, documented
# gap rather than a guess"), now pinned at the consumer field
# (consecutive_rework_count) instead of only at the producer field (sha).
#
# Scope: this cap is a property of same (date, branch, feature) -- because
# OUTPUT_FILE embeds DATE, a different DATE produces a different
# $OUTPUT_FILE and the same three calls spread across successive days DO
# accumulate (1 -> 2 -> 3 -> 4), which is exactly what lets #2339's `>= 3`
# escalation fire on the third consecutive day. This scenario pins only the
# same-day cell; the cross-day accumulation is pinned separately below
# (scenario 41).
# ---------------------------------------------------------------------------
FEATURE40="rework-count-composition-no-sha"
BRANCH40="feat/composition-no-sha"
DATE40="2026-08-17"

# Companion file-mode review file, left over from an unrelated run, holding
# a deliberately foreign sha + a NEEDS_REWORK verdict of its own. Present
# throughout all three calls below. Must never be consulted for sha (PR mode,
# per H-AUDIT-SHA-FILE-LEAK) or for verdicts (PR mode always resolves
# structural_qc for real, per the FILE_MODE guard).
cat > "${TMP_REPO}/dev/reviews/${FEATURE40}.md" <<'EOF'
Reviewed SHA: FOREIGNSHA40

## Verdict
APPROVED

## Quality Score
5 — this file belongs to a different run and must NOT be used
EOF

_scenario40_call() {
  # $1 = subdirectory name, $2 = PR number
  local dir="${TMP_REPO}/$1" pr="$2"
  mkdir -p "${dir}"
  cat > "${dir}/reviews.txt" <<EOF
STATE:CHANGES_REQUESTED

## Structural QC — ${FEATURE40}

## Verdict
NEEDS_REWORK
EOF
  echo "ENDBODY" >> "${dir}/reviews.txt"
  make_gh_mock "${dir}" "${dir}/reviews.txt"
  REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${dir}/gh" \
    bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
    "${FEATURE40}" "${BRANCH40}" "${DATE40}" --pr-number "${pr}" 2>&1
}

out40_1=$(_scenario40_call "s40a" 3009) && rc40_1=0 || rc40_1=$?
out40_2=$(_scenario40_call "s40b" 3010) && rc40_2=0 || rc40_2=$?
out40_3=$(_scenario40_call "s40c" 3011) && rc40_3=0 || rc40_3=$?

JSON40="${TMP_REPO}/dev/audit/${DATE40}-feat-composition-no-sha-${FEATURE40}.json"
audit_count_40="$(_glob_count "${TMP_REPO}/dev/audit" "${DATE40}-*-${FEATURE40}.json")"

if (( rc40_1 == 0 )) && (( rc40_2 == 0 )) && (( rc40_3 == 0 )) \
   && [[ -f "${JSON40}" ]] \
   && [[ "${audit_count_40}" == "1" ]] \
   && grep -q '"sha": *""' "${JSON40}" \
   && grep -q '"overall_qc": *"NEEDS_REWORK"' "${JSON40}" \
   && grep -q '"consecutive_rework_count": *1,' "${JSON40}" \
   && echo "${out40_3}" | grep -q 'consecutive_rework_count=1'; then
  pass "scenario 40 — 3 consecutive PR-mode NEEDS_REWORK calls with no Reviewed SHA line: sha stays empty AND consecutive_rework_count stays 1 (not 3) end to end, no preserved-aside file (H-AUDIT-REWORK-COUNT-COMPOSITION-UNPINNED, empty-sha degrade-to-overwrite path)"
else
  fail "scenario 40 — expected rc=0/0/0 + exactly 1 audit file + sha \"\" + overall NEEDS_REWORK + consecutive_rework_count=1; got rc=${rc40_1}/${rc40_2}/${rc40_3}, audit_count=${audit_count_40}"
  echo "${out40_1}" | sed 's/^/      /'
  echo "${out40_2}" | sed 's/^/      /'
  echo "${out40_3}" | sed 's/^/      /'
  [[ -f "${JSON40}" ]] && echo "      json: $(cat "${JSON40}")"
fi

# ---------------------------------------------------------------------------
# Scenario 41 — H-AUDIT-REWORK-COUNT-COMPOSITION-UNPINNED (cross-date half):
# mechanically pins the other half of scenario 40's scope note. Scenario 40
# pins that the empty-sha degrade-to-overwrite cap holds WITHIN a single
# date. This scenario pins that the cap does NOT hold ACROSS dates for the
# same branch+feature -- because OUTPUT_FILE embeds DATE
# ("${DATE}-${BRANCH_SAFE}-${FEATURE}.json"), two calls on two different
# dates produce two distinct files, both visible to the
# consecutive_rework_count scan (which globs "*-${FEATURE}.json" across all
# dates, not just the current one -- see write_audit.sh's "Look at prior
# audit records for this feature" scan). Two consecutive PR-mode
# NEEDS_REWORK calls on successive dates, same branch, no Reviewed SHA line,
# must therefore accumulate 1 -> 2, not stay pinned at 1. This is the
# reachable half of #2339's `>= 3` escalation through the empty-sha path
# (H-REWORK-STREAK-ESCALATION-UNTESTED): it fires on the third consecutive
# DAY, not the third consecutive call within a day.
# ---------------------------------------------------------------------------
FEATURE41="rework-count-composition-cross-date"
BRANCH41="feat/composition-cross-date"
DATE41A="2026-08-17"
DATE41B="2026-08-18"

_scenario41_call() {
  # $1 = subdirectory name, $2 = PR number, $3 = date
  local dir="${TMP_REPO}/$1" pr="$2" date="$3"
  mkdir -p "${dir}"
  cat > "${dir}/reviews.txt" <<EOF
STATE:CHANGES_REQUESTED

## Structural QC — ${FEATURE41}

## Verdict
NEEDS_REWORK
EOF
  echo "ENDBODY" >> "${dir}/reviews.txt"
  make_gh_mock "${dir}" "${dir}/reviews.txt"
  REPO_ROOT="${TMP_REPO}" RECORD_QC_AUDIT_GH_BIN="${dir}/gh" \
    bash "${TMP_REPO}/trading/devtools/checks/record_qc_audit.sh" \
    "${FEATURE41}" "${BRANCH41}" "${date}" --pr-number "${pr}" 2>&1
}

out41_1=$(_scenario41_call "s41a" 3012 "${DATE41A}") && rc41_1=0 || rc41_1=$?
out41_2=$(_scenario41_call "s41b" 3013 "${DATE41B}") && rc41_2=0 || rc41_2=$?

JSON41A="${TMP_REPO}/dev/audit/${DATE41A}-feat-composition-cross-date-${FEATURE41}.json"
JSON41B="${TMP_REPO}/dev/audit/${DATE41B}-feat-composition-cross-date-${FEATURE41}.json"

if (( rc41_1 == 0 )) && (( rc41_2 == 0 )) \
   && [[ -f "${JSON41A}" ]] && [[ -f "${JSON41B}" ]] \
   && grep -q '"consecutive_rework_count": *1,' "${JSON41A}" \
   && grep -q '"consecutive_rework_count": *2,' "${JSON41B}" \
   && echo "${out41_2}" | grep -q 'consecutive_rework_count=2'; then
  pass "scenario 41 — 2 consecutive PR-mode NEEDS_REWORK calls on successive dates, same branch, no Reviewed SHA line: consecutive_rework_count ACCUMULATES 1 -> 2 across dates (H-AUDIT-REWORK-COUNT-COMPOSITION-UNPINNED, cross-date half)"
else
  fail "scenario 41 — expected rc=0/0 + day A consecutive_rework_count=1 + day B consecutive_rework_count=2; got rc=${rc41_1}/${rc41_2}"
  echo "${out41_1}" | sed 's/^/      /'
  echo "${out41_2}" | sed 's/^/      /'
  [[ -f "${JSON41A}" ]] && echo "      json A: $(cat "${JSON41A}")"
  [[ -f "${JSON41B}" ]] && echo "      json B: $(cat "${JSON41B}")"
fi

# ---------------------------------------------------------------------------
# Scenario 42 — _glob_count guard pin, DIRECT invocation
# (H-AUDIT-GLOB-COUNT-GUARD-UNPINNED)
#
# Every real call site in this suite is shaped `x="$(_glob_count ...)"`.
# That command substitution runs the helper's body in a subshell where
# `errexit` is inactive (`shopt inherit_errexit` is off), so a pin written
# in that call shape passes whether or not `_glob_count` still guards its
# internal pipeline (2>/dev/null + `|| true`) -- mutation M-A (stripping
# the guard) is invisible to scenarios 1-41 and leaves this suite green.
#
# The one call shape that DOES exercise the guard is a DIRECT, top-level
# invocation (no `$( )` wrapper) against a missing directory: `errexit` is
# active in the caller's frame there, so an unguarded internal pipeline
# failure (pipefail-propagated from `find` on a missing dir) aborts the
# call instead of returning "0". We extract the function's CURRENT body
# via `declare -f` (rather than duplicating its source here) so this pin
# tracks whatever `_glob_count` actually does, not a copy that can drift.
# ---------------------------------------------------------------------------
GLOB_COUNT_DEF="$(declare -f _glob_count)"
SCENARIO42_MISSING_DIR="${TMP_REPO}/dev/audit/nonexistent-dir-42"
SCENARIO42_SCRIPT="${TMP_REPO}/scenario42_direct_call.sh"
cat > "${SCENARIO42_SCRIPT}" <<EOF
set -euo pipefail
${GLOB_COUNT_DEF}
_glob_count "${SCENARIO42_MISSING_DIR}" "*.json"
EOF
out42="$(bash "${SCENARIO42_SCRIPT}" 2>&1)" && rc42=0 || rc42=$?

if [[ "${rc42}" -eq 0 ]] && [[ "${out42}" == "0" ]]; then
  pass "scenario 42 — _glob_count called DIRECTLY (not via command substitution) against a nonexistent directory prints a clean 0 and does not abort (H-AUDIT-GLOB-COUNT-GUARD-UNPINNED)"
else
  fail "scenario 42 — expected direct _glob_count call against a missing dir to print '0' and exit 0; got rc=${rc42} output=${out42}"
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
