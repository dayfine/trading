#!/bin/sh
# token_usage_report.sh -- per-dispatch and per-session token accounting read
# straight out of the local Claude Code transcripts (issue #2922, item 1 of 4).
#
# WHY THIS EXISTS
# ---------------
# We cannot see where tokens go, so we cannot optimise them. The only
# measurement that ever existed is a single hand-run audit
# (dev/notes/token-usage-audit-2026-09-08.md: main-context cache READS ~55% of
# weighted spend, subagent cache WRITES ~40%) which was never re-run because
# re-running it meant re-deriving its jq from scratch. This script is that jq,
# committed, pinned by a fixture test, and extended with the two per-dispatch
# columns the audit could not produce by hand: `resumes` (a stalled agent whose
# whole transcript is replayed for zero new output) and `outcome`.
#
# WHAT IT MEASURES (and what it cannot -- read this before quoting a number)
# -------------------------------------------------------------------------
# Measured, from `message.usage` on every assistant record, DEDUPED ON
# `message.id`:
#   input_tokens, output_tokens, cache_read_input_tokens,
#   cache_creation_input_tokens, and the API-call count.
#
#   The dedup is load-bearing, not hygiene. The transcript writes ONE RECORD
#   PER CONTENT BLOCK, and every record of a message carries the SAME `usage`
#   object -- so a message with thinking + text + tool_use appears three times
#   with identical usage. Summing raw records inflates every figure ~2x; that
#   is exactly the error the 09-08 audit shipped and had to correct in place
#   ("Correction (21:55 PT, same day) -- absolute figures above are ~2x too
#   high"). See the `dedup` assertion in the fixture test.
#
# Measured, per dispatch (one subagent transcript = one dispatch):
#   agent_type   -- `agentType` from the sibling `agent-<id>.meta.json`, else
#                   the launching Agent tool_use's `input.subagent_type`
#                   joined from the parent session transcript, else "unknown".
#   description  -- same two sources, in the same order.
#   ref          -- first `#<digits>` found in the description (the PR/issue
#                   the dispatch is about). Heuristic: it is whatever the
#                   dispatcher typed, nothing more.
#   resumes      -- count of externally-injected user prompts after the first.
#                   An injected prompt is a `type: "user"` record with NO
#                   `sourceToolAssistantUUID` and no `tool_result` block; the
#                   first such record is the dispatch brief itself, so
#                   resumes = injected_prompts - 1. A resume is therefore
#                   counted as a resume OF an existing dispatch, never as a
#                   new dispatch row -- a resumed agent continues writing to
#                   the same transcript file.
#   wall         -- last timestamp minus first timestamp, in seconds.
#   outcome      -- NEEDS_REWORK / APPROVED / a PR URL / done / stalled, in
#                   that precedence, read off the agent's final text.
#
# NOT measured -- do not infer these from this report:
#   * Dollars. Transcripts carry no price. The per-run cost records under
#     dev/budget/<date>-<run>.json carry `total_cost_usd` and this script
#     deliberately does not try to reconcile with them.
#   * Cache TTL split. `cache_creation.ephemeral_1h/5m` IS in the transcript
#     but is not broken out here; the 09-08 audit's lever 3 needs it and a
#     follow-up should add it.
#   * Anything about a session whose transcript is not on THIS machine.
#     Transcripts are local per-machine state: a GHA runner sees only the run
#     it is executing. A report run here is not a report of "all our spend".
#   * "stalled" vs "still in flight". Both look identical from the transcript
#     (it ends mid tool-loop). The outcome column says `stalled` for both; if
#     you are running this against a live session, its own agents will read
#     `stalled`. Stated plainly rather than guessed.
#
# LAYOUT IT WALKS
#   $PROJECTS_DIR/<project>/<session>.jsonl            -- main context (depth 1)
#   $PROJECTS_DIR/<project>/**/<deeper>.jsonl          -- subagents (deeper)
# Current Claude Code writes subagents to
# `<project>/<session>/subagents/agent-<id>.jsonl` plus an
# `agent-<id>.meta.json`; the 09-08 audit observed a flatter depth-2 layout.
# Both are handled: depth 1 is main, ANY greater depth is a subagent.
#
# USAGE
#   sh dev/scripts/token_usage_report.sh [options]
#     --projects-dir DIR   default $HOME/.claude/projects
#     --since YYYY-MM-DD   only rows dated >= this (UTC date of first record)
#     --until YYYY-MM-DD   only rows dated <= this
#     --format table|json  default table
#     --top N              limit the dispatch table to the N largest rows
#                          (json output is never truncated); default 0 = all
#     -h | --help
#
# EXIT CODES -- "could not measure" is never reported as "measured zero"
#   0  report produced
#   2  usage error, or --projects-dir does not exist
#   3  projects dir exists but contains no transcript at all
#   4  a transcript is malformed beyond a single partial trailing line
#
# A partial LAST line is tolerated with a warning on stderr: a transcript
# being appended to by a live session is routinely caught mid-write. Any
# malformed line that is not the last one is a hard error -- a silently
# truncated prefix would under-report every total in the file.

