#!/bin/sh
# Structural + functional smoke test for the deep-scan Linter Exception
# Expiry section (sub-item 3 of "Deep scan heuristic gaps" in
# dev/status/harness.md).
#
# Does NOT invoke deep_scan.sh from dune runtest because:
#   - deep_scan.sh runs weekly (not on every PR) and writes outside the
#     dune sandbox (dev/health/).
#
# Instead, this verifies four things:
#   1. deep_scan.sh contains the required Check 11 implementation markers
#      (the ## Linter Exception Expiry detection logic and section emission,
#      for all THREE scanned conf files — see BQ-1 below).
#   2. The most-recent dev/health/*-deep.md report contains a
#      ## Linter Exception Expiry section, confirming the script has been
#      run at least once successfully.
#   3. FUNCTIONALLY, not just structurally: check_11_linter_expiry.sh
#      actually surfaces an expired adapter_effectiveness_exceptions.conf
#      entry, and a mutated copy with the scan call removed does NOT —
#      i.e. this test goes RED if a future edit silently drops the third
#      conf file from the scan (BQ-1, PR #2585 rework iteration 1).
#   4. The ROLL-UP "W:" findings line (the mechanism deep_scan/main.sh
#      uses to build the top-level "## Warnings" section), not just the
#      per-file "[EXPIRED]" detail line Part 3 already pins — see R-5
#      below.
#
# BQ-1 (2026-08-28, dev/reviews/harness-2567-2585.md): PR #2585 added
# adapter_effectiveness_exceptions.conf with mandatory "# review_at:"
# annotations, and its plan claimed expiry was "checked by the existing
# deep_scan_linter_expiry_check.sh machinery pattern" — but check_11's
# _scan_exceptions_conf() was only ever called for linter_exceptions.conf
# and universe_deps_exceptions.conf. 8 of 14 grandfathered fields carried
# decorative review_at dates that nothing enforced. This test's Part 3 is
# the mutation-proof that the wiring (added in this rework) is load-bearing,
# not just present.
#
# R-5 (2026-08-28, dev/reviews/harness-2567-2585.md, #2585 qc-behavioral
# re-review): Part 3 only ever grepped the REPORT_FILE for the per-file
# "[EXPIRED] ... fixture_expired_field" detail line, which
# _scan_exceptions_conf() builds directly into _SCAN_DETAILS regardless of
# whether add_warning() is called. Deleting the add_warning() call in the
# date branch of _scan_exceptions_conf() (trading/devtools/checks/deep_scan/
# check_11_linter_expiry.sh, the line matching 'add_warning.*has passed')
# leaves that detail line, and therefore the whole Part 1-3 suite, green —
# while the roll-up "W:" findings line that deep_scan/main.sh's "##
# Warnings" section is built from silently disappears, identically for all
# three conf files (the function is shared). Part 4 below runs check_11
# with a FINDINGS_FILE argument (main.sh's real calling convention, which
# Part 3 does not use) and pins the "W: ...fixture_expired_field..." line
# itself, then proves that assertion is load-bearing with two independent
# mutations: removing the add_warning() call (3d) and corrupting its
# message content while leaving the call in place (3e).
#
# How to re-verify the output by hand:
#   sh trading/devtools/checks/deep_scan.sh
#   grep '## Linter Exception Expiry' dev/health/$(date +%Y-%m-%d)-deep.md
#   grep '## Warnings' dev/health/$(date +%Y-%m-%d)-deep.md

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
DEEP_SCAN_DIR="${REPO_ROOT}/trading/devtools/checks/deep_scan"
CHECK_11="${DEEP_SCAN_DIR}/check_11_linter_expiry.sh"
[ -f "$CHECK_11" ] || die "deep_scan_linter_expiry_check: $CHECK_11 does not exist"

fail() {
  echo "FAIL: deep_scan_linter_expiry_check — $1" >&2
  exit 1
}

# ── Part 1: structural check of check_11_linter_expiry.sh ────────

