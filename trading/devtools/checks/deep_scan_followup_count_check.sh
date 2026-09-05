#!/bin/sh
# Change-detector test for the deep-scan follow-up / open-item counter
# (H-FOLLOWUP-COUNT / H-FOLLOWUP-THRESHOLD-RETUNE). Unlike the other
# deep_scan_*_check.sh smoke tests in this directory (which are structural —
# they grep for implementation markers), this test actually INVOKES
# check_05_followup_items.sh and check_08_trends.sh against synthetic
# fixture trees with known-correct answers, using the REPO_ROOT env-var
# override that _check_lib.sh's repo_root() supports (see
# budget_rollup_check.sh for the same pattern).
#
# It pins:
#   1. Only "- [ ]" (open checkbox) lines are counted — not "- [x]"
#      (closed) and not plain prose bullets.
#   2. Counting is unscoped by heading — an open item under "### Follow-up"
#      (H3) or under an unrelated heading like "## Backlog" is counted the
#      same as one under "## Follow-up / Known Improvements" (H2).
#   3. Check 5's per-file sidecar handoff is read correctly by Check 8 —
#      the Trends section's "no baseline" table must show the SAME
#      per-file counts Check 5 computed, not "No open followup items in
#      either scan" (the exact self-contradiction the bug produced: see
#      dev/health/2026-07-27-deep.md lines 10 vs 303).
#   4. (H-FOLLOWUP-THRESHOLD-RETUNE) Tier/roadmap items (a "- [ ]" line
#      under a "## Tier <digit>" H2 heading) and template text inside a
#      fenced code block are EXCLUDED from the actionable FOLLOWUP_COUNT
#      metric, but still counted and surfaced via FOLLOWUP_EXCLUDED /
#      FOLLOWUP_TOTAL and the Warnings/Info line — never silently dropped.
#   5. (H-FOLLOWUP-THRESHOLD-RETUNE) The check FAILS LOUDLY (non-zero
#      exit, "FAIL:" to stderr) when it reads zero dev/status/*.md files,
#      rather than silently reporting FOLLOWUP_COUNT=0 (which would read
#      as "no open debt" instead of "the scan didn't run").
#
# Fixture layout (see below):
#   track-a.md — one open item under "## Backlog" (a non-Follow-up
#                heading), one closed item and one prose bullet under the
#                SAME heading, then one open + one closed item under
#                "## Follow-up / Known Improvements" (H2).
#     Expected: 2 actionable, 0 excluded, 2 total open.
#   track-b.md — one open + one closed item under "### Follow-up" (H3).
#     Expected: 1 actionable, 0 excluded, 1 total open.
#   track-c.md — one open item under "## Tier 2 — Milestone-gated" (a
#                closed item under the same heading, should not count
#                either way), one open item under an ordinary heading,
#                one open item inside a fenced code block, one open item
#                after the fence closes.
#     Expected: 2 actionable (the ordinary-heading item + the
#     after-the-fence item), 2 excluded (the Tier-2 item + the
#     inside-the-fence item), 4 total open.
#
#   Combined fixture totals: 5 actionable, 2 excluded, 7 total open.
#
# How to re-verify by hand:
#   sh trading/devtools/checks/deep_scan_followup_count_check.sh

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT_REAL="$(repo_root)"
DEEP_SCAN_DIR="${REPO_ROOT_REAL}/trading/devtools/checks/deep_scan"
CHECK_05="${DEEP_SCAN_DIR}/check_05_followup_items.sh"
CHECK_08="${DEEP_SCAN_DIR}/check_08_trends.sh"
[ -f "$CHECK_05" ] || die "deep_scan_followup_count_check: $CHECK_05 does not exist"
[ -f "$CHECK_08" ] || die "deep_scan_followup_count_check: $CHECK_08 does not exist"

FAIL_COUNT=0

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: deep_scan_followup_count_check — $1" >&2
}

