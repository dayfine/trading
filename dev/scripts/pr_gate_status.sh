#!/bin/sh
# pr_gate_status.sh -- print the merge-gate state of every open PR, and the ONE
# next action each needs.
#
# WHY THIS EXISTS
#   `.claude/rules/pr-merge-gates.md` requires three green gates per PR (CI,
#   qc-structural, qc-behavioral) *at the current tip*. Re-deriving that by hand
#   costs a dozen `gh` calls per session and gets it wrong in several specific
#   ways:
#     1. A verdict pinned to an OLD sha reads as green when a rework has since
#        moved the tip -- the gate must be re-run, not counted.
#     2. `--approve` is blocked by GitHub for self-authored PRs, so every QC
#        verdict here lands as a COMMENTED review with the word in the body.
#        A naive `state == APPROVED` check sees zero approvals, always.
#     3. (#2432) A LATER review at the SAME tip can silently supersede an
#        earlier, unresolved NEEDS_REWORK -- see "MULTI-REVIEW AGGREGATION"
#        in `_gate` below.
#     4. (#2432) The reader's own `gh` dependency is not always present in the
#        environment that runs it -- see "BACKEND SELECTION" below.
#   This script encodes all four, so the gate state is read, not remembered.
#
# USAGE
#   sh dev/scripts/pr_gate_status.sh            # all open PRs
#   sh dev/scripts/pr_gate_status.sh 2265 2280  # just these
#
# BACKEND SELECTION (#2432 defect 2)
#   This script needs to read PR lists/metadata/check-runs from GitHub. Local
#   interactive sessions have `gh` on PATH and a browser login; the GHA
#   orchestrator container (`.claude/rules/gha-local-coordination.md`) --
#   the environment the cron actually runs this script in -- has neither, only
#   `curl` + `$GH_TOKEN`. The OLD code called `gh pr list`/`gh pr view`/
#   `gh pr checks` unconditionally. Verified directly (dash AND bash, `gh`
#   genuinely absent, `set -eu` in effect): `PRS=$(gh pr list ...)` does NOT
#   silently degrade to an empty `PRS` -- the command-substitution failure
#   DOES trip `set -e` in a bare assignment, same as a failing pipeline, in
#   both shells. What actually happens is arg-dependent and still bad, just
#   not the exact shape once assumed here:
#     - No args (the orchestrator's normal invocation): dies at the `gh pr
#       list` line itself, exit 127, RAW `gh: not found` on stderr, with NO
#       table header ever printed -- already non-zero, but the message is a
#       bare shell error with no diagnosis and no remediation, easy to mistake
#       for a transient glitch and easy to lose if a wrapper swallows stderr.
#     - Explicit PR numbers (`sh pr_gate_status.sh 2265 2280`): the header +
#       separator print FIRST (that branch needs no `gh` call), THEN it dies
#       on the first PR's `gh pr view` -- a misleading PARTIAL table followed
#       by a crash, worse than either a clean crash or a clean table.
#   Either way: no explicit detection, no actionable message, and (in the
#   explicit-PR-numbers case) a misleading partial table on the way down. Two
#   runs' worth of orchestrator gate reads had to be redone by hand via REST
#   because of this.
#
#   Fix: detect the available backend explicitly (`_detect_backend`, called
#   once below the PR_GATE_STATUS_LIB guard) and FAIL LOUDLY (non-zero exit,
#   clear stderr message) if neither `gh` nor (`curl` + `$GH_TOKEN`) is usable
#   -- never print an empty table and exit 0 for that reason. When `gh` is
#   absent but curl+token are available, a REST fallback (`_list_open_prs_curl`
#   / `_pr_meta_curl` / `_pr_checks_curl`) covers the same three calls the `gh`
#   backend makes, so the script is actually usable in the GHA container, not
#   just loud about not being usable.
#
#   Override for testing: PR_GATE_STATUS_BACKEND=gh|curl forces a backend
#   regardless of what's on PATH (see pr_gate_status_test.sh's e2e probes).
#
# OUTPUT: one row per PR --
#   PR  CI  STRUCT  BEHAV  NEXT-ACTION
# where STRUCT/BEHAV are ok | rework | unclear | stale(<sha>) | none.
# "unclear" (#2432) means the gate's reviews disagree in a way this script
# will not guess through -- NEXT-ACTION reads "ADJUDICATE", never "MERGE".
#
# "unclear"'S MEASURED BASE RATE (qc-behavioral review 4991549803, B3, rework
# iteration 1 of PR #2432/#2456; CORRECTED in rework iteration 2, review
# 4991759359, F1 -- the "ALL FIVE" claim below was false, see that finding).
# Read this before assuming an ADJUDICATE row is rare or necessarily a
# #2423-shaped blind supersede.
#
#   Replaying old vs. new `_gate` over 166 gate-matching reviews across the 35
#   most-recently-updated PRs that have reviews: 5 of 70 gate reads flip
#   ok -> unclear (5 of 35 PRs, ~14%). That headline still stands -- only the
#   causal story for one of the five changed.
#
#   FOUR of the five (#2417, #2437, #2448, #2452) genuinely are the healthy
#   terminal state of a completed rework loop -- a NEEDS_REWORK followed by a
#   later APPROVED at the SAME tip, headed "final pass" / "confirmation pass"
#   / "re-review, body-only change" / "re-verdict".
#
#   #2397 is NOT a rework loop. Its tip DID move (9346b3b -> de734f2d1960),
#   exactly as the merge-gate process intends -- its `unclear` was a PARSE
#   ARTIFACT: both of its gate-matching reviews carry a 7-character "Reviewed
#   SHA", one character short of the (then) `{8,40}` capture bound, so both
#   parsed as sha-less and were treated as current-at-every-tip-forever (see
#   the MULTI-REVIEW AGGREGATION comment on `_gate` below), disagreeing
#   permanently with a real current-tip APPROVED that should have superseded
#   them cleanly. Fixed here (#2456 F2): the bound is now `{7,40}`; #2397
#   reads `ok` under it, verified against the real PR.
#
#   ZERO blind-supersedes (the actual #2423 shape) appeared in the window,
#   under either bound.
#
#   Stated plainly because it cuts against the fix: 1 in 5 observed
#   `unclear`s (#2397) was a one-character parsing bug, not a design tension
#   -- which makes the measured false-positive rate LESS defensible, not more.
#
#   The mechanism behind the OTHER four is structural, not coincidental:
#   qc-behavioral's own CP2 row
#   (`.claude/rules/qc-behavioral-authority.md`) routinely produces PR-body-only
#   findings ("your PR body advertises a test that does not exist"). Curing a
#   body-only finding cannot move the tip, because nothing in the tree changed
#   -- so the standard, CORRECT resolution of a CP2 finding always lands as
#   rework-then-approve-at-one-sha, which is exactly the shape this script
#   flags. The repo's own checklist manufactures the flagged shape on the
#   success path, more often than on the failure path it was built for.
#
#   "unclear" IS TERMINAL: no number of additional current-tip APPROVEDs clears
#   it (the aggregation's $distinct set only grows). The only exits are (a) a
#   tip-moving commit (even an empty one), or (b) `--admin` merging past the
#   reader entirely -- and (b) is precisely the habit that produced #2384 and
#   #2423 (`.claude/rules/pr-merge-gates.md` Rule 0). There is deliberately NO
#   third exit here (no label, no sentinel) that would let an operator record
#   "I adjudicated this and it's fine" without moving the tip -- that would add
#   new automation vocabulary to the merge-gate contract, which is a decision
#   for a human to make explicitly, not something this rework adds unilaterally.
#   See dev/status/harness.md for the open question.
#
#   Re-run this measurement (replay both readers over a fresh PR sample) after
#   any future change to `_gate` -- the 5/35 figure is empirical on today's
#   corpus, not a guaranteed property of the aggregation rule.
set -eu

