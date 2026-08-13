#!/bin/sh
# pr_gate_status.sh -- print the merge-gate state of every open PR, and the ONE
# next action each needs.
#
# WHY THIS EXISTS
#   `.claude/rules/pr-merge-gates.md` requires three green gates per PR (CI,
#   qc-structural, qc-behavioral) *at the current tip*. Re-deriving that by hand
#   costs a dozen `gh` calls per session and gets it wrong in two specific ways:
#     1. A verdict pinned to an OLD sha reads as green when a rework has since
#        moved the tip -- the gate must be re-run, not counted.
#     2. `--approve` is blocked by GitHub for self-authored PRs, so every QC
#        verdict here lands as a COMMENTED review with the word in the body.
#        A naive `state == APPROVED` check sees zero approvals, always.
#   This script encodes both, so the gate state is read, not remembered.
#
# USAGE
#   sh dev/scripts/pr_gate_status.sh            # all open PRs
#   sh dev/scripts/pr_gate_status.sh 2265 2280  # just these
#
# OUTPUT: one row per PR --
#   PR  CI  STRUCT  BEHAV  NEXT-ACTION
# where STRUCT/BEHAV are ok | rework | stale(<sha>) | none, and stale means a
# verdict exists but at a sha that is no longer the tip.
set -eu

REPO=dayfine/trading

if [ "$#" -gt 0 ]; then
  PRS="$*"
else
  PRS=$(gh pr list --repo "$REPO" --state open --limit 50 --json number --jq '.[].number')
fi

# A PR is docs-only (both QC gates skipped, per pr-merge-gates.md) when every
# path is *.md or under the doc dirs. Anything else -- including experiment
# .sexp fixtures -- takes the full three gates.
_is_docs_only() {
  _files=$1
  for f in $_files; do
    case "$f" in
      *.md) ;;
      dev/notes/*|dev/plans/*|dev/reviews/*|dev/status/*) ;;
      *) return 1 ;;
    esac
  done
  return 0
}

# Verdict for one gate at the current tip. QC reviews are COMMENTED (see header),
# so read the body: find the review whose body names the gate, take the last one,
# and compare its "Reviewed SHA" against the tip.
#
# Two traps, both hit on real reviews:
#   - Match the gate on a HEADING ("## Behavioral QC"), not on the word appearing
#     anywhere. Behavioral bodies routinely say "qc-structural already returned
#     APPROVED", so a loose match assigns the behavioral review to both gates.
#   - Read the verdict from the "## Verdict" SECTION, not from the first
#     APPROVED/NEEDS_REWORK token in the body -- reviews quote each other's
#     verdicts, and the checklist rows contain the words too.
_gate() {
  _reviews=$1; _kind=$2; _tip=$3
  printf '%s' "$_reviews" | jq -r --arg kind "$_kind" --arg tip "$_tip" '
    [ .[] | select(.body | test("(?im)^#{1,4} +.*\\b" + $kind + "\\b")) ] | last
    | if . == null then "none"
      else
        (.body | capture("(?i)Reviewed SHA:?[ `*]*(?<s>[0-9a-f]{8,40})").s // "") as $sha
        | (.body | capture("(?is)#+ +Verdict[ *`\\n]+(?<v>APPROVED|NEEDS_REWORK)").v
             // (.body | capture("(?i)Verdict:[ *`]*(?<v>APPROVED|NEEDS_REWORK)").v)
             // "") as $raw
        | (if $raw == "NEEDS_REWORK" then "rework"
           elif $raw == "APPROVED" then "ok"
           else "unclear" end) as $verdict
        | if ($sha == "") then $verdict
          elif ($tip | startswith($sha)) or ($sha | startswith($tip)) then $verdict
          else "stale(" + $sha[0:8] + ")"
          end
      end'
}

printf '%-6s %-8s %-14s %-14s %s\n' PR CI STRUCT BEHAV NEXT-ACTION
printf '%s\n' "----------------------------------------------------------------------------"

for n in $PRS; do
  meta=$(gh pr view "$n" --repo "$REPO" --json headRefOid,files,reviews)
  tip=$(printf '%s' "$meta" | jq -r '.headRefOid')
  files=$(printf '%s' "$meta" | jq -r '.files[].path')
  reviews=$(printf '%s' "$meta" | jq -c '.reviews')

  # CI: pending anywhere beats fail beats pass -- never merge on non-pass.
  checks=$(gh pr checks "$n" --repo "$REPO" 2>/dev/null | awk '{print $2}' | sort -u | tr '\n' ' ')
  case "$checks" in
    *pending*) ci=pending ;;
    *fail*)    ci=FAIL ;;
    *pass*)    ci=pass ;;
    *)         ci=none ;;
  esac

  if _is_docs_only "$files"; then
    struct=skip; behav=skip
  else
    struct=$(_gate "$reviews" "structural" "$tip")
    behav=$(_gate "$reviews" "behavioral" "$tip")
  fi

  # One next action, in dependency order: CI first, then structural (behavioral
  # does not run until structural is APPROVED), then behavioral, then merge.
  case "$ci:$struct:$behav" in
    FAIL:*)          action="fix CI -- do not merge" ;;
    pending:*)       action="wait for CI" ;;
    *:rework:*)      action="rework (structural findings)" ;;
    *:*:rework)      action="rework (behavioral findings)" ;;
    *:none:*)        action="dispatch qc-structural" ;;
    *:stale*:*)      action="re-run qc-structural at $tip" ;;
    *:ok:none)       action="dispatch qc-behavioral" ;;
    *:ok:stale*)     action="re-run qc-behavioral at $tip" ;;
    pass:ok:ok)      action="MERGE" ;;
    pass:skip:skip)  action="MERGE (docs-only)" ;;
    *)               action="inspect manually" ;;
  esac

  printf '%-6s %-8s %-14s %-14s %s\n' "$n" "$ci" "$struct" "$behav" "$action"
done