FAKE_ROOT="$(mktemp -d)"
FINDINGS_DIR="$(mktemp -d)"
DETAIL_FILE="$(mktemp)"
FAKE_ROOT_WARN="$(mktemp -d)"
FINDINGS_DIR_WARN="$(mktemp -d)"
DETAIL_FILE_WARN="$(mktemp)"
FAKE_ROOT_EMPTY="$(mktemp -d)"
FINDINGS_DIR_EMPTY="$(mktemp -d)"
DETAIL_FILE_EMPTY="$(mktemp)"
STDERR_EMPTY="$(mktemp)"
trap 'rm -rf "$FAKE_ROOT" "$FINDINGS_DIR" "$DETAIL_FILE" "$FAKE_ROOT_WARN" "$FINDINGS_DIR_WARN" "$DETAIL_FILE_WARN" "$FAKE_ROOT_EMPTY" "$FINDINGS_DIR_EMPTY" "$DETAIL_FILE_EMPTY" "$STDERR_EMPTY"' EXIT

mkdir -p "${FAKE_ROOT}/dev/status" "${FAKE_ROOT}/dev/health"

cat > "${FAKE_ROOT}/dev/status/track-a.md" <<'EOF'
## Status

- Status: IN_PROGRESS

## Backlog

- [ ] AAA an open backlog item not under any Follow-up heading
- [x] BBB a closed backlog item, should not count
- some prose bullet with no checkbox, should not count

## Follow-up / Known Improvements

- [ ] CCC an open follow-up item
- [x] DDD a closed follow-up item, should not count
EOF

cat > "${FAKE_ROOT}/dev/status/track-b.md" <<'EOF'
## Status

- Status: IN_PROGRESS

### Follow-up

- [ ] EEE an open item under an H3 Follow-up heading
- [x] FFF a closed item under an H3 Follow-up heading, should not count
EOF

cat > "${FAKE_ROOT}/dev/status/track-c.md" <<'EOF'
## Tier 2 — Milestone-gated

- [ ] TIER-ITEM: an open item under a Tier-2 heading, should be EXCLUDED
- [x] TIER-ITEM-CLOSED: a closed item under Tier-2, should not count either way

## Not a tier heading

- [ ] GGG an open item under an ordinary heading, should be actionable

## How findings get here

Some prose describing the template shape below.

```
- [ ] HHH an open item inside a fenced code block, should be EXCLUDED
```

- [ ] III an open item after the fence closes, should be actionable
EOF

# ── Step 1: run Check 5 against the fixture ───────────────────────

FINDINGS_05="${FINDINGS_DIR}/05.findings"
: > "$FINDINGS_05"
REPO_ROOT="$FAKE_ROOT" sh "$CHECK_05" "$DETAIL_FILE" "$FINDINGS_05"

METRIC_LINE="$(grep '^M: FOLLOWUP_COUNT=' "$FINDINGS_05" || true)"
if [ "$METRIC_LINE" != "M: FOLLOWUP_COUNT=5" ]; then
  fail "expected 'M: FOLLOWUP_COUNT=5' in Check 5 findings, got: '${METRIC_LINE:-<missing>}'"
fi

EXCLUDED_LINE="$(grep '^M: FOLLOWUP_EXCLUDED=' "$FINDINGS_05" || true)"
if [ "$EXCLUDED_LINE" != "M: FOLLOWUP_EXCLUDED=2" ]; then
  fail "expected 'M: FOLLOWUP_EXCLUDED=2' in Check 5 findings, got: '${EXCLUDED_LINE:-<missing>}'"
fi

TOTAL_LINE="$(grep '^M: FOLLOWUP_TOTAL=' "$FINDINGS_05" || true)"
if [ "$TOTAL_LINE" != "M: FOLLOWUP_TOTAL=7" ]; then
  fail "expected 'M: FOLLOWUP_TOTAL=7' in Check 5 findings, got: '${TOTAL_LINE:-<missing>}'"
fi

SIDECAR="${FINDINGS_DIR}/followup_per_file.sidecar"
if [ ! -f "$SIDECAR" ]; then
  fail "Check 5 did not write the sidecar file at ${SIDECAR}"
