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
if (( rc == 0 )) && [[ -f "${TMP_REPO}/dev/audit/2026-05-25-${FEATURE1}.json" ]] \
   && grep -q '"structural_qc": *"APPROVED"' "${TMP_REPO}/dev/audit/2026-05-25-${FEATURE1}.json" \
   && grep -q '"behavioral_qc": *"APPROVED"' "${TMP_REPO}/dev/audit/2026-05-25-${FEATURE1}.json" \
   && grep -q '"quality_score": *4' "${TMP_REPO}/dev/audit/2026-05-25-${FEATURE1}.json"; then
  pass "scenario 1 — file-mode regression: APPROVED+APPROVED+score 4 extracted"
else
  fail "scenario 1 — file-mode regression: expected APPROVED+APPROVED+4; got rc=${rc}, output:"
  echo "${out}" | sed 's/^/      /'
  [[ -f "${TMP_REPO}/dev/audit/2026-05-25-${FEATURE1}.json" ]] && \
    echo "      json: $(cat "${TMP_REPO}/dev/audit/2026-05-25-${FEATURE1}.json")"
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
JSON2="${TMP_REPO}/dev/audit/2026-05-25-${FEATURE2}.json"
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
JSON3="${TMP_REPO}/dev/audit/2026-05-25-${FEATURE3}.json"
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
JSON5="${TMP_REPO}/dev/audit/2026-05-25-${FEATURE5}.json"
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
JSON6="${TMP_REPO}/dev/audit/2026-05-25-${FEATURE6}.json"
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
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "record_qc_audit_test: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
if (( FAIL_COUNT > 0 )); then
  exit 1
fi
exit 0
