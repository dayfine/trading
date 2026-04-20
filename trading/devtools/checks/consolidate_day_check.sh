#!/bin/sh
# Smoke test for dev/lib/consolidate_day.sh.
#
# Generates a minimal three-run fixture in /tmp/consolidate_day_test/,
# runs consolidate_day.sh against it, and verifies the output contains:
#   - "Runs included: run-1, run-2, run-3"
#   - dedup of a repeated Escalation (with "(seen in: ...)" suffix)
#   - distinct-outcome rows both preserved with (run-N) suffix
#   - all three per-run links
#
# Does NOT invoke the orchestrator or touch real dev/daily/ files.

set -e

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
SCRIPT="${REPO_ROOT}/dev/lib/consolidate_day.sh"

[ -f "$SCRIPT" ] || die "consolidate_day_check: $SCRIPT does not exist"

fail() {
  echo "FAIL: consolidate_day_check — $1" >&2
  exit 1
}

# ── fixture setup ─────────────────────────────────────────────────────────────
TMP_DIR="/tmp/consolidate_day_test_$$"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

DATE="2099-01-15"

# run-1
cat > "${TMP_DIR}/${DATE}.md" <<'EOF'
# Status — 2099-01-15
Run timestamp: 2099-01-15T01:00:00Z
Run ID: 2099-01-15-run-1

## Pending work

| Track | State | Branch | PR | Next step |
|-------|-------|--------|----|-----------|
| feat-alpha | in-progress | feat/alpha | #1 | Awaiting QC |

## Dispatched this run

| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| feat-alpha | feat-weinstein | completed | Initial slice. |
| feat-beta | qc-structural | APPROVED | Clean pass. |

## QC Status
- feat-alpha: PENDING
- feat-beta: **APPROVED** @ abc1234

## Budget
- Budget cap: $50.0
- Subagents spawned: 2
- Budget utilization: ~$3 / $50 (~6%)
- Any subagent killed mid-flight: No

## Escalations

1. [critical] Main build is red — dune runtest exits 1 on main.
2. [info] Orchestrator under-utilized budget.

