#!/bin/sh
# Change-detector test for the deep-scan follow-up / open-item counter
# (H-FOLLOWUP-COUNT). Unlike the other deep_scan_*_check.sh smoke tests in
# this directory (which are structural — they grep for implementation
# markers), this test actually INVOKES check_05_followup_items.sh and
# check_08_trends.sh against a synthetic fixture tree with a known-correct
# answer, using the REPO_ROOT env-var override that _check_lib.sh's
# repo_root() supports (see budget_rollup_check.sh for the same pattern).
#
# It pins three things that were all broken simultaneously in the
# incident this test exists for:
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
#
# Fixture layout (see _make_fixture below):
#   track-a.md — one open item under "## Backlog" (a non-Follow-up
#                heading), one closed item and one prose bullet under the
#                SAME heading, then one open + one closed item under
#                "## Follow-up / Known Improvements" (H2).
#     Expected open count: 2 (the "## Backlog" open item + the
#     "## Follow-up" open item).
#   track-b.md — one open + one closed item under "### Follow-up" (H3).
#     Expected open count: 1.
#   Fixture total: 3.
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
trap 'rm -rf "$FAKE_ROOT" "$FINDINGS_DIR" "$DETAIL_FILE"' EXIT

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

# ── Step 1: run Check 5 against the fixture ───────────────────────

FINDINGS_05="${FINDINGS_DIR}/05.findings"
: > "$FINDINGS_05"
REPO_ROOT="$FAKE_ROOT" sh "$CHECK_05" "$DETAIL_FILE" "$FINDINGS_05"

METRIC_LINE="$(grep '^M: FOLLOWUP_COUNT=' "$FINDINGS_05" || true)"
if [ "$METRIC_LINE" != "M: FOLLOWUP_COUNT=3" ]; then
  fail "expected 'M: FOLLOWUP_COUNT=3' in Check 5 findings, got: '${METRIC_LINE:-<missing>}'"
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
fi

# A warning must fire (3 items is under the threshold=10, so this should be
# an "I:" info line, not a "W:" warning — sanity-check the threshold branch
# didn't get inverted).
if grep -q '^W: ' "$FINDINGS_05"; then
  fail "3 open items should not cross the threshold=10 warning; found a W: line"
fi
if ! grep -q '^I: Open items: 3 total' "$FINDINGS_05"; then
  fail "expected an info line reporting 3 total open items"
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
  fail "Check 8 printed 'No open followup items found.' despite Check 5 counting 3 — sidecar handoff is broken"
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

# ── Step 3: threshold-crossing fixture — pins the W: warning branch ──
#
# The 3-item fixture above only ever exercises the `elif` info branch
# (check_05_followup_items.sh:92); the `if [ "$FOLLOWUP_COUNT" -gt 10 ]`
# warning branch (:90) is the ACTUAL signal the orchestrator's Step 2b
# maintenance-cycle decision reads, and it went unpinned in the original
# version of this test — inverting `-gt` to `-lt` would leave the suite
# green while flipping that signal backwards. Use a separate fixture root
# so this doesn't disturb the sidecar Step 2 above already validated.

FAKE_ROOT_WARN="$(mktemp -d)"
FINDINGS_DIR_WARN="$(mktemp -d)"
DETAIL_FILE_WARN="$(mktemp)"
trap 'rm -rf "$FAKE_ROOT" "$FINDINGS_DIR" "$DETAIL_FILE" "$FAKE_ROOT_WARN" "$FINDINGS_DIR_WARN" "$DETAIL_FILE_WARN"' EXIT

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

# Pin the W: wording, the count, and the "see 'Followup Count Detail' below"
# pointer — this is the whole point of the fixture, not just "a W: line
# exists somewhere."
WARN_LINE="$(grep '^W: Open item accumulation:' "$FINDINGS_WARN" || true)"
case "$WARN_LINE" in
  "W: Open item accumulation: 11 open"*"(threshold: 10)"*"see 'Followup Count Detail' below"*)
    ;;
  *)
    fail "expected a W: warning line for 11 open items crossing threshold=10 with the 'Followup Count Detail' pointer, got: '${WARN_LINE:-<missing>}'"
    ;;
esac

if grep -q '^I: Open items:' "$FINDINGS_WARN"; then
  fail "11 open items crosses the threshold=10; should emit W:, not also I:"
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAIL: deep_scan_followup_count_check — ${FAIL_COUNT} assertion(s) failed" >&2
  exit 1
fi

echo "OK: deep scan follow-up/open-item counter (H-FOLLOWUP-COUNT) change-detector test passed."
