#!/bin/sh
# token_usage_report_test.sh -- fixture-driven regression test for
# dev/scripts/token_usage_report.sh (issue #2922, item 1).
#
# HERMETIC BY CONSTRUCTION. Every invocation passes an explicit
# `--projects-dir` pointing into
# `trading/devtools/checks/fixtures/token_usage/`; the real `~/.claude/projects`
# tree is never read. That tree is per-machine local state -- it does not exist
# on a CI runner, and where it does exist it is different on every run, so a
# test that touched it would be both non-reproducible and vacuous.
#
# WHY THESE ASSERTIONS AND NOT OTHERS
# -----------------------------------
# Each one pins a way the report could silently produce a wrong number that
# still LOOKS like a report. Cheerful-zero and double-counting are the two
# failure shapes that matter here, because nobody re-derives a token figure by
# hand to check it -- that is the entire reason this script exists.
#
#   1-4   message.id DEDUP. The transcript writes ONE RECORD PER CONTENT BLOCK,
#         each carrying the SAME `usage` object. `agent-a1.jsonl` contains
#         THREE assistant records but only TWO distinct message ids: msg_a1
#         appears twice (text block + tool_use block) with identical usage.
#         Without the dedup every one of its four token classes reads ~1.7x
#         high. This is not hypothetical -- it is the correction the 09-08
#         hand audit had to publish against itself ("absolute figures above
#         are ~2x too high").
#   5-7   AGENT-TYPE ATTRIBUTION and its precedence. a1 has BOTH a sibling
#         meta.json (`qc-behavioral`) and a launching Agent tool_use in the
#         parent transcript (`qc-structural`) -- deliberately DIFFERENT, so
#         the assertion pins which one wins (the meta, being the per-agent
#         record) rather than passing under either. b2 has no meta.json at
#         all and must fall back to the parent-transcript join. c3 has
#         neither and must read `unknown`, never an invented type.
#   8-10  RESUME accounting. b2's transcript carries a second externally
#         injected prompt (the "please continue" nudge after a stall). That
#         must increment `resumes` on the EXISTING row, never add a row --
#         a resumed agent keeps writing to the same transcript file, so
#         counting it as a new dispatch would both inflate the dispatch count
#         and hide the replay cost this column exists to expose.
#   11-13 OUTCOME classification, including `stalled` for a transcript that
#         ends mid tool-loop (c3).
#   14-16 CONTEXT HISTOGRAM -- the /compact-at-150k question. Fixture context
#         sizes are 45001 / 161001 / 251001, one per bucket, so a bucket
#         boundary error shows up as a specific bucket, not as a vague total.
#   17-20 LOUD FAILURE on absent / empty / malformed input. A missing dir, a
#         dir with no transcripts, and a mid-file parse error must each exit
#         non-zero with a distinct code. "Could not measure" reported as
#         "measured zero" is the single most dangerous output this script
#         could produce.
#   21-22 PARTIAL TRAILING LINE is tolerated with a WARNING (a live session is
#         routinely caught mid-write) and the valid prefix is still counted.
#   23-26 ARGUMENT VALIDATION.
#   27-29 JSON output shape -- the keys item 3 of #2922 will need to write
#         dev/budget/local-<date>.json.
#   30-31 WINDOW FILTERING, including that the agent-type join still works for
#         a row whose parent session record is OUTSIDE the window (the index
#         is built before filtering).
#
# Run:
#   sh trading/devtools/checks/token_usage_report_test.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="token_usage_report_test"
PASS=0
FAILED=0