# Check 11 header
grep -qF 'Check 11: Linter Exception Expiry' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh missing 'Check 11: Linter Exception Expiry' header"

# Reads linter_exceptions.conf
grep -qF 'linter_exceptions.conf' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh does not reference linter_exceptions.conf"

# Reads universe_deps_exceptions.conf (#2148 FLAG-1 residual)
grep -qF 'universe_deps_exceptions.conf' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh does not reference universe_deps_exceptions.conf"

# Reads adapter_effectiveness_exceptions.conf (issue #2567 / BQ-1)
grep -qF 'adapter_effectiveness_exceptions.conf' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh does not reference adapter_effectiveness_exceptions.conf (BQ-1 regression: third exceptions file dropped from the expiry scan)"

# Detects review_at annotation
grep -qF 'review_at:' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh missing review_at detection logic"

# Accumulator variables for expiry tracking
grep -qF 'EXPIRY_COUNT' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh missing EXPIRY_COUNT accumulator"

grep -qF 'EXPIRY_MISSING_COUNT' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh missing EXPIRY_MISSING_COUNT accumulator (missing review_at tracking)"

# Adapter-effectiveness accumulator variables specifically (BQ-1: a
# structural-only check that just greps EXPIRY_COUNT would pass even if
# the AE_* wiring were removed, since UD_EXPIRY_COUNT also matches
# "EXPIRY_COUNT" as a substring — name the AE_ prefix explicitly).
grep -qF 'AE_EXPIRY_COUNT' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh missing AE_EXPIRY_COUNT accumulator (adapter-effectiveness expiry wiring, BQ-1)"

grep -qF 'AE_EXPIRY_MISSING_COUNT' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh missing AE_EXPIRY_MISSING_COUNT accumulator (adapter-effectiveness expiry wiring, BQ-1)"

# Report emits ## Linter Exception Expiry section
grep -qF '## Linter Exception Expiry' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh does not emit '## Linter Exception Expiry' section in report"

# Report emits ## Adapter-Effectiveness Exception Expiry section (BQ-1)
grep -qF '## Adapter-Effectiveness Exception Expiry' "$CHECK_11" \
  || fail "check_11_linter_expiry.sh does not emit '## Adapter-Effectiveness Exception Expiry' section in report (BQ-1)"

# ── Part 2: most-recent deep report has ## Linter Exception Expiry ──

