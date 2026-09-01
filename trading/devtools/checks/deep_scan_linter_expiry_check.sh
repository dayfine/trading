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
# linter_exceptions.conf: a date-expired entry (O2 fixture — same shape
# as the AE entry below, used to pin the "Linter exception expiry" roll-up
# label specifically in Part 5), PLUS two more entries (O3-2,
# 2026-08-30, qc-behavioral rework on PR #2595) that hit the SAME
# milestone-unknown (:161) and unrecognised-format (:184) branches as
# universe_deps_exceptions.conf's fixtures below, under a DIFFERENT
# label ("Linter exception expiry" vs "Universe-deps exception expiry").
# Without a second conf file exercising these two branches, a per-label
# case guard restricted to `Universe-deps*` right before either
# add_warning() call would leave 6a/6b (below) fully green while
# silently dropping the finding for every other conf file — the exact
# residual qc-behavioral found on PR #2595 (all four Part-6 sites were
# only ever exercised via universe_deps_exceptions.conf fixtures).
cat > "$AE_FAKE_ROOT/trading/devtools/checks/linter_exceptions.conf" <<'EOF'
fixture_stale_le_entry  # review_at: 2019-01-01 (O2 fixture)
fixture_unknown_milestone_le  # review_at: M4 (O3-2 dual-conf-file fixture for :161)
fixture_unrecognised_format_le  # review_at: no-clue (O3-2 dual-conf-file fixture for :184)
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
#
# O3-2 (2026-08-30, qc-behavioral rework on PR #2595,
# H-EXPIRY-ADDWARNING-SITES-UNPINNED residual): O3 above closed each site
# against "delete the add_warning() call entirely", but every one of the
# four fixtures used only a SINGLE conf file's label (Universe-deps for
# :113/:161/:166/:184). A per-label case guard restricted to allow only
# `Universe-deps*` labels — the mirror image of Part 5's `Adapter*` guard
# — left the whole suite green at all four sites (confirmed by hand
# before writing 6a2/6b2/6d2/6f2 below: applying
# `case "${label}" in Universe-deps*) : ;; *) continue ;; esac` (or
# `return 0` for :113, which runs before the while loop) immediately
# before each site's add_warning() call reproduces exit 0 with the
# Universe-deps finding intact and every other conf file's finding at
# that site silently gone). 6a2/6d2/6f2 add a second, differently-labelled
# fixture entry hitting the SAME branch (reusing AE_FAKE_ROOT's
# linter_exceptions.conf above for :161/:184; MS_FAKE_ROOT's
# linter_exceptions.conf for :166; a second missing conf file in
# NF_FAKE_ROOT for :113), and 6b2/6d3/6f3 add the matching mutation-proof.
#
# O3-3 (2026-08-30, qc-behavioral rework iteration 2 on PR #2595): all of
# Part 6's mutation-proofs above delete the whole add_warning() call. A
# narrower corruption — deleting ONLY the _SCAN_COUNT increment at a site,
# leaving add_warning() and _SCAN_DETAILS intact — desyncs the roll-up
# "W:" line (still correct) from the REPORT_FILE's own per-entry detail
# line (silently dropped, because the report's print gate is the
# per-conf-file COUNT, not _SCAN_DETAILS non-emptiness). None of 6a-6f2
# would catch this since they only ever assert against the roll-up
# findings file, never REPORT_FILE, for these four sites. See Part 7 below.

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

# --- 6a2 (O3-2): the SAME two branches, exercised via a DIFFERENT conf
# file (linter_exceptions.conf) and label ("Linter exception expiry"),
# not just universe_deps_exceptions.conf. Without this, a per-label case
# guard restricted to `Universe-deps*` would leave 6a green while
# silently dropping the finding for every other conf file at these
# two sites.
if grep -q '^W: Linter exception expiry (milestone unknown): fixture_unknown_milestone_le pinned to M4' "$AE_FINDINGS3"; then
  echo "OK: the milestone-unknown add_warning site (:~161) also fires for a linter_exceptions.conf entry, not just universe_deps_exceptions.conf's (O3-2 dual-conf-file fix)"
else
  fail "fixture_unknown_milestone_le was NOT surfaced via the milestone-unknown add_warning site: $(cat "$AE_FINDINGS3")"
fi

if grep -q '^W: Linter exception expiry: fixture_unrecognised_format_le has unrecognised review_at format:' "$AE_FINDINGS3"; then
  echo "OK: the unrecognised-format add_warning site (:~184) also fires for a linter_exceptions.conf entry, not just universe_deps_exceptions.conf's (O3-2 dual-conf-file fix)"
else
  fail "fixture_unrecognised_format_le was NOT surfaced via the unrecognised-format add_warning site: $(cat "$AE_FINDINGS3")"
fi

# --- 6b2 (O3-2): mutation-proof for the exact H-EXPIRY-ADDWARNING-SITES
# residual — a per-label case guard restricted to `Universe-deps*`,
# placed right before each site's add_warning() call, must make the
# linter_exceptions.conf-labelled line disappear while the
# universe_deps_exceptions.conf-labelled line (same branch, different
# label) survives untouched. Confirmed by hand before writing this
# assertion: without the case guard, both lines are present; with it,
# only the Universe-deps line remains and the process still exits 0.
AE_MUT_161_UD_GUARD="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_161_udguard.sh"
awk '
  /add_warning "\$\{label\} \(milestone unknown\)/ {
    print "        case \"${label}\" in Universe-deps*) : ;; *) continue ;; esac"
  }
  { print }
' "$CHECK_11" > "$AE_MUT_161_UD_GUARD"
chmod +x "$AE_MUT_161_UD_GUARD"

AE_FINDINGS_161_UD_GUARD="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_MUT_161_UD_GUARD" "$(mktemp)" "$AE_FINDINGS_161_UD_GUARD" >/dev/null 2>&1
AE_CODE_161_UD_GUARD=$?
set -e

if [ "$AE_CODE_161_UD_GUARD" -eq 0 ] \
  && grep -q '^W: Universe-deps exception expiry (milestone unknown): fixture_unknown_milestone_ud pinned to M2' "$AE_FINDINGS_161_UD_GUARD" \
  && ! grep -q 'fixture_unknown_milestone_le pinned to' "$AE_FINDINGS_161_UD_GUARD"; then
  echo "OK: MUTATION (per-label case guard restricting :161's add_warning to Universe-deps* labels) leaves exit 0 and the Universe-deps finding intact but drops the linter_exceptions.conf finding — reproduces the PR #2595 residual and proves 6a2's first assertion catches it"
else
  fail "MUTATION (Universe-deps-only case guard at :161) did not produce the expected split (exit=$AE_CODE_161_UD_GUARD): $(cat "$AE_FINDINGS_161_UD_GUARD")"