set -eu

PROJECTS_DIR="${HOME:-/root}/.claude/projects"
SINCE=""
UNTIL=""
FORMAT="table"
TOP=0

usage() {
  sed -n '/^# USAGE/,/^# EXIT CODES/p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

die() {
  printf 'FAIL: token_usage_report: %s\n' "$1" >&2
  exit "${2:-2}"
}

while [ $# -gt 0 ]; do
  case "$1" in
  --projects-dir)
    [ $# -ge 2 ] || die "--projects-dir needs a value"
    PROJECTS_DIR="$2"
    shift 2
    ;;
  --since)
    [ $# -ge 2 ] || die "--since needs a value"
    SINCE="$2"
    shift 2
    ;;
  --until)
    [ $# -ge 2 ] || die "--until needs a value"
    UNTIL="$2"
    shift 2
    ;;
  --format)
    [ $# -ge 2 ] || die "--format needs a value"
    FORMAT="$2"
    shift 2
    ;;
  --top)
    [ $# -ge 2 ] || die "--top needs a value"
    TOP="$2"
    shift 2
    ;;
  -h | --help) usage 0 ;;
  *) die "unknown argument: $1" ;;
  esac
done

case "$FORMAT" in
table | json) ;;
*) die "--format must be 'table' or 'json', got: $FORMAT" ;;
esac

case "$SINCE" in
"" | ????-??-??) ;;
*) die "--since must be YYYY-MM-DD, got: $SINCE" ;;
esac

case "$UNTIL" in
"" | ????-??-??) ;;
*) die "--until must be YYYY-MM-DD, got: $UNTIL" ;;
esac

case "$TOP" in
'' | *[!0-9]*) die "--top must be a non-negative integer, got: $TOP" ;;
*) ;;
esac

command -v jq >/dev/null 2>&1 || die "jq not found on PATH"

[ -d "$PROJECTS_DIR" ] || die "projects dir does not exist: $PROJECTS_DIR" 2

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

# ---------------------------------------------------------------------------
# jq programs
# ---------------------------------------------------------------------------