REPO=dayfine/trading

# NOTE: every network-touching call (`gh pr list`/`pr view`/`pr checks`, or
# their curl equivalents) lives at the BOTTOM of this file, after the
# PR_GATE_STATUS_LIB guard -- not here. It used to sit at the top, which meant
# sourcing the file for the unit tests ran it before reaching the guard: the
# "offline" suite made a network call, and in CI (no `gh` on PATH) died with
# `gh: not found`, exit 127. Keep every side effect below the guard; only
# definitions (including the backend-selection functions) belong above it, so
# the offline test suite can call them directly with a stubbed PATH/env and no
# network.

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
# so read the body: find every review whose body names the gate, extract each
# one's own verdict + Reviewed SHA, then combine (see MULTI-REVIEW AGGREGATION
# below) rather than blindly trusting whichever review happens to be last.
#
# Traps hit on real reviews:
#   - Match the gate on a HEADING ("## Behavioral QC"), not on the word appearing
#     anywhere. Behavioral bodies routinely say "qc-structural already returned
#     APPROVED", so a loose match assigns the behavioral review to both gates.
#   - Anchor the gate word to the START of the heading text. Matching it anywhere
#     in a heading is not enough: on PR #2417 the *structural* review carried a
#     "### Notes for Behavioral QC" section, so its APPROVED was read as the
#     behavioral verdict too and the PR printed `pass / ok / ok  MERGE` while
#     qc-behavioral had never run. Real verdict reviews open with
#     "## <Kind> QC — ..." or "## qc-<kind>", which is what the anchor allows.
#   - The anchor-to-heading-start check above is NOT enough on its own: it says
#     nothing about WHERE in the body the matching heading sits. #2620: PR
#     #2619's structural review carried an INTERIOR heading "## Behavioral
#     equivalence verification" (legitimate structural content -- verifying a
#     find-replacement preserved an ls-pattern's behaviour) that happens to
#     START with the word "Behavioral". With zero qc-behavioral reviews
#     posted, that interior heading alone satisfied the behavioral gate and
#     the PR printed `pass / ok / ok  MERGE`. Fixed by consulting ONLY the
#     review's FIRST heading (`first_heading_text`, computed after fence
#     stripping) for gate attribution -- every interior heading, however it is
#     phrased, is prose from here on, never a gate name.
#   - Ignore headings inside FENCED CODE BLOCKS. A review that quotes another
#     review's headings as evidence would otherwise satisfy that other gate.
#     Found the hard way: qc-behavioral's review of this very PR pasted #2417's
#     heading list, and immediately satisfied the STRUCTURAL gate with it.
#   - Read the verdict from the "## Verdict" SECTION, not from the first
#     APPROVED/NEEDS_REWORK token in the body -- reviews quote each other's
#     verdicts, and the checklist rows contain the words too.
#   - Within a single review body, take the LAST unfenced "## Verdict" section,
#     not the first: a review that quotes another gate's sign-off flush left
#     (no fence needed) puts that quotation's heading above its own (#2421).
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
    # body is prose, so over-eager is the right default HERE -- but only because
    # the inline verdict fallback below was deleted. While that fallback existed,
    # over-stripping could reach a QUOTED foreign verdict and return a false
    # GREEN; an earlier version of this comment claimed the opposite and was
    # wrong. With "## Verdict" as the sole verdict source, an over-stripped body
    # that removes its OWN heading entirely usually reads "unclear" (cases
    # 17/18) -- but only when no OTHER unfenced Verdict heading survives the
    # strip. If a quoted heading sits BEFORE the point an unpaired fence starts
    # eating the rest of the body, that quoted heading is left as the sole
    # survivor and wins outright: a false "ok", not "unclear" (see probe p8 in
    # the test suite -- a known, pre-existing gap, not introduced by this fix).
    #
    # NOT a fence stack: `.inside` is a single boolean toggled by ANY fence-like
    # line, so nesting (a 4-backtick block containing a 3-backtick block) is not
    # tracked as depth. The inner-open flips `.inside` back to false, so content
    # between the inner-open and the inner-close is treated as NOT inside a
    # fence and leaks into $clean -- not, as an earlier PR body description
    # claimed, content between the outer-open and inner-open (that span is
    # still correctly stripped; see the disagreement-based mitigation below).
    def strip_fences:
      split("\n")
      | reduce .[] as $l ({out: [], inside: false};
          if ($l | test("^ *(```|~~~)")) then .inside = (.inside | not)
          elif .inside then .
          else .out += [$l] end)
      | .out | join("\n");

    # The top-level heading a review opens with -- the FIRST line matching
    # "#{1,4} <text>" in the fence-stripped body, or null if there is none.
    # Gate attribution below tests ONLY this heading, never any later one
    # (see the #2620 bullet above) -- `match` without the "g" flag yields at
    # most one result, so wrapping it in `[...]` gives a 0-or-1-element array
    # without needing a separate "no match" branch of its own.
    def first_heading_text:
      strip_fences
      | [match("(?m)^#{1,4} +(?<h>.*)$")]
      | if length == 0 then null else .[0].captures[0].string end;

    # Per-review verdict extraction. Applied to EACH review whose body names
    # this gate (not just the last one -- see MULTI-REVIEW AGGREGATION below).
    # Every read here is on the FENCE-STRIPPED body. A review that quotes
    # another review verbatim carries its "## Verdict / NEEDS_REWORK" and its
    # "Reviewed SHA" too, and reading those out of a code block attributes a
    # foreign verdict to this gate. The first version stripped fences for the
    # heading only, and case 10b in the test suite caught it immediately.
    # (No apostrophes in this jq program: it is single-quoted in sh.)
    def review_result:
      (.body | strip_fences) as $clean
      | ($clean | capture("(?i)Reviewed SHA:?[ `*]*(?<s>[0-9a-f]{7,40})").s // "") as $body_sha
      #
      # (#2626) FALLBACK TO commit_id WHEN THE BODY HAS NO "Reviewed SHA" LINE.
      # A sha-less review used to be treated as current-at-every-tip-forever
      # (see MULTI-REVIEW AGGREGATION below) -- reachable simply by an agent
      # forgetting one line of prose, no malice or mutation required. Every
      # review the GitHub API returns carries `commit_id`, the exact commit it
      # was POSTed against -- structurally present, impossible to forget the
      # way a prose line is. Fall back to it ONLY when the body yields nothing,
      # so a review can still explicitly declare it reviewed a different sha
      # than the one it was posted against (the body stays primary). This does
      # not, on its own, make the always-current path unreachable in every
      # backend: `gh pr view --json reviews` DOES supply the per-review sha,
      # but under the key `.commit.oid`, whereas this reader looks for
      # `.commit_id` -- so a sha-less LOCAL review under the gh backend still
      # falls through to "" here. The gap is a key-name mismatch, not a
      # missing field: closing it needs only a normalisation on data
      # `_pr_meta_gh` already receives (e.g. reading
      # (.commit_id // .commit.oid // "")), not a switch to the REST
      # endpoint. Only the curl/REST backend (`_pr_meta_curl`, which is what
      # the GHA orchestrator actually runs) is covered by this fallback today.
      | (if ($body_sha != "") then $body_sha else (.commit_id // "") end) as $sha
      #
      # DISAGREEING matches within ONE review body read "unclear", not
      # "whichever position wins" (#2425 rework of #2421). #2421 shipped "take
      # the LAST unfenced Verdict match" to fix a flush-left quotation sitting
      # ABOVE the real verdict -- but "first" and "last" are symmetric failure
      # modes, not a fix: `capture()` (no /g, FIRST match) lets a quotation
      # ABOVE the real verdict win; `match(...; "g") | last` lets a quotation
      # BELOW the real verdict win instead. And $clean is NOT a reliable proxy
      # for "no quoted verdict remains" -- strip_fences does not track fence
      # nesting (see its doc comment above) and does not touch HTML comments
      # or `<details>` blocks at all, so a quoted heading below the real one
      # routinely survives into $clean.
      #
      # The fix: collect EVERY unfenced "## Verdict" match in THIS body, not
      # just one.
      #   - Zero matches -> no verdict in the body -> "unclear".
      #   - Exactly one DISTINCT verdict value across all matches -> use it.
      #   - More than one DISTINCT verdict value -> the body contains an
      #     unresolved quotation with a conflicting token -- "unclear" rather
      #     than guessing which one is "the real" verdict.
      #   Differential-tested against 84 real QC review bodies pulled from the
      #   40 most-recently-updated PRs (`Reviewed SHA` stripped so the verdict
      #   surfaces): zero bodies carry disagreeing matches, so this is
      #   empirically inert on the corpus that exists today.
      #
      # STILL NOT COVERED: an unpaired fence (opens, never closes) can erase
      # the reviews OWN "## Verdict" section entirely, leaving an earlier
      # QUOTED heading as the ONLY surviving match -- one match, nothing to
      # disagree with, so it wins outright. Known, pre-existing false green
      # (not introduced by this fix); pinned as probe p8 in the test suite
      # rather than silently rediscovered later.
      #
      # `\\r` alongside `\\n` in the gap class: a CRLF review body (GitHub
      # normalises to LF on ingest, but a pasted-in body can still carry CR)
      # leaves "## Verdict\r" as the heading line, and the untouched \r
      # between it and the verdict token used to break the match entirely,
      # reading "unclear" -- fail-safe but wrong. Covered directly here since
      # it is a one-character class addition with no interaction with the
      # fence stripper (which matches fence markers, not the gap between a
      # heading and its token).
      | ( [ $clean
            | match("(?ism)^#+ +Verdict[ *`\\r\\n]+(?<v>APPROVED|NEEDS_REWORK)"; "g")
            | .captures[] | select(.name == "v") | .string
          ] | unique
        ) as $verdicts
      | ( if ($verdicts | length) == 1 then $verdicts[0] else "" end ) as $raw
      | (if $raw == "NEEDS_REWORK" then "rework"
         elif $raw == "APPROVED" then "ok"
         else "unclear" end) as $verdict
      | { sha: $sha, verdict: $verdict };

    [ .[] | select(
        (.body | first_heading_text) as $h
        | ($h != null) and ($h | test("(?i)^(qc[- ])?" + $kind + "\\b"))
      ) ]
    | if length == 0 then "none"
      else
        map(review_result) as $results
        #
        # MULTI-REVIEW AGGREGATION (#2432 defect 1). Reviews whose "Reviewed
        # SHA" does not match the current tip are stale w.r.t. this tip and
        # excluded from the decision below -- a review with no SHA field at
        # all ($sha == "") is treated as always-current.
        #
        # THIS IS NOT "same as the single-review behaviour this replaces" --
        # an earlier version of this comment said so and had it backwards
        # (qc-behavioral review 4991549803, B2). Under the OLD single-review
        # reader there was no "every tip": a sha-less review was simply
        # superseded the moment a later review landed, so it was harmless.
        # Under aggregation, "always-current" means current AT EVERY TIP,
        # FOREVER -- it can never go stale and can never be outvoted, no
        # matter how many further tips and further APPROVEDs follow. If it
        # disagrees with another current review, the gate reads "unclear"
        # permanently; the only way out is deleting the review.
        #
        # This was not hypothetical: the capture regex used to require
        # `{8,40}` hex characters, so a 7-character short sha parsed as NO
        # sha at all and hit this exact path. PR #2397 carried two
        # gate-matching reviews both opening "Reviewed SHA: 9346b3b" (7
        # chars) -- pinned in pr_gate_status_test.sh cases 37-38. FIXED
        # (#2456 F2, rework iteration 2): the bound is now `{7,40}`, a pure
        # parsing fix independent of the aggregation design -- both #2397
        # reviews now parse a real sha, go correctly stale against the tip
        # that superseded them, and the gate reads `ok`. The OTHER real fix
        # named above -- excluding sha-less reviews from aggregation
        # entirely, instead of treating them as always-current -- remains
        # deliberately deferred: it is entangled with the `unclear` design
        # question the human owns (see dev/status/harness.md), not a pure
        # parsing defect like this one was.
        #
        # (#2626) A narrower version of that deferred fix landed instead of
        # touching the aggregation logic here: `review_result` above now
        # falls back to the reviews `commit_id` field (curl/REST backend only --
        # see the comment on that fallback) whenever the body has no
        # "Reviewed SHA" line, so $sha == "" from a MISSING line is no longer
        # reachable on that backend at all -- the always-current branch below
        # still exists (a review whose commit_id ALSO comes back empty still
        # hits it), but "forgot the prose line" no longer routes through it.
        # `.sha as $s | ...` (not a bare `.sha` inline): piping a value INTO
        # `startswith(.sha)` rebinds `.` to that piped value for the rest of
        # the expression, so `.sha` there would read `.sha` OF THE PIPED VALUE
        # (a string, since $tip is a string) instead of the review objects --
        # `jq: error: Cannot index string with string "sha"`. Binding to a
        # variable first sidesteps the rebind entirely.
        | ($results | map(select(.sha as $s
                                  | $s == "" or ($tip | startswith($s)) or ($s | startswith($tip)))))
          as $current
        | if ($current | length) == 0 then
            # every matching review is stale relative to the tip -- report
            # using the LAST one, same as the pre-aggregation behaviour.
            "stale(" + ($results[-1].sha[0:8]) + ")"
          else
            ($current | map(.verdict)) as $vs
            | ($vs | unique) as $distinct
            | if ($distinct | length) == 1 then
                # All current-tip reviews for this gate agree (the overwhelming
                # common case: exactly one review). Includes the degenerate
                # case where every one of them independently read "unclear".
                $distinct[0]
              elif ($vs[-1] == "rework") then
                # The CHRONOLOGICALLY LATEST current-tip review is the one
                # that should govern -- a reviewer who re-reads and escalates
                # to NEEDS_REWORK after an earlier APPROVED is a real, safe
                # finding: report it. (Test 9, "TWO_AT_SAME_TIP": APPROVED
                # then NEEDS_REWORK -> "rework". Unaffected by this change --
                # this branch is exactly the old "last review wins" behaviour,
                # kept because it was never the unsafe direction.)
                "rework"
              else
                # The unsafe direction (#2432, PR #2423): an EARLIER
                # NEEDS_REWORK with a LATER APPROVED at the SAME tip. The old
                # "last review wins" reader took the later APPROVED at face
                # value and merged past an unresolved finding.
                #
                # A later APPROVED can be a legitimate resolution (PR #2452,
                # same morning: a body-only CP2 finding, correctly fixed
                # without moving the tip, the follow-up review explicitly
                # citing and re-verifying the prior one) OR a blind supersede
                # from an unrelated second QC pass that never saw the finding
                # (#2423 itself). Telling those apart requires reading BOTH
                # bodies and judging whether the later one actually owns the
                # earlier finding -- not reliably text-matchable (a review
                # that fails to mention the prior finding is not distinguishable
                # from one that silently overwrote it). Per the already-shipped
                # #2425 fail-safe for INTRA-body disagreement: report
                # "unclear", never "ok", and never a stuck "rework" either --
                # a human (or the next QC dispatch) adjudicates by reading both
                # review bodies, which takes about two minutes (that is
                # literally how PR #2452 got resolved by hand the same
                # morning this bug was found).
                "unclear"
              end
          end
      end'
}

# --- Backend selection (#2432 defect 2) -------------------------------------
#
# Picks which backend supplies the three GitHub reads this script needs: list
# open PRs, one PR's metadata (tip sha / files / reviews / labels), and a
# commit's check-run summary. `gh` is preferred when present (existing local
# workflow, unchanged); `curl` + `$GH_TOKEN` is the REST fallback for the GHA
# orchestrator container, which has neither `gh` nor a browser login. Neither
# available -> the caller (below the PR_GATE_STATUS_LIB guard) fails loudly
# instead of silently iterating over an empty PR list.
#
# PR_GATE_STATUS_BACKEND overrides auto-detection (used by the offline e2e
# probes in pr_gate_status_test.sh to force a backend regardless of what's
# actually on PATH).
_detect_backend() {
  if [ -n "${PR_GATE_STATUS_BACKEND:-}" ]; then
    printf '%s' "$PR_GATE_STATUS_BACKEND"
    return 0
  fi
  if command -v gh >/dev/null 2>&1; then
    printf gh
    return 0
  fi
  if command -v curl >/dev/null 2>&1 && [ -n "${GH_TOKEN:-}" ]; then
    printf curl
    return 0
  fi
  return 1
}

# --- gh backend --------------------------------------------------------------
_list_open_prs_gh() {
  gh pr list --repo "$REPO" --state open --limit 50 --json number --jq '.[].number'
}
_pr_meta_gh() {
  gh pr view "$1" --repo "$REPO" --json headRefOid,files,reviews,labels
}
_pr_checks_gh() {
  gh pr checks "$1" --repo "$REPO" 2>/dev/null | awk '{print $2}' | sort -u | tr '\n' ' '
}

# --- curl backend (REST fallback; no `gh`, needs $GH_TOKEN) ------------------
#
# Reshapes each REST response into the SAME field names the `gh --json`
# backend produces (headRefOid / files[].path / reviews[].body / labels[].name)
# so every consumer below (`_gate`, `_is_docs_only`, the do-not-merge label
# check) is backend-agnostic and unchanged.
#
# No pagination beyond a single `per_page=100` page on any of the three
# endpoints -- matches the `gh pr list --limit 50` scope this replaces, and
# PRs in this repo do not carry 100+ files/reviews/check-runs. A repo that
# grew past that would need real pagination; not a gap worth solving here.
_curl_gh() {
  curl -sS -f \
    -H "Authorization: token ${GH_TOKEN:-}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/$1"
}
_list_open_prs_curl() {
  _curl_gh "repos/$REPO/pulls?state=open&per_page=100" | jq -r '.[].number'
}
_pr_meta_curl() {
  _n=$1
  _pr=$(_curl_gh "repos/$REPO/pulls/$_n")
  _files=$(_curl_gh "repos/$REPO/pulls/$_n/files?per_page=100")
  _reviews=$(_curl_gh "repos/$REPO/pulls/$_n/reviews?per_page=100")
  jq -n --argjson pr "$_pr" --argjson files "$_files" --argjson reviews "$_reviews" '{
    headRefOid: $pr.head.sha,
    files: ($files | map({path: .filename})),
    # commit_id (#2626): the REST review payload carries the exact commit the
    # review was POSTed against. Widened here so the body-sha-fallback inside
    # `_gate` can reach it -- an earlier version projected only `.body`, which
    # silently dropped the field before it ever reached the jq that needed it.
    reviews: ($reviews | map({body: .body, commit_id: .commit_id})),
    labels: ($pr.labels | map({name: .name}))
  }'
}
_pr_checks_curl() {
  # Keyed by commit sha (the PR's tip), not PR number -- the caller already
  # has $tip from _pr_meta, so it's passed in rather than re-fetched.
  # Conclusion -> pass/fail/pending mapping mirrors the column-2 values
  # `gh pr checks` prints, which the case statement below matches on.
  _sha=$1
  _curl_gh "repos/$REPO/commits/$_sha/check-runs?per_page=100" \
    | jq -r '.check_runs[] |
        if .status != "completed" then "pending"
        elif (.conclusion == "success" or .conclusion == "neutral" or .conclusion == "skipped") then "pass"
        else "fail" end' \
    | sort -u | tr '\n' ' '
}

# --- backend-dispatching wrappers -------------------------------------------
_list_open_prs() {
  case "${_BACKEND:-}" in
    gh)   _list_open_prs_gh ;;
    curl) _list_open_prs_curl ;;
  esac
}
_pr_meta() {
  case "${_BACKEND:-}" in
    gh)   _pr_meta_gh "$1" ;;
    curl) _pr_meta_curl "$1" ;;
  esac
}
_pr_checks_summary() {
  # $1 = PR number (gh backend), $2 = tip sha (curl backend).
  case "${_BACKEND:-}" in
    gh)   _pr_checks_gh "$1" ;;
    curl) _pr_checks_curl "$2" ;;
  esac
}