fi

AE_MUT_184_UD_GUARD="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_184_udguard.sh"
awk '
  /add_warning "\$\{label\}: \$\{decl\} has unrecognised review_at format/ {
    print "      case \"${label}\" in Universe-deps*) : ;; *) continue ;; esac"
  }
  { print }
' "$CHECK_11" > "$AE_MUT_184_UD_GUARD"
chmod +x "$AE_MUT_184_UD_GUARD"

AE_FINDINGS_184_UD_GUARD="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_MUT_184_UD_GUARD" "$(mktemp)" "$AE_FINDINGS_184_UD_GUARD" >/dev/null 2>&1
AE_CODE_184_UD_GUARD=$?
set -e

if [ "$AE_CODE_184_UD_GUARD" -eq 0 ] \
  && grep -q '^W: Universe-deps exception expiry: fixture_unrecognised_format_ud has unrecognised review_at format:' "$AE_FINDINGS_184_UD_GUARD" \
  && ! grep -q 'fixture_unrecognised_format_le has unrecognised' "$AE_FINDINGS_184_UD_GUARD"; then
  echo "OK: MUTATION (per-label case guard restricting :184's add_warning to Universe-deps* labels) leaves exit 0 and the Universe-deps finding intact but drops the linter_exceptions.conf finding — reproduces the PR #2595 residual and proves 6a2's second assertion catches it"
else
  fail "MUTATION (Universe-deps-only case guard at :184) did not produce the expected split (exit=$AE_CODE_184_UD_GUARD): $(cat "$AE_FINDINGS_184_UD_GUARD")"
fi

# --- 6a3 (vacuity direction, O3-2): reword the :161/:184 production
# messages benignly (call left in place, content changed) and confirm
# 6a2's assertions fail CLOSED rather than passing vacuously — mirrors
# the vacuity check already applied to 5a/5b (see comment at Part 5).
AE_MUT_161_REWORD="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_161_reword.sh"
sed 's/cannot auto-compare; review manually/needs manual triage/' "$CHECK_11" > "$AE_MUT_161_REWORD"
chmod +x "$AE_MUT_161_REWORD"
AE_FINDINGS_161_REWORD="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_MUT_161_REWORD" "$(mktemp)" "$AE_FINDINGS_161_REWORD" >/dev/null 2>&1
set -e
if ! grep -q '^W: Linter exception expiry (milestone unknown): fixture_unknown_milestone_le pinned to M4 — cannot auto-compare; review manually' "$AE_FINDINGS_161_REWORD"; then
  echo "OK: vacuity check — benignly rewording the :161 message (call left in place) makes 6a2's exact-text assertion fail closed rather than pass"
else
  fail "vacuity check FAILED — 6a2's :161 assertion still matched after the message was reworded, so it does not actually pin the message content: $(cat "$AE_FINDINGS_161_REWORD")"
fi

AE_MUT_184_REWORD="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_184_reword.sh"
sed 's/has unrecognised review_at format/has an unparseable review_at value/' "$CHECK_11" > "$AE_MUT_184_REWORD"
chmod +x "$AE_MUT_184_REWORD"
AE_FINDINGS_184_REWORD="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_MUT_184_REWORD" "$(mktemp)" "$AE_FINDINGS_184_REWORD" >/dev/null 2>&1
set -e
if ! grep -q '^W: Linter exception expiry: fixture_unrecognised_format_le has unrecognised review_at format:' "$AE_FINDINGS_184_REWORD"; then
  echo "OK: vacuity check — benignly rewording the :184 message (call left in place) makes 6a2's exact-text assertion fail closed rather than pass"
else
  fail "vacuity check FAILED — 6a2's :184 assertion still matched after the message was reworded, so it does not actually pin the message content: $(cat "$AE_FINDINGS_184_REWORD")"
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
# linter_exceptions.conf also carries a milestone-landed entry (O3-2,
# 2026-08-30) so the :166 site is exercised via a SECOND conf file /
# label pair, not just universe_deps_exceptions.conf's — see the O3-2
# note above Part 6 for why this is required to close the residual.
cat > "$MS_FAKE_ROOT/trading/devtools/checks/linter_exceptions.conf" <<'EOF'
fixture_milestone_landed_le  # review_at: M1 (O3-2 dual-conf-file fixture for :166)
EOF
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

# --- 6c2 (O3-2): the SAME branch, exercised via linter_exceptions.conf /
# "Linter exception expiry" too — see the O3-2 note above Part 6.
if grep -q '^W: Linter exception expiry: fixture_milestone_landed_le was due for review at M1 (current: M3)' "$MS_FINDINGS"; then
  echo "OK: the milestone-landed add_warning site (:~166) also fires for a linter_exceptions.conf entry, not just universe_deps_exceptions.conf's (O3-2 dual-conf-file fix)"
else
  fail "fixture_milestone_landed_le was NOT surfaced via the milestone-landed add_warning site: $(cat "$MS_FINDINGS")"
fi

MS_MUT="$MS_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_166.sh"
sed '/was due for review at ${entry_milestone}/d' "$CHECK_11" > "$MS_MUT"
chmod +x "$MS_MUT"
MS_FINDINGS2="$(mktemp)"
set +e
REPO_ROOT="$MS_FAKE_ROOT" sh "$MS_MUT" "$(mktemp)" "$MS_FINDINGS2" >/dev/null 2>&1
set -e
if ! grep -q 'fixture_milestone_landed_ud was due for review' "$MS_FINDINGS2" \
  && ! grep -q 'fixture_milestone_landed_le was due for review' "$MS_FINDINGS2"; then
  echo "OK: MUTATION (milestone-landed add_warning call removed) makes BOTH the universe_deps_exceptions.conf and linter_exceptions.conf findings disappear, confirming 6c/6c2 pin that site rather than some other coincidental match"
else
  fail "MUTATION (milestone-landed add_warning removed) did not remove both findings: $(cat "$MS_FINDINGS2")"
fi

# --- 6d2 (O3-2): mutation-proof for the exact per-label-guard evasion at
# :166 — a case guard restricted to `Universe-deps*` right before this
# site's add_warning() call must drop the linter_exceptions.conf finding
# while leaving the universe_deps_exceptions.conf finding (same branch,
# different label) intact, at exit 0. Confirmed by hand before writing
# this assertion.
MS_MUT_UD_GUARD="$MS_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_166_udguard.sh"
awk '
  /add_warning "\$\{label\}: \$\{decl\} was due for review at/ {
    print "        case \"${label}\" in Universe-deps*) : ;; *) continue ;; esac"
  }
  { print }