HEALTH_DIR="${REPO_ROOT}/dev/health"
LATEST_DEEP=""
for f in $(ls -1 "${HEALTH_DIR}"/*-deep.md 2>/dev/null | sort); do
  LATEST_DEEP="$f"
done

if [ -z "$LATEST_DEEP" ]; then
  # No deep report exists yet — acceptable if deep_scan.sh has never run.
  echo "INFO: no dev/health/*-deep.md found; skipping report content check."
else
  grep -qF '## Linter Exception Expiry' "$LATEST_DEEP" \
    || fail "$(basename "$LATEST_DEEP") does not contain '## Linter Exception Expiry' section — run: sh trading/devtools/checks/deep_scan.sh"
fi

# ── Part 3: functional mutation-proof (BQ-1) ──────────────────────
#
# Parts 1-2 are purely structural (grep for markers in source / in the
# most recent report). Neither would have caught BQ-1: the AE_* strings
# and the report section header can all be textually present while the
# _scan_exceptions_conf() call that actually populates them is missing
# or dead — exactly the shape the original PR shipped (mandatory
# review_at annotations that nothing ever read back). This block proves
# the wiring is load-bearing by RUNNING check_11_linter_expiry.sh against
# a synthetic fixture tree (REPO_ROOT override, same pattern
# adapter_effectiveness_check_test.sh uses) with a known-expired entry,
# then RUNNING A MUTATED COPY with the adapter-effectiveness scan call
# removed and confirming the finding disappears.

AE_FAKE_ROOT="$(mktemp -d)"
trap 'rm -rf "$AE_FAKE_ROOT"' EXIT

mkdir -p "$AE_FAKE_ROOT/.claude"
mkdir -p "$AE_FAKE_ROOT/trading/devtools/checks/deep_scan"

# Empty-but-present sibling conf files so their own _scan_exceptions_conf
# calls report "no expired/missing" cleanly rather than "not found" noise.
: > "$AE_FAKE_ROOT/trading/devtools/checks/linter_exceptions.conf"
: > "$AE_FAKE_ROOT/trading/devtools/checks/universe_deps_exceptions.conf"

# One entry, seven years expired — the exact BQ-1 repro (match_fraction
# with review_at: 2019-01-01, per dev/reviews/harness-2567-2585.md).
cat > "$AE_FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf" <<'EOF'
fixture_expired_field  # review_at: 2019-01-01 (BQ-1 fixture)
EOF

# _lib.sh (sourced by check_11) reaches back to _check_lib.sh via
# "$(dirname "$0")/../_check_lib.sh" — mirror that relative layout.
cp "${DEEP_SCAN_DIR}/_lib.sh" "$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/_lib.sh"
cp "$(dirname "$0")/_check_lib.sh" "$AE_FAKE_ROOT/trading/devtools/checks/_check_lib.sh"
cp "$CHECK_11" "$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh"

# --- 3a: the REAL (unmutated) script surfaces the expired entry ---
AE_REPORT1="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh" "$AE_REPORT1" >/dev/null 2>&1
AE_CODE1=$?
set -e

if [ "$AE_CODE1" -eq 0 ] \
  && grep -q '\[EXPIRED\].*fixture_expired_field' "$AE_REPORT1"; then
  echo "OK: expired adapter_effectiveness_exceptions.conf entry is surfaced by check_11_linter_expiry.sh (BQ-1 fix verified)"
else
  fail "expired fixture_expired_field entry was NOT surfaced (exit=$AE_CODE1) — the adapter-effectiveness scan is not wired, or is broken: $(cat "$AE_REPORT1")"
fi

# --- 3b: MUTATION — remove the _scan_exceptions_conf call for
# adapter_effectiveness_exceptions.conf from a working copy of the real
# script. If the wiring is what's finding the entry (not some other
# coincidental match), the finding must disappear.
#
# The mutated copy MUST live in the SAME directory as the fixture
# _lib.sh: when `sh <script>` runs, `$0` is the invoked path, and
# check_11 sources its sibling via "$(dirname "$0")/_lib.sh" — a
# separate tmpdir would make that source fail rather than exercise the
# mutation.
AE_MUT_CHECK="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated.sh"
sed '/_scan_exceptions_conf "\${TRADING_DIR}\/devtools\/checks\/adapter_effectiveness_exceptions\.conf"/d' \
  "$CHECK_11" > "$AE_MUT_CHECK"
chmod +x "$AE_MUT_CHECK"

AE_REPORT2="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_MUT_CHECK" "$AE_REPORT2" >/dev/null 2>&1
AE_CODE2=$?
set -e

if ! grep -q '\[EXPIRED\].*fixture_expired_field' "$AE_REPORT2"; then
  echo "OK: MUTATION (adapter-effectiveness _scan_exceptions_conf call removed) makes the expired-entry finding disappear — proves the wiring, not a coincidence, produced 3a's finding (BQ-1 mutation-proof)"
else
  fail "MUTATION removed the adapter-effectiveness scan call but fixture_expired_field is STILL reported as expired — the mutation didn't take, or something else is finding it; this test does not actually pin the wiring"
fi

# ── Part 4: the ROLL-UP "W:" findings line, not just the per-file detail
# line (R-5, 2026-08-28, dev/reviews/harness-2567-2585.md) ─────────────
#
# 3a/3b run check_11_linter_expiry.sh with only a REPORT_FILE argument, so
# _lib.sh's flush_findings() takes its "standalone" branch and never
# exercises the "W: <message>" line format that deep_scan/main.sh's real
# calling convention (REPORT_FILE + FINDINGS_FILE) depends on to build the
# top-level "## Warnings" section. _SCAN_DETAILS (the per-file [EXPIRED]
# line 3a/3b check) is populated independently of add_warning() inside
# _scan_exceptions_conf() -- so deleting the add_warning() call in the
# date branch leaves 3a/3b, and the rest of this suite, fully green while
# silently dropping the roll-up for all three conf files (the function is
# shared). Part 4 closes that gap.

# --- 3c: the REAL (unmutated) script populates the roll-up "W:" line in
# the findings file when invoked with main.sh's real calling convention.
AE_REPORT3="$(mktemp)"
AE_FINDINGS3="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh" \
  "$AE_REPORT3" "$AE_FINDINGS3" >/dev/null 2>&1
AE_CODE3=$?
set -e

if [ "$AE_CODE3" -eq 0 ] \
  && grep -q '^W: .*fixture_expired_field.*has passed' "$AE_FINDINGS3"; then
  echo "OK: expired adapter_effectiveness_exceptions.conf entry is surfaced in the roll-up W: findings line, not just the per-file detail line (R-5 fix verified)"
else
  fail "expired fixture_expired_field entry was NOT surfaced in the roll-up W: findings line (exit=$AE_CODE3) — the per-file detail may be pinned but the top-level ## Warnings roll-up is not: $(cat "$AE_FINDINGS3")"
fi

# --- 3d: MUTATION C (call removed) — delete the add_warning() call in the
# date branch of _scan_exceptions_conf(), leaving the _SCAN_DETAILS
# construction (and therefore the report's [EXPIRED] line) untouched. This
# is the EXACT R-5 repro: before Part 4 existed, this mutation left the
# whole suite green.
AE_MUT_CHECK2="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated2.sh"
sed '/add_warning.*has passed/d' "$CHECK_11" > "$AE_MUT_CHECK2"
chmod +x "$AE_MUT_CHECK2"

AE_REPORT4="$(mktemp)"
AE_FINDINGS4="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_MUT_CHECK2" "$AE_REPORT4" "$AE_FINDINGS4" >/dev/null 2>&1
set -e

if grep -q '\[EXPIRED\].*fixture_expired_field' "$AE_REPORT4" \
  && ! grep -q '^W: .*fixture_expired_field' "$AE_FINDINGS4"; then
  echo "OK: MUTATION C (add_warning call removed from the date branch) leaves the per-file [EXPIRED] detail line intact but drops the roll-up W: line — proves 3c actually pins the roll-up wiring rather than re-checking what 3a/3b already cover"
else
  fail "MUTATION C did not produce the expected split — detail report: $(cat "$AE_REPORT4"); findings: $(cat "$AE_FINDINGS4")"
fi

# --- 3e: MUTATION D (content corrupted, call left in place) — a SECOND,
# independent break direction: keep the add_warning() call but strip the
# field name from its message, so a roll-up line still exists but no
# longer names the expired field. Confirms 3c's grep checks content, not
# merely "a W: line exists."
AE_MUT_CHECK3="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated3.sh"
sed 's/add_warning "\${label}: \${decl} review date/add_warning "\${label}: (redacted) review date/' \
  "$CHECK_11" > "$AE_MUT_CHECK3"
chmod +x "$AE_MUT_CHECK3"

AE_REPORT5="$(mktemp)"
AE_FINDINGS5="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_MUT_CHECK3" "$AE_REPORT5" "$AE_FINDINGS5" >/dev/null 2>&1
set -e

if grep -q '\[EXPIRED\].*fixture_expired_field' "$AE_REPORT5" \
  && ! grep -q '^W: .*fixture_expired_field' "$AE_FINDINGS5"; then
  echo "OK: MUTATION D (roll-up message content corrupted, call left in place) leaves the detail line intact but the W: line no longer names fixture_expired_field — second, independent break direction caught"
else
  fail "MUTATION D did not produce the expected split — detail report: $(cat "$AE_REPORT5"); findings: $(cat "$AE_FINDINGS5")"
fi

echo "OK: deep scan Linter Exception Expiry section (T1-K) structural + functional check passed."