## Integration Queue
- feat-beta (#2) — APPROVED, ready to merge.
EOF

# run-2
cat > "${TMP_DIR}/${DATE}-run2.md" <<'EOF'
# Status — 2099-01-15
Run timestamp: 2099-01-15T05:00:00Z
Run ID: 2099-01-15-run-2

## Pending work

| Track | State | Branch | PR | Next step |
|-------|-------|--------|----|-----------|
| feat-alpha | dispatched | feat/alpha | #1 | QC in progress |

## Dispatched this run

| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| feat-alpha | qc-structural | NEEDS_REWORK | P2: magic number violation. |
| feat-beta | qc-behavioral | APPROVED | Quality 4. |

## QC Status
- feat-alpha: **NEEDS_REWORK (P2)** @ def5678
- feat-beta: **APPROVED** @ abc1234 (structural + behavioral)

## Budget
- Budget cap: $50.0
- Subagents spawned: 2
- Budget utilization: ~$3 / $50 (~6%)
- Any subagent killed mid-flight: No

## Escalations

1. [critical] Main build is red — dune runtest exits 1 on main.
3. [medium] Magic number linter trips on date string in comment.

## Integration Queue
- feat-beta (#2) — APPROVED (structural + behavioral), ready to merge.
EOF

# run-3
cat > "${TMP_DIR}/${DATE}-run3.md" <<'EOF'
# Status — 2099-01-15
Run timestamp: 2099-01-15T10:00:00Z
Run ID: 2099-01-15-run-3

## Pending work

| Track | State | Branch | PR | Next step |
|-------|-------|--------|----|-----------|
| feat-alpha | re-QC | feat/alpha | #1 | Fixed magic number; re-QC dispatched |

## Dispatched this run

| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| feat-alpha | qc-structural | APPROVED | Magic number fix confirmed. |
| feat-alpha | qc-behavioral | APPROVED | Quality 5. |

## QC Status
- feat-alpha: **APPROVED** @ feed9012 (structural + behavioral)
- feat-beta: **APPROVED** @ abc1234 (merged)

## Budget
- Budget cap: $50.0
- Subagents spawned: 2
- Budget utilization: ~$3 / $50 (~6%)
- Any subagent killed mid-flight: No

## Escalations

2. [info] Orchestrator under-utilized budget.

## Integration Queue
- feat-alpha (#1) — APPROVED, ready to merge.
EOF

# ── run the script ─────────────────────────────────────────────────────────────
OUTPUT="${TMP_DIR}/${DATE}-summary.md"

# Pass the test dir as CONSOLIDATE_DAY_DIR so the script doesn't need .git root
CONSOLIDATE_DAY_DIR="$TMP_DIR" sh "$SCRIPT" "$DATE" \
  || fail "consolidate_day.sh exited non-zero"

[ -f "$OUTPUT" ] || fail "output file $OUTPUT not created"

# ── assertions ─────────────────────────────────────────────────────────────────

# 1. Runs included header
grep -q "Runs included: run-1, run-2, run-3" "$OUTPUT" \
  || fail "output missing 'Runs included: run-1, run-2, run-3'"

# 2. Deduped escalation — the critical main-build line appears in both run-1 and
#    run-2; the consolidated output should show it ONCE with "(seen in: ...)" suffix.
grep -q "seen in:" "$OUTPUT" \
  || fail "output missing dedup '(seen in: ...)' suffix for repeated escalation"

# 3. Distinct outcomes for feat-alpha / qc-structural: run-2 = NEEDS_REWORK,
#    run-3 = APPROVED; both rows should be present in the Dispatched table.
grep -q "NEEDS_REWORK" "$OUTPUT" \
  || fail "output missing NEEDS_REWORK row from run-2 feat-alpha qc-structural"
grep -q "APPROVED" "$OUTPUT" \
  || fail "output missing APPROVED row from run-3 feat-alpha qc-structural"

# 4. Per-run links section contains all three files
grep -q "run-1" "$OUTPUT" && grep -q "run-2" "$OUTPUT" && grep -q "run-3" "$OUTPUT" \
  || fail "output missing one or more per-run links"
grep -q "${DATE}.md" "$OUTPUT" \
  || fail "output missing link to ${DATE}.md (run-1)"
grep -q "${DATE}-run2.md" "$OUTPUT" \
  || fail "output missing link to ${DATE}-run2.md"
grep -q "${DATE}-run3.md" "$OUTPUT" \
  || fail "output missing link to ${DATE}-run3.md"

# 5. Budget totals — 3 runs × 2 subagents each = 6
grep -q "Total subagents spawned: 6" "$OUTPUT" \
  || fail "output total subagents should be 6 (3 runs × 2 each)"

# 6. Idempotency — re-run should overwrite without error and produce same output
FIRST_OUTPUT="$(cat "$OUTPUT")"
CONSOLIDATE_DAY_DIR="$TMP_DIR" sh "$SCRIPT" "$DATE" \
  || fail "consolidate_day.sh idempotent re-run exited non-zero"
SECOND_OUTPUT="$(cat "$OUTPUT")"
[ "$FIRST_OUTPUT" = "$SECOND_OUTPUT" ] \
  || fail "output is not idempotent — re-run produced different content"

# 7. Error on missing date arg
CONSOLIDATE_DAY_DIR="$TMP_DIR" sh "$SCRIPT" 2>/dev/null && fail "should fail on missing date arg" || true

# 8. Error on bad date format
CONSOLIDATE_DAY_DIR="$TMP_DIR" sh "$SCRIPT" "not-a-date" 2>/dev/null && fail "should fail on malformed date" || true

# 9. Error on date with no files
CONSOLIDATE_DAY_DIR="$TMP_DIR" sh "$SCRIPT" "2099-12-31" 2>/dev/null && fail "should fail when no files exist for date" || true

# ── cleanup ────────────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"

echo "OK: consolidate_day_check — all assertions passed."