else
  if ! grep -qF 'track-a.md:2' "$SIDECAR"; then
    fail "sidecar missing 'track-a.md:2' (got: $(cat "$SIDECAR" | tr '\n' ';'))"
  fi
  if ! grep -qF 'track-b.md:1' "$SIDECAR"; then
    fail "sidecar missing 'track-b.md:1' (got: $(cat "$SIDECAR" | tr '\n' ';'))"
  fi
  if ! grep -qF 'track-c.md:2' "$SIDECAR"; then
    fail "sidecar missing 'track-c.md:2' (got: $(cat "$SIDECAR" | tr '\n' ';'))"
  fi
fi

# A warning must fire (5 actionable items is under the threshold=10, so this
# should be an "I:" info line, not a "W:" warning — sanity-check the
# threshold branch didn't get inverted).
if grep -q '^W: ' "$FINDINGS_05"; then
  fail "5 actionable open items should not cross the threshold=10 warning; found a W: line"
fi
if ! grep -q '^I: Open items: 5 actionable total' "$FINDINGS_05"; then
  fail "expected an info line reporting 5 actionable total open items, got: $(grep '^I: ' "$FINDINGS_05" || echo '<none>')"
fi

# ── Step 2: run Check 8 against the same fixture + findings dir ──

FINDINGS_08="${FINDINGS_DIR}/08.findings"
: > "$FINDINGS_08"
REPO_ROOT="$FAKE_ROOT" sh "$CHECK_08" "$DETAIL_FILE" "$FINDINGS_08"

# The Trends "no baseline" table must show the SAME breakdown Check 5
# computed. This is the sidecar-handoff regression test: previously
# check_08 read a mismatched path and printed
# "No open followup items found." here despite Check 5 having counted 3.
if grep -qF 'No open followup items found.' "$DETAIL_FILE"; then
  fail "Check 8 printed 'No open followup items found.' despite Check 5 counting open items — sidecar handoff is broken"
fi
if ! grep -qF 'track-a.md' "$DETAIL_FILE"; then
  fail "Check 8 Trends detail is missing track-a.md — sidecar handoff is broken"
fi
if ! grep -qF 'track-b.md' "$DETAIL_FILE"; then
  fail "Check 8 Trends detail is missing track-b.md — sidecar handoff is broken"
fi
# Check the per-file counts landed correctly, not just the filenames.
if ! grep -E '\| `track-a\.md` \| 2 \|' "$DETAIL_FILE" > /dev/null; then
  fail "Check 8 Trends detail does not show track-a.md with count 2"
fi
if ! grep -E '\| `track-b\.md` \| 1 \|' "$DETAIL_FILE" > /dev/null; then
  fail "Check 8 Trends detail does not show track-b.md with count 1"
fi
if ! grep -E '\| `track-c\.md` \| 2 \|' "$DETAIL_FILE" > /dev/null; then
  fail "Check 8 Trends detail does not show track-c.md with count 2 (post-exclusion actionable count)"
fi

# ── Step 3: threshold-crossing fixture — pins the W: warning branch ──
#
# The 5-actionable-item fixture above only ever exercises the `elif` info
# branch (check_05_followup_items.sh's threshold check); the
# `[ "$FOLLOWUP_COUNT" -gt 10 ]` warning branch is the ACTUAL signal the
# orchestrator's Step 2b maintenance-cycle decision reads, and it went
# unpinned in the original version of this test — inverting `-gt` to `-lt`
# would leave the suite green while flipping that signal backwards. Use a
# separate fixture root so this doesn't disturb the sidecar Step 2 above
# already validated.

mkdir -p "${FAKE_ROOT_WARN}/dev/status"

{
  echo "## Backlog"
  echo
  i=1
  while [ "$i" -le 11 ]; do
    echo "- [ ] open item number ${i}, crosses the threshold=10 warning"
    i=$((i + 1))
  done
} > "${FAKE_ROOT_WARN}/dev/status/track-warn.md"

