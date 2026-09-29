#!/bin/sh
# issue_fix_audit.sh -- weekly report of issues whose fix status needs a human
# decision (issue #3019). Reports only; it closes and edits nothing.
#
# usage: sh dev/scripts/issue_fix_audit.sh
#
# Prints two sections:
#   (a) open issues that a MERGED PR mentions, with PR numbers + merge dates.
#       Candidates to close (evidence in the close comment) or to comment on.
#   (b) every open issue labelled verify/pending, with its [after-merge]
#       conditions quoted from its "## Done when" section.
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
# Test seam: ISSUE_FIX_AUDIT_FIXTURE_DIR=<dir> reads <dir>/issues.json (open
# issues: number,title,labels,body) and <dir>/prs.json (merged PRs:
# number,title,body,mergedAt) instead of calling gh.
set -eu

if [ -n "${ISSUE_FIX_AUDIT_FIXTURE_DIR:-}" ]; then
  ISSUES=$(cat "$ISSUE_FIX_AUDIT_FIXTURE_DIR/issues.json")
  PRS=$(cat "$ISSUE_FIX_AUDIT_FIXTURE_DIR/prs.json")
else
  ISSUES=$(gh issue list --state open --limit 500 --json number,title,labels,body)
  PRS=$(gh pr list --state merged --limit "${AUDIT_PR_LIMIT:-500}" \
    --json number,title,body,mergedAt)
fi

# The merged-PR JSON (~1.6 MB for 500 PRs) goes to jq through a file, never
# argv: --argjson would exceed ARG_MAX / Linux's 128 KiB per-argument cap.
PRS_FILE=$(mktemp)
trap 'rm -f "$PRS_FILE"' EXIT
printf '%s\n' "$PRS" >"$PRS_FILE"

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