ok() {
  printf 'OK: %s\n' "$1"
  PASS=$((PASS + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1" >&2
  FAILED=$((FAILED + 1))
}

expect_eq() {
  # $1 = label, $2 = expected, $3 = actual
  if [ "$2" = "$3" ]; then
    ok "$1 ($3)"
  else
    bad "$1: expected '$2', got '$3'"
  fi
}

ROOT="$(repo_root)"
SCRIPT="${ROOT}/dev/scripts/token_usage_report.sh"
FIX="${ROOT}/trading/devtools/checks/fixtures/token_usage"

[ -f "$SCRIPT" ] || die "script under test not found: $SCRIPT"
[ -d "$FIX" ] || die "fixture tree not found: $FIX"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# --------------------------------------------------------------------------
# Baseline run over the good fixture tree.
# --------------------------------------------------------------------------
set +e
sh "$SCRIPT" --projects-dir "$FIX/projects" --format json >"$TMP/good.json" 2>"$TMP/good.err"
GOOD_RC=$?
set -e
expect_eq "good fixture exits 0" "0" "$GOOD_RC"

if [ "$GOOD_RC" -ne 0 ]; then
  printf 'FAIL: %s -- baseline run failed, remaining assertions are meaningless:\n' "$LABEL" >&2
  cat "$TMP/good.err" >&2
  exit 1
fi

q() { jq -r "$1" "$TMP/good.json"; }
row() { jq -r --arg id "$1" '.rows[] | select(.agent_id == $id) | '"$2" "$TMP/good.json"; }

# --- 1-4: message.id dedup -------------------------------------------------
# agent-a1.jsonl holds 3 assistant records / 2 distinct message ids.
RAW_A1=$(grep -c '"type":"assistant"' "$FIX/projects/proj-demo/sess-main/subagents/agent-a1.jsonl")
expect_eq "fixture agent-a1 really has 3 raw assistant records" "3" "$RAW_A1"
expect_eq "dedup: agent-a1 api_calls counts messages not records" "2" "$(row a1 .api_calls)"
expect_eq "dedup: agent-a1 cache_read not doubled by the repeated msg_a1" \
  "3000" "$(row a1 .cache_read_input_tokens)"
expect_eq "dedup: agent-a1 output not doubled by the repeated msg_a1" \
  "150" "$(row a1 .output_tokens)"

# --- 5-7: agent_type attribution ------------------------------------------
expect_eq "attribution: sibling meta.json agentType wins over the tool_use join" \
  "qc-behavioral" "$(row a1 .agent_type)"
expect_eq "attribution: no meta.json falls back to Agent tool_use subagent_type" \
  "harness-maintainer" "$(row b2 .agent_type)"
expect_eq "attribution: neither source available reads 'unknown', not invented" \
  "unknown" "$(row c3 .agent_type)"

# --- 8-10: resumes ---------------------------------------------------------
expect_eq "resume: a second injected prompt increments resumes" "1" "$(row b2 .resumes)"
expect_eq "resume: a normal tool-loop transcript has zero resumes" "0" "$(row a1 .resumes)"
expect_eq "resume: a resume is NOT counted as an extra dispatch row" \
  "3" "$(q '.rows | length')"

# --- 11-13: outcome --------------------------------------------------------
expect_eq "outcome: APPROVED read from the final text" "APPROVED" "$(row a1 .outcome)"
expect_eq "outcome: NEEDS_REWORK read from the final text" "NEEDS_REWORK" "$(row b2 .outcome)"
expect_eq "outcome: transcript ending mid tool-loop reads 'stalled'" \
  "stalled" "$(row c3 .outcome)"

# --- 14-16: context histogram (the /compact-at-150k question) --------------
expect_eq "histogram: counts one entry per main-session API call" "3" "$(q '.context_histogram.calls')"
expect_eq "histogram: calls above 150k counted (45001/161001/251001)" \
  "2" "$(q '.context_histogram.calls_above_150k')"
expect_eq "histogram: 45001 lands in the 0-50k bucket" \
  "1" "$(q '.context_histogram.buckets[] | select(.label == "0-50k") | .calls')"

# --- 17-20: loud failure ---------------------------------------------------
set +e
sh "$SCRIPT" --projects-dir "$FIX/does-not-exist" >"$TMP/o" 2>"$TMP/e"
expect_eq "absent projects dir exits 2" "2" "$?"
set -e
if grep -q '^FAIL: token_usage_report' "$TMP/e"; then
  ok "absent projects dir prints a FAIL: line"
else
  bad "absent projects dir printed no FAIL: line"
fi

set +e
sh "$SCRIPT" --projects-dir "$FIX/empty" >"$TMP/o" 2>"$TMP/e"
expect_eq "projects dir with no transcripts exits 3 (not a cheerful zero)" "3" "$?"
sh "$SCRIPT" --projects-dir "$FIX/malformed-mid" >"$TMP/o" 2>"$TMP/e"
expect_eq "malformed mid-file transcript exits 4" "4" "$?"
set -e

# --- 21-22: partial trailing line ------------------------------------------
set +e
sh "$SCRIPT" --projects-dir "$FIX/partial-tail" --format json >"$TMP/tail.json" 2>"$TMP/tail.err"
expect_eq "partial trailing line still produces a report (exit 0)" "0" "$?"
set -e
if grep -q 'partial trailing line' "$TMP/tail.err"; then
  ok "partial trailing line warns on stderr"
else
  bad "partial trailing line produced no WARN on stderr"
fi
expect_eq "partial trailing line: the valid 2-record prefix is still counted" \
  "2" "$(jq -r '.sessions[0].api_calls' "$TMP/tail.json")"

# --- 23-26: argument validation --------------------------------------------
set +e
sh "$SCRIPT" --projects-dir "$FIX/projects" --format yaml >/dev/null 2>&1
expect_eq "--format yaml is rejected" "2" "$?"
sh "$SCRIPT" --projects-dir "$FIX/projects" --since 2026-9-1 >/dev/null 2>&1
expect_eq "--since with a non-ISO date is rejected" "2" "$?"
sh "$SCRIPT" --projects-dir "$FIX/projects" --top x >/dev/null 2>&1
expect_eq "--top with a non-integer is rejected" "2" "$?"
sh "$SCRIPT" --frobnicate >/dev/null 2>&1
expect_eq "an unknown argument is rejected" "2" "$?"
set -e

# --- 27-29: JSON shape (what #2922 item 3 will write to dev/budget/) -------
expect_eq "json: source names the measurement surface" "local-transcripts" "$(q .source)"
expect_eq "json: date is the newest row date" "2026-09-21" "$(q .date)"
MISSING=$(q '["date","source","totals","rows"] - (. | keys) | join(",")')
expect_eq "json: dev/budget-compatible top-level keys all present" "" "$MISSING"

# --- 30-31: window filtering -----------------------------------------------
set +e
sh "$SCRIPT" --projects-dir "$FIX/projects" --since 2026-09-21 --format json >"$TMP/win.json" 2>&1
WIN_RC=$?
set -e
if [ "$WIN_RC" -ne 0 ]; then
  bad "--since window run failed (rc=$WIN_RC)"
else
  expect_eq "--since 2026-09-21 keeps only the one later dispatch" \
    "1" "$(jq -r '.rows | length' "$TMP/win.json")"
  expect_eq "--since: agent_type join survives its parent session being filtered out" \
    "harness-maintainer" "$(jq -r '.rows[0].agent_type' "$TMP/win.json")"
fi

# --------------------------------------------------------------------------
printf '=== Results: %s passed, %s failed ===\n' "$PASS" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  printf 'FAIL: %s -- %s assertion(s) failed.\n' "$LABEL" "$FAILED" >&2
  exit 1
fi
printf 'OK: %s -- all %s assertions passed.\n' "$LABEL" "$PASS"
