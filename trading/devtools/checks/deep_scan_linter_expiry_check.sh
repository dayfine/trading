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
# O2 (2026-08-28, qc-behavioral on PR #2589, attack E2,
# H-EXPIRY-ROLLUP-SHARED-FN-ASSUMED): Part 4 only ever populated the
# adapter_effectiveness_exceptions.conf fixture with an expired entry, so
# nothing distinguished "the roll-up is wired for all three conf files"
# from "the roll-up is wired for adapter-effectiveness specifically". A
# per-label special case inside the shared _scan_exceptions_conf() function
# (e.g. `case "${label}" in Adapter*) : ;; *) continue ;; esac` placed
# right before an add_warning() call) suppresses the roll-up for
# linter_exceptions.conf and universe_deps_exceptions.conf while the AE
# roll-up — and therefore the whole suite — stays green. Part 5 below adds
# an expired entry to linter_exceptions.conf too (the fixture already
# created it empty for Part 3/4's sibling-file noise suppression; it is no
# longer empty) and pins the "Linter exception expiry" roll-up line
# specifically, with its own mutation-proof of the exact evasion shape
# above.
#
# O3 (2026-08-28, qc-behavioral on PR #2589, observation O3,
# H-EXPIRY-ADDWARNING-SITES-UNPINNED): _scan_exceptions_conf() has FIVE
# add_warning() call sites total — conf-file-not-found, milestone-unknown
# (manual review), milestone-landed (expired), date-expired, and
# unrecognised-review_at-format — and before Part 6 below, only the
# date-expired site (the one Part 3/4 exercise) was pinned. Part 6 adds a
# fixture + assertion + mutation-proof for each of the other four sites.
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

# Present sibling conf files. Both now carry fixture entries of their own
# (O2/O3 below) rather than being left empty — each entry below is named
# distinctly from adapter_effectiveness_exceptions.conf's
# "fixture_expired_field" so grep patterns anchored to one fixture cannot
# accidentally match another's finding line.
#
# linter_exceptions.conf: one date-expired entry (O2 fixture — same shape
# as the AE entry below, used to pin the "Linter exception expiry" roll-up
# label specifically in Part 5).
cat > "$AE_FAKE_ROOT/trading/devtools/checks/linter_exceptions.conf" <<'EOF'
fixture_stale_le_entry  # review_at: 2019-01-01 (O2 fixture)
EOF

# universe_deps_exceptions.conf: two entries exercising the two
# add_warning() sites that don't need a parseable docs/design/
# weinstein-trading-system-v2.md (which this fake root does not create —
# CURRENT_MILESTONE_NUM stays 0 = unknown, matching production behaviour
# when the design doc's milestone marker can't be parsed):
#   - a milestone-pinned entry, surfaced via the "milestone unknown /
#     manual review" branch (O3, check_11_linter_expiry.sh:~161)
#   - an entry whose review_at is neither a milestone nor a date, surfaced
#     via the "unrecognised format" branch (O3, ~:184)
cat > "$AE_FAKE_ROOT/trading/devtools/checks/universe_deps_exceptions.conf" <<'EOF'
fixture_unknown_milestone_ud  # review_at: M2 (O3 milestone-unknown fixture)
fixture_unrecognised_format_ud  # review_at: whenever-someone-notices (O3 unrecognised fixture)
EOF

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

# ── Part 5: O2 closure — the roll-up is per-CONF-FILE wired, not just
# per-adapter-effectiveness (2026-08-28, qc-behavioral on PR #2589,
# attack E2, H-EXPIRY-ROLLUP-SHARED-FN-ASSUMED) ───────────────────────
#
# Parts 3/4 above only ever populate adapter_effectiveness_exceptions.conf
# with an expired entry, so nothing in the suite distinguishes "the roll-up
# is wired for all three conf files that share _scan_exceptions_conf()"
# from "the roll-up is wired for adapter-effectiveness specifically". A
# per-label special case inside the shared function — e.g.
# `case "${label}" in Adapter*) : ;; *) continue ;; esac` placed right
# before an add_warning() call — suppresses the roll-up for
# linter_exceptions.conf (and universe_deps_exceptions.conf) while the AE
# roll-up, and therefore the whole suite, stays green. This was confirmed
# by hand before writing 5a/5b below: applying that exact case guard
# before the date-branch add_warning() call in a working copy of the real
# script leaves the AE_FINDINGS3-style output at exit 0 with the AE line
# intact and the "Linter exception expiry" line for fixture_stale_le_entry
# gone — the silent evasion this part exists to close.

