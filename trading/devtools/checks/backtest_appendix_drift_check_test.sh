#!/bin/sh
# Fixture-driven self-test for backtest_appendix_drift_check.sh.
#
# Builds synthetic repo trees under mktemp (pointed at via the REPO_ROOT
# override that _check_lib.sh's repo_root() already honors) so this test
# never depends on the real repo's current appendix content or backtest/
# subdirectory list — it pins the LOGIC, not a snapshot of today's state.
#
# Nine scenarios:
#   1. clean:              every on-disk subdir has a row             -> OK
#   2. missing-row:        one subdir has no row                      -> FAIL, names it
#   3. no-heading:         plan file exists, appendix heading absent   -> FAIL (guard 1)
#   4. no-rows:            heading present, zero parseable rows       -> FAIL (guard 2)
#   5. empty-backtest-dir: backtest dir exists but is empty            -> FAIL (guard 3)
#   6. exclusions:         lib/test/scenarios present with NO rows,
#                          everything else covered                    -> OK (proves the
#                          hardcoded exclusion list actually excludes)
#   7. section-scoped:     a subdir's row lives under a LATER "## "
#                          section (not the appendix), plus a real
#                          appendix row for a different subdir         -> FAIL, names
#                          the smuggled subdir (pins that the appendix
#                          extraction stops at the next "## " heading,
#                          not at EOF -- see PR #2494 rework)
#   8. outside-appendix:   a subdir is mentioned in prose AND has a
#                          row in a table BEFORE the appendix heading,
#                          but has no row in the appendix itself       -> FAIL, names it
#                          (pins the check's headline differentiating
#                          claim over check_02's loose whole-doc grep)
#   9. exclusion-not-broad: subdirs whose names merely CONTAIN an
#                          excluded name as a substring (lib_extra,
#                          test_harness, scenarios_v2), with no rows   -> FAIL, names
#                          all three (pins that EXCLUDED_SUBDIRS
#                          matching is exact, not substring)
#
# Scenarios 3-5 serve as the mutation test for the three vacuous-pass
# guards: each fixture is exactly the input state that guard exists to catch
# (heading missing / table unparsed / directory listing empty). This was
# verified by hand before landing (guard commented out, script re-run
# against these same fixtures; see the harness dispatch report for the
# recorded before/after transcript) with the following actual outcome, not
# a uniform one: deleting guard 3 flips scenario 5 from "FAIL as expected"
# to a false OK (the true vacuous pass this whole suite exists to prevent).
# Deleting guard 1 or guard 2 does NOT produce a false OK -- scenarios 3/4
# still FAIL, because the normal diff logic (an empty appendix-rows set
# against non-empty on-disk dirs) is itself a natural backstop; only the
# FAIL *message* changes (from the guard's specific diagnostic to the
# generic "no row" list), not the exit code. Guards 1+2 are kept anyway for
# the clearer diagnostic and as defense-in-depth against the combined
# all-three-guards-removed case, which does still reproduce a genuine
# silent OK.

set -eu

. "$(dirname "$0")/_check_lib.sh"

CHECK="$(dirname "$0")/backtest_appendix_drift_check.sh"
[ -f "$CHECK" ] || die "backtest_appendix_drift_check_test: check script not found at $CHECK"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

FAILURES=0

# _make_fixture <name>
# Creates a fresh synthetic repo root under $TMPDIR_BASE/<name> with the
# minimal marker (.claude/) repo_root()'s walk-up looks for, plus an empty
# dev/plans/ dir and trading/trading/backtest/ dir. Echoes the path.
_make_fixture() {
  fixture_name="$1"
  root="${TMPDIR_BASE}/${fixture_name}"
  mkdir -p "${root}/.claude" "${root}/dev/plans" "${root}/trading/trading/backtest"
  echo "$root"
}

# _run_check <repo-root>
# Runs the check with REPO_ROOT overridden; prints "EXIT=<n>" then the
# combined stdout+stderr on the following lines so callers can grep both.
_run_check() {
  root="$1"
  set +e
  OUTPUT="$(REPO_ROOT="$root" sh "$CHECK" 2>&1)"
  CODE=$?
  set -e
  printf 'EXIT=%s\n%s' "$CODE" "$OUTPUT"
}

_assert_exit() {
  scenario="$1"
  expected="$2"
  result="$3"
  actual="$(printf '%s' "$result" | sed -n '1s/^EXIT=//p')"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: backtest_appendix_drift_check_test [$scenario] -- expected exit $expected, got $actual"
    echo "  output: $(printf '%s' "$result" | tail -n +2)"
    FAILURES=$((FAILURES + 1))
    return 1
  fi
  return 0
}

_assert_contains() {
  scenario="$1"
  needle="$2"
  result="$3"
  if ! printf '%s' "$result" | grep -qF "$needle"; then
    echo "FAIL: backtest_appendix_drift_check_test [$scenario] -- expected output to contain '$needle'"
    echo "  output: $(printf '%s' "$result" | tail -n +2)"
    FAILURES=$((FAILURES + 1))
    return 1
  fi
  return 0
}

