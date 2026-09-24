#!/bin/sh
# budget_local_record.sh -- write one day's LOCAL spend record,
# dev/budget/local-<date>.json, next to the GHA orchestrator's per-run records
# (issue #2922, item 3 of 4).
#
# WHY THIS EXISTS
# ---------------
# dev/budget/<date>-<run>.json covers cron orchestrator runs only; the local
# interactive session -- where most dispatches, QC waves and chain-wait wakes
# happen -- left no committed record. token_usage_report.sh (item 1) measures
# it but prints to stdout and forgets; codex_review.sh (item 2) logs Codex
# usage to gitignored dev/_tmp/codex. This script joins both for one UTC date
# into a committed JSON record, so the weekly §Usage read (item 4) compares
# files instead of re-running anything.
#
# SHAPE (same top level as the orchestrator records where it applies)
#   run_id              "local-<date>"
#   timestamp           generation time (UTC)
#   commit_sha          HEAD of the tree it ran in, or null
#   source              "local-session"
#   measurement_source  where each block came from
#   notes               what is NOT covered (read before quoting a number)
#   totals              input/output/cache_read/cache_creation tokens (Claude,
#                       main + subagents), total_cost_usd null (transcripts
#                       carry no price), codex_* token sums, measurement
#   claude              token_usage_report.sh --format json for the date,
#                       verbatim (rows, sessions, context_histogram, totals)
#   codex               { runs, measured_runs, rows[] } from the run log
#                       reviews-<date>.log; a row recorded as tokens=na keeps
#                       null token fields -- never 0
#
# USAGE
#   sh dev/scripts/budget_local_record.sh [options]
#     --date YYYY-MM-DD    UTC date to record (default: today, UTC)
#     --projects-dir DIR   passed to token_usage_report.sh
#     --codex-log-dir DIR  default $CODEX_REVIEW_LOG_DIR, else dev/_tmp/codex
#     --out-dir DIR        default dev/budget
#     --stdout             print the record instead of writing the file
#   Re-running for the same date overwrites local-<date>.json: a record taken
#   mid-day is superseded by the end-of-session one, never appended to.
#
# EXIT CODES
#   0  record written (or printed)
#   2  usage error
#   *  token_usage_report.sh's own non-zero code (3 = no transcripts, 4 =
#      malformed): nothing is written -- a record that could not be measured
#      must not land as a zero-spend day.
set -eu

HERE=$(dirname "$0")
ROOT=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null || echo "$HERE/../..")
DATE=$(date -u +%F)
PROJECTS_ARGS=""
CODEX_LOG_DIR=${CODEX_REVIEW_LOG_DIR:-"$ROOT/dev/_tmp/codex"}
OUT_DIR="$ROOT/dev/budget"
TO_STDOUT=0

die() { printf 'FAIL: budget_local_record: %s\n' "$1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --date) [ $# -ge 2 ] || die "--date needs a value"; DATE=$2; shift 2 ;;
    --projects-dir) [ $# -ge 2 ] || die "--projects-dir needs a value"; PROJECTS_ARGS=$2; shift 2 ;;
    --codex-log-dir) [ $# -ge 2 ] || die "--codex-log-dir needs a value"; CODEX_LOG_DIR=$2; shift 2 ;;
    --out-dir) [ $# -ge 2 ] || die "--out-dir needs a value"; OUT_DIR=$2; shift 2 ;;
    --stdout) TO_STDOUT=1; shift ;;
    -h | --help) sed -n '2,/^set -eu/p' "$0" | sed 's/^# \{0,1\}//; /^set -eu/d'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
printf '%s' "$DATE" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || die "--date must be YYYY-MM-DD, got '$DATE'"
command -v jq >/dev/null 2>&1 || die "jq not on PATH"

# codex_rows LOG -> JSON array, one object per "PR SHA [fields]" line; token
# fields are null unless the line carries in=/cached=/out=/reasoning=.
codex_rows() {
  if [ ! -f "$1" ]; then echo '[]'; return 0; fi
  awk '
    function num(k,   i) { for (i = 3; i <= NF; i++) if (index($i, k "=") == 1) { v = substr($i, length(k) + 2); sub(/s$/, "", v); if (v ~ /^[0-9]+$/) return v }
                           return "null" }
    NF >= 2 {
      printf "%s{\"pr\":%s,\"sha\":\"%s\",\"input_tokens\":%s,\"cached_input_tokens\":%s,\"output_tokens\":%s,\"reasoning_output_tokens\":%s,\"wall_seconds\":%s}",
        (n++ ? "," : "["), ($1 ~ /^[0-9]+$/ ? $1 : "null"), $2,
        num("in"), num("cached"), num("out"), num("reasoning"), num("wall")
    }
    END { print (n ? "]" : "[]") }' "$1"
}

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT INT TERM
set -- --since "$DATE" --until "$DATE" --format json
[ -n "$PROJECTS_ARGS" ] && set -- "$@" --projects-dir "$PROJECTS_ARGS"
RC=0; sh "$HERE/token_usage_report.sh" "$@" > "$TMP/claude.json" || RC=$?
if [ "$RC" -ne 0 ]; then
  echo "budget_local_record: token_usage_report.sh exited $RC; no record written for $DATE" >&2
  exit "$RC"
fi
codex_rows "$CODEX_LOG_DIR/reviews-$DATE.log" > "$TMP/codex.json"

SHA=$(git -C "$HERE" rev-parse HEAD 2>/dev/null || true)
jq -n --slurpfile c "$TMP/claude.json" --slurpfile x "$TMP/codex.json" \
  --arg date "$DATE" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg sha "$SHA" '
  ($c[0]) as $cl | ($x[0]) as $cx
  | [$cx[] | select(.input_tokens != null)] as $m
  | { run_id: "local-\($date)",
      timestamp: $ts,
      commit_sha: (if $sha == "" then null else $sha end),
      source: "local-session",
      measurement_source: "claude: dev/scripts/token_usage_report.sh over local transcripts (message.usage, deduped on message.id); codex: codex_review.sh run log reviews-<date>.log (turn.completed usage)",
      notes: "Dates are UTC (a row is dated by its first record). Covers transcripts on THIS machine only; GHA runs are in dev/budget/<date>-<run>.json. No dollar figure: transcripts carry no price. Codex input_tokens include cached_input_tokens.",
      totals: {
        input_tokens: $cl.totals.input_tokens,
        output_tokens: $cl.totals.output_tokens,
        cache_read_input_tokens: $cl.totals.cache_read_input_tokens,
        cache_creation_input_tokens: $cl.totals.cache_creation_input_tokens,
        total_cost_usd: null,
        codex_input_tokens: (if ($m | length) == 0 then null else ([$m[].input_tokens] | add) end),
        codex_output_tokens: (if ($m | length) == 0 then null else ([$m[].output_tokens] | add) end),
        measurement: "measured from local transcripts + codex run log; cost not measured" },
      claude: $cl,
      codex: { runs: ($cx | length), measured_runs: ($m | length), rows: $cx } }' > "$TMP/record.json"

if [ "$TO_STDOUT" = 1 ]; then cat "$TMP/record.json"; exit 0; fi
mkdir -p "$OUT_DIR"
cp "$TMP/record.json" "$OUT_DIR/local-$DATE.json"
echo "budget_local_record: wrote $OUT_DIR/local-$DATE.json"