' "$CHECK_11" > "$MS_MUT_UD_GUARD"
chmod +x "$MS_MUT_UD_GUARD"

MS_FINDINGS_UD_GUARD="$(mktemp)"
set +e
REPO_ROOT="$MS_FAKE_ROOT" sh "$MS_MUT_UD_GUARD" "$(mktemp)" "$MS_FINDINGS_UD_GUARD" >/dev/null 2>&1
MS_CODE_UD_GUARD=$?
set -e

if [ "$MS_CODE_UD_GUARD" -eq 0 ] \
  && grep -q '^W: Universe-deps exception expiry: fixture_milestone_landed_ud was due for review at M2 (current: M3)' "$MS_FINDINGS_UD_GUARD" \
  && ! grep -q 'fixture_milestone_landed_le was due for review' "$MS_FINDINGS_UD_GUARD"; then
  echo "OK: MUTATION (per-label case guard restricting :166's add_warning to Universe-deps* labels) leaves exit 0 and the Universe-deps finding intact but drops the linter_exceptions.conf finding — reproduces the PR #2595 residual and proves 6c2 catches it"
else
  fail "MUTATION (Universe-deps-only case guard at :166) did not produce the expected split (exit=$MS_CODE_UD_GUARD): $(cat "$MS_FINDINGS_UD_GUARD")"
fi

# --- 6d3 (vacuity direction, O3-2): reword the :166 production message
# benignly (call left in place) and confirm 6c2's exact-text assertion
# fails closed rather than passing vacuously.
MS_MUT_REWORD="$MS_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_166_reword.sh"
sed 's/retire or re-annotate/retire or update the annotation/' "$CHECK_11" > "$MS_MUT_REWORD"
chmod +x "$MS_MUT_REWORD"
MS_FINDINGS_REWORD="$(mktemp)"
set +e
REPO_ROOT="$MS_FAKE_ROOT" sh "$MS_MUT_REWORD" "$(mktemp)" "$MS_FINDINGS_REWORD" >/dev/null 2>&1
set -e
if ! grep -q '^W: Linter exception expiry: fixture_milestone_landed_le was due for review at M1 (current: M3) — retire or re-annotate' "$MS_FINDINGS_REWORD"; then
  echo "OK: vacuity check — benignly rewording the :166 message (call left in place) makes 6c2's exact-text assertion fail closed rather than pass"
else
  fail "vacuity check FAILED — 6c2's :166 assertion still matched after the message was reworded, so it does not actually pin the message content: $(cat "$MS_FINDINGS_REWORD")"
fi

# --- 6e/6f: conf-file-not-found (:113) needs a fixture that OMITS one of
# the three conf files entirely — incompatible with every fixture above,
# which all rely on the files existing (a missing file short-circuits
# _scan_exceptions_conf() via `return 0` before any entry is read, per
# check_11_linter_expiry.sh:112-115). Separate root, third fixture.
NF_FAKE_ROOT="$(mktemp -d)"
trap 'rm -rf "$AE_FAKE_ROOT" "$MS_FAKE_ROOT" "$NF_FAKE_ROOT"' EXIT

mkdir -p "$NF_FAKE_ROOT/trading/devtools/checks/deep_scan"
: > "$NF_FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf"
# universe_deps_exceptions.conf AND linter_exceptions.conf are both
# deliberately NOT created (O3-2, 2026-08-30) — TWO missing conf files
# so the :113 site is exercised via a SECOND conf file / label pair,
# not just universe_deps_exceptions.conf's. See the O3-2 note above
# Part 6 for why this is required to close the residual.
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

# --- 6e2 (O3-2): the SAME branch, exercised via a second missing conf
# file (linter_exceptions.conf / "Linter exception expiry") — see the
# O3-2 note above Part 6.
if grep -q '^W: Linter exception expiry: linter_exceptions.conf not found — cannot check exception policy' "$NF_FINDINGS"; then
  echo "OK: the conf-file-not-found add_warning site (:~113) also fires for a missing linter_exceptions.conf, not just universe_deps_exceptions.conf's (O3-2 dual-conf-file fix)"
else
  fail "a missing linter_exceptions.conf was NOT surfaced via the conf-not-found add_warning site: $(cat "$NF_FINDINGS")"
fi

NF_MUT="$NF_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_113.sh"
sed '/not found — cannot check exception policy/d' "$CHECK_11" > "$NF_MUT"
chmod +x "$NF_MUT"
NF_FINDINGS2="$(mktemp)"
set +e
REPO_ROOT="$NF_FAKE_ROOT" sh "$NF_MUT" "$(mktemp)" "$NF_FINDINGS2" >/dev/null 2>&1
set -e
if ! grep -q 'universe_deps_exceptions.conf not found' "$NF_FINDINGS2" \
  && ! grep -q 'linter_exceptions.conf not found' "$NF_FINDINGS2"; then
  echo "OK: MUTATION (conf-not-found add_warning call removed) makes BOTH the universe_deps_exceptions.conf and linter_exceptions.conf findings disappear, confirming 6e/6e2 pin that site rather than some other coincidental match"
else
  fail "MUTATION (conf-not-found add_warning removed) did not remove both findings: $(cat "$NF_FINDINGS2")"
fi

# --- 6f2 (O3-2): mutation-proof for the exact per-label-guard evasion at
# :113 — a case guard restricted to `Universe-deps*` right before this
# site's add_warning() call (note: this site runs BEFORE the while loop,
# so the non-matching branch must `return 0`, not `continue`) must drop
# the linter_exceptions.conf finding while leaving the
# universe_deps_exceptions.conf finding (same branch, different label)
# intact, at exit 0. Confirmed by hand before writing this assertion.
NF_MUT_UD_GUARD="$NF_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_113_udguard.sh"
awk '
  /add_warning "\$\{label\}: \$\(basename "\$conf_path"\) not found/ {
    print "    case \"${label}\" in Universe-deps*) : ;; *) return 0 ;; esac"
  }
  { print }
' "$CHECK_11" > "$NF_MUT_UD_GUARD"
chmod +x "$NF_MUT_UD_GUARD"

NF_FINDINGS_UD_GUARD="$(mktemp)"
set +e
REPO_ROOT="$NF_FAKE_ROOT" sh "$NF_MUT_UD_GUARD" "$(mktemp)" "$NF_FINDINGS_UD_GUARD" >/dev/null 2>&1
NF_CODE_UD_GUARD=$?
set -e

