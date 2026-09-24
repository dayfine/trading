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
#   14-16 CONTEXT HISTOGRAM -- the /compact-threshold question (default 250k,
#         --context-threshold overrides; #2946). Fixture context
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
#   32-37 TOTALS BY VALUE. Asserting only that the `totals` KEY EXISTS is the
#         cheerful-zero hole in its purest form: every aggregate could read 0,
#         or silently drop a whole token class, and the report still has the
#         right shape. On this fixture, dropping `cache_read` from
#         `subagent_tokens` turns 4491 into 891 (5x) and `main_tokens`
#         457063 into 7063 (65x) -- both are the figures the report prints
#         LAST and LARGEST, i.e. the ones a reader quotes. Each total is
#         pinned to a value that differs under each of its terms being lost.
#   38-42 PER-ROW FIELDS the earlier blocks do not reach: `input_tokens`
#         (pinned by value, so a zeroed column is caught), `ref` parsed from
#         the description AND its empty case (a `ref` must never be invented,
#         same discipline as `unknown` in 5-7), `wall_seconds` derived from
#         the timestamp span, and histogram `p50` (pinned to a value distinct
#         from `max`, so a percentile that silently reports the max is
#         caught).
#   43    ROWS ORDERING. `rows` is sorted largest-total-first, and that order
#         is the contract `--top` truncates against -- an inverted sort makes
#         `--top N` report the N SMALLEST dispatches under a header that says
#         otherwise.
#   44    --until, symmetric with the --since coverage in 30-31.
#   45-48 TABLE CONTENT. `table` is the DEFAULT format and the one a human
#         actually reads, so the assertions above (all JSON) leave the primary
#         renderer unpinned: it could print zeros for every headline total or
#         emit no dispatch rows at all. These pin the totals line by value,
#         the dispatch row count, and that --top truncation is both ANNOUNCED
#         (47) and APPLIED (48) -- dropping the `.rows[0:$top]` slice leaves
#         the suppression notice intact, so 47 alone does not catch it.
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

# --- 14-16: context histogram (the /compact-threshold question) -------------
expect_eq "histogram: counts one entry per main-session API call" "3" "$(q '.context_histogram.calls')"
expect_eq "histogram: default threshold is 250k" "250000" "$(q '.context_histogram.compact_threshold')"
expect_eq "histogram: calls above the default 250k counted (45001/161001/251001)" \
  "1" "$(q '.context_histogram.calls_above_threshold')"
thr() { sh "$SCRIPT" --projects-dir "$FIX/projects" --format json --context-threshold "$1" 2>/dev/null | jq -r .context_histogram.calls_above_threshold; }
expect_eq "histogram: --context-threshold 150000 counts 161001 and 251001" "2" "$(thr 150000)"
expect_eq "histogram: threshold is strict (> N): 251001 at N=251001 is not over" "0" "$(thr 251001)"
expect_eq "histogram: ... and 251000 counts it" "1" "$(thr 251000)"
set +e
sh "$SCRIPT" --projects-dir "$FIX/projects" --context-threshold 250k >"$TMP/o" 2>"$TMP/e"
expect_eq "histogram: non-integer --context-threshold is a usage error (exit 2)" "2" "$?"
sh "$SCRIPT" --projects-dir "$FIX/projects" --context-threshold 0 >"$TMP/o" 2>"$TMP/e"
expect_eq "histogram: --context-threshold 0 is a usage error (exit 2)" "2" "$?"
set -e
expect_eq "table: the above-threshold line names the threshold" "1" \
  "$(sh "$SCRIPT" --projects-dir "$FIX/projects" 2>/dev/null | grep -c '^  above 250k: 1/3 calls')"
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

# --- 32-37: totals.* BY VALUE (key presence alone is a cheerful-zero hole) --
expect_eq "totals: subagent_tokens sums all four token classes over dispatches" \
  "4491" "$(q '.totals.subagent_tokens')"
expect_eq "totals: main_tokens sums all four token classes over sessions" \
  "457063" "$(q '.totals.main_tokens')"
expect_eq "totals: api_calls spans dispatches + sessions" "8" "$(q '.totals.api_calls')"
expect_eq "totals: input_tokens spans dispatches + sessions" "24" "$(q '.totals.input_tokens')"
expect_eq "totals: cache_read spans dispatches + sessions" \
  "453600" "$(q '.totals.cache_read_input_tokens')"
expect_eq "totals: resumes aggregates the per-row resume counts" "1" "$(q '.totals.resumes')"

# --- 38-42: per-row fields not otherwise pinned ----------------------------
expect_eq "row: input_tokens is summed, not zeroed" "15" "$(row a1 .input_tokens)"
expect_eq "ref: parsed from the description" "#2922" "$(row b2 .ref)"
expect_eq "ref: a description with no #NNNN yields empty, not invented" "" "$(row c3 .ref)"
expect_eq "wall_seconds: last timestamp minus first" "630" "$(row b2 .wall_seconds)"
expect_eq "histogram: p50 is a median, not the max" "161001" "$(q '.context_histogram.p50')"

# --- 43: rows ordering (the contract --top truncates against) --------------
expect_eq "rows sorted by total tokens, largest first" \
  "a1 b2 c3" "$(q '[.rows[].agent_id] | join(" ")')"

# --- 44: --until, symmetric with the --since coverage above ----------------
set +e
sh "$SCRIPT" --projects-dir "$FIX/projects" --until 2026-09-20 --format json \
  >"$TMP/until.json" 2>&1
UNTIL_RC=$?
set -e
if [ "$UNTIL_RC" -ne 0 ]; then
  bad "--until window run failed (rc=$UNTIL_RC)"
else
  expect_eq "--until 2026-09-20 drops the later dispatch" \
    "2" "$(jq -r '.rows | length' "$TMP/until.json")"
fi

# --- 45-47: table format -- CONTENT, not just exit code --------------------
# `table` is the default format and the one a human reads; every assertion
# above runs against --format json, so without these the primary renderer is
# entirely unpinned.
sh "$SCRIPT" --projects-dir "$FIX/projects" >"$TMP/table.txt" 2>/dev/null
expect_eq "table: totals line carries the real headline figures" \
  "1" "$(grep -c 'subagent_tokens 4491   main_tokens 457063' "$TMP/table.txt")"
expect_eq "table: one line per dispatch row" \
  "3" "$(grep -cE '^2026-09-[0-9]{2} sess-main  [a-z]' "$TMP/table.txt")"
expect_eq "table: --top 1 truncates and says so" \
  "1" "$(sh "$SCRIPT" --projects-dir "$FIX/projects" --top 1 2>/dev/null \
         | grep -c 'further dispatch row(s) suppressed')"
# The line above pins that the suppression NOTICE is printed; this one pins
# that the truncation actually HAPPENED. Dropping the `.rows[0:$top]` slice
# leaves the notice intact, so the notice alone does not catch it.
expect_eq "table: --top 1 emits exactly one dispatch row" \
  "1" "$(sh "$SCRIPT" --projects-dir "$FIX/projects" --top 1 2>/dev/null \
         | grep -cE '^2026-09-[0-9]{2} sess-main  [a-z]')"

# --------------------------------------------------------------------------
printf '=== Results: %s passed, %s failed ===\n' "$PASS" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  printf 'FAIL: %s -- %s assertion(s) failed.\n' "$LABEL" "$FAILED" >&2
  exit 1
fi
printf 'OK: %s -- all %s assertions passed.\n' "$LABEL" "$PASS"