# --- 5a: the REAL (unmutated) script populates the roll-up "W:" line for
# the linter_exceptions.conf fixture entry too, not just AE's. Anchored on
# the label PLUS the fixture name plus the date-branch tail ("has passed")
# — not a bare "^W: Linter exception expiry:" check, which would also
# match the milestone-parse-warning line ("Design doc ... not found") that
# carries the same label prefix and is present in this fixture regardless
# of whether the date-branch roll-up fires. (Verified by hand: a
# label-only anchor wrongly matches under the 5b mutation below; the
# fixture-name-anchored form below correctly does not.)
if [ "$AE_CODE3" -eq 0 ] \
  && grep -q '^W: Linter exception expiry: fixture_stale_le_entry review date .* has passed' "$AE_FINDINGS3"; then
  echo "OK: expired linter_exceptions.conf entry is ALSO surfaced in the roll-up W: findings line, alongside adapter-effectiveness's (O2 fix verified — the roll-up is wired per conf file, not just for AE)"
else
  fail "expired fixture_stale_le_entry entry was NOT surfaced in the roll-up W: findings line (exit=$AE_CODE3) — either the roll-up wiring regressed for linter_exceptions.conf specifically, or a per-label special case is suppressing it: $(cat "$AE_FINDINGS3")"
fi

# --- 5b: MUTATION E (the exact O2 evasion shape) — insert a per-label
# case guard before the date-branch add_warning() call so only labels
# starting with "Adapter" reach it. If 5a is pinning real per-conf-file
# wiring (not a coincidental match), this must make the LE line disappear
# while the AE line — same branch, different label — survives untouched.
AE_MUT_CHECK4="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated4.sh"
awk '
  /add_warning "\$\{label\}: \$\{decl\} review date \$\{review_date\} has passed/ {
    print "        case \"${label}\" in Adapter*) : ;; *) continue ;; esac"
  }
  { print }
' "$CHECK_11" > "$AE_MUT_CHECK4"
chmod +x "$AE_MUT_CHECK4"

AE_REPORT6="$(mktemp)"
AE_FINDINGS6="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_MUT_CHECK4" "$AE_REPORT6" "$AE_FINDINGS6" >/dev/null 2>&1
AE_CODE6=$?
set -e

if [ "$AE_CODE6" -eq 0 ] \
  && grep -q '^W: Adapter-effectiveness exception expiry: fixture_expired_field' "$AE_FINDINGS6" \
  && ! grep -q '^W: Linter exception expiry: fixture_stale_le_entry' "$AE_FINDINGS6"; then
  echo "OK: MUTATION E (per-label case guard restricting add_warning to Adapter* labels) leaves the exit code at 0 and the AE roll-up intact but drops the linter_exceptions.conf roll-up — reproduces H-EXPIRY-ROLLUP-SHARED-FN-ASSUMED and proves 5a catches it"
else
  fail "MUTATION E did not produce the expected split (exit=$AE_CODE6) — findings: $(cat "$AE_FINDINGS6")"
fi

# ── Part 6: O3 closure — the four remaining add_warning() call sites
# (2026-08-28, qc-behavioral on PR #2589, observation O3,
# H-EXPIRY-ADDWARNING-SITES-UNPINNED) ─────────────────────────────────
#
# _scan_exceptions_conf() has FIVE add_warning() call sites. Before this
# part, only the date-expired site (Parts 3/4 above) was pinned:
#   :113  conf-file-not-found         -> Part 6, fixture 6e/6f below
#   :161  milestone-unknown           -> 6a/6b below (AE_FAKE_ROOT fixture)
#   :166  milestone-landed (expired)  -> 6c/6d below (separate fixture:
#                                        needs a parseable design doc,
#                                        which conflicts with :161's
#                                        "milestone unknown" precondition
#                                        in the same fixture root)
#   :176  date-expired                -> already pinned by Part 3/4
#   :184  unrecognised-review_at-format -> 6a/6b below (AE_FAKE_ROOT fixture)

# --- 6a: the REAL (unmutated) script surfaces both the milestone-unknown
# and unrecognised-format universe_deps_exceptions.conf fixture entries in
# the roll-up. Reuses AE_FINDINGS3 (Part 4's 3c run already exercised the
# full fixture, which now includes both entries).
if grep -q '^W: Universe-deps exception expiry (milestone unknown): fixture_unknown_milestone_ud pinned to M2' "$AE_FINDINGS3"; then
  echo "OK: milestone-pinned entry with an unresolvable current-milestone is surfaced via the 'milestone unknown / manual review' add_warning site (:~161)"