if [ "$NF_CODE_UD_GUARD" -eq 0 ] \
  && grep -q '^W: Universe-deps exception expiry: universe_deps_exceptions.conf not found — cannot check exception policy' "$NF_FINDINGS_UD_GUARD" \
  && ! grep -q 'linter_exceptions.conf not found' "$NF_FINDINGS_UD_GUARD"; then
  echo "OK: MUTATION (per-label case guard restricting :113's add_warning to Universe-deps* labels) leaves exit 0 and the Universe-deps finding intact but drops the linter_exceptions.conf finding — reproduces the PR #2595 residual and proves 6e2 catches it"
else
  fail "MUTATION (Universe-deps-only case guard at :113) did not produce the expected split (exit=$NF_CODE_UD_GUARD): $(cat "$NF_FINDINGS_UD_GUARD")"
fi

# --- 6f3 (vacuity direction, O3-2): reword the :113 production message
# benignly (call left in place) and confirm 6e2's exact-text assertion
# fails closed rather than passing vacuously.
NF_MUT_REWORD="$NF_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_113_reword.sh"
sed 's/not found — cannot check exception policy/not found — skipping expiry check/' "$CHECK_11" > "$NF_MUT_REWORD"
chmod +x "$NF_MUT_REWORD"
NF_FINDINGS_REWORD="$(mktemp)"
set +e
REPO_ROOT="$NF_FAKE_ROOT" sh "$NF_MUT_REWORD" "$(mktemp)" "$NF_FINDINGS_REWORD" >/dev/null 2>&1
set -e
if ! grep -q '^W: Linter exception expiry: linter_exceptions.conf not found — cannot check exception policy' "$NF_FINDINGS_REWORD"; then
  echo "OK: vacuity check — benignly rewording the :113 message (call left in place) makes 6e2's exact-text assertion fail closed rather than pass"
else
  fail "vacuity check FAILED — 6e2's :113 assertion still matched after the message was reworded, so it does not actually pin the message content: $(cat "$NF_FINDINGS_REWORD")"
fi


# ── Part 7: report DETAIL LINE desync from the roll-up "W:" line (rework
# iteration 2, qc-behavioral re-review of PR #2595 at commit d83d1243) ────
#
# Iteration 1 (Part 6 above) pinned each add_warning() call site against
# "delete the whole call". A narrower corruption survives: delete ONLY the
# _SCAN_COUNT increment at a site, leaving add_warning() and the
# _SCAN_DETAILS append untouched. The roll-up "W:" line (Part 4/5/6's
# assertions) stays correct — add_warning() still ran — but the
# REPORT_FILE's own gate is different: the "### Expired or due-for-review
# entries (%d)" block only prints when the per-conf-file COUNT
# (EXPIRY_COUNT / UD_EXPIRY_COUNT / AE_EXPIRY_COUNT) is > 0, never when
# _SCAN_DETAILS is merely non-empty (check_11_linter_expiry.sh's report
# emission, each guarded by "$..._COUNT" -gt 0). If the corrupted entry is
# that conf file's ONLY expired entry, the count stays 0, the whole block
# is skipped, and the report prints "No expired or missing review_at
# annotations found" — the ## Linter Exception Expiry section silently
# claims nothing is wrong while a real entry is expired. This is the exact
# green-while-broken shape the qc-behavioral re-review found.
#
# Confirmed by hand: the corruption is INVISIBLE when a SIBLING entry in
# the same conf file still increments the count — Part 6's
# AE_FAKE_ROOT universe_deps_exceptions.conf / linter_exceptions.conf
# fixtures both carry >1 entry per file, and _SCAN_DETAILS is one
# accumulated string printed as a whole once the gate opens, so a
# sibling's increment reopens the gate and the corrupted entry's own
# detail line prints anyway. 7a-7l below therefore use fresh, deliberately
# SINGLE-entry-per-conf-file fixtures — one isolated conf file per
# affected site — so the corruption is actually observable.
#
# Coverage against this corruption shape, site by site:
#   :113  conf-file-not-found  — N/A. This branch returns before the
#         per-entry while loop runs at all; there is no per-entry
#         _SCAN_COUNT to corrupt independently of the add_warning() call
#         itself. Already fully covered by Part 6's 6e/6e2 (call deletion)
#         and 6f2/6f3 (per-label guard + vacuity reword).
#   :161  milestone-unknown    — GAP. Closed by 7a-7c (MU_FAKE_ROOT).
#   :166  milestone-landed     — GAP. Closed by 7d-7f (reuses
#         MS_FAKE_ROOT, already single-entry-per-conf-file from Part 6).
#   :176  date-expired         — closed only INCIDENTALLY before this
#         Part: Part 3a's REPORT_FILE assertion already runs against
#         AE_FAKE_ROOT's adapter_effectiveness_exceptions.conf, which
#         happens to carry exactly one entry, so the identical count-only
#         corruption already makes 3a fail (verified by hand while
#         drafting this rework — 3a's own pattern, `[EXPIRED\].*fixture_
#         expired_field`, is loose enough to still fail under this
#         mutation since the whole detail line vanishes). 7g-7i below
#         makes that deliberate: an explicit count-only mutation-proof
#         plus vacuity reword against the same fixture, rather than
#         relying on 3a's single-entry shape being an accident of an
#         unrelated fixture's design.
#   :184  unrecognised-format  — GAP. Closed by 7j-7l (UF_FAKE_ROOT).

# --- 7a: MU_FAKE_ROOT — isolated single-entry milestone-unknown fixture.
# No design doc (mirrors AE_FAKE_ROOT) so CURRENT_MILESTONE_NUM stays 0.
# The conf line is deliberately free of any trailing "(...)" annotation
# comment — that text would be captured into review_at_val (and therefore
# into entry_label / the REPORT_FILE detail line) verbatim, since
# _scan_exceptions_conf() takes everything after "# review_at:" to end of
# line, not just the milestone/date token.
MU_FAKE_ROOT="$(mktemp -d)"
trap 'rm -rf "$AE_FAKE_ROOT" "$MS_FAKE_ROOT" "$NF_FAKE_ROOT" "$MU_FAKE_ROOT" "$UF_FAKE_ROOT"' EXIT

mkdir -p "$MU_FAKE_ROOT/trading/devtools/checks/deep_scan"
cat > "$MU_FAKE_ROOT/trading/devtools/checks/linter_exceptions.conf" <<'EOF'
fixture_isolated_unknown_milestone  # review_at: M5
EOF
: > "$MU_FAKE_ROOT/trading/devtools/checks/universe_deps_exceptions.conf"
: > "$MU_FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf"
cp "${DEEP_SCAN_DIR}/_lib.sh" "$MU_FAKE_ROOT/trading/devtools/checks/deep_scan/_lib.sh"
cp "$(dirname "$0")/_check_lib.sh" "$MU_FAKE_ROOT/trading/devtools/checks/_check_lib.sh"
cp "$CHECK_11" "$MU_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh"

