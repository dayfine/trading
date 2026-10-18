#!/bin/sh
# lane_board.sh [--issue N] [--dry-run]
#
# The async "GitHub as message board" loop for the external lanes (Codex, Jules).
# Reads open PRs and issues in those lanes, decides WHOSE TURN each one is, sets
# exactly one turn/* label on it, and rewrites the board issue (#3330) body.
# No model calls: shell + gh + jq only, so it runs from a cron workflow.
# Rule: .claude/rules/async-lanes.md.
#
# Collected:
#   - open PRs labelled author/codex|author/jules, or on a codex/* | jules/* branch
#   - open issues labelled agent/codex | agent/jules
#
# Turn (first match wins), per PR:
#   theirs  a gate reads `rework`; or OUR hand-off comment (marker
#           `<!-- lane-handoff`) is newer than their last push/comment; or CI
#           is FAIL/none (they must fix or retrigger)
#   ours    CI pending, or CI green with a QC gate missing/stale/unclear
#           (the gate state comes from dev/scripts/pr_gate_status.sh)
#   merge   CI pass and both gates ok|skip
#   user    the item is NOT `merge` and nothing moved for more than STALE_H hours
# Per lane issue with no PR that mentions it:
#   theirs  handed out (marker comment present)      ours  never handed out
#   user    handed out and silent past STALE_H (never-handed-out issues are backlog,
#           not stuck, so they stay `ours`)
# "Last move" = newest of their pushes/comments and our comments/reviews. Issue
# and PR updatedAt are NOT used: this script's own label edits would reset it.
# Label per item: turn/claude (ours, merge), turn/codex, turn/jules, turn/user.
# The board gets a comment ONLY when an item newly turns user.
#
# Env: REPO, BOARD_ISSUE (3330), STALE_H (48), CAP (3), PR_GATE_STATUS (script
#      path; tests stub it), NOW (epoch seconds; tests pin it).
set -eu

REPO=${REPO:-dayfine/trading}
BOARD_ISSUE=${BOARD_ISSUE:-3330}
STALE_H=${STALE_H:-48}
CAP=${CAP:-3}
here=$(cd "$(dirname "$0")" && pwd)
GATE=${PR_GATE_STATUS:-$here/pr_gate_status.sh}
NOW=${NOW:-$(date +%s)}
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --issue) BOARD_ISSUE=$2; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "usage: lane_board.sh [--issue N] [--dry-run]" >&2; exit 2 ;;
  esac
done

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# --- 1. lane PRs -----------------------------------------------------------
gh pr list --repo "$REPO" --state open --limit 200 \
  --json number,title,body,headRefName,labels | jq '
  def lane:
    ([.labels[].name]) as $l
    | if ($l | index("author/codex")) or (.headRefName | startswith("codex/")) then "codex"
      elif ($l | index("author/jules")) or (.headRefName | startswith("jules/")) then "jules"
      else null end;
  map(. + {lane: lane}) | map(select(.lane != null))' > "$T/prs.json"

PRNUMS=$(jq -r '.[].number' "$T/prs.json" | tr '\n' ' ')

# --- 2. gate state (reuse pr_gate_status.sh) + per-PR event history --------
: > "$T/gates.jsonl"
if [ -n "$PRNUMS" ]; then
  # shellcheck disable=SC2086
  sh "$GATE" $PRNUMS 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {
    printf "{\"n\":%s,\"ci\":\"%s\",\"struct\":\"%s\",\"behav\":\"%s\"}\n", $1, $2, $3, $4 }' > "$T/gates.jsonl" || true
