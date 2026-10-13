#!/bin/sh
# issue_fix_audit.sh -- weekly report of issues whose fix status needs a human
# decision (issue #3019) and of issue-hygiene drift (issue #3275,
# .claude/rules/issue-hygiene.md). Reports only; it closes and edits nothing.
#
# usage: sh dev/scripts/issue_fix_audit.sh
#
# Prints the open-issue count against the cap, then six sections:
#   (a) open issues that a MERGED PR mentions, with PR numbers + merge dates.
#       Candidates to close (evidence in the close comment) or to comment on.
#   (b) every open issue labelled verify/pending, with its [after-merge]
#       conditions quoted from its "## Done when" section.
#   (c) untriaged: open issues with none of the owner labels owner/local,
#       env/cloud, agent/codex, owner/user.
#   (d) stale verify: verify/pending for more than AUDIT_STALE_VERIFY_DAYS
#       (default 14) days, measured from when the label was last added
#       (issue timeline API), else from the issue's last update.
#   (e) idle: no update for more than AUDIT_IDLE_DAYS (default 30) days.
#   (f) user decisions waiting: owner/user issues, each with the first
#       non-blank line of its latest comment (the question, by the rule).
# The cap is AUDIT_ISSUE_CAP (default 20).
#
# Limits of (a): matching is textual -- "#N" (not followed by a digit) in a
# merged PR's title or body, over the newest AUDIT_PR_LIMIT (default 500)
# merged PRs. False positives: a PR that merely cites the issue, or a bare
# number such as "issue #12" in an unrelated sentence. False negatives: a PR
# older than the window (gh orders by creation date, not merge date), and
# any open issue past the first 500. Read each hit; the report decides nothing.
#
# Limits of (b): only an H2 "## Done when" opens the section, and the next
# "## " line (even inside a code fence) closes it. A condition is a list item
# "- [after-merge] <text>"; HTML comments and empty placeholders are skipped.
#
# Limits of (d)/(e): "last update" is GitHub's updatedAt, which any comment,
# label change or edit (including a bot's) resets. (d) makes one timeline call
# per verify/pending issue; a failed call falls back to updatedAt and says so.
#
# Test seam: ISSUE_FIX_AUDIT_FIXTURE_DIR=<dir> reads <dir>/issues.json (open
# issues: number,title,labels,body,updatedAt,comments), <dir>/prs.json (merged
# PRs: number,title,body,mergedAt) and, per verify/pending issue N, the
# optional <dir>/timeline-N.json (raw timeline events) instead of calling gh.
# ISSUE_FIX_AUDIT_NOW=<ISO-8601 UTC> fixes "now" for the day counts.
set -eu

STALE_VERIFY_DAYS=${AUDIT_STALE_VERIFY_DAYS:-14}
IDLE_DAYS=${AUDIT_IDLE_DAYS:-30}
ISSUE_CAP=${AUDIT_ISSUE_CAP:-20}
NOW=${ISSUE_FIX_AUDIT_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}

if [ -n "${ISSUE_FIX_AUDIT_FIXTURE_DIR:-}" ]; then
  ISSUES=$(cat "$ISSUE_FIX_AUDIT_FIXTURE_DIR/issues.json")
  PRS=$(cat "$ISSUE_FIX_AUDIT_FIXTURE_DIR/prs.json")
else
  ISSUES=$(gh issue list --state open --limit 500 \
    --json number,title,labels,body,updatedAt,comments)
  PRS=$(gh pr list --state merged --limit "${AUDIT_PR_LIMIT:-500}" \
    --json number,title,body,mergedAt)
fi

# Raw timeline events for issue $1 on stdout; non-zero when unavailable.
_timeline() {
  if [ -n "${ISSUE_FIX_AUDIT_FIXTURE_DIR:-}" ]; then
    cat "$ISSUE_FIX_AUDIT_FIXTURE_DIR/timeline-$1.json" 2>/dev/null
  else
    gh api --paginate "repos/{owner}/{repo}/issues/$1/timeline" 2>/dev/null
  fi
}

# The merged-PR JSON (~1.6 MB for 500 PRs) goes to jq through a file, never
# argv: --argjson would exceed ARG_MAX / Linux's 128 KiB per-argument cap.
PRS_FILE=$(mktemp)
trap 'rm -f "$PRS_FILE"' EXIT
printf '%s\n' "$PRS" >"$PRS_FILE"