MU_REPORT="$(mktemp)"
MU_FINDINGS="$(mktemp)"
set +e
REPO_ROOT="$MU_FAKE_ROOT" sh "$MU_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh" \
  "$MU_REPORT" "$MU_FINDINGS" >/dev/null 2>&1
set -e

MU_DETAIL_TEXT='[MANUAL REVIEW — milestone unknown] fixture_isolated_unknown_milestone (review_at: M5)'
if grep -qF "$MU_DETAIL_TEXT" "$MU_REPORT"; then
  echo "OK: the REPORT_FILE detail line for the milestone-unknown site (:~161) is present for an isolated single-entry conf file"
else
  fail "the milestone-unknown detail line was NOT present in REPORT_FILE: $(cat "$MU_REPORT")"
fi

# --- 7b: MUTATION (count-only) — delete ONLY the _SCAN_COUNT increment at
# the milestone-unknown site, leaving add_warning() and _SCAN_DETAILS
# intact. This must desync: the roll-up W: line survives, but the
# REPORT_FILE detail line disappears and the section falls back to
# "No expired or missing review_at annotations found".
MU_MUT_COUNTONLY="$MU_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_161_countonly.sh"
sed '/_SCAN_COUNT=\$((_SCAN_COUNT + 1))/{N;/MANUAL REVIEW/{s/.*\n//}}' "$CHECK_11" > "$MU_MUT_COUNTONLY"
chmod +x "$MU_MUT_COUNTONLY"

MU_REPORT2="$(mktemp)"
MU_FINDINGS2="$(mktemp)"
set +e
REPO_ROOT="$MU_FAKE_ROOT" sh "$MU_MUT_COUNTONLY" "$MU_REPORT2" "$MU_FINDINGS2" >/dev/null 2>&1
MU_CODE2=$?
set -e

if [ "$MU_CODE2" -eq 0 ] \
  && ! grep -qF "$MU_DETAIL_TEXT" "$MU_REPORT2" \
  && grep -qF 'No expired or missing review_at annotations found' "$MU_REPORT2" \
  && grep -qF 'W: Linter exception expiry (milestone unknown): fixture_isolated_unknown_milestone pinned to M5' "$MU_FINDINGS2"; then
  echo "OK: MUTATION (count-only removal at :161) leaves exit 0 and the roll-up W: line intact, but the REPORT_FILE detail line disappears and the section falsely reports 'No expired...' — reproduces the qc-behavioral rework-2 finding and proves 7a's assertion catches it"
else
  fail "MUTATION (count-only removal at :161) did not produce the expected desync (exit=$MU_CODE2) — report: $(cat "$MU_REPORT2"); findings: $(cat "$MU_FINDINGS2")"
fi

# --- 7c: vacuity direction — reword the milestone-unknown REPORT_FILE
# detail-line tag (call, count, and add_warning left untouched) and
# confirm 7a's exact-text assertion fails closed rather than matching a
# looser pattern vacuously.
MU_MUT_REWORD="$MU_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_161_reword.sh"
sed 's/\[MANUAL REVIEW — milestone unknown\] \${entry_label}/[NEEDS MANUAL REVIEW] \${entry_label}/' \
  "$CHECK_11" > "$MU_MUT_REWORD"
chmod +x "$MU_MUT_REWORD"
MU_REPORT3="$(mktemp)"
set +e
REPO_ROOT="$MU_FAKE_ROOT" sh "$MU_MUT_REWORD" "$MU_REPORT3" "$(mktemp)" >/dev/null 2>&1
set -e
if ! grep -qF "$MU_DETAIL_TEXT" "$MU_REPORT3"; then
  echo "OK: vacuity check — benignly rewording the :161 REPORT_FILE detail tag (call left in place) makes 7a's exact-text assertion fail closed rather than pass"
else
  fail "vacuity check FAILED — 7a's :161 REPORT_FILE assertion still matched after the tag was reworded: $(cat "$MU_REPORT3")"
fi

# --- 7d: reuse MS_FAKE_ROOT (already single-entry-per-conf-file from Part
# 6) — the milestone-landed site (:~166), REPORT_FILE detail line. Its
# fixture_milestone_landed_le entry carries a trailing descriptive comment
# inside the review_at field itself ("M1 (O3-2 dual-conf-file fixture for
# :166)"), which _scan_exceptions_conf() captures verbatim into
# entry_label — the exact text below reflects that, not a clean "M1".
ML_DETAIL_TEXT='[EXPIRED] fixture_milestone_landed_le (review_at: M1 (O3-2 dual-conf-file fixture for :166)) — M1 <= current milestone M3'
ML_REPORT="$(mktemp)"
ML_FINDINGS="$(mktemp)"
set +e
REPO_ROOT="$MS_FAKE_ROOT" sh "$MS_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh" \
  "$ML_REPORT" "$ML_FINDINGS" >/dev/null 2>&1
set -e

if grep -qF "$ML_DETAIL_TEXT" "$ML_REPORT"; then
  echo "OK: the REPORT_FILE detail line for the milestone-landed site (:~166) is present for MS_FAKE_ROOT's single-entry linter_exceptions.conf"
else
  fail "the milestone-landed detail line was NOT present in REPORT_FILE: $(cat "$ML_REPORT")"
fi

# --- 7e: MUTATION (count-only) at :166.
ML_MUT_COUNTONLY="$MS_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_166_countonly.sh"
sed '/_SCAN_COUNT=\$((_SCAN_COUNT + 1))/{N;/<= current milestone/{s/.*\n//}}' "$CHECK_11" > "$ML_MUT_COUNTONLY"
chmod +x "$ML_MUT_COUNTONLY"

ML_REPORT2="$(mktemp)"
ML_FINDINGS2="$(mktemp)"
set +e
REPO_ROOT="$MS_FAKE_ROOT" sh "$ML_MUT_COUNTONLY" "$ML_REPORT2" "$ML_FINDINGS2" >/dev/null 2>&1
ML_CODE2=$?
set -e

if [ "$ML_CODE2" -eq 0 ] \
  && ! grep -qF "$ML_DETAIL_TEXT" "$ML_REPORT2" \
  && grep -qF 'No expired or missing review_at annotations found' "$ML_REPORT2" \
  && grep -qF 'W: Linter exception expiry: fixture_milestone_landed_le was due for review at M1' "$ML_FINDINGS2"; then
  echo "OK: MUTATION (count-only removal at :166) leaves exit 0 and the roll-up W: line intact, but the REPORT_FILE detail line disappears and the section falsely reports 'No expired...' — reproduces the qc-behavioral rework-2 finding and proves 7d's assertion catches it"