fi
: > "$T/views.jsonl"
for n in $PRNUMS; do
  gh pr view "$n" --repo "$REPO" --json commits,comments,reviews | jq -c --argjson n "$n" '
    {n: $n,
     commits: [.commits[].committedDate | fromdateiso8601],
     events: ([.comments[] | {t: (.createdAt | fromdateiso8601), who: (.author.login // ""), body: (.body // "")}]
            + [.reviews[] | select(.submittedAt != null)
                | {t: (.submittedAt | fromdateiso8601), who: (.author.login // ""), body: (.body // "")}])}' \
    >> "$T/views.jsonl"
done

# --- 3. lane issues --------------------------------------------------------
: > "$T/issues.jsonl"
for lane in codex jules; do
  gh issue list --repo "$REPO" --state open --label "agent/$lane" --limit 100 \
    --json number,title,labels,createdAt,comments | jq -c --arg lane "$lane" '.[] | . + {lane: $lane}' \
    >> "$T/issues.jsonl"
done

# --- 4. classify -----------------------------------------------------------
cat > "$T/classify.jq" <<'JQ'
def tmax: (map(select(. != null)) | max) // 0;
def gv: if . == null then "none" else (split("(")[0]) end;
def okish: . == "ok" or . == "skip";
def finish($now; $stale):
  (([.th, .ou] | max)) as $last
  | (if $last == 0 then 0 else (($now - $last) / 3600 | floor) end) as $idle
  | . + {idle: $idle,
         actor: (if .th > 0 and .th >= .ou then .lane else "us" end),
         turn: (if .base != "merge" and .stale_ok and $idle > $stale then "user" else .base end)}
  | . + {who: (if .turn == "theirs" then .lane
                elif .turn == "user" then "user" else "claude" end)};

$p[0] as $prs
| [ $prs[] as $p
  | (($views | map(select(.n == $p.number)) | .[0]) // {commits: [], events: []}) as $v
  | (($gates | map(select(.n == $p.number)) | .[0]) // {ci: "none", struct: "none", behav: "none"}) as $g
  | ($g.struct | gv) as $s | ($g.behav | gv) as $b
  | ($v.events | map(select(.who | test($p.lane; "i")))) as $te
  | ($v.events | map(select((.who | test($p.lane; "i")) | not))) as $oe
  | (($v.commits + ($te | map(.t))) | tmax) as $th
  | ($oe | map(.t) | tmax) as $ou
  | ($oe | map(select(.body | test("lane-handoff")) | .t) | tmax) as $ho
  | {kind: "pr", number: $p.number, title: $p.title, lane: $p.lane,
     labels: [$p.labels[].name], gates: "\($g.ci)/\($s)/\($b)",
     th: $th, ou: $ou, stale_ok: true,
     base: (if $s == "rework" or $b == "rework" then "theirs"
            elif $ho > $th then "theirs"
            elif $g.ci == "FAIL" or $g.ci == "none" then "theirs"
            elif $g.ci == "pending" then "ours"
            elif ($s | okish) and ($b | okish) then "merge"
            else "ours" end)}
  | finish($now; $stale)
]
+ [ $issues[] as $i
  | ([$prs[] | select(((.title // "") + " " + (.body // "")) | test("#\($i.number)([^0-9]|$)"))] | length) as $covered
  | select($covered == 0)
  | ($i.comments | map({t: (.createdAt | fromdateiso8601), who: (.author.login // ""), body: (.body // "")})) as $ev
  | ($ev | map(select(.who | test($i.lane; "i")) | .t) | tmax) as $th
  | ($ev | map(select((.who | test($i.lane; "i")) | not)) | map(.t)) as $ot
  | ($ev | map(select((.who | test($i.lane; "i")) | not) | select(.body | test("lane-handoff")) | .t) | tmax) as $ho
  | {kind: "issue", number: $i.number, title: $i.title, lane: $i.lane,
     labels: [$i.labels[].name], gates: "-",
     th: $th, ou: (($ot + [$i.createdAt | fromdateiso8601]) | tmax),
     stale_ok: ($ho > 0),
     base: (if $ho > 0 then "theirs" else "ours" end)}
  | finish($now; $stale)
]
JQ
jq -n -f "$T/classify.jq" --argjson now "$NOW" --argjson stale "$STALE_H" \
  --slurpfile p "$T/prs.json" --slurpfile views "$T/views.jsonl" \
  --slurpfile gates "$T/gates.jsonl" --slurpfile issues "$T/issues.jsonl" > "$T/items.json"

# --- 5. board markdown -----------------------------------------------------
{
  echo "<!-- lane-board: generated by dev/scripts/lane_board.sh; do not edit by hand -->"
  echo "Updated $(jq -rn --argjson n "$NOW" '$n | todate') by \`dev/scripts/lane_board.sh\` (rule: \`.claude/rules/async-lanes.md\`). Stale after ${STALE_H}h."
  echo
  jq -r --argjson cap "$CAP" '
    . as $all
    | ["codex", "jules"][] as $lane
    | ($all | map(select(.lane == $lane))) as $rows
    | ($rows | map(select(.kind == "pr")) | length) as $np
    | "## \($lane | ascii_upcase) lane",
      "",
      "Open PRs: \($np) of \($cap). **Can hand out: \([$cap - $np, 0] | max)**",
      "",
      "| item | title | turn | CI/struct/behav | idle h | last actor |",
      "|---|---|---|---|---:|---|",
      ($rows | sort_by(.kind, .number)[]
        | "| #\(.number) | \(.title[0:60] | gsub("\\|"; "/")) | \(.turn) | \(.gates) | \(.idle) | \(.actor) |"),
      ""' "$T/items.json"
  echo "## Stale (turn/user)"
  echo
  jq -r 'map(select(.turn == "user")) | if length == 0 then "none" else .[] | "- #\(.number) \(.title[0:60]) (\(.lane), idle \(.idle) h)" end' "$T/items.json"
} > "$T/board.md"

# --- 6. labels and board ----------------------------------------------------
NEWUSER=$(jq -r '.[] | select(.turn == "user") | select(.labels | index("turn/user") | not)
  | "- #\(.number) (\(.lane), idle \(.idle) h): \(.title[0:60])"' "$T/items.json")

if [ "$DRY" = 1 ]; then
  cat "$T/board.md"
  echo
  echo "== planned label edits"
  jq -r '.[] | "\(.kind) #\(.number) -> turn/\(.who)"' "$T/items.json"
  [ -z "$NEWUSER" ] || { echo "== would comment on #$BOARD_ISSUE"; echo "$NEWUSER"; }
  exit 0
fi

have=$(gh label list --repo "$REPO" --limit 200 --json name | jq -r '.[].name')
for l in claude codex jules user; do
  printf '%s\n' "$have" | grep -qx "turn/$l" || \
    gh label create "turn/$l" --repo "$REPO" --color 5319e7 --description "async lane board: whose move it is" || true
done

jq -r '.[] | [.kind, .number, .who, (.labels | map(select(startswith("turn/"))) | join(","))] | @tsv' "$T/items.json" |
while IFS="	" read -r kind num who cur; do
  [ "$cur" = "turn/$who" ] && continue
  sub=issue; [ "$kind" = pr ] && sub=pr
  rm_args=""
  for c in $(printf '%s' "$cur" | tr ',' ' '); do
    [ "$c" = "turn/$who" ] || rm_args="$rm_args --remove-label $c"
  done
  # shellcheck disable=SC2086
  gh "$sub" edit "$num" --repo "$REPO" --add-label "turn/$who" $rm_args
done

gh issue edit "$BOARD_ISSUE" --repo "$REPO" --body-file "$T/board.md"
if [ -n "$NEWUSER" ]; then
  gh issue comment "$BOARD_ISSUE" --repo "$REPO" --body "Needs the user (silent more than ${STALE_H}h):
$NEWUSER"
fi
