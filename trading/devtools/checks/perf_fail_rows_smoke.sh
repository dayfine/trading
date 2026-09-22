#!/bin/sh
# perf_fail_rows_smoke.sh -- fixture-driven regression test for the SHARED
# perf-tier summary.txt FAIL-row parser in dev/lib/perf_fail_rows.sh
# (issue #2891).
#
# Background: perf-nightly.yml / perf-weekly.yml / perf-tier1.yml each ran
# their perf script under `continue-on-error: true` (nightly/weekly) with
# no artifact upload at all, so a FAIL row was both invisible at the job
# level and undiagnosable after the fact -- see #2891. The fix uploads the
# per-cell logs as artifacts (already shipped for tier2/tier3 in #2894) and
# promotes FAIL rows out of the raw summary.txt table into the job summary
# and GHA `::warning::` annotations. This test pins the ONE shared parser
# all three workflows call, so a format change in one caller can't silently
# diverge from its siblings the way #2559 found five independent copies of
# the same RSS-parsing bug.
#
# Assertions against the shared helpers:
#   1. _perf_fail_row_fields extracts exactly the FAIL rows (not PASS rows,
#      not the header/divider lines) with correct scenario/wall/rss fields.
#   2. _perf_fail_row_fields on an all-PASS summary prints nothing.
#   3. _perf_failed_count reads the "  failed: N" line.
#   4. _perf_failed_count falls back to counting FAIL rows when the
#      "failed:" line is missing or malformed.
#   5. _perf_write_fail_summary emits a heading + one bullet per FAIL row,
#      and emits NOTHING when there are zero failures (no banner noise on
#      an all-green run).
#   6. _perf_emit_fail_annotations emits one `::warning::` line per FAIL
#      row, carrying the scenario name, wall, rss, and the artifact name.
#   7. Every known call site (the three perf-tier*.yml workflows) sources
#      the shared library rather than re-inlining its own awk parser --
#      the mechanical guard against the #2559-shaped regression (a fix
#      landing in one copy and failing to propagate to its siblings).
#
# Run:
#   sh trading/devtools/checks/perf_fail_rows_smoke.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="perf_fail_rows_smoke"
PASS=0
FAIL=0

ok() {
  printf 'OK: %s\n' "$1"
  PASS=$((PASS + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

REPO_ROOT_REAL="$(repo_root)"
LIB="${REPO_ROOT_REAL}/dev/lib/perf_fail_rows.sh"
[ -f "$LIB" ] || die "${LABEL}: $LIB does not exist"

. "$LIB"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

# ---------------------------------------------------------------------------
# Fixture: a realistic mixed-result summary.txt, in the exact shape
# perf_tier3_weekly.sh's SUMMARY block writes (header text + passed/failed
# counters + STATUS/SCENARIO/WALL/PEAK_RSS table).
# ---------------------------------------------------------------------------
MIXED="${WORK}/mixed_summary.txt"
cat >"$MIXED" <<'EOF'
Tier-3 perf weekly summary (2026-09-21T070000Z)
  passed: 8
  failed: 2

STATUS  SCENARIO                          WALL      PEAK_RSS
----------------------------------------------------------------------
PASS    bull-1y                            88s       125904kB
FAIL    sp500-2010-2026-longshort          4831s     715408kB
PASS    bull-3y                            210s      198552kB
FAIL    sp500-2010-2026                    4738s     716908kB
EOF

# ---------------------------------------------------------------------------
# Assertion 1: _perf_fail_row_fields extracts exactly the FAIL rows, in
# order, with correct fields -- not the PASS rows, not the header/divider.
# ---------------------------------------------------------------------------
GOT1="$(_perf_fail_row_fields "$MIXED")"
WANT1="sp500-2010-2026-longshort 4831s 715408kB
sp500-2010-2026 4738s 716908kB"
if [ "$GOT1" = "$WANT1" ]; then
  ok "${LABEL} — mixed summary: exactly the 2 FAIL rows extracted with correct fields"
else
  bad "${LABEL} — mixed summary: expected:
${WANT1}
got:
${GOT1}"
fi

# ---------------------------------------------------------------------------
# Assertion 2: an all-PASS summary yields zero FAIL rows.
# ---------------------------------------------------------------------------
ALLPASS="${WORK}/allpass_summary.txt"
cat >"$ALLPASS" <<'EOF'
Tier-1 perf smoke summary (2026-09-21T070000Z)
  passed: 4
  failed: 0

STATUS  SCENARIO                          WALL      PEAK_RSS
----------------------------------------------------------------------
PASS    bull-3m                            12s       88012kB
PASS    bull-6m                            19s       91004kB
EOF
GOT2="$(_perf_fail_row_fields "$ALLPASS")"
if [ -z "$GOT2" ]; then
  ok "${LABEL} — all-PASS summary: zero FAIL rows extracted"
else
  bad "${LABEL} — all-PASS summary: expected no output, got: ${GOT2}"
fi

# ---------------------------------------------------------------------------
# Assertion 3: _perf_failed_count reads the declared "failed: N" line.
# ---------------------------------------------------------------------------
GOT3="$(_perf_failed_count "$MIXED")"
if [ "$GOT3" = "2" ]; then
  ok "${LABEL} — mixed summary: _perf_failed_count reads 'failed: 2'"
else
  bad "${LABEL} — mixed summary: expected failed count '2', got '${GOT3}'"
fi

# ---------------------------------------------------------------------------
# Assertion 4: with the "failed:" line missing/malformed, the count falls
# back to counting FAIL rows directly rather than silently reading zero.
# ---------------------------------------------------------------------------
NOCOUNT="${WORK}/nocount_summary.txt"
cat >"$NOCOUNT" <<'EOF'
Tier-2 perf nightly summary (2026-09-21T070000Z)

STATUS  SCENARIO                          WALL      PEAK_RSS
----------------------------------------------------------------------
FAIL    crash-2020h1                       55s       102344kB
PASS    recovery-2023                      41s       97120kB
FAIL    bull-2019h2                        38s       94004kB
EOF
GOT4="$(_perf_failed_count "$NOCOUNT")"
if [ "$GOT4" = "2" ]; then
  ok "${LABEL} — missing 'failed:' line: falls back to counting 2 FAIL rows"
else
  bad "${LABEL} — missing 'failed:' line: expected fallback count '2', got '${GOT4}'"
fi

# ---------------------------------------------------------------------------
# Assertion 5a: _perf_write_fail_summary on a mixed summary emits a heading
# naming the tier label + count, plus one bullet per FAIL row.
# ---------------------------------------------------------------------------
GOT5A="$(_perf_write_fail_summary "$MIXED" "Tier-3 perf weekly")"
case "$GOT5A" in
  *"Tier-3 perf weekly: 2 scenario(s)"*) ok "${LABEL} — write_fail_summary: heading names tier label + count" ;;
  *) bad "${LABEL} — write_fail_summary: heading missing tier label/count; got: ${GOT5A}" ;;
esac
case "$GOT5A" in
  *'`sp500-2010-2026-longshort`'*'`sp500-2010-2026`'*) ok "${LABEL} — write_fail_summary: both FAIL scenarios listed as bullets" ;;
  *) bad "${LABEL} — write_fail_summary: expected both FAIL scenario bullets; got: ${GOT5A}" ;;