APPENDIX_HEADER='## Appendix: `trading/trading/backtest/` subdirectory inventory'

# ---- Scenario 1: clean -- every subdir has a row ----

ROOT1="$(_make_fixture clean)"
mkdir -p "${ROOT1}/trading/trading/backtest/alpha" "${ROOT1}/trading/trading/backtest/beta"
cat > "${ROOT1}/dev/plans/backtest-scale-optimization-2026-04-17.md" << EOF
# Plan

${APPENDIX_HEADER}

| Subdir | What it does |
|---|---|
| \`alpha/\` | Does alpha things. |
| \`beta/\` | Does beta things. |
EOF

RESULT1="$(_run_check "$ROOT1")"
_assert_exit "clean" "0" "$RESULT1"
_assert_contains "clean" "OK: backtest_appendix_drift_check" "$RESULT1"

# ---- Scenario 2: missing-row -- 'beta' has no row ----

ROOT2="$(_make_fixture missing-row)"
mkdir -p "${ROOT2}/trading/trading/backtest/alpha" "${ROOT2}/trading/trading/backtest/beta"
cat > "${ROOT2}/dev/plans/backtest-scale-optimization-2026-04-17.md" << EOF
# Plan

${APPENDIX_HEADER}

| Subdir | What it does |
|---|---|
| \`alpha/\` | Does alpha things. |
EOF

RESULT2="$(_run_check "$ROOT2")"
_assert_exit "missing-row" "1" "$RESULT2"
_assert_contains "missing-row" "FAIL: backtest_appendix_drift_check" "$RESULT2"
_assert_contains "missing-row" "trading/trading/backtest/beta/" "$RESULT2"
# 'alpha' DOES have a row -- must not be reported as missing.
if printf '%s' "$RESULT2" | grep -q 'backtest/alpha/$'; then
  echo "FAIL: backtest_appendix_drift_check_test [missing-row] -- 'alpha' (which HAS a row) was wrongly reported as missing"
  FAILURES=$((FAILURES + 1))
fi

# ---- Scenario 3: no-heading -- plan file exists, no appendix heading ----

ROOT3="$(_make_fixture no-heading)"
mkdir -p "${ROOT3}/trading/trading/backtest/alpha"
cat > "${ROOT3}/dev/plans/backtest-scale-optimization-2026-04-17.md" << 'EOF'
# Plan

Some other content, no appendix section at all.
EOF

RESULT3="$(_run_check "$ROOT3")"
_assert_exit "no-heading" "1" "$RESULT3"
_assert_contains "no-heading" "appendix heading not found" "$RESULT3"

# ---- Scenario 4: no-rows -- heading present, no parseable rows ----

ROOT4="$(_make_fixture no-rows)"
mkdir -p "${ROOT4}/trading/trading/backtest/alpha"
cat > "${ROOT4}/dev/plans/backtest-scale-optimization-2026-04-17.md" << EOF
# Plan

${APPENDIX_HEADER}

(table intentionally omitted -- format changed)
EOF

RESULT4="$(_run_check "$ROOT4")"
_assert_exit "no-rows" "1" "$RESULT4"
_assert_contains "no-rows" "parsed ZERO table rows" "$RESULT4"

# ---- Scenario 5: empty-backtest-dir -- dir exists, nothing in it ----

ROOT5="$(_make_fixture empty-backtest-dir)"
cat > "${ROOT5}/dev/plans/backtest-scale-optimization-2026-04-17.md" << EOF
# Plan

${APPENDIX_HEADER}

| Subdir | What it does |
|---|---|
| \`alpha/\` | Does alpha things. |
EOF

RESULT5="$(_run_check "$ROOT5")"
_assert_exit "empty-backtest-dir" "1" "$RESULT5"
_assert_contains "empty-backtest-dir" "found ZERO subdirectories" "$RESULT5"

# ---- Scenario 6: exclusions -- lib/test/scenarios present, no rows for
# them, everything else covered -- must still be OK ----

ROOT6="$(_make_fixture exclusions)"
mkdir -p \
  "${ROOT6}/trading/trading/backtest/lib" \
  "${ROOT6}/trading/trading/backtest/test" \
  "${ROOT6}/trading/trading/backtest/scenarios" \
  "${ROOT6}/trading/trading/backtest/alpha"
cat > "${ROOT6}/dev/plans/backtest-scale-optimization-2026-04-17.md" << EOF
# Plan

${APPENDIX_HEADER}

| Subdir | What it does |
|---|---|
| \`alpha/\` | Does alpha things. |
EOF

RESULT6="$(_run_check "$ROOT6")"
_assert_exit "exclusions" "0" "$RESULT6"
_assert_contains "exclusions" "OK: backtest_appendix_drift_check" "$RESULT6"

# ---- Scenario 7: section-scoped -- a row for an on-disk subdir lives under
# a LATER "## " section, not the appendix itself. This must NOT be credited
# as an appendix row -- pins that appendix-row extraction stops at the next
# "## " heading rather than running to EOF (PR #2494 rework, finding B1).
# 'alpha' has a real appendix row; 'smuggled' has on-disk presence and a
# table row, but that row is under an unrelated later section.

ROOT7="$(_make_fixture section-scoped)"
mkdir -p \
  "${ROOT7}/trading/trading/backtest/alpha" \
  "${ROOT7}/trading/trading/backtest/smuggled"
cat > "${ROOT7}/dev/plans/backtest-scale-optimization-2026-04-17.md" << EOF
# Plan

${APPENDIX_HEADER}

| Subdir | What it does |
|---|---|
| \`alpha/\` | Does alpha things. |

## Appendix B: something else entirely

| Subdir | What it does |
|---|---|
| \`smuggled/\` | not the subdirectory inventory |
EOF

RESULT7="$(_run_check "$ROOT7")"
_assert_exit "section-scoped" "1" "$RESULT7"
_assert_contains "section-scoped" "FAIL: backtest_appendix_drift_check" "$RESULT7"
_assert_contains "section-scoped" "trading/trading/backtest/smuggled/" "$RESULT7"
if printf '%s' "$RESULT7" | grep -q 'backtest/alpha/$'; then
  echo "FAIL: backtest_appendix_drift_check_test [section-scoped] -- 'alpha' (which HAS a real appendix row) was wrongly reported as missing"
  FAILURES=$((FAILURES + 1))
fi

# ---- Scenario 8: outside-appendix -- a subdir is mentioned in prose AND
# has a row in a DIFFERENT table BEFORE the appendix heading, but has no row
# in the appendix itself. Neither a prose mention nor a pre-appendix table
# row may satisfy the check -- pins the script's headline differentiating
# claim over deep_scan/check_02's loose whole-doc substring grep (PR #2494
# rework, finding B2).

ROOT8="$(_make_fixture outside-appendix)"
mkdir -p \
  "${ROOT8}/trading/trading/backtest/alpha" \
  "${ROOT8}/trading/trading/backtest/ghostwritten"
cat > "${ROOT8}/dev/plans/backtest-scale-optimization-2026-04-17.md" << EOF
# Plan

Some prose here mentions \`ghostwritten/\` as a subdir we use.

## Some Other Table

| Subdir | What it does |
|---|---|
| \`ghostwritten/\` | wrong table, before the appendix |

${APPENDIX_HEADER}

| Subdir | What it does |
|---|---|
| \`alpha/\` | Does alpha things. |
EOF

RESULT8="$(_run_check "$ROOT8")"
_assert_exit "outside-appendix" "1" "$RESULT8"
_assert_contains "outside-appendix" "FAIL: backtest_appendix_drift_check" "$RESULT8"
_assert_contains "outside-appendix" "trading/trading/backtest/ghostwritten/" "$RESULT8"
if printf '%s' "$RESULT8" | grep -q 'backtest/alpha/$'; then
  echo "FAIL: backtest_appendix_drift_check_test [outside-appendix] -- 'alpha' (which HAS a real appendix row) was wrongly reported as missing"
  FAILURES=$((FAILURES + 1))
fi

# ---- Scenario 9: exclusion-not-broad -- subdirs whose names merely CONTAIN
# an excluded name as a substring (lib_extra, test_harness, scenarios_v2),
# with no appendix rows for them. All three must be reported -- pins that
# EXCLUDED_SUBDIRS matching is exact equality, not substring/prefix (PR
# #2494 rework, finding B5). A regression to substring matching would
# silently under-report these forever.

ROOT9="$(_make_fixture exclusion-not-broad)"
mkdir -p \
  "${ROOT9}/trading/trading/backtest/lib_extra" \
  "${ROOT9}/trading/trading/backtest/test_harness" \
  "${ROOT9}/trading/trading/backtest/scenarios_v2" \
  "${ROOT9}/trading/trading/backtest/alpha"
cat > "${ROOT9}/dev/plans/backtest-scale-optimization-2026-04-17.md" << EOF
# Plan

${APPENDIX_HEADER}

| Subdir | What it does |
|---|---|
| \`alpha/\` | Does alpha things. |
EOF

RESULT9="$(_run_check "$ROOT9")"
_assert_exit "exclusion-not-broad" "1" "$RESULT9"
_assert_contains "exclusion-not-broad" "trading/trading/backtest/lib_extra/" "$RESULT9"
_assert_contains "exclusion-not-broad" "trading/trading/backtest/test_harness/" "$RESULT9"
_assert_contains "exclusion-not-broad" "trading/trading/backtest/scenarios_v2/" "$RESULT9"

if [ "$FAILURES" -ne 0 ]; then
  echo "FAIL: backtest_appendix_drift_check_test -- ${FAILURES} scenario(s) failed"
  exit 1
fi

echo "OK: backtest_appendix_drift_check_test -- all 9 scenarios passed (clean, missing-row, no-heading, no-rows, empty-backtest-dir, exclusions, section-scoped, outside-appendix, exclusion-not-broad)."