else
  fail "MUTATION (count-only removal at :166) did not produce the expected desync (exit=$ML_CODE2) — report: $(cat "$ML_REPORT2"); findings: $(cat "$ML_FINDINGS2")"
fi

# --- 7f: vacuity direction for :166 — reword the unique trailing text in
# the REPORT_FILE detail line (call, count, add_warning untouched).
ML_MUT_REWORD="$MS_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_166_reword.sh"
sed 's/<= current milestone \${CURRENT_MILESTONE}/<= current MS \${CURRENT_MILESTONE}/' \
  "$CHECK_11" > "$ML_MUT_REWORD"
chmod +x "$ML_MUT_REWORD"
ML_REPORT3="$(mktemp)"
set +e
REPO_ROOT="$MS_FAKE_ROOT" sh "$ML_MUT_REWORD" "$ML_REPORT3" "$(mktemp)" >/dev/null 2>&1
set -e
if ! grep -qF "$ML_DETAIL_TEXT" "$ML_REPORT3"; then
  echo "OK: vacuity check — benignly rewording the :166 REPORT_FILE detail text (call left in place) makes 7d's exact-text assertion fail closed rather than pass"
else
  fail "vacuity check FAILED — 7d's :166 REPORT_FILE assertion still matched after the text was reworded: $(cat "$ML_REPORT3")"
fi

# --- 7g: reuse AE_FAKE_ROOT (already single-entry in
# adapter_effectiveness_exceptions.conf) — the date-expired site (:~176),
# REPORT_FILE detail line. Makes deliberate what Part 3a only caught
# incidentally (3a's own pattern is loose — `[EXPIRED\].*fixture_expired_
# field` — and does not pin the review-date text this exact-text check
# does). fixture_expired_field's review_at field also carries a trailing
# "(BQ-1 fixture)" comment, captured verbatim into entry_label same as
# the :166 fixture above.
DE_DETAIL_TEXT='[EXPIRED] fixture_expired_field (review_at: 2019-01-01 (BQ-1 fixture)) — review date 2019-01-01 has passed'
DE_REPORT="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh" \
  "$DE_REPORT" "$(mktemp)" >/dev/null 2>&1
set -e
if grep -qF "$DE_DETAIL_TEXT" "$DE_REPORT"; then
  echo "OK: the REPORT_FILE detail line for the date-expired site (:~176) is present for AE_FAKE_ROOT's single-entry adapter_effectiveness_exceptions.conf"
else
  fail "the date-expired detail line was NOT present in REPORT_FILE: $(cat "$DE_REPORT")"
fi

# --- 7h: MUTATION (count-only) at :176 — deliberate, not incidental.
DE_MUT_COUNTONLY="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_176_countonly.sh"
sed '/_SCAN_COUNT=\$((_SCAN_COUNT + 1))/{N;/has passed (today/{s/.*\n//}}' "$CHECK_11" > "$DE_MUT_COUNTONLY"
chmod +x "$DE_MUT_COUNTONLY"

DE_REPORT2="$(mktemp)"
DE_FINDINGS2="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$DE_MUT_COUNTONLY" "$DE_REPORT2" "$DE_FINDINGS2" >/dev/null 2>&1
DE_CODE2=$?
set -e

if [ "$DE_CODE2" -eq 0 ] \
  && ! grep -qF "$DE_DETAIL_TEXT" "$DE_REPORT2" \
  && grep -qF 'No expired or missing review_at annotations found' "$DE_REPORT2" \
  && grep -q '^W: .*fixture_expired_field.*has passed' "$DE_FINDINGS2"; then
  echo "OK: MUTATION (count-only removal at :176) leaves exit 0 and the roll-up W: line intact, but the REPORT_FILE detail line disappears and the section falsely reports 'No expired...' — makes deliberate what Part 3a only caught incidentally"
else
  fail "MUTATION (count-only removal at :176) did not produce the expected desync (exit=$DE_CODE2) — report: $(cat "$DE_REPORT2"); findings: $(cat "$DE_FINDINGS2")"
fi

# --- 7i: vacuity direction for :176.
DE_MUT_REWORD="$AE_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_176_reword.sh"
sed 's/review date \${review_date} has passed (today/review date \${review_date} has elapsed (today/' \
  "$CHECK_11" > "$DE_MUT_REWORD"
chmod +x "$DE_MUT_REWORD"
DE_REPORT3="$(mktemp)"
set +e
REPO_ROOT="$AE_FAKE_ROOT" sh "$DE_MUT_REWORD" "$DE_REPORT3" "$(mktemp)" >/dev/null 2>&1
set -e
if ! grep -qF "$DE_DETAIL_TEXT" "$DE_REPORT3"; then
  echo "OK: vacuity check — benignly rewording the :176 REPORT_FILE detail text (call left in place) makes 7g's exact-text assertion fail closed rather than pass"
else
  fail "vacuity check FAILED — 7g's :176 REPORT_FILE assertion still matched after the text was reworded: $(cat "$DE_REPORT3")"
fi

# --- 7j: UF_FAKE_ROOT — isolated single-entry unrecognised-format
# fixture. Same no-trailing-comment discipline as MU_FAKE_ROOT (7a) above.
UF_FAKE_ROOT="$(mktemp -d)"
mkdir -p "$UF_FAKE_ROOT/trading/devtools/checks/deep_scan"
cat > "$UF_FAKE_ROOT/trading/devtools/checks/linter_exceptions.conf" <<'EOF'
fixture_isolated_unrecognised  # review_at: someday
EOF
: > "$UF_FAKE_ROOT/trading/devtools/checks/universe_deps_exceptions.conf"
: > "$UF_FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf"
cp "${DEEP_SCAN_DIR}/_lib.sh" "$UF_FAKE_ROOT/trading/devtools/checks/deep_scan/_lib.sh"
cp "$(dirname "$0")/_check_lib.sh" "$UF_FAKE_ROOT/trading/devtools/checks/_check_lib.sh"
cp "$CHECK_11" "$UF_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh"

UF_DETAIL_TEXT='[UNRECOGNISED format] fixture_isolated_unrecognised (review_at: someday) — review_at value not a milestone'
UF_REPORT="$(mktemp)"
UF_FINDINGS="$(mktemp)"
set +e
REPO_ROOT="$UF_FAKE_ROOT" sh "$UF_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh" \
  "$UF_REPORT" "$UF_FINDINGS" >/dev/null 2>&1
set -e

if grep -qF "$UF_DETAIL_TEXT" "$UF_REPORT"; then
  echo "OK: the REPORT_FILE detail line for the unrecognised-format site (:~184) is present for an isolated single-entry conf file"