# Sourcing with PR_GATE_STATUS_LIB=1 stops here, exposing every function above
# for pr_gate_status_test.sh without hitting the network. EVERYTHING BELOW THIS
# LINE IS A SIDE EFFECT and must stay below it.
[ "${PR_GATE_STATUS_LIB:-}" = 1 ] && return 0

if ! _BACKEND=$(_detect_backend); then
  {
    echo "ERROR: pr_gate_status.sh cannot read GitHub PR state."
    echo
    echo "Neither \`gh\` nor (\`curl\` + \$GH_TOKEN) is available on this"
    echo "environment. Printing an empty table and exiting 0 here would be a"
    echo "false-clean on the repo's own merge-gate reader (#2432) --"
    echo "indistinguishable from \"no open PRs need attention\". Refusing"
    echo "instead."
    echo
    echo "Fix: run where \`gh\` is authenticated, or export GH_TOKEN with"
    echo "curl on PATH for the REST fallback."
  } >&2
  exit 2
fi

if [ "$#" -gt 0 ]; then
  PRS="$*"
else
  PRS=$(_list_open_prs)
fi

printf '%-6s %-8s %-14s %-14s %s\n' PR CI STRUCT BEHAV NEXT-ACTION
printf '%s\n' "----------------------------------------------------------------------------"

for n in $PRS; do
  meta=$(_pr_meta "$n")
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
  checks=$(_pr_checks_summary "$n" "$tip")
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
    # "unclear" (#2432) must never fall through to MERGE -- surface it as an
    # explicit adjudication step, distinct from both "rework" (a concrete fix
    # is needed) and "dispatch" (nothing has run yet).
    *:unclear:*)     action="ADJUDICATE -- conflicting verdicts at $tip (structural)" ;;
    *:*:unclear)     action="ADJUDICATE -- conflicting verdicts at $tip (behavioral)" ;;
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