else
  fail "fixture_unknown_milestone_ud was NOT surfaced via the milestone-unknown add_warning site: $(cat "$AE_FINDINGS3")"
fi

if grep -q '^W: Universe-deps exception expiry: fixture_unrecognised_format_ud has unrecognised review_at format:' "$AE_FINDINGS3"; then
  echo "OK: an entry whose review_at is neither a milestone nor a date is surfaced via the 'unrecognised format' add_warning site (:~184)"
else
  fail "fixture_unrecognised_format_ud was NOT surfaced via the unrecognised-format add_warning site: $(cat "$AE_FINDINGS3")"
fi

# --- 6b: mutation-proof for both 6a sites — delete each add_warning() call
# independently and confirm its own line disappears while the sibling
# stays, proving each assertion pins its own site rather than the pair
# passing/failing together coincidentally.
AE_MUT_161="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_161.sh"
sed '/milestone unknown): ${decl} pinned to/d' "$CHECK_11" > "$AE_MUT_161"
chmod +x "$AE_MUT_161"
AE_FINDINGS_161="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_MUT_161" "$(mktemp)" "$AE_FINDINGS_161" >/dev/null 2>&1
set -e
if ! grep -q 'fixture_unknown_milestone_ud pinned to' "$AE_FINDINGS_161" \
  && grep -q 'fixture_unrecognised_format_ud has unrecognised' "$AE_FINDINGS_161"; then
  echo "OK: MUTATION (milestone-unknown add_warning call removed) drops only the milestone-unknown finding, confirming 6a's first assertion pins that site specifically"
else
  fail "MUTATION (milestone-unknown add_warning removed) did not produce the expected split: $(cat "$AE_FINDINGS_161")"
fi

AE_MUT_184="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_184.sh"
sed '/has unrecognised review_at format/d' "$CHECK_11" > "$AE_MUT_184"
chmod +x "$AE_MUT_184"
AE_FINDINGS_184="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_MUT_184" "$(mktemp)" "$AE_FINDINGS_184" >/dev/null 2>&1
set -e
if grep -q 'fixture_unknown_milestone_ud pinned to' "$AE_FINDINGS_184" \
  && ! grep -q 'fixture_unrecognised_format_ud has unrecognised' "$AE_FINDINGS_184"; then
  echo "OK: MUTATION (unrecognised-format add_warning call removed) drops only the unrecognised-format finding, confirming 6a's second assertion pins that site specifically"
else
  fail "MUTATION (unrecognised-format add_warning removed) did not produce the expected split: $(cat "$AE_FINDINGS_184")"
fi

# --- 6c/6d: milestone-landed (:166) needs its own fixture — a parseable
# "Current milestone" marker in a fake docs/design/weinstein-trading-system
# -v2.md, which would change AE_FAKE_ROOT's "milestone unknown" fixture
# (6a above) from unresolvable to resolvable if added there. Separate root.
MS_FAKE_ROOT="$(mktemp -d)"
trap 'rm -rf "$AE_FAKE_ROOT" "$MS_FAKE_ROOT"' EXIT

mkdir -p "$MS_FAKE_ROOT/trading/devtools/checks/deep_scan"
mkdir -p "$MS_FAKE_ROOT/docs/design"
cat > "$MS_FAKE_ROOT/docs/design/weinstein-trading-system-v2.md" <<'EOF'
# Weinstein Trading System v2

**Current milestone:** M3
EOF
: > "$MS_FAKE_ROOT/trading/devtools/checks/linter_exceptions.conf"
cat > "$MS_FAKE_ROOT/trading/devtools/checks/universe_deps_exceptions.conf" <<'EOF'
fixture_milestone_landed_ud  # review_at: M2 (O3 milestone-landed fixture)
EOF
: > "$MS_FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf"
cp "${DEEP_SCAN_DIR}/_lib.sh" "$MS_FAKE_ROOT/trading/devtools/checks/deep_scan/_lib.sh"
cp "$(dirname "$0")/_check_lib.sh" "$MS_FAKE_ROOT/trading/devtools/checks/_check_lib.sh"
cp "$CHECK_11" "$MS_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh"