else
  fail "the unrecognised-format detail line was NOT present in REPORT_FILE: $(cat "$UF_REPORT")"
fi

# --- 7k: MUTATION (count-only) at :184.
UF_MUT_COUNTONLY="$UF_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_184_countonly.sh"
sed '/_SCAN_COUNT=\$((_SCAN_COUNT + 1))/{N;/UNRECOGNISED format/{s/.*\n//}}' "$CHECK_11" > "$UF_MUT_COUNTONLY"
chmod +x "$UF_MUT_COUNTONLY"

UF_REPORT2="$(mktemp)"
UF_FINDINGS2="$(mktemp)"
set +e
REPO_ROOT="$UF_FAKE_ROOT" sh "$UF_MUT_COUNTONLY" "$UF_REPORT2" "$UF_FINDINGS2" >/dev/null 2>&1
UF_CODE2=$?
set -e

if [ "$UF_CODE2" -eq 0 ] \
  && ! grep -qF "$UF_DETAIL_TEXT" "$UF_REPORT2" \
  && grep -qF 'No expired or missing review_at annotations found' "$UF_REPORT2" \
  && grep -qF 'W: Linter exception expiry: fixture_isolated_unrecognised has unrecognised review_at format:' "$UF_FINDINGS2"; then
  echo "OK: MUTATION (count-only removal at :184) leaves exit 0 and the roll-up W: line intact, but the REPORT_FILE detail line disappears and the section falsely reports 'No expired...' — reproduces the qc-behavioral rework-2 finding and proves 7j's assertion catches it"
else
  fail "MUTATION (count-only removal at :184) did not produce the expected desync (exit=$UF_CODE2) — report: $(cat "$UF_REPORT2"); findings: $(cat "$UF_FINDINGS2")"
fi

# --- 7l: vacuity direction for :184.
UF_MUT_REWORD="$UF_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_184_reword.sh"
sed 's/review_at value not a milestone/review_at is not a milestone/' \
  "$CHECK_11" > "$UF_MUT_REWORD"
chmod +x "$UF_MUT_REWORD"
UF_REPORT3="$(mktemp)"
set +e
REPO_ROOT="$UF_FAKE_ROOT" sh "$UF_MUT_REWORD" "$UF_REPORT3" "$(mktemp)" >/dev/null 2>&1
set -e
if ! grep -qF "$UF_DETAIL_TEXT" "$UF_REPORT3"; then
  echo "OK: vacuity check — benignly rewording the :184 REPORT_FILE detail text (call left in place) makes 7j's exact-text assertion fail closed rather than pass"
else
  fail "vacuity check FAILED — 7j's :184 REPORT_FILE assertion still matched after the text was reworded: $(cat "$UF_REPORT3")"
fi

# ── Part 8: the missing-review_at branch itself (H-EXPIRY-MISSING-REVIEWAT
# -UNPINNED, filed 2026-08-30 while closing PR #2589's O2/O3) ─────────────
#
# Parts 1-7 above all pin the branches inside _scan_exceptions_conf() that
# fire when a review_at annotation IS present (expired / milestone-unknown /
# milestone-landed / unrecognised-format / conf-file-not-found). None of
# them exercise the SIBLING branch at check_11_linter_expiry.sh:130-137,
# which fires when review_at is ABSENT entirely — a T1-K policy violation —
# and populates _SCAN_MISSING / _SCAN_MISSING_COUNT. That branch never calls
# add_warning() (confirmed by reading the branch: no add_warning call
# appears between the `if [ -z "$review_at_val" ]` guard and its
# `continue`), so it is invisible to the roll-up "W:" findings line and
# main.sh's top-level "## Warnings" section entirely — it only ever
# surfaces via the per-file REPORT_FILE "### Missing review_at annotation —
# policy violation T1-K" section. This is a DIFFERENT failure mode than
# BQ-1/R-5/O2/O3 above: a regression here silently drops that per-file
# section, not a roll-up warning line, and main.sh's "## Warnings" stays
# unaffected either way (verified directly below in 8d, not assumed).
#
# Confirmed by hand before writing 8a-8d: deleting the two population
# lines inside the branch (the _SCAN_MISSING_COUNT increment and the
# _SCAN_MISSING append) from a working copy of the real script left the
# ENTIRE pre-existing suite (Parts 1-7, all 39 assertions) green at exit 0
# — none of them touch this branch. That is the gap this Part closes.
#
# Fixture cardinality: TWO entries, deliberately — and NOT for the reason an
# earlier revision of this comment gave. That revision claimed a single-entry
# fixture was required as a "masking-hazard guard per Part 7's precedent," so
# that a sibling entry's _SCAN_MISSING_COUNT increment could not mask a
# per-entry corruption. qc-behavioral (PR #2624, review 5075929429) measured
# that claim and found it FALSE AND INVERTED here:
#
#   - Part 7's masking hazard does not apply. 8b and 8c produce byte-identical
#     outcomes at one entry and at two, because this branch carries no
#     per-entry state to corrupt independently of the call — it is one branch
#     with one accumulator pair.
#   - Single-entry was, in fact, the SOLE reason a real mutation escaped:
#     hardcoding the header's count to "(1)" is invisible against a one-entry
#     fixture and goes RED at two.
#
# So the single-entry choice bought nothing and cost coverage. Two entries it
# is, and the header assertion below pins the count as "(2)" — which is what
# makes the hardcoded-count mutation fail closed.

MR_FAKE_ROOT="$(mktemp -d)"
trap 'rm -rf "$AE_FAKE_ROOT" "$MS_FAKE_ROOT" "$NF_FAKE_ROOT" "$MU_FAKE_ROOT" "$UF_FAKE_ROOT" "$MR_FAKE_ROOT"' EXIT

mkdir -p "$MR_FAKE_ROOT/trading/devtools/checks/deep_scan"
# Two entries, neither carrying a "# review_at:" annotation — the T1-K
# violation. The second entry exists to pin the count (see above).
cat > "$MR_FAKE_ROOT/trading/devtools/checks/linter_exceptions.conf" <<'EOF'
fixture_missing_review_at
fixture_missing_review_at_second
EOF
: > "$MR_FAKE_ROOT/trading/devtools/checks/universe_deps_exceptions.conf"
: > "$MR_FAKE_ROOT/trading/devtools/checks/adapter_effectiveness_exceptions.conf"
cp "${DEEP_SCAN_DIR}/_lib.sh" "$MR_FAKE_ROOT/trading/devtools/checks/deep_scan/_lib.sh"
cp "$(dirname "$0")/_check_lib.sh" "$MR_FAKE_ROOT/trading/devtools/checks/_check_lib.sh"
cp "$CHECK_11" "$MR_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh"