# Whole days from ISO timestamp to $NOW (GitHub's fractional seconds dropped).
JQ_DAYS='def days_since($now): ((($now | fromdateiso8601)
  - (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)) / 86400 | floor);'

open_count=$(printf '%s\n' "$ISSUES" | jq 'length')
if [ "$open_count" -gt "$ISSUE_CAP" ]; then
  echo "open issues: $open_count (cap $ISSUE_CAP, over by $((open_count - ISSUE_CAP)))"
else
  echo "open issues: $open_count (cap $ISSUE_CAP)"
fi

echo
echo "== (a) open issues mentioned by a merged PR =="
printf '%s\n' "$ISSUES" | jq -r --slurpfile prs "$PRS_FILE" '
  .[] | . as $i
  | ($prs[0] | map(select(((.title // "") + " " + (.body // ""))
      | test("#" + ($i.number | tostring) + "([^0-9]|$)")))) as $hits
  | select(($hits | length) > 0)
  | "#\($i.number) \($i.title) <- "
    + ($hits | map("PR #\(.number) (\((.mergedAt // "?")[0:10]))") | join(", "))'

echo
echo "== (b) verify/pending issues: [after-merge] conditions =="
printf '%s\n' "$ISSUES" | jq -r '
  .[] | select(any(.labels[]?; .name == "verify/pending"))
  | "\(.number)\t\(.title)"' | while IFS="$(printf '\t')" read -r num title; do
  echo "#$num $title"
  printf '%s\n' "$ISSUES" | jq -r --argjson n "$num" \
    '.[] | select(.number == $n) | .body // ""' | tr -d '\r' | awk '
    /<!--/ { in_c = 1 }
    in_c { if ($0 ~ /-->/) in_c = 0; next }
    /^## / { in_done = ($0 ~ /^## Done when/); next }
    in_done && /^[-*] \[after-merge\] *[^ ]/ { print "    " $0 }'
done

echo
echo "== (c) untriaged: no owner label (owner/local, env/cloud, agent/codex, owner/user) =="
printf '%s\n' "$ISSUES" | jq -r '
  .[] | select(any(.labels[]?.name;
      . == "owner/local" or . == "env/cloud" or . == "agent/codex" or . == "owner/user") | not)
  | "#\(.number) \(.title)"'

echo
echo "== (d) stale verify: verify/pending for more than $STALE_VERIFY_DAYS days =="
printf '%s\n' "$ISSUES" | jq -r '
  .[] | select(any(.labels[]?; .name == "verify/pending"))
  | "\(.number)\t\(.updatedAt // "-")\t\(.title)"' |
while IFS="$(printf '\t')" read -r num updated title; do
  since=""
  if events=$(_timeline "$num"); then
    # --paginate concatenates one array per page; -s + add rejoins them.
    since=$(printf '%s\n' "$events" | jq -rs 'add // [] | map(select(.event == "labeled"
      and .label.name == "verify/pending") | .created_at) | last // empty' 2>/dev/null || true)
  fi
  if [ -n "$since" ]; then src="label added"; else since=$updated; src="last update, no label event"; fi
  # IFS-tab read collapses empty fields, so a missing updatedAt arrives as "-".
  [ "$since" != - ] || since=""
  [ -n "$since" ] || { echo "#$num $title (no date available)"; continue; }
  days=$(jq -rn --arg t "$since" --arg now "$NOW" "$JQ_DAYS"' $t | days_since($now)')
  if [ "$days" -gt "$STALE_VERIFY_DAYS" ]; then
    echo "#$num $title -- $days days (since ${since%%T*}, $src)"
  fi
done

echo
echo "== (e) idle: no update for more than $IDLE_DAYS days =="
printf '%s\n' "$ISSUES" | jq -r --arg now "$NOW" --argjson idle "$IDLE_DAYS" "$JQ_DAYS"'
  .[] | select(.updatedAt != null)
  | (.updatedAt | days_since($now)) as $d | select($d > $idle)
  | "#\(.number) \(.title) -- \($d) days (last update \(.updatedAt[0:10]))"'

echo
echo "== (f) user decisions waiting: owner/user, latest comment =="
printf '%s\n' "$ISSUES" | jq -r '
  .[] | select(any(.labels[]?; .name == "owner/user"))
  | ((.comments // []) | last) as $c
  | "#\(.number) \(.title)\n    "
    + (if $c == null then "(no comment -- the rule wants the question in the latest comment)"
       else ($c.body // "" | gsub("\r"; "") | split("\n") | map(select(test("[^ ]")))
             | .[0] // "(empty comment)") end)'