# Shared prelude: dedupe assistant records on message.id and sum usage.
JQ_PRELUDE=$(
  cat <<'PRELUDE'
def iso2epoch: if . == null then null else (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) end;

def usage_msgs:
  [ .[]
    | select(.type == "assistant" and (.message | type) == "object"
              and .message.id != null and (.message.usage | type) == "object")
    | { id: .message.id,
        input: (.message.usage.input_tokens // 0),
        output: (.message.usage.output_tokens // 0),
        cache_read: (.message.usage.cache_read_input_tokens // 0),
        cache_creation: (.message.usage.cache_creation_input_tokens // 0) } ]
  | unique_by(.id);

def totals_of:
  { api_calls: length,
    input_tokens: (map(.input) | add // 0),
    output_tokens: (map(.output) | add // 0),
    cache_read_input_tokens: (map(.cache_read) | add // 0),
    cache_creation_input_tokens: (map(.cache_creation) | add // 0) };

def first_ts: [ .[] | .timestamp | select(. != null) ] | first;
def last_ts:  [ .[] | .timestamp | select(. != null) ] | last;
def day_of:   (first_ts // "") | .[0:10];

def wall_seconds:
  (first_ts | iso2epoch) as $a | (last_ts | iso2epoch) as $b
  | if $a == null or $b == null then 0 else ($b - $a) end;

# An externally injected prompt: a user record that is NOT a tool_result
# reply. The first one is the dispatch brief; later ones are resumes.
def injected_prompts:
  [ .[]
    | select(.type == "user" and .sourceToolAssistantUUID == null)
    | select((((.message // {}) | if type == "object" then (.content // []) else [] end)
              | if type == "array"
                then ([ .[] | if type == "object" then .type else "" end ] | index("tool_result"))
                else null end) == null) ]
  | length;

def assistant_texts:
  [ .[] | select(.type == "assistant" and (.message | type) == "object")
        | .message.content[]? | select(type == "object" and .type == "text") | .text ];

# Blocks belonging to the LAST assistant message. A final message that still
# carries a tool_use means the agent was mid-loop when the transcript ended.
def final_blocks:
  ([ .[] | select(.type == "assistant" and (.message | type) == "object")
          | .message.id ] | last) as $last
  | if $last == null then []
    else [ .[] | select(.type == "assistant" and (.message | type) == "object"
                        and .message.id == $last)
                | .message.content[]? | select(type == "object") | .type ] end;

def outcome:
  (assistant_texts | last // "") as $t
  | final_blocks as $fb
  | if ($t | test("NEEDS_REWORK")) then "NEEDS_REWORK"
    elif ($t | test("\\bAPPROVED\\b")) then "APPROVED"
    elif ($t | test("https://github\\.com/[^ )\\]]+/pull/[0-9]+"))
      then ($t | capture("(?<u>https://github\\.com/[^ )\\]]+/pull/[0-9]+)") | .u)
    elif (($fb | index("text")) != null and ($fb | index("tool_use")) == null) then "done"
    else "stalled" end;
PRELUDE
)

# Per-project dispatch index built from the MAIN transcripts:
#   agentId -> { agent_type, description, session }
# Used when a subagent transcript has no sibling .meta.json (the older layout).
JQ_DISPATCH_INDEX=$(
  cat <<'IDX'
  ([ .[] | select(.type == "assistant" and (.message | type) == "object")
         | .message.content[]?
         | select(type == "object" and .type == "tool_use" and .name == "Agent")
         | { key: .id,
             value: { agent_type: (.input.subagent_type // "unknown"),
                      description: (.input.description // "") } } ]
   | from_entries) as $byTool
| [ .[] | select((.toolUseResult | type) == "object" and .toolUseResult.agentId != null)
        | { agent_id: .toolUseResult.agentId,
            tool_use_id: ([ .message.content[]? | select(type == "object")
                          | .tool_use_id | select(. != null) ] | first),
            description: (.toolUseResult.description // "") } ]
| map({ key: .agent_id,
        value: { agent_type: ((($byTool[.tool_use_id // ""]) // {}).agent_type // "unknown"),
                 description: (if (.description | length) > 0
                               then .description
                               else ((($byTool[.tool_use_id // ""]) // {}).description // "") end),
                 session: $session } })
| from_entries
IDX
)

JQ_SESSION=$(
  cat <<'SESS'
usage_msgs as $m
| ($m | map(.input + .cache_read + .cache_creation)) as $ctx
| { kind: "session",
    session: $session,
    date: day_of,
    wall_seconds: wall_seconds,
    dispatches_launched:
      ([ .[] | select(.type == "assistant" and (.message | type) == "object")
             | .message.content[]?
             | select(type == "object" and .type == "tool_use" and .name == "Agent") ] | length),
    context_sizes: $ctx }
  + ($m | totals_of)
SESS
)

JQ_DISPATCH=$(
  cat <<'DISP'
{ kind: "dispatch",
  session: $session,
  agent_id: $agent_id,
  agent_type: $agent_type,
  description: $description,
  ref: (if ($description | test("#[0-9]+"))
        then ($description | capture("(?<r>#[0-9]+)") | .r) else "" end),
  date: day_of,
  wall_seconds: wall_seconds,
  resumes: ([injected_prompts - 1, 0] | max),
  outcome: outcome }
+ (usage_msgs | totals_of)
DISP
)

# ---------------------------------------------------------------------------
# Transcript normalisation: validate and emit the valid record prefix.
# ---------------------------------------------------------------------------
# `jq -c .` stops at the FIRST parse error, so the number of records it emits
# is exactly the count of good leading lines. Comparing that to the count of
# non-blank input lines localises the first bad line without a second parser.
normalise() {
  # $1 = source transcript, $2 = destination normalised jsonl
  n_total=$(awk 'NF {n++} END {print n + 0}' "$1")
  jq -c . "$1" >"$2" 2>/dev/null || true
  n_parsed=$(awk 'END {print NR + 0}' "$2")
  if [ "$n_total" -eq 0 ]; then
    return 0
  fi
  if [ "$n_parsed" -eq "$n_total" ]; then
    return 0
  fi
  if [ "$n_parsed" -eq $((n_total - 1)) ] && [ "$n_parsed" -gt 0 ]; then
    printf 'WARN: token_usage_report: %s has a partial trailing line (live session?); using its first %s records.\n' \
      "$1" "$n_parsed" >&2
    return 0
  fi
  die "malformed transcript $1: parsed $n_parsed of $n_total records (first bad line is not the last)" 4
}

in_window() {
  # $1 = YYYY-MM-DD of the row
  if [ -n "$SINCE" ] && [ "$1" \< "$SINCE" ]; then return 1; fi
  if [ -n "$UNTIL" ] && [ "$UNTIL" \< "$1" ]; then return 1; fi
  return 0
}

# ---------------------------------------------------------------------------
# Walk
# ---------------------------------------------------------------------------

: >"$WORK/rows.jsonl"
FOUND=0

for proj in "$PROJECTS_DIR"/*; do
  [ -d "$proj" ] || continue
  echo '{}' >"$WORK/index.json"

  # Pass 1 -- main transcripts (depth 1) build the dispatch index.
  for f in "$proj"/*.jsonl; do
    [ -f "$f" ] || continue
    FOUND=1
    sess=$(basename "$f" .jsonl)
    normalise "$f" "$WORK/norm.jsonl"
    jq -s --arg session "$sess" "$JQ_DISPATCH_INDEX" "$WORK/norm.jsonl" >"$WORK/idx_one.json"
    jq -s '.[0] * .[1]' "$WORK/index.json" "$WORK/idx_one.json" >"$WORK/index.next"
    mv "$WORK/index.next" "$WORK/index.json"
    jq -s --arg session "$sess" "$JQ_PRELUDE $JQ_SESSION" "$WORK/norm.jsonl" >"$WORK/row.json"
    day=$(jq -r '.date' "$WORK/row.json")
    if in_window "$day"; then cat "$WORK/row.json" >>"$WORK/rows.jsonl"; fi
  done

  # Pass 2 -- everything deeper is a subagent transcript, one row per dispatch.
  find "$proj" -mindepth 2 -name '*.jsonl' -type f 2>/dev/null | sort >"$WORK/subs.txt"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    FOUND=1
    base=$(basename "$f" .jsonl)
    agent_id=${base#agent-}
    sess=$(basename "$(dirname "$f")")
    if [ "$sess" = "subagents" ]; then sess=$(basename "$(dirname "$(dirname "$f")")"); fi
    meta="$(dirname "$f")/$base.meta.json"
    a_type=""
    a_desc=""
    if [ -f "$meta" ]; then
      a_type=$(jq -r '.agentType // ""' "$meta" 2>/dev/null || echo "")
      a_desc=$(jq -r '.description // ""' "$meta" 2>/dev/null || echo "")
    fi
    if [ -z "$a_type" ] || [ "$a_type" = "null" ]; then
      a_type=$(jq -r --arg id "$agent_id" '(.[$id].agent_type) // "unknown"' "$WORK/index.json")
    fi
    if [ -z "$a_desc" ] || [ "$a_desc" = "null" ]; then
      a_desc=$(jq -r --arg id "$agent_id" '(.[$id].description) // ""' "$WORK/index.json")
    fi
    normalise "$f" "$WORK/norm.jsonl"
    jq -s --arg session "$sess" --arg agent_id "$agent_id" \
      --arg agent_type "$a_type" --arg description "$a_desc" \
      "$JQ_PRELUDE $JQ_DISPATCH" "$WORK/norm.jsonl" >"$WORK/row.json"
    day=$(jq -r '.date' "$WORK/row.json")
    if in_window "$day"; then cat "$WORK/row.json" >>"$WORK/rows.jsonl"; fi
  done <"$WORK/subs.txt"
done

[ "$FOUND" -eq 1 ] || die "no transcripts (*.jsonl) found under $PROJECTS_DIR" 3

# ---------------------------------------------------------------------------
# Assemble the report
# ---------------------------------------------------------------------------

JQ_REPORT=$(
  cat <<'REP'
def sum_class($rows; $k): ($rows | map(.[$k]) | add) // 0;
def pct($n; $d): if $d == 0 then 0 else (($n * 1000 / $d) | floor) / 10 end;
def bucket($c):
  if   $c <  50000 then "0-50k"
  elif $c < 100000 then "50-100k"
  elif $c < 150000 then "100-150k"
  elif $c < 200000 then "150-200k"
  elif $c < 300000 then "200-300k"
  elif $c < 500000 then "300-500k"
  else "500k+" end;
def at_pct($sorted; $p):
  if ($sorted | length) == 0 then 0
  else $sorted[ ((($sorted | length) - 1) * $p / 100) | floor ] end;

[ .[] | select(.kind == "dispatch") ] as $disp
| [ .[] | select(.kind == "session") ] as $sess
| ($sess | map(.context_sizes) | add // []) as $ctx
| ($ctx | sort) as $ctxs
| ($ctx | length) as $nctx
| ($ctx | map(select(. > 150000)) | length) as $over
| ["0-50k","50-100k","100-150k","150-200k","200-300k","300-500k","500k+"] as $labels
| ($ctx | map(bucket(.)) | group_by(.) | map({key: .[0], value: length}) | from_entries) as $hist
| { date: ((($disp + $sess) | map(.date) | max) // ""),
    source: "local-transcripts",
    generated_at: $now,
    projects_dir: $projects_dir,
    window: { since: $since, until: $until },
    totals: {
      dispatches: ($disp | length),
      sessions: ($sess | length),
      resumes: (sum_class($disp; "resumes")),
      api_calls: (sum_class($disp + $sess; "api_calls")),
      input_tokens: (sum_class($disp + $sess; "input_tokens")),
      output_tokens: (sum_class($disp + $sess; "output_tokens")),
      cache_read_input_tokens: (sum_class($disp + $sess; "cache_read_input_tokens")),
      cache_creation_input_tokens: (sum_class($disp + $sess; "cache_creation_input_tokens")),
      subagent_tokens: (sum_class($disp; "input_tokens") + sum_class($disp; "output_tokens")
                        + sum_class($disp; "cache_read_input_tokens")
                        + sum_class($disp; "cache_creation_input_tokens")),
      main_tokens: (sum_class($sess; "input_tokens") + sum_class($sess; "output_tokens")
                    + sum_class($sess; "cache_read_input_tokens")
                    + sum_class($sess; "cache_creation_input_tokens"))
    },
    context_histogram: {
      calls: $nctx,
      p50: at_pct($ctxs; 50),
      p90: at_pct($ctxs; 90),
      max: ($ctx | max // 0),
      calls_above_150k: $over,
      share_above_150k_pct: pct($over; $nctx),
      buckets: [ $labels[] | { label: ., calls: ($hist[.] // 0),
                               share_pct: pct(($hist[.] // 0); $nctx) } ]
    },
    rows: ($disp | sort_by(-(.cache_read_input_tokens + .cache_creation_input_tokens
                             + .input_tokens + .output_tokens))),
    sessions: ($sess | map(del(.context_sizes))) }
REP
)

NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
jq -s --arg now "$NOW" --arg projects_dir "$PROJECTS_DIR" \
  --arg since "$SINCE" --arg until "$UNTIL" \
  "$JQ_REPORT" "$WORK/rows.jsonl" >"$WORK/report.json"

if [ "$FORMAT" = "json" ]; then
  cat "$WORK/report.json"
  exit 0
fi

JQ_TABLE=$(
  cat <<'TBL'
def pad($s; $n): ($s | tostring) as $t
  | if ($t | length) >= $n then $t[0:$n] else $t + (" " * ($n - ($t | length))) end;
def rpad($s; $n): ($s | tostring) as $t
  | if ($t | length) >= $n then $t[0:$n] else ((" " * ($n - ($t | length))) + $t) end;
def hm: (. | floor) as $s | "\(($s / 3600) | floor)h\((($s % 3600) / 60) | floor)m";

"=== token usage: \(.projects_dir)  window[\(.window.since // "-")..\(.window.until // "-")]  generated \(.generated_at)",
"",
"--- dispatches (one row per subagent transcript) ---",
(pad("date"; 10) + " " + pad("session"; 10) + " " + pad("agent_type"; 20) + " "
 + pad("ref"; 7) + " " + rpad("res"; 3) + " " + rpad("wall"; 7) + " "
 + rpad("calls"; 5) + " " + rpad("input"; 8) + " " + rpad("output"; 8) + " "
 + rpad("cache_rd"; 11) + " " + rpad("cache_wr"; 10) + " " + pad("outcome"; 14) + " description"),
( (if $top > 0 then .rows[0:$top] else .rows end)[]
  | pad(.date; 10) + " " + pad(.session; 10) + " " + pad(.agent_type; 20) + " "
    + pad(.ref; 7) + " " + rpad(.resumes; 3) + " " + rpad((.wall_seconds | hm); 7) + " "
    + rpad(.api_calls; 5) + " " + rpad(.input_tokens; 8) + " " + rpad(.output_tokens; 8) + " "
    + rpad(.cache_read_input_tokens; 11) + " " + rpad(.cache_creation_input_tokens; 10) + " "
    + pad(.outcome; 14) + " " + (.description | .[0:52]) ),
(if ($top > 0 and (.rows | length) > $top)
 then "  ... \((.rows | length) - $top) further dispatch row(s) suppressed by --top \($top)"
 else empty end),
"",
"--- main-context sessions ---",
(pad("date"; 10) + " " + pad("session"; 12) + " " + rpad("calls"; 5) + " "
 + rpad("disp"; 4) + " " + rpad("input"; 8) + " " + rpad("output"; 8) + " "
 + rpad("cache_rd"; 12) + " " + rpad("cache_wr"; 10)),
( .sessions[]
  | pad(.date; 10) + " " + pad(.session; 12) + " " + rpad(.api_calls; 5) + " "
    + rpad(.dispatches_launched; 4) + " " + rpad(.input_tokens; 8) + " "
    + rpad(.output_tokens; 8) + " " + rpad(.cache_read_input_tokens; 12) + " "
    + rpad(.cache_creation_input_tokens; 10) ),
"",
"--- context size per main-session API call (is /compact at ~150k happening?) ---",
( .context_histogram.buckets[]
  | "  " + pad(.label; 10) + rpad(.calls; 6) + "  " + rpad(.share_pct; 5) + "%" ),
"  ----",
"  p50 \(.context_histogram.p50)  p90 \(.context_histogram.p90)  max \(.context_histogram.max)",
"  above 150k: \(.context_histogram.calls_above_150k)/\(.context_histogram.calls) calls (\(.context_histogram.share_above_150k_pct)%)",
"",
"--- totals ---",
"  dispatches \(.totals.dispatches)   sessions \(.totals.sessions)   resumes \(.totals.resumes)   api_calls \(.totals.api_calls)",
"  input \(.totals.input_tokens)   output \(.totals.output_tokens)   cache_read \(.totals.cache_read_input_tokens)   cache_creation \(.totals.cache_creation_input_tokens)",
"  subagent_tokens \(.totals.subagent_tokens)   main_tokens \(.totals.main_tokens)"
TBL
)

jq -r --argjson top "$TOP" "$JQ_TABLE" "$WORK/report.json"