# --- 8a: functional pin — the REAL script surfaces the per-file
# "### Missing review_at annotation — policy violation T1-K" section,
# naming the fixture entry, for an entry with no review_at annotation.
# The "policy violation T1-K" suffix is unique to linter_exceptions.conf's
# section (universe_deps/adapter_effectiveness sections omit the T1-K
# suffix — see check_11_linter_expiry.sh:241 vs :265/:292), so this also
# confirms the section belongs to the right conf file.
MR_REPORT="$(mktemp)"
MR_FINDINGS="$(mktemp)"
set +e
REPO_ROOT="$MR_FAKE_ROOT" sh "$MR_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry.sh" \
  "$MR_REPORT" "$MR_FINDINGS" >/dev/null 2>&1
MR_CODE=$?
set -e

MR_HEADER_TEXT='### Missing review_at annotation — policy violation T1-K (2)'
MR_DETAIL_TEXT='Missing review_at on: fixture_missing_review_at'
if [ "$MR_CODE" -eq 0 ] \
  && grep -qF -- "$MR_HEADER_TEXT" "$MR_REPORT" \
  && grep -qF -- "$MR_DETAIL_TEXT" "$MR_REPORT"; then
  echo "OK: an entry with no review_at annotation is surfaced via the per-file 'Missing review_at annotation — policy violation T1-K' REPORT_FILE section (H-EXPIRY-MISSING-REVIEWAT-UNPINNED functional pin)"
else
  fail "fixture_missing_review_at was NOT surfaced via the missing-review_at REPORT_FILE section (exit=$MR_CODE): $(cat "$MR_REPORT")"
fi

# --- 8b: MUTATION (population removed) — the exact gap this Part closes.
# Delete ONLY the two lines that populate _SCAN_MISSING_COUNT / _SCAN_MISSING
# inside the missing-review_at branch, leaving the branch's `continue` (and
# every other branch) intact. Hand-verified before writing this assertion:
# with this exact mutation applied to the real script, Parts 1-7's full
# suite stays green — this assertion is what makes that gap fail red.
# Also confirms the mutation is ISOLATED to this branch, not a wholesale
# script failure: the report still renders its "No expired or missing
# review_at annotations found" fallback (proving the script ran to
# completion and the surrounding report structure survived) and exits 0,
# not crashed.
MR_MUT_NOPOP="$MR_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_missing_nopop.sh"
sed '/_SCAN_MISSING_COUNT=\$((_SCAN_MISSING_COUNT + 1))/d; /_SCAN_MISSING="\${_SCAN_MISSING}  - Missing review_at on: \${decl}\\n"/d' \
  "$CHECK_11" > "$MR_MUT_NOPOP"
chmod +x "$MR_MUT_NOPOP"

MR_REPORT2="$(mktemp)"
MR_FINDINGS2="$(mktemp)"
set +e
REPO_ROOT="$MR_FAKE_ROOT" sh "$MR_MUT_NOPOP" "$MR_REPORT2" "$MR_FINDINGS2" >/dev/null 2>&1
MR_CODE2=$?
set -e

if [ "$MR_CODE2" -eq 0 ] \
  && ! grep -qF -- "$MR_HEADER_TEXT" "$MR_REPORT2" \
  && ! grep -qF -- "$MR_DETAIL_TEXT" "$MR_REPORT2" \
  && grep -qF 'No expired or missing review_at annotations found' "$MR_REPORT2"; then
  echo "OK: MUTATION (missing-review_at population removed) makes the per-file T1-K section vanish while the surrounding report survives intact and exit stays 0 — reproduces H-EXPIRY-MISSING-REVIEWAT-UNPINNED and proves 8a's assertion catches it"
else
  fail "MUTATION (missing-review_at population removed) did not produce the expected result (exit=$MR_CODE2): $(cat "$MR_REPORT2")"
fi

# --- 8c: second, independent break direction — corrupt the section's
# message content while LEAVING the population in place (mirrors Part 4's
# Mutation D / 3e shape). The count still fires and the section still
# prints, but the entry's declaration text no longer reads "Missing
# review_at on: ...". Confirms 8a pins the exact detail text, not merely
# "some line under this header exists" — the count-present, text-corrupted
# escape the masking-hazard note warns about.
MR_MUT_REWORD="$MR_FAKE_ROOT/trading/devtools/checks/deep_scan/check_11_linter_expiry_mutated_missing_reword.sh"
sed 's/- Missing review_at on: \${decl}/- No review_at annotation present on: ${decl}/' \
  "$CHECK_11" > "$MR_MUT_REWORD"
chmod +x "$MR_MUT_REWORD"

MR_REPORT3="$(mktemp)"
set +e
REPO_ROOT="$MR_FAKE_ROOT" sh "$MR_MUT_REWORD" "$MR_REPORT3" "$(mktemp)" >/dev/null 2>&1
MR_CODE3=$?
set -e

if [ "$MR_CODE3" -eq 0 ] \
  && grep -qF -- "$MR_HEADER_TEXT" "$MR_REPORT3" \
  && ! grep -qF -- "$MR_DETAIL_TEXT" "$MR_REPORT3"; then
  echo "OK: MUTATION (message content corrupted, population left in place) keeps the T1-K header/count intact but the entry's detail text no longer matches — second, independent break direction caught; proves 8a's assertion is not vacuous against a count-only check"
else
  fail "MUTATION (missing-review_at message corrupted) did not produce the expected split (exit=$MR_CODE3): $(cat "$MR_REPORT3")"
fi

# --- 8d: the entry's own caveat, VERIFIED rather than assumed — the
# missing-review_at branch never calls add_warning(), so it must be
# entirely absent from the roll-up FINDINGS_FILE (and therefore from
# main.sh's "## Warnings" section, which is built only from "W: " lines —
# see deep_scan/main.sh's findings-file loop). If a future edit wires
# add_warning() into this branch, that is a deliberate behaviour change
# (out of scope for this Part — see dev/status/harness.md) and this
# assertion should be updated alongside it, not silently left stale.
if ! grep -q 'fixture_missing_review_at' "$MR_FINDINGS"; then
  echo "OK: the missing-review_at branch does NOT emit a roll-up 'W:' findings line for the fixture entry — confirms main.sh's '## Warnings' section is unaffected either way, as the harness.md item's caveat claims (verified, not assumed)"
else
  fail "fixture_missing_review_at unexpectedly appeared in the roll-up FINDINGS_FILE — the missing-review_at branch now calls add_warning(), which contradicts the harness.md item's caveat and is a behaviour change out of this Part's scope: $(cat "$MR_FINDINGS")"
fi

echo "OK: deep scan Linter Exception Expiry section (T1-K) structural + functional check passed."