FINDINGS_WARN="${FINDINGS_DIR_WARN}/05.findings"
: > "$FINDINGS_WARN"
REPO_ROOT="$FAKE_ROOT_WARN" sh "$CHECK_05" "$DETAIL_FILE_WARN" "$FINDINGS_WARN"

METRIC_LINE_WARN="$(grep '^M: FOLLOWUP_COUNT=' "$FINDINGS_WARN" || true)"
if [ "$METRIC_LINE_WARN" != "M: FOLLOWUP_COUNT=11" ]; then
  fail "expected 'M: FOLLOWUP_COUNT=11' in Check 5 findings for the threshold fixture, got: '${METRIC_LINE_WARN:-<missing>}'"
fi

EXCLUDED_LINE_WARN="$(grep '^M: FOLLOWUP_EXCLUDED=' "$FINDINGS_WARN" || true)"
if [ "$EXCLUDED_LINE_WARN" != "M: FOLLOWUP_EXCLUDED=0" ]; then
  fail "expected 'M: FOLLOWUP_EXCLUDED=0' in Check 5 findings for the threshold fixture (no Tier/fence content), got: '${EXCLUDED_LINE_WARN:-<missing>}'"
fi

# Pin the W: wording, the count, and the "see 'Followup Count Detail' below"
# pointer — this is the whole point of the fixture, not just "a W: line
# exists somewhere."
WARN_LINE="$(grep '^W: Open item accumulation:' "$FINDINGS_WARN" || true)"
case "$WARN_LINE" in
  "W: Open item accumulation: 11 actionable open"*"(threshold: 10"*"see 'Followup Count Detail' below"*)
    ;;
  *)
    fail "expected a W: warning line for 11 actionable open items crossing threshold=10 with the 'Followup Count Detail' pointer, got: '${WARN_LINE:-<missing>}'"
    ;;
esac

if grep -q '^I: Open items:' "$FINDINGS_WARN"; then
  fail "11 actionable open items crosses the threshold=10; should emit W:, not also I:"
fi

# ── Step 4: zero-files-found fixture — pins the fail-loud guard ──
#
# A REPO_ROOT that resolves to a tree with no dev/status/*.md files must
# make check_05_followup_items.sh die loudly (non-zero exit, "FAIL:" to
# stderr) rather than silently reporting FOLLOWUP_COUNT=0. dev/status/
# exists but is empty — the realistic broken-resolution shape (the
# directory resolved, nothing inside it matched the glob) rather than a
# missing directory, which would look identical from the glob's
# perspective anyway.

mkdir -p "${FAKE_ROOT_EMPTY}/dev/status"

set +e
REPO_ROOT="$FAKE_ROOT_EMPTY" sh "$CHECK_05" "$DETAIL_FILE_EMPTY" "${FINDINGS_DIR_EMPTY}/05.findings" \
  > /dev/null 2> "$STDERR_EMPTY"
RC_EMPTY=$?
set -e

if [ "$RC_EMPTY" -eq 0 ]; then
  fail "check_05_followup_items.sh exited 0 against a dev/status/ directory with zero .md files -- must fail loudly instead of silently reporting FOLLOWUP_COUNT=0"
fi

if ! grep -qF 'FAIL: check_05_followup_items: found zero dev/status/*.md files' "$STDERR_EMPTY"; then
  fail "expected a 'FAIL: check_05_followup_items: found zero dev/status/*.md files' line on stderr for the zero-files case, got: $(cat "$STDERR_EMPTY")"
fi

if [ -f "${FINDINGS_DIR_EMPTY}/05.findings" ] && [ -s "${FINDINGS_DIR_EMPTY}/05.findings" ]; then
  fail "check_05_followup_items.sh wrote findings (including possibly a false FOLLOWUP_COUNT=0 metric) despite dying on zero files read: $(cat "${FINDINGS_DIR_EMPTY}/05.findings")"
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL: deep_scan_followup_count_check — ${FAIL_COUNT} assertion(s) failed" >&2
  exit 1
fi

echo "OK: deep scan follow-up/open-item counter (H-FOLLOWUP-COUNT / H-FOLLOWUP-THRESHOLD-RETUNE) change-detector test passed."
