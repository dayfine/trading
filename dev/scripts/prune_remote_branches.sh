#!/bin/sh
# prune_remote_branches.sh [--apply] [--closed-days N]
#
# Lists (default) or deletes (--apply) origin branches whose work is finished:
#   - merged:  the newest PR with this head branch is MERGED;
#   - closed:  the newest PR is CLOSED unmerged and was closed more than N days ago (default 7).
# A branch is kept when it heads an open PR, has no PR at all (it may be a live experiment or a run's pinned
# branch), is protected, or its tip moved after the PR's last head commit (new work landed after the PR).
# Deleting a PR's head branch is reversible from the PR page ("Restore branch").
#
# Run weekly (.github/workflows/prune-branches-weekly.yml) and by hand. Needs gh with repo scope.
set -eu
REPO=${REPO:-dayfine/trading}
APPLY=0; CLOSED_DAYS=7
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --closed-days) CLOSED_DAYS=$2; shift ;;
    *) echo "usage: $0 [--apply] [--closed-days N]" >&2; exit 2 ;;
  esac
  shift
done
now=$(date -u +%s)
kept=0; pruned=0
for b in $(gh api "repos/$REPO/branches" --paginate --jq '.[] | select(.protected | not) | .name'); do
  [ "$b" = main ] && continue
  tip=$(gh api "repos/$REPO/branches/$b" --jq .commit.sha)
  # newest PR (any state) with this head branch: state, merged, closed_at, head sha
  pr=$(gh api "repos/$REPO/pulls?state=all&head=${REPO%%/*}:$b&per_page=1&sort=created&direction=desc" \
    --jq '.[0] | if . == null then "" else "\(.number) \(.state) \(.merged_at != null) \(.closed_at // "-") \(.head.sha)" end')
  if [ -z "$pr" ]; then echo "keep    $b (no PR)"; kept=$((kept + 1)); continue; fi
  set -- $pr; num=$1; state=$2; merged=$3; closed_at=$4; head=$5
  why=""
  if [ "$state" = open ]; then why="open PR #$num"
  elif [ "$tip" != "$head" ]; then why="tip moved after PR #$num"
  elif [ "$merged" = true ]; then :
  else
    age=$(( (now - $(date -u -j -f %Y-%m-%dT%H:%M:%SZ "$closed_at" +%s 2>/dev/null || date -u -d "$closed_at" +%s)) / 86400 ))
    [ "$age" -lt "$CLOSED_DAYS" ] && why="PR #$num closed ${age}d ago (< ${CLOSED_DAYS}d)"
  fi
  if [ -n "$why" ]; then echo "keep    $b ($why)"; kept=$((kept + 1)); continue; fi
  label=merged; [ "$merged" = true ] || label=closed
  if [ "$APPLY" = 1 ]; then
    gh api -X DELETE "repos/$REPO/git/refs/heads/$b" >/dev/null && echo "deleted $b ($label PR #$num)"
  else
    echo "prune   $b ($label PR #$num)"
  fi
  pruned=$((pruned + 1))
done
mode=dry-run; [ "$APPLY" = 1 ] && mode=applied
echo "prune_remote_branches: $mode, prune $pruned, keep $kept"
