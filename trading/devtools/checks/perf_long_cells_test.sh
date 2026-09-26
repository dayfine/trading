#!/bin/sh
# perf_long_cells_test.sh -- fixture-driven regression test for
# dev/scripts/perf_long_cells.sh (the local long-cell runtime ledger).
#
# Fixture: fixtures/perf_long_cells/dev/experiments/demo-2026-01-01/ -- one
# chain log (HEAD + cap header, five RESULT lines) and the spec of arm n0
# (a 10-year PIT top-3000 schedule).
#
# What it pins:
#   - a RESULT line becomes one row: date, experiment dir, tag, universe
#     (pit-schedule-3000), years (10.00), cap (12000), HEAD, wall, s/yr;
#   - a <no result> (guard-killed) cell is dropped, never timed;
#   - a cell whose spec is missing keeps "?" and never enters a comparison;
#   - update dedupes on (date, tag): a second update adds no rows;
#   - check exits 1 when the newest cell of a shape is > 20 % slower per
#     simulated year than that shape's median (1500 s vs median 1050 s),
#     and 0 once the tolerance is raised above the gap.
#
# Run:
#   sh trading/devtools/checks/perf_long_cells_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

PASS=0
FAILED=0
expect_eq() {
  # $1 = label, $2 = expected, $3 = actual
  if [ "$2" = "$3" ]; then
    printf 'OK: %s (%s)\n' "$1" "$3"; PASS=$((PASS + 1))
  else
    printf 'FAIL: %s: expected '\''%s'\'', got '\''%s'\''\n' "$1" "$2" "$3" >&2; FAILED=$((FAILED + 1))
  fi
}
ROOT="$(repo_root)"
SCRIPT="${ROOT}/dev/scripts/perf_long_cells.sh"
FIX="${ROOT}/trading/devtools/checks/fixtures/perf_long_cells"
LOG="${FIX}/dev/experiments/demo-2026-01-01/chain.log"
LOG2="${FIX}/dev/experiments/demo2-2026-01-02/chain.log"
[ -f "$SCRIPT" ] || { echo "FAIL: script under test not found: $SCRIPT" >&2; exit 1; }
[ -f "$LOG" ] && [ -f "$LOG2" ] || { echo "FAIL: fixture not found under $FIX" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
export PERF_LONG_LEDGER="$TMP/ledger.csv"
export PERF_LONG_YEAR=2026 PERF_LONG_GOLDEN_SPECS="${FIX}/goldens"

rows=$(sh "$SCRIPT" collect "$LOG")
expect_eq "four timed cells (the <no result> one dropped)" 4 "$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
expect_eq "row shape for n0-s0" "2026-01-01T01:00:00,demo-2026-01-01,n0-s0-v11,pit-schedule-3000,10.00,12000,abc1234,1000,100" \
  "$(printf '%s\n' "$rows" | grep ',n0-s0-v11,')"
expect_eq "missing spec keeps ?" "?,?" "$(printf '%s\n' "$rows" | grep ',missing-spec-s0,' | cut -d, -f4,5)"

rows2=$(sh "$SCRIPT" collect "$LOG2")
expect_eq "a chain that logs no cap ran at the pre-#2882 default 256" 256 "$(printf '%s\n' "$rows2" | grep ',n0-s0-v11,' | cut -d, -f6)"
expect_eq "golden <family>--<name>-new resolves under the golden spec root" "broad,5.00" \
  "$(printf '%s\n' "$rows2" | grep ',goldens-small--g1-new,' | cut -d, -f4,5)"

sh "$SCRIPT" update "$LOG" "$LOG2" >/dev/null
sh "$SCRIPT" update "$LOG" "$LOG2" >/dev/null
expect_eq "update dedupes on (timestamp, tag)" 11 "$(wc -l < "$PERF_LONG_LEDGER" | tr -d ' ')"
expect_eq "ledger is in time order" "$(tail -n +2 "$PERF_LONG_LEDGER" | cut -d, -f1 | sort | tr '\n' ' ')" \
  "$(tail -n +2 "$PERF_LONG_LEDGER" | cut -d, -f1 | tr '\n' ' ')"

rc=0; sh "$SCRIPT" check >"$TMP/check.txt" 2>"$TMP/check.err" || rc=$?
expect_eq "newest cap-12000 cell 43 % slower than its median -> exit 1" 1 "$rc"
expect_eq "check names the slow shape" 1 "$(grep -c 'SLOWER *pit-schedule-3000|10y|cap12000' "$TMP/check.txt")"
# cap is part of the shape: the cap-256 cells (500-520 s/yr) never share a
# median with the cap-12000 ones (100-150 s/yr), and the wall-0 cell is not in it
expect_eq "cap-256 shape compared on its own, wall-0 cell excluded" 1 "$(grep -c '^ok *pit-schedule-3000|10y|cap256 .* 520 s/yr vs median *500 of 1 earlier' "$TMP/check.txt")"
# the two '?' rows never form a shape (they would divide by a zero median)
expect_eq "unresolved rows never enter a comparison" "0 0" "$(grep -c '^\(ok\|SLOWER\) *?' "$TMP/check.txt") $(wc -c < "$TMP/check.err" | tr -d ' ')"
rc=0; PERF_LONG_TOLERANCE=50 sh "$SCRIPT" check >/dev/null || rc=$?
expect_eq "inside a 50 % tolerance -> exit 0" 0 "$rc"

printf '%s: %d passed, %d failed\n' "perf_long_cells_test" "$PASS" "$FAILED"
[ "$FAILED" = 0 ]