MS_FINDINGS="$(mktemp)"
set +e
REPO_ROOT="$MS_FAKE_ROOT" sh "$MS_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh" \
  "$(mktemp)" "$MS_FINDINGS" >/dev/null 2>&1
MS_CODE=$?
set -e

if [ "$MS_CODE" -eq 0 ] \
  && grep -q '^W: Universe-deps exception expiry: fixture_milestone_landed_ud was due for review at M2 (current: M3)' "$MS_FINDINGS"; then
  echo "OK: an entry pinned to a milestone <= the current milestone is surfaced via the 'milestone landed / expired' add_warning site (:~166)"
else
  fail "fixture_milestone_landed_ud was NOT surfaced via the milestone-landed add_warning site (exit=$MS_CODE): $(cat "$MS_FINDINGS")"
fi

MS_MUT="$MS_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_166.sh"
sed '/was due for review at ${entry_milestone}/d' "$CHECK_11" > "$MS_MUT"
chmod +x "$MS_MUT"
MS_FINDINGS2="$(mktemp)"
set +e
REPO_ROOT="$MS_FAKE_ROOT" sh "$MS_MUT" "$(mktemp)" "$MS_FINDINGS2" >/dev/null 2>&1
set -e
if ! grep -q 'fixture_milestone_landed_ud was due for review' "$MS_FINDINGS2"; then
  echo "OK: MUTATION (milestone-landed add_warning call removed) makes the finding disappear, confirming 6c pins that site rather than some other coincidental match"
else
  fail "MUTATION (milestone-landed add_warning removed) did not remove the finding: $(cat "$MS_FINDINGS2")"
fi

# --- 6e/6f: conf-file-not-found (:113) needs a fixture that OMITS one of
# the three conf files entirely — incompatible with every fixture above,
# which all rely on the files existing (a missing file short-circuits
# _scan_exceptions_conf() via `return 0` before any entry is read, per
# check_11_linter_expiry.sh:112-115). Separate root, third fixture.
NF_FAKE_ROOT="$(mktemp -d)"
trap 'rm -rf "$AE_FAKE_ROOT" "$MS_FAKE_ROOT" "$NF_FAKE_ROOT"' EXIT

mkdir -p "$NF_FAKE_ROOT/trading/devtools/checks/deep_scan"
: > "$NF_FAKE_ROOT/trading/devtools/checks/linter_exceptions.conf"
: > "$NF_FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf"
# universe_deps_exceptions.conf is deliberately NOT created.
cp "${DEEP_SCAN_DIR}/_lib.sh" "$NF_FAKE_ROOT/trading/devtools/checks/deep_scan/_lib.sh"
cp "$(dirname "$0")/_check_lib.sh" "$NF_FAKE_ROOT/trading/devtools/checks/_check_lib.sh"
cp "$CHECK_11" "$NF_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh"

NF_FINDINGS="$(mktemp)"
set +e
REPO_ROOT="$NF_FAKE_ROOT" sh "$NF_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh" \
  "$(mktemp)" "$NF_FINDINGS" >/dev/null 2>&1
NF_CODE=$?
set -e

if [ "$NF_CODE" -eq 0 ] \
  && grep -q '^W: Universe-deps exception expiry: universe_deps_exceptions.conf not found — cannot check exception policy' "$NF_FINDINGS"; then
  echo "OK: a missing conf file is surfaced via the 'conf-file-not-found' add_warning site (:~113)"
else
  fail "a missing universe_deps_exceptions.conf was NOT surfaced via the conf-not-found add_warning site (exit=$NF_CODE): $(cat "$NF_FINDINGS")"
fi

NF_MUT="$NF_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_113.sh"
sed '/not found — cannot check exception policy/d' "$CHECK_11" > "$NF_MUT"
chmod +x "$NF_MUT"
NF_FINDINGS2="$(mktemp)"
set +e
REPO_ROOT="$NF_FAKE_ROOT" sh "$NF_MUT" "$(mktemp)" "$NF_FINDINGS2" >/dev/null 2>&1
set -e
if ! grep -q 'universe_deps_exceptions.conf not found' "$NF_FINDINGS2"; then
  echo "OK: MUTATION (conf-not-found add_warning call removed) makes the finding disappear, confirming 6e pins that site rather than some other coincidental match"
else
  fail "MUTATION (conf-not-found add_warning removed) did not remove the finding: $(cat "$NF_FINDINGS2")"
fi

echo "OK: deep scan Linter Exception Expiry section (T1-K) structural + functional check passed."
