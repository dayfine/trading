#!/bin/sh
# budget_local_record_test.sh -- fixture-driven regression test for
# dev/scripts/budget_local_record.sh (issue #2922 item 3): the committed
# dev/budget/local-<date>.json record joining the local Claude transcripts
# (token_usage_report.sh, over the SAME fixture tree its own test uses) and
# the codex_review.sh run log.
#
# What it pins:
#   - the date filter reaches token_usage_report.sh (fixture rows span
#     2026-09-19..21; recording 2026-09-21 keeps exactly one dispatch row);
#   - the orchestrator-shaped top level (run_id, source, totals with a null
#     total_cost_usd -- transcripts carry no price);
#   - codex rows: a completed line parses to numbers, a tokens=na line and a
#     bare line keep NULL tokens (never 0), and the codex totals sum only the
#     measured rows;
#   - a report failure (missing projects dir) writes NOTHING and propagates
#     the report's exit code -- an unmeasured day never lands as zero spend;
#   - the file lands at <out-dir>/local-<date>.json and a re-run overwrites.
#
# Run:
#   sh trading/devtools/checks/budget_local_record_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="budget_local_record_test"
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
SCRIPT="${ROOT}/dev/scripts/budget_local_record.sh"
FIX="${ROOT}/trading/devtools/checks/fixtures/token_usage"
[ -f "$SCRIPT" ] || { echo "FAIL: script under test not found: $SCRIPT" >&2; exit 1; }
[ -d "$FIX" ] || { echo "FAIL: fixture tree not found: $FIX" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP/codex" "$TMP/out"
{
  echo "42 aaaa in=4200 cached=4000 out=90 reasoning=30 wall=61s"
  echo "43 bbbb tokens=na events=4 wall=2s"
  echo "44 cccc"
  echo "45 dddd in=800 cached=0 out=10 reasoning=0 wall=9s"
} > "$TMP/codex/reviews-2026-09-21.log"

rec() { sh "$SCRIPT" --projects-dir "$FIX/projects" --codex-log-dir "$TMP/codex" "$@"; }

rc=0; rec --date 2026-09-21 --out-dir "$TMP/out" >/dev/null || rc=$?
expect_eq "writes the record: exit 0" 0 "$rc"
F="$TMP/out/local-2026-09-21.json"
expect_eq "file lands at <out-dir>/local-<date>.json" 1 "$([ -f "$F" ] && echo 1 || echo 0)"
expect_eq "run_id" "local-2026-09-21" "$(jq -r .run_id "$F")"
expect_eq "source" "local-session" "$(jq -r .source "$F")"
expect_eq "total_cost_usd is null, not 0" "null" "$(jq -c .totals.total_cost_usd "$F")"
expect_eq "date filter reaches the report: one dispatch row on 2026-09-21" 1 "$(jq '.claude.rows | length' "$F")"
expect_eq "claude totals carried from the report" \
  "$(jq -c '.claude.totals.output_tokens' "$F")" "$(jq -c '.totals.output_tokens' "$F")"
expect_eq "codex: all four lines are rows" 4 "$(jq .codex.runs "$F")"
expect_eq "codex: two measured rows" 2 "$(jq .codex.measured_runs "$F")"
expect_eq "codex: completed line parses" '{"pr":42,"sha":"aaaa","input_tokens":4200,"cached_input_tokens":4000,"output_tokens":90,"reasoning_output_tokens":30,"wall_seconds":61}' \
  "$(jq -c '.codex.rows[0]' "$F")"
expect_eq "codex: tokens=na keeps null tokens, keeps wall" '[null,2]' "$(jq -c '[.codex.rows[1].input_tokens, .codex.rows[1].wall_seconds]' "$F")"
expect_eq "codex: bare line keeps null tokens" "null" "$(jq -c '.codex.rows[2].output_tokens' "$F")"
expect_eq "codex totals sum measured rows only" '[5000,100]' "$(jq -c '[.totals.codex_input_tokens, .totals.codex_output_tokens]' "$F")"

rc=0; rec --date 2026-09-20 --out-dir "$TMP/out" >/dev/null || rc=$?
expect_eq "no codex log for the date: exit 0" 0 "$rc"
expect_eq "no codex log: zero runs, null codex totals" '[0,null]' \
  "$(jq -c '[.codex.runs, .totals.codex_input_tokens]' "$TMP/out/local-2026-09-20.json")"

printf '{"stale":true}\n' > "$F"
rec --date 2026-09-21 --out-dir "$TMP/out" >/dev/null
expect_eq "re-run overwrites the day's record" "local-2026-09-21" "$(jq -r .run_id "$F")"

rc=0; sh "$SCRIPT" --projects-dir "$FIX/does-not-exist" --date 2026-09-22 --out-dir "$TMP/out" >/dev/null 2>&1 || rc=$?
expect_eq "report failure propagates its exit code" 2 "$rc"
expect_eq "report failure writes nothing" 0 "$([ -f "$TMP/out/local-2026-09-22.json" ] && echo 1 || echo 0)"

rc=0; sh "$SCRIPT" --date 09-21 --stdout >/dev/null 2>&1 || rc=$?
expect_eq "malformed --date is a usage error" 2 "$rc"

printf '=== Results: %s passed, %s failed ===\n' "$PASS" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  printf 'FAIL: %s -- %s assertion(s) failed.\n' "$LABEL" "$FAILED" >&2
  exit 1
fi
printf 'OK: %s -- all %s assertions passed.\n' "$LABEL" "$PASS"
