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

# NOTE: the `gh pr list` that discovers open PRs lives at the BOTTOM of this
# file, after the PR_GATE_STATUS_LIB guard -- not here. It used to sit at the
# top, which meant sourcing the file for the unit tests ran it before reaching
# the guard: the "offline" suite made a network call, and in CI (no `gh` on
# PATH) died with `gh: not found`, exit 127. Keep every side effect below the
# guard; only definitions belong above it.

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
#   - Anchor the gate word to the START of the heading text. Matching it anywhere
#     in a heading is not enough: on PR #2417 the *structural* review carried a
#     "### Notes for Behavioral QC" section, so its APPROVED was read as the
#     behavioral verdict too and the PR printed `pass / ok / ok  MERGE` while
#     qc-behavioral had never run. Real verdict reviews open with
#     "## <Kind> QC — ..." or "## qc-<kind>", which is what the anchor allows.
#   - Ignore headings inside FENCED CODE BLOCKS. A review that quotes another
#     review's headings as evidence would otherwise satisfy that other gate.
#     Found the hard way: qc-behavioral's review of this very PR pasted #2417's
#     heading list, and immediately satisfied the STRUCTURAL gate with it.
#   - Read the verdict from the "## Verdict" SECTION, not from the first
#     APPROVED/NEEDS_REWORK token in the body -- reviews quote each other's
#     verdicts, and the checklist rows contain the words too.
#   - Take the LAST matching review, not the first: a rework cycle leaves the
#     superseded verdict earlier in the list.
_gate() {
  _reviews=$1; _kind=$2; _tip=$3
  printf '%s' "$_reviews" | jq -r --arg kind "$_kind" --arg tip "$_tip" '
    # Drop fenced blocks before any heading match. Line-wise rather than a
    # multiline regex so an unterminated fence degrades to "ignore the rest"
    # instead of matching across the whole body.
    # Both fence spellings, and any indent. Matching only ``` at <=3 spaces let
    # a ~~~ fence or a 4-space-indented one leak a quoted heading straight back
    # through -- the same false-green this function exists to stop, one notation
    # over. An indented fence is not a fence in strict CommonMark, but a review
    # body is prose, and being over-eager here can only produce a false RED
    # (an ignored verdict reads "unclear"), never a false green.
    def strip_fences:
      split("\n")
      | reduce .[] as $l ({out: [], inside: false};
          if ($l | test("^ *(```|~~~)")) then .inside = (.inside | not)
          elif .inside then .
          else .out += [$l] end)
      | .out | join("\n");
    [ .[] | select(.body | strip_fences
                         | test("(?im)^#{1,4} +(qc[- ])?" + $kind + "\\b")) ] | last
    | if . == null then "none"
      else
        # Every read below is on the FENCE-STRIPPED body, not just the heading
        # match. A review that quotes another review verbatim carries its
        # "## Verdict / NEEDS_REWORK" and its "Reviewed SHA" too, and reading
        # those out of a code block attributes a foreign verdict to this gate.
        # The first version stripped fences for the heading only, and case 10b
        # in the test suite caught it immediately.
        # (No apostrophes in this jq program: it is single-quoted in sh.)
        (.body | strip_fences) as $clean
        | ($clean | capture("(?i)Reviewed SHA:?[ `*]*(?<s>[0-9a-f]{8,40})").s // "") as $sha
        # Each alternative re-enters from $clean. Written as a single piped
        # chain, the second `.body` would be applied to the STRING the first
        # produced, jq would exit 5, and -- because the caller assigns bare
        # under `set -eu` -- the whole run would die mid-table. That also made
        # the inline "Verdict:" fallback and the "unclear" branch unreachable.
        # `^` anchor on the Verdict heading: without it, an INDENTED quotation
        # of another review (four spaces, so not a fence at all) supplied this
        # gate its verdict.
        | ( ($clean | capture("(?ism)^#+ +Verdict[ *`\\n]+(?<v>APPROVED|NEEDS_REWORK)").v)
            # `^` here too, for the same reason as the heading form above. Left
            # unanchored, this fallback made OVER-stripping produce a false
            # GREEN rather than the false red claimed: if the stripper eats the
            # reviews OWN "## Verdict" (a lone ~~~ separator is enough), this
            # line then matches a QUOTED foreign "Verdict: APPROVED" anywhere in
            # the body. Anchored, an over-stripped body reaches "unclear" and
            # routes to "inspect manually", which is the safe direction.
            // ($clean | capture("(?im)^Verdict:[ *`]*(?<v>APPROVED|NEEDS_REWORK)").v)
            // "" ) as $raw
        | (if $raw == "NEEDS_REWORK" then "rework"
           elif $raw == "APPROVED" then "ok"
           else "unclear" end) as $verdict
        | if ($sha == "") then $verdict
          elif ($tip | startswith($sha)) or ($sha | startswith($tip)) then $verdict
          else "stale(" + $sha[0:8] + ")"
          end
      end'
}

# Sourcing with PR_GATE_STATUS_LIB=1 stops here, exposing _gate / _is_docs_only
# for pr_gate_status_test.sh without hitting the network. EVERYTHING BELOW THIS
# LINE IS A SIDE EFFECT and must stay below it.
[ "${PR_GATE_STATUS_LIB:-}" = 1 ] && return 0

if [ "$#" -gt 0 ]; then
  PRS="$*"
else
  PRS=$(gh pr list --repo "$REPO" --state open --limit 50 --json number --jq '.[].number')
fi

printf '%-6s %-8s %-14s %-14s %s\n' PR CI STRUCT BEHAV NEXT-ACTION
printf '%s\n' "----------------------------------------------------------------------------"

for n in $PRS; do
  meta=$(gh pr view "$n" --repo "$REPO" --json headRefOid,files,reviews,labels)
  tip=$(printf '%s' "$meta" | jq -r '.headRefOid')
  files=$(printf '%s' "$meta" | jq -r '.files[].path')
  reviews=$(printf '%s' "$meta" | jq -c '.reviews')
  # A do-not-merge label is a HARD hold: it outranks every gate below, including
  # three greens. Draft status does NOT do this -- `gh pr merge --admin` merges
  # drafts without complaint and the orchestrator reads gate state, not draft
  # state, which is how #2384 merged 30 min after being drafted under an
  # explicit hold (#2396).
  held=$(printf '%s' "$meta" | jq -r '[.labels[].name] | index("do-not-merge") // empty')

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
    *)               if [ -n "$held" ]; then
                       printf '%-6s %-8s %-14s %-14s %s\n' \
                         "$n" "$ci" "$struct" "$behav" "HOLD -- do-not-merge label"
                       continue
                     fi ;;
  esac

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