esac

# ---------------------------------------------------------------------------
# Assertion 5b: on an all-PASS summary, write_fail_summary emits NOTHING --
# no banner noise on a clean run.
# ---------------------------------------------------------------------------
GOT5B="$(_perf_write_fail_summary "$ALLPASS" "Tier-1 perf smoke")"
if [ -z "$GOT5B" ]; then
  ok "${LABEL} — write_fail_summary: all-PASS summary produces no output"
else
  bad "${LABEL} — write_fail_summary: expected no output on all-PASS, got: ${GOT5B}"
fi

# ---------------------------------------------------------------------------
# Assertion 6: _perf_emit_fail_annotations emits one ::warning:: line per
# FAIL row, carrying the scenario name, wall, rss, and artifact name.
# ---------------------------------------------------------------------------
GOT6="$(_perf_emit_fail_annotations "$MIXED" "perf-tier3-weekly-123456")"
LINE_COUNT6="$(printf '%s\n' "$GOT6" | grep -c '^::warning title=perf FAIL::')"
if [ "$LINE_COUNT6" = "2" ]; then
  ok "${LABEL} — emit_fail_annotations: exactly 2 ::warning:: lines emitted"
else
  bad "${LABEL} — emit_fail_annotations: expected 2 ::warning:: lines, got ${LINE_COUNT6}: ${GOT6}"
fi
case "$GOT6" in
  *"sp500-2010-2026-longshort wall=4831s rss=715408kB -- see artifact perf-tier3-weekly-123456"*)
    ok "${LABEL} — emit_fail_annotations: first row carries scenario/wall/rss/artifact"
    ;;
  *)
    bad "${LABEL} — emit_fail_annotations: expected first row content not found; got: ${GOT6}"
    ;;
esac

# ---------------------------------------------------------------------------
# Assertion 7: every perf-tier workflow sources the shared library rather
# than re-inlining its own FAIL-row awk/parsing logic. Mechanical guard
# against the #2559-shaped regression: a fix landing in one copy and
# quietly failing to propagate to its siblings.
# ---------------------------------------------------------------------------
CALL_SITES=".github/workflows/perf-tier1.yml
.github/workflows/perf-nightly.yml
.github/workflows/perf-weekly.yml"

OLD_IFS="$IFS"
IFS='
'
for rel in $CALL_SITES; do
  IFS="$OLD_IFS"
  path="${REPO_ROOT_REAL}/${rel}"
  if [ ! -f "$path" ]; then
    bad "${LABEL} — ${rel}: file does not exist"
    IFS='
'
    continue
  fi
  if grep -qE 'dev/lib/perf_fail_rows\.sh' "$path"; then
    ok "${LABEL} — ${rel}: sources the shared perf_fail_rows.sh helper"
  else
    bad "${LABEL} — ${rel}: does not reference dev/lib/perf_fail_rows.sh (re-inlined FAIL-row parsing?)"
  fi
  IFS='
'
done
IFS="$OLD_IFS"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "OK: ${LABEL} -- all assertions passed."
