#!/bin/sh
# lane_handoff.sh <PR|issue> <rework|task> [--iter N] [--dry-run]
#
# Posts the hand-off comment that addresses an external agent: `@codex` for the
# Codex lane, `@jules` for the Jules lane. Rule: .claude/rules/async-lanes.md.
#
# RUN THIS FROM A LOCAL SESSION ONLY, with the user's own `gh` login. A comment
# posted with a bot token (the workflow's GITHUB_TOKEN) may not trigger Codex or
# Jules, so lane-board.yml never calls this script.
#
#   rework  PR only. Links the latest NEEDS_REWORK review and states "rework
#           iteration N of 2". N is --iter, else 1 + the rework hand-offs
#           already on the PR. Past iteration 2 it REFUSES, labels the PR
#           turn/user and exits 1 (feat-agent-dispatch.md section 3).
#   task    issue only. Links the brief and its "Done when", names the branch
#           prefix, asks for a PR with `Closes #N` and a reply here.
#
# The comment carries `<!-- lane-handoff ... -->`, which lane_board.sh reads as
# "ours, handed out" (turn -> theirs until they push or reply).
# Env: REPO (dayfine/trading).
set -eu

REPO=${REPO:-dayfine/trading}
MAX_ITER=2

usage() { echo "usage: lane_handoff.sh <PR|issue> <rework|task> [--iter N] [--dry-run]" >&2; exit 2; }
[ $# -ge 2 ] || usage
N=$1; MODE=$2; shift 2
ITER=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --iter) ITER=$2; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) usage ;;
  esac
done
case "$MODE" in rework|task) ;; *) usage ;; esac

# PR or issue? A PR number answers `gh pr view`.
if META=$(gh pr view "$N" --repo "$REPO" --json number,labels,headRefName,url,comments 2>/dev/null); then
  SUB=pr
  BRANCH=$(printf '%s' "$META" | jq -r '.headRefName')
else
  SUB=issue
  META=$(gh issue view "$N" --repo "$REPO" --json number,labels,url,comments)
  BRANCH=""
fi
URL=$(printf '%s' "$META" | jq -r '.url')

LANE=$(printf '%s' "$META" | jq -r --arg b "$BRANCH" '
  ([.labels[].name]) as $l
  | if ($l | index("author/codex")) or ($l | index("agent/codex")) or ($b | startswith("codex/")) then "codex"
    elif ($l | index("author/jules")) or ($l | index("agent/jules")) or ($b | startswith("jules/")) then "jules"
    else "" end')
[ -n "$LANE" ] || { echo "lane_handoff: #$N is not in the codex or jules lane" >&2; exit 1; }

post() {
  if [ "$DRY" = 1 ]; then printf '%s\n' "$1"; return 0; fi
  gh "$SUB" comment "$N" --repo "$REPO" --body "$1"
}

case "$MODE" in
  rework)
    [ "$SUB" = pr ] || { echo "lane_handoff: rework needs a PR number" >&2; exit 1; }
    if [ -z "$ITER" ]; then
      PRIOR=$(printf '%s' "$META" | jq '[.comments[] | select((.body // "") | test("lane-handoff rework"))] | length')
      ITER=$((PRIOR + 1))
    fi
    if [ "$ITER" -gt "$MAX_ITER" ]; then
      echo "lane_handoff: rework iteration $ITER exceeds the cap of $MAX_ITER; leaving PR #$N for the user" >&2
      rm_args=""
      for c in $(printf '%s' "$META" | jq -r '.labels[].name | select(startswith("turn/") and . != "turn/user")'); do
        rm_args="$rm_args --remove-label $c"
      done
      if [ "$DRY" != 1 ]; then
        # shellcheck disable=SC2086
        gh pr edit "$N" --repo "$REPO" --add-label turn/user $rm_args
      fi
      exit 1
    fi
    REVIEW=$(gh api "repos/$REPO/pulls/$N/reviews" --paginate \
      --jq '[.[] | select((.body // "") | test("NEEDS_REWORK"))] | last | .html_url // empty')
    [ -n "$REVIEW" ] || REVIEW="$URL (no NEEDS_REWORK review found; read the latest review on the PR)"
    post "<!-- lane-handoff rework iter=$ITER -->
@$LANE rework iteration $ITER of $MAX_ITER on this PR.

Review to address: $REVIEW

- Address every failed item in that review. No new scope.
- Push a second commit (do not amend or force-push).
- Reply on this PR when done, so the board can hand it back to review."
    ;;
  task)
    [ "$SUB" = issue ] || { echo "lane_handoff: task needs an issue number" >&2; exit 1; }
    post "<!-- lane-handoff task -->
@$LANE please take this issue.

Brief and \`## Done when\`: $URL

- Branch prefix: \`$LANE/\`.
- Open a PR with \`Closes #$N\` (or the \`Refs #$N\` form the issue's Done when calls for).
- Reply here when the PR is open."
    ;;
esac
