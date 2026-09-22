#!/bin/sh
# orchestrator_fastexit_gate.sh -- mechanical backstop for A-FASTEXIT-VACUOUS
# (issue #2579).
#
# WHY THIS EXISTS
#   `.claude/agents/lead-orchestrator.md` Step 0.5 has a "Precondition -- the
#   queue must be non-empty" block (added 2026-08-02 to fix A-FASTEXIT-VACUOUS):
#   if the open orchestrator-PR queue is empty, the no-op fast-exit must NOT
#   fire -- an empty queue means a full pass is required, not that the queue is
#   saturated. That block is PROSE inside an agent-instructions file. Run
#   33063628087 (2026-08-27) proved prose does not bind: the orchestrator took
#   the no-op path with an empty PR queue AND with dev/status/ drift since the
#   prior summary -- both of the fast-exit's own gates said "do a full pass" --
#   and nothing caught it. See issue #2579.
#
#   Per `.claude/rules/pr-merge-gates.md` Rule 0's lesson ("anything that must
#   not happen while nobody is watching has to be expressed in the vocabulary
#   automation reads"), this script moves the precondition out of agent
#   judgment and into a mechanical check `.github/workflows/orchestrator.yml`
#   runs independently of the model:
#
#     1. BEFORE the orchestrator agent runs, the workflow calls
#        `open_pr_count` and injects the number into the agent's prompt as a
#        computed fact ("QUEUE_NON_EMPTY=<n>") -- so the agent does not have
#        to compute it itself and cannot silently drop the precondition. This
#        layer alone is still prose-adjacent (the agent could still ignore
#        the fact), so it is not the enforcement -- see (2).
#     2. AFTER the orchestrator agent finishes, the workflow calls
#        `verify <summary-path>` on the daily summary it wrote. If the
#        summary declares NO-OP mode (`**Mode:** NO-OP`) while the open-PR
#        queue is empty, or while dev/status/*.md changed since the prior
#        summary (Condition 2), `verify` exits non-zero and the workflow
#        FAILS THE JOB. This is the actual backstop: it does not depend on
#        the model reading or obeying anything.
#
# USAGE
#   dev/scripts/orchestrator_fastexit_gate.sh open_pr_count
#       Prints the number of currently-open PRs in the repo. Used both as the
#       pre-run prompt-injection fact and internally by `verify`.
#
#   dev/scripts/orchestrator_fastexit_gate.sh status_changed_since <iso-ts>
#       Prints the count of dev/status/ file touches by a commit since
#       <iso-ts>, excluding orchestrator summary-landing commits. This is
#       Step 0.5 Condition 2's check, exposed as a single source of truth --
#       see the `_status_changed_since` comment below for why the inline
#       grep-pipeline version this replaced did not actually implement its
#       own documented exemption.
#
#   dev/scripts/orchestrator_fastexit_gate.sh prior_summary_iso [current-summary-path]
#       Prints the selected prior summary's commit timestamp, falling back to
#       mtime only for an uncommitted file; empty when no prior summary exists.
#   dev/scripts/orchestrator_fastexit_gate.sh verify <summary-path> [expected-date]
#       FIRST, regardless of mode: checks that <summary-path> is actually
#       dated the run it is being verified for (see "STALE-SUMMARY CHECK"
#       below) and FAILS (exit 1) if it is not -- this runs before, and
#       independently of, everything below, since a stale summary makes the
#       mode-specific checks meaningless (they'd be validating the wrong
#       file). <expected-date> is an optional override of the date verify
#       compares against (see that section for the full resolution order);
#       every existing one-argument call site is unaffected.
#
#       Then, if it is NO-OP-mode, independently recomputes the open-PR count
#       and the dev/status/ drift since the prior summary and FAILS (exit 1,
#       with an `::error::` line per violation) if either contradicts the
#       no-op claim. If it is FULL-mode, checks BOTH that the summary was
#       actually PUBLISHED (see "FULL-MODE PUBLICATION CHECK" below) AND that
#       its claimed dispatches produced artifacts (see "FULL-MODE
#       DISPATCH-ARTIFACT CHECK" below), and FAILS if either check fails
#       (exit 2 if either check could not be determined, i.e. failed closed).
#       Neither NO-OP nor FULL: prints a note and exits 0 (nothing this
#       script knows how to check for that mode string). Exits 0 only when
#       every applicable check (or lack of one) confirms nothing is wrong.
#
# STALE-SUMMARY CHECK (issue #2850)
#   All the checks below this one assume `verify` was handed the CORRECT
#   summary for the run being evaluated. That assumption broke on run
#   35096884441 (2026-09-16): `actions/checkout` sets every tracked file's
#   mtime to checkout time, so `ls -t dev/daily/*.md` has no real ordering
#   information left and GNU `ls` falls back to name-ascending -- returning
#   the OLDEST file, not the newest, everywhere this repo's tooling uses that
#   idiom to mean "newest". The workflow's own locate-summary fallback hit
#   this exact trap: no dev/daily/2026-09-16*.md existed (the orchestrator
#   agent turn wrote no summary that run), the fallback glob picked
#   dev/daily/2026-09-14.md -- two days stale -- and `verify` validated it
#   as though it were today's run, reporting its three unresolved `_in
#   flight_` rows as if today's run had dispatched three agents and lost
#   them. The gate correctly failed the job (0 open PRs, per the NO-OP
#   check), but for the wrong reason: it named a two-day-old file instead of
#   the true fault (today's run produced no summary at all).
#
#   `_prior_summary_timestamp` (used by the drift check below) already
#   solved the identical checkout-mtime trap for ITS OWN `ls -t` call by
#   preferring the file's commit date; this check solves the same trap for
#   `verify`'s OWN summary argument, which has no analogous "prefer git
#   history" escape (the current run's summary is often not yet committed at
#   all when `verify` runs against it).
#
#   `_prior_summary_path` (the "which file is prior" SELECTOR, as opposed to
#   `_prior_summary_timestamp`'s "how old is that file") carried the exact
#   same `ls -t | head -1` idiom and was NOT fixed alongside it -- issue
#   #2887. Measured on the 2026-09-21 GHA orchestrator run: with 388
#   checkout-flattened `dev/daily/*.md` files, `ls -t | head -6` returned
#   `2026-09-16.md` ahead of the true second-newest `2026-09-20.md`, a
#   4-day error in the drift window `_status_changed_since` measures from.
#   Fixed by selecting on the DATE ENCODED IN THE FILENAME instead of mtime:
#   `dev/daily/YYYY-MM-DD[-runN].md` sorts correctly under a plain
#   lexicographic `sort`, since the ISO date prefix always decides the
#   comparison before any `-runN` suffix is reached -- so `sort | tail -1`
#   (never `sort -r | head -1`; this file already treats "-t | head -1" as
#   the banned idiom for a newest-file lookup, and swapping `head` for
#   `tail` without also dropping `-t` would just be the same bug spelled
#   differently) reproduces the mtime-based idiom's INTENT without its
#   checkout-flattening blind spot.
#
#   The check compares the summary's OWN date -- parsed from its
#   dev/daily/YYYY-MM-DD[-runN].md basename -- against an expected date. It
#   accepts the expected date OR the day before it (UTC), so a run
#   straddling UTC midnight is never falsely rejected; the guard only fires
#   at >=2 days stale, unambiguously the defect class (today's incident was
#   exactly 2 days stale). The expected date is resolved, in order: an
#   explicit second positional argument to `verify` (for callers that want
#   to pin a specific date), else $ORCHESTRATOR_EXPECTED_DATE (set to `any`
#   to disable the check entirely -- the escape hatch the fixture suite uses,
#   since its fixtures carry synthetic dates unrelated to wall-clock "today",
#   and the one a human uses to manually verify an intentionally old
#   summary), else the real system UTC date -- which is what the workflow's
#   existing one-argument `verify "$SUMMARY"` call relies on implicitly, so
#   the fix is live on that call site with NO workflow-YAML edit required.
#
#   A basename with no parsable leading date (e.g. a hand-named fixture path
#   that isn't shaped like a daily summary at all) is NOT treated as a
#   violation -- SILENCE, matching this script's existing convention that an
#   input shape a check doesn't recognise is not evidence of anything (see
#   the DISPATCH-ARTIFACT check's TABLE-SHAPE GATE below for the precedent).
#   There is no rc=2 "couldn't determine" case here the way there is for the
#   PR-count checks: unlike a failed network call standing between the
#   script and a real answer, a stale/fresh verdict is either fully
#   determined from local inputs (the basename plus the expected date, no
#   network) or genuinely not applicable (unparsable basename, or the `any`
#   escape hatch) -- so this check only ever returns 0 or 1.
#
# FULL-MODE PUBLICATION CHECK (issue #2803)
#   The NO-OP check above answers "was the no-op claim honest". It has no
#   opinion on the other branch: a FULL-mode run that did real work but then
#   never got its own summary published was INVISIBLE to it -- `verify`
#   printed "is not a NO-OP-mode run; nothing to verify." and exited 0. Run
#   34768165769 (2026-09-13 evening) is the measured instance: $28.30, 50
#   minutes, 23/23 green steps, two feature PRs merged -- and
#   dev/daily/2026-09-13-run2.md never reached `main`, no
#   `ops/daily-2026-09-13-run2` PR ever opened, and the Step 5.5 index
#   reconcile it should have carried was lost with it. Fourth instance of
#   this class this month (#2741, #2747, #2771, #2803 itself); each prior fix
#   closed one ROUTE to summary loss and left the CLASS open: a green run is
#   indistinguishable from a productive one because nothing checks the
#   artifact against the exit code.
#
#   "Published" (for a FULL-mode summary at path P, branch
#   ops/daily-<basename-of-P-without-.md>, matching `publish_daily_summary.sh`'s
#   own `_branch_name_for` convention) means EITHER:
#     (a) P already exists in the tree at origin/main (checked first --
#         free, no network, and correct even if some other route landed it
#         without going through the ops/daily-* branch convention at all), OR
#     (b) an open-or-merged PR exists for that branch (checked via the same
#         gh/curl backend as open_pr_count).
#   A PR that is closed WITHOUT having merged does NOT count -- that shape
#   (open a PR, then abandon/close it) is exactly as much a loss as never
#   opening one, and is deliberately distinguished from "merged" in the
#   fixture suite.
#
#   ORDERING CONSTRAINT, worth stating because it makes the predicate
#   non-obvious: this script's caller (.github/workflows/orchestrator.yml)
#   runs `verify` BEFORE its own auto-merge step. So on a perfectly healthy
#   run, (a) is normally false at call time -- the summary hasn't merged yet,
#   only its PR exists. The predicate MUST key on the PR existing (open OR
#   merged), never on the merge having already happened, or every healthy
#   run would fail this check. (a) exists as a second, independent path for
#   cases outside that ordering (e.g. a summary folded into some other
#   commit that reached main by a different route, or a later re-check of
#   `verify` after the merge completed) -- it is not the primary signal.
#
#   KNOWN GAP, stated rather than silently left implicit (the whole point of
#   this file existing is to not let a check pass vacuously the way the old
#   "nothing to verify" fallback did): this check only fires for a Mode
#   string that starts with "full" (case-insensitively) right after
#   "**Mode:**". The daily-summary corpus also contains many OTHER mode
#   strings that are equally "real work happened" runs -- "NO-DISPATCH
#   PASS", "LIGHT COORDINATION", "RECONCILE + HEALTH + PR-EVAL pass", etc. --
#   and those still fall through to the untouched "nothing to verify" path.
#   Extending coverage to all such strings was out of scope for this pass;
#   the issue #2803 dispatch scoped the fix to "FULL-mode" specifically. A
#   summary using one of those other mode strings and losing its PR would
#   NOT be caught by this script today.
#
# FULL-MODE DISPATCH-ARTIFACT CHECK (issue #2810)
#   The publication check above answers "did the summary FILE reach origin".
#   It has no opinion on the summary's own CONTENT: a FULL-mode run can
#   publish a perfectly real summary that itself admits three agents were
#   dispatched and never finished. Run 34853606164 (2026-09-14, "run 1") is
#   the measured instance: three `## Dispatched this run` rows read
#   `_in flight_`, the run ended there (turn budget exhausted mid-dispatch),
#   and the job still reported `conclusion: success` -- $18.30 for zero
#   branches, zero PRs, zero status updates. Third instance of the general
#   "green run, no artifact" class after #2741/#2747/#2771, and the second
#   half of what #2803 opened (#2803's own fix, `_verify_full_mode_published`
#   above, closed the SUMMARY half; this closes the DISPATCH half).
#
#   WHAT COUNTS AS A VIOLATION -- two independent signatures, checked
#   against the `## Dispatched this run` section only (see
#   `_verify_full_mode_dispatch_artifacts` for the exact parse):
#     (a) the section contains the literal "turn ended mid-dispatch"
#         placeholder text ("completed at the end of the run", matched as a
#         case-insensitive substring so it catches every wording variant
#         observed in the corpus), anywhere in the section -- this needs no
#         table at all, since it is direct textual evidence on its own.
#     (b) within the canonical `| Track | Agent | Outcome | Notes |` table
#         (see `.claude/agents/lead-orchestrator.md` "## Dispatched this
#         run" template), a row whose Agent names a WRITING agent
#         (feat-backtest / feat-data / feat-weinstein / harness-maintainer /
#         ops-data / code-health -- matched by case-insensitive prefix, so
#         "feat-backtest (rework #1)" etc. still match) still reads
#         "in flight" in its Outcome column.
#
#   WHY SCOPED TO WRITING AGENTS, AND WHY "in flight" RATHER THAN "cites no
#   PR/branch" (issue #2810's own dispatch brief proposed the latter, and it
#   does not survive contact with the real dev/daily/*.md corpus --
#   surveyed 2026-09-15, see the mutation-test-file header for the specific
#   counter-examples):
#     - A rework-iteration row (e.g. "harness-maintainer | **completed** |
#       rework iteration 1") legitimately cites its PR only in the TRACK
#       column, not Outcome, because the PR already exists from an earlier
#       row. Requiring an artifact reference IN Outcome false-positives on
#       every rework row in the corpus.
#     - A QC-verdict row ("qc-structural | **APPROVED (5)**") never cites a
#       PR/branch in Outcome either -- the QC agent reviews an existing
#       artifact, it doesn't create one. Requiring an artifact anywhere in
#       the row (to dodge the above) creates the OPPOSITE hole: run 1's own
#       broken rows cite unrelated issue numbers in Notes as context
#       ("(#2803)", "(#2800 follow-up)") that are not this row's own
#       produced artifact -- a bare `#\d+` search anywhere in the row would
#       have missed the exact case this check exists to catch.
#     - A QC re-review CAN legitimately read "in flight at run end"
#       (dev/daily/2026-09-05.md) when a review spans a run boundary per
#       `.claude/rules/pr-gate-loop.md` -- the PR under review already
#       exists, nothing was lost. Scoping to writing agents excludes this
#       correctly; scoping to "no artifact in Outcome" would not.
#   The "in flight" marker itself is grounded in two independently confirmed
#   real instances, not just #2810: dev/daily/2026-09-03.md's
#   `harness-maintainer | *in flight at write time*` row, which
#   dev/daily/2026-09-04.md's own next-day entry confirms "produced no
#   branch and no PR" and had to be re-dispatched from scratch.
#
#   TABLE-SHAPE GATE: (b) only fires when the section's first `|`-prefixed
#   line matches the canonical 4-column header (whitespace/case-insensitive).
#   A summary with no `## Dispatched this run` section, or a table in some
#   other shape, makes (b) a no-op -- SILENCE, not failure, per the
#   fail-direction requirement (a table shape this script doesn't recognise
#   is not evidence of anything). (a) still applies regardless of table
#   shape or absence, since it needs no table to be meaningful.
#
# BACKEND SELECTION (mirrors dev/scripts/pr_gate_status.sh)
#   The GHA orchestrator container has `curl` + `$GH_TOKEN` but no `gh`
#   binary (see pr_gate_status.sh's "BACKEND SELECTION" comment for the
#   measured evidence). Local interactive sessions usually have `gh`
#   authenticated. Prefer `gh` when present (fewer moving parts locally);
#   fall back to the curl+REST path otherwise; refuse loudly if neither is
#   usable rather than silently reporting a PR count of 0 (which would be
#   indistinguishable from a real empty queue -- exactly the false-clean this
#   script exists to prevent).
#
#   Test-only override: ORCHESTRATOR_FASTEXIT_GATE_BACKEND=gh|curl forces a
#   backend regardless of what's on PATH (see
#   orchestrator_fastexit_gate_test.sh).
#
# LIMITATION: open_pr_count reads a single page (per_page=100, no
# pagination), same limitation as pr_gate_status.sh's `_list_open_prs_curl`.
# This repo's open-PR queue has never approached 100; if it ever does, this
# undercounts rather than erroring -- worth revisiting then, not now.

set -eu

REPO="${ORCHESTRATOR_FASTEXIT_GATE_REPO:-dayfine/trading}"

# --- backend selection -------------------------------------------------

_detect_backend() {
  if [ -n "${ORCHESTRATOR_FASTEXIT_GATE_BACKEND:-}" ]; then
    printf '%s' "$ORCHESTRATOR_FASTEXIT_GATE_BACKEND"
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

_open_pr_count_gh() {
  gh pr list --repo "$REPO" --state open --json number --jq 'length'
}

_open_pr_count_curl() {
  # Capture the body FIRST and check curl's own exit status before piping to
  # jq. `sh` has no `pipefail`, so `curl -f ... | jq 'length'` swallows a
  # failing curl: on a 401/403/5xx, `-f` makes curl exit non-zero and print
  # NOTHING to stdout, but the pipeline's exit status is jq's -- and jq on
  # empty input prints nothing and exits 0. That turned a curl failure into
  # `open_pr_count` silently returning rc=0 with an EMPTY count, which
  # `verify` could not distinguish from "queue is empty" (issue #2605
  # rework). Splitting the pipe closes that gap.
  _body=$(
    curl -sS -f \
      -H "Authorization: Bearer ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${REPO}/pulls?state=open&per_page=100"
  ) || return 2
  _count=$(printf '%s' "$_body" | jq 'length') || return 2
  # Belt-and-braces: refuse to return anything that isn't a plain non-negative
  # integer, so a malformed/empty jq result can never be mistaken for a real
  # PR count by a caller that only checks the exit status.
  case "$_count" in
    '' | *[!0-9]*) return 2 ;;
  esac
  printf '%s' "$_count"
}

open_pr_count() {
  _backend=$(_detect_backend) || {
    echo "orchestrator_fastexit_gate: neither \`gh\` nor (\`curl\` + \$GH_TOKEN)" >&2
    echo "is available -- refusing to report an open-PR count (a silent 0" >&2
    echo "here would be indistinguishable from a real empty queue)." >&2
    return 2
  }
  case "$_backend" in
    gh) _open_pr_count_gh ;;
    curl) _open_pr_count_curl ;;
    *)
      echo "orchestrator_fastexit_gate: unrecognised backend '$_backend'" \
        "(from \$ORCHESTRATOR_FASTEXIT_GATE_BACKEND) -- refusing to report" \
        "an open-PR count rather than silently returning nothing." >&2
      return 2
      ;;
  esac
}

# --- FULL-mode publication check (issue #2803) -------------------------

# _daily_summary_branch <summary-path>
# ops/daily-<basename-without-.md> -- MUST match publish_daily_summary.sh's
# own `_branch_name_for` exactly, since that is the branch the publisher
# actually creates. Deliberately re-derived here rather than sourced from
# that script: this script has no dependency on publish_daily_summary.sh
# today, and adding one just to share one line would trade a one-line
# duplication for a cross-script coupling that isn't worth it. If the two
# ever drift, the fixture suite's branch-name assertions will catch it.
_daily_summary_branch() {
  _base=$(basename "$1" .md)
  printf 'ops/daily-%s' "$_base"
}

# _daily_summary_on_main <summary-path>
# True (rc 0) iff <summary-path> already exists in the tree at origin/main.
# Cheap, no network. See the "FULL-MODE PUBLICATION CHECK" header comment
# for why this is a secondary path, not the primary signal: verify runs
# BEFORE this workflow's own auto-merge step, so on a healthy run this is
# normally false even when publishing worked correctly. If `origin/main`
# doesn't resolve at all (no such ref locally), `git cat-file` fails and
# this reports false -- the safe direction, since the caller then falls
# back to the stronger PR-existence check rather than silently assuming
# "published".
_daily_summary_on_main() {
  git cat-file -e "origin/main:$1" 2>/dev/null
}

_daily_summary_pr_count_gh() {
  gh pr list --repo "$REPO" --head "$1" --state all --json state,mergedAt \
    --jq '[.[] | select(.state == "OPEN" or .mergedAt != null)] | length'
}

_daily_summary_pr_count_curl() {
  # Same split-the-pipe discipline as _open_pr_count_curl (capture body,
  # check curl's own exit status, THEN pipe to jq) -- `sh` has no
  # pipefail, so a bare `curl -f ... | jq ...` would let a failing curl
  # through as jq's rc=0-on-empty-input, exactly the defect issue #2605
  # fixed for open_pr_count. `state=all` is required to see merged PRs
  # (which report as `state: closed`, distinguished from a genuinely
  # abandoned closed PR only by `merged_at`).
  _branch="$1"
  _owner="${REPO%%/*}"
  _body=$(
    curl -sS -f \
      -H "Authorization: Bearer ${GH_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${REPO}/pulls?head=${_owner}:${_branch}&state=all&per_page=100"
  ) || return 2
  _count=$(printf '%s' "$_body" | jq '[.[] | select(.state == "open" or .merged_at != null)] | length') || return 2
  case "$_count" in
    '' | *[!0-9]*) return 2 ;;
  esac
  printf '%s' "$_count"
}

# daily_summary_pr_count <branch>
# Count of PRs for <branch> that are either currently open or have merged.
# A count of 0 means neither -- either no PR was ever opened for this
# branch, or one was opened and later closed without merging. Both are the
# "not published" shape this check exists to catch.
daily_summary_pr_count() {
  _branch="$1"
  _backend=$(_detect_backend) || {
    echo "orchestrator_fastexit_gate: neither \`gh\` nor (\`curl\` + \$GH_TOKEN)" >&2
    echo "is available -- refusing to report a daily-summary PR count (a silent 0" >&2
    echo "here would be indistinguishable from a real missing/unmerged PR)." >&2
    return 2
  }
  case "$_backend" in
    gh) _daily_summary_pr_count_gh "$_branch" ;;
    curl) _daily_summary_pr_count_curl "$_branch" ;;
    *)
      echo "orchestrator_fastexit_gate: unrecognised backend '$_backend'" \
        "(from \$ORCHESTRATOR_FASTEXIT_GATE_BACKEND) -- refusing to report" \
        "a daily-summary PR count rather than silently returning nothing." >&2
      return 2
      ;;
  esac
}

# _verify_full_mode_published <summary-path>
# The FULL-mode half of `verify` -- see the "FULL-MODE PUBLICATION CHECK"
# header comment for the predicate and its rationale. Split out of
# `verify` itself (rather than inlined) so the mode-dispatch in `verify`
# reads as a flat if/elif/else over the three cases.
_verify_full_mode_published() {
  _summary="$1"

  if _daily_summary_on_main "$_summary"; then
    echo "orchestrator_fastexit_gate verify: $_summary is already present on origin/main; published."
    return 0
  fi

  _branch=$(_daily_summary_branch "$_summary")
  _pr_count=$(daily_summary_pr_count "$_branch") || {
    echo "::error::orchestrator_fastexit_gate verify: $_summary declares FULL mode but the PR status for branch $_branch could not be determined -- refusing to validate a full-mode run blind." >&2
    return 2
  }
  # Same belt-and-braces as the NO-OP path's numeric guard (see its comment
  # for why this must be checked explicitly rather than trusted to `[ -eq
  # 0 ]` alone under `set -e`).
  case "$_pr_count" in
    '' | *[!0-9]*)
      echo "::error::orchestrator_fastexit_gate verify: $_summary declares FULL mode but daily_summary_pr_count returned a non-numeric value ('$_pr_count') for branch $_branch -- refusing to validate a full-mode run blind." >&2
      return 2
      ;;
  esac

  if [ "$_pr_count" -eq 0 ]; then
    echo "::error::A-FASTEXIT-VACUOUS (issue #2803): $_summary declares FULL mode but no open-or-merged PR exists for branch $_branch, and the summary is not present on origin/main. The daily summary was NOT published -- see H-DAILY-SUMMARY-PR-LOST / issue #2803 for the failure class this catches (a green, costly run whose only durable artifact silently never left the runner)." >&2
    return 1
  fi

  echo "orchestrator_fastexit_gate verify: FULL-mode run OK (branch $_branch has an open-or-merged PR; count: $_pr_count)."
  return 0
}

# --- FULL-mode dispatch-artifact check (issue #2810) --------------------

# _verify_full_mode_dispatch_artifacts <summary-path>
# The dispatch half of the FULL-mode check -- see the "FULL-MODE
# DISPATCH-ARTIFACT CHECK" header comment for the predicate, the two
# violation signatures, and why the design is scoped to writing agents +
# an "in flight" marker rather than a generic "cites no PR/branch" rule.
#
# Pure text parsing, no network -- unlike _verify_full_mode_published this
# never fails closed with rc=2; there is nothing here that can be
# undetermined the way a curl call can.
_verify_full_mode_dispatch_artifacts() {
  _summary="$1"
  _awk_out=$(awk '
    BEGIN { insec = 0; sawsection = 0; rowno = 0; placeholder = 0; nfail = 0; intable = 0 }
    /^## Dispatched this run/ { insec = 1; sawsection = 1; next }
    insec && /^## / { insec = 0 }
    insec && /^---$/ { insec = 0 }
    insec {
      lower = tolower($0)
      if (index(lower, "completed at the end of the run") > 0) placeholder = 1
      if (substr($0, 1, 1) == "|") {
        rowno++
        if (rowno == 1) {
          norm = lower
          gsub(/[ \t]/, "", norm)
          if (norm == "|track|agent|outcome|notes|") intable = 1
          next
        }
        if (rowno == 2) next  # separator row (|---|---|---|---|), never data
        if (!intable) next    # header did not match the canonical shape
        n = split($0, cols, "|")
        if (n < 4) next
        track = cols[2]; agent = cols[3]; outcome = cols[4]
        gsub(/^[ \t]+|[ \t]+$/, "", track)
        gsub(/^[ \t]+|[ \t]+$/, "", agent)
        gsub(/^[ \t]+|[ \t]+$/, "", outcome)
        agentlow = tolower(agent)
        iswriter = 0
        np = split("feat-backtest feat-data feat-weinstein harness-maintainer ops-data code-health", pfx, " ")
        for (i = 1; i <= np; i++) {
          if (index(agentlow, pfx[i]) == 1) { iswriter = 1; break }
        }
        if (iswriter && index(tolower(outcome), "in flight") > 0) {
          nfail++
          print "ROW:" track "\t" agent "\t" outcome
        }
      } else {
        rowno = 0
        intable = 0
      }
    }
    END {
      print "PLACEHOLDER:" placeholder
      print "SAWSECTION:" sawsection
      print "NFAIL:" nfail
    }
  ' "$_summary")

  _placeholder=$(printf '%s\n' "$_awk_out" | grep '^PLACEHOLDER:' | cut -d: -f2)
  _sawsection=$(printf '%s\n' "$_awk_out" | grep '^SAWSECTION:' | cut -d: -f2)
  _nfail=$(printf '%s\n' "$_awk_out" | grep '^NFAIL:' | cut -d: -f2)

  if [ "${_placeholder:-0}" = "1" ] || [ "${_nfail:-0}" -gt 0 ]; then
    echo "::error::A-FASTEXIT-VACUOUS (issue #2810): $_summary's ## Dispatched this run section claims a dispatch with no artifact to show for it. Per run 34853606164 (2026-09-14) -- three agents dispatched, zero branches, zero PRs, job still green -- a claimed dispatch that never resolved is exactly this failure class." >&2
    printf '%s\n' "$_awk_out" | grep '^ROW:' | while IFS= read -r _r; do
      echo "::error::  unresolved writing-agent row: ${_r#ROW:}" >&2
    done
    if [ "${_placeholder:-0}" = "1" ]; then
      echo "::error::  the section still carries its 'completed at the end of the run' placeholder -- the turn ended mid-dispatch and the table was never finalized." >&2
    fi
    return 1
  fi

  if [ "${_sawsection:-0}" = "1" ]; then
    echo "orchestrator_fastexit_gate verify: dispatch-artifact check OK ($_summary's ## Dispatched this run table has no unresolved writing-agent rows)."
  else
    echo "orchestrator_fastexit_gate verify: $_summary has no ## Dispatched this run section; dispatch-artifact check not applicable."
  fi
  return 0
}

# --- dev/status/ drift (Condition 2, mirrored from lead-orchestrator.md) ----

# _current_summary_path <date>
# The dev/daily/<date>[-runN].md path THIS run's own summary is (or will be)
# written to, for a given <date> (a YYYY-MM-DD string; callers pass
# `$(date +%F)`). Single source of truth for lead-orchestrator.md's Step 0.5
# Condition 2/4 and Step 7, which both need this same value and previously
# each carried their own copy of the run-count formula inline as Markdown
# prose (issue #2887 CP4 rework).
#
# Counts only GIT-TRACKED dev/daily/<date>*.md files (via `git ls-files`,
# excluding -plan.md and -summary.md) -- NOT a raw filesystem `ls`. An
# UNTRACKED same-day file is, by construction, always THIS run's own
# in-progress summary: every completed prior run's summary is committed (via
# Step 8a) before the next run starts, so nothing else can leave an
# uncommitted dev/daily/<date>*.md file lying around. Counting it would
# double-count the run's own file once it exists on disk earlier in the run
# than Step 8a's commit -- the write-early escalation described at
# `_prior_summary_path` below and in dev/daily/2026-09-21.md. Reproduced with
# the pre-fix `ls`-based formula: with no committed same-day file but an
# uncommitted write-early skeleton already at dev/daily/<date>.md on disk,
# `ls | wc -l` counted 1, producing N=2 and a CURRENT_SUMMARY_PATH of
# `<date>-run2.md` -- one higher than the skeleton's real name -- so
# `_prior_summary_path`'s exclusion argument named a file that doesn't exist,
# excluded nothing, and the skeleton was selected as its own "prior" (the
# exact Defect-1 vacuity this whole family of fixes exists to close).
# `git ls-files` immunizes the count against this because the skeleton stays
# untracked until Step 8a, regardless of when in the run it was written.
_current_summary_path() {
  _date="$1"
  _run_count=$(git ls-files -- "dev/daily/${_date}*.md" 2>/dev/null \
    | grep -v -- '-plan\.md$' \
    | grep -v -- '-summary\.md$' \
    | wc -l | tr -d ' ')
  _n=$((_run_count + 1))
  if [ "$_n" -eq 1 ]; then
    printf 'dev/daily/%s.md' "$_date"
  else
    printf 'dev/daily/%s-run%s.md' "$_date" "$_n"
  fi
}

# _prior_summary_path <current-summary-path>
# Newest dev/daily/*.md (excluding -plan.md, -summary.md, and the current
# summary itself), by the date ENCODED IN THE FILENAME -- not by mtime (issue
# #2887). Empty output means no prior summary exists (first run ever) --
# callers must treat that as "nothing to compare against", not a violation.
#
# `_current` must be the path THIS run's own summary is written to (or will
# be written to), even if that file does not exist yet on disk. Passing "" or
# omitting it disables the exclusion entirely -- and once the summary is
# written earlier in a run than the workflow's historical commit-and-push
# step, that makes this function select the run's OWN just-written file as
# its "prior", comparing a timestamp against itself and silently zeroing the
# drift window every caller below measures from. This is why EVERY call
# site -- both here in the script and in lead-orchestrator.md's Conditions 2
# and 4 -- always passes the current summary's path; a call missing it is a
# regression, not a convenience shortcut (issue #2887, Defect 1).
#
# `ls -t | head -1` (mtime-newest) was the original selector, matching the
# same idiom `_prior_summary_timestamp` below independently had to fix for
# the same reason: `actions/checkout` stamps every tracked file with one
# identical mtime, so on the runner that idiom carries no real ordering
# information and falls back to something OS/filesystem-dependent -- not
# "newest" in any date sense (issue #2887, Defect 2; measured on a
# 388-file dev/daily/ tree post-checkout). `dev/daily/YYYY-MM-DD[-runN].md`
# names already sort correctly by date under plain lexicographic `sort`, so
# `sort | tail -1` (see the STALE-SUMMARY CHECK header comment above for why
# not `sort -r | head -1`) reads the same "which file is most recent" intent
# straight from committed filenames, with no mtime dependency at all.
#
# -summary.md (the consolidated multi-run rollup the orchestrator also
# writes) is excluded for the same reason the workflow's own "Locate daily
# summary" step excludes it (.github/workflows/orchestrator.yml, run
# 24745079773 post-mortem): it is written LAST, minutes after this run's own
# per-run summary, by the SAME run. Without this exclusion, the selector can
# pick the current run's own rollup as its "prior" summary -- comparing a
# timestamp against itself and independently zeroing the drift window,
# regardless of the mtime-vs-filename-date fix above.
_prior_summary_path() {
  _current="$1"
  ls -1 dev/daily/*.md 2>/dev/null \
    | grep -v -- '-plan\.md$' \
    | grep -v -- '-summary\.md$' \
    | grep -vxF "$_current" \
    | sort \
    | tail -1 || true
}

# _file_iso_mtime <path> -- portable (BSD date on macOS, GNU date on Linux/CI)
_file_iso_mtime() {
  date -r "$1" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null \
    || date -d "@$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1")" '+%Y-%m-%dT%H:%M:%S'
}

# _prior_summary_timestamp <path>
# Prefer the file's last COMMIT date over its mtime: `actions/checkout@v4`
# (the tree the GHA orchestrator job runs on) writes every file at checkout
# time and does not preserve mtimes, so on that runner `_file_iso_mtime`
# always reads as "a few seconds ago" regardless of how old the prior
# summary actually is -- making `_status_changed_since` structurally return
# 0 and the Condition-2 half of `verify` permanently inert where it is
# deployed (issue #2605 rework). Fall back to mtime only when the file has
# no commit history at all (e.g. a summary this run just wrote and has not
# committed yet).
_prior_summary_timestamp() {
  _path="$1"
  _committed=$(git log -1 --format='%cI' -- "$_path" 2>/dev/null || true)
  if [ -n "$_committed" ]; then
    printf '%s' "$_committed"
  else
    _file_iso_mtime "$_path"
  fi
}

# Shared CLI lookup for Step 0.5. Optional current summary is excluded, as
# verify excludes its own output. Empty output means no prior summary exists.
_prior_summary_iso() {
  _prior_path=$(_prior_summary_path "${1:-}")
  [ -n "$_prior_path" ] || return 0
  _prior_summary_timestamp "$_prior_path"
}

# _file_epoch_mtime <path> -- portable (BSD `stat -f`, GNU `stat -c`) mtime
# as a UNIX epoch integer. Sibling of `_file_iso_mtime` above, returning an
# epoch instead of an ISO string so callers can do plain integer arithmetic
# without round-tripping through ISO-8601 parsing (BSD `date -j -f` cannot
# parse a `%cI`-style offset reliably; GNU `date -d` doesn't exist on macOS
# at all -- `_file_iso_mtime`'s own fallback already routes through this
# same `stat` pair for exactly that reason).
_file_epoch_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"
}

# _prior_summary_epoch <path> -- epoch-integer sibling of
# `_prior_summary_timestamp`, same commit-date-first/mtime-fallback
# preference and the same reason (checkout-flattened mtimes on GHA).
_prior_summary_epoch() {
  _path="$1"
  _committed=$(git log -1 --format='%ct' -- "$_path" 2>/dev/null || true)
  if [ -n "$_committed" ]; then
    printf '%s' "$_committed"
  else
    _file_epoch_mtime "$_path"
  fi
}

# _hours_since_prior_summary <current-summary-path>
# Whole hours between now and the prior summary's commit date (mtime
# fallback), excluding <current-summary-path> the same way `_prior_summary_iso`
# does. Empty output means no prior summary exists (first run ever) --
# callers must treat that as "nothing to compare against", not zero hours.
# Existed to replace Step 0.5's escape-hatch mtime/`ls -t` arithmetic
# (lead-orchestrator.md, issue #2887 CP4 rework advisory 2): that inline
# block used `ls -t dev/daily/*.md | head -1` plus `date -r`/`stat -f %m` on
# whatever it selected, which is defeated by write-early the same way
# `_prior_summary_path`'s old `ls -t` selector was (Defect 2) -- an
# uncommitted same-day skeleton has the newest mtime by construction, so it
# would be selected as "most recent" and read as zero hours old regardless
# of how long ago the true prior summary actually landed.
_hours_since_prior_summary() {
  _current="$1"
  _prior_path=$(_prior_summary_path "$_current")
  [ -n "$_prior_path" ] || return 0
  _prior_epoch=$(_prior_summary_epoch "$_prior_path")
  _now_epoch=$(date '+%s')
  echo $(( (_now_epoch - _prior_epoch) / 3600 ))
}

# _status_changed_since <iso-timestamp>
# Count of dev/status/ file touches by a commit since <iso-timestamp>,
# excluding the orchestrator's own summary-landing commits ("ops: daily
# orchestrator summary ..." -- Step 5.5's auto-merged index reconciliation,
# not new track drift). Same exemption intent as lead-orchestrator.md Step
# 0.5 Condition 2, but resolved per-commit rather than by a single grep
# pipeline: a `--name-only --pretty="%s"` stream interleaves each subject
# line with its own touched-file lines, and every dev/status/ path contains
# a literal '.' (the .md extension) -- so filtering only the subject line
# out of that stream still leaves the exempted commit's file lines behind,
# and `grep -c '\.'` counts them anyway. Walking commit-by-commit and
# skipping the whole commit (subject AND files) when it matches the
# exemption is what actually implements the documented exemption.
_status_changed_since() {
  _since="$1"
  _count=0
  for _hash in $(git log --since="$_since" --pretty="format:%H" -- dev/status/); do
    _subject=$(git log -1 --pretty="format:%s" "$_hash")
    case "$_subject" in
      "ops: daily orchestrator summary "*) continue ;;
    esac
    _n=$(git show --name-only --pretty="format:" "$_hash" -- dev/status/ | grep -c '\.' || true)
    _count=$((_count + _n))
  done
  echo "$_count"
}

# --- stale-summary check (issue #2850) ----------------------------------

# _summary_date_from_basename <path>
# Parses the leading YYYY-MM-DD out of a dev/daily/<date>[-suffix].md
# basename. Prints the date and returns 0 on success; returns 1 (prints
# nothing) if the basename doesn't start with a date shaped that way --
# callers must treat that as "unknown", not as evidence of staleness.
_summary_date_from_basename() {
  _base=$(basename "$1" .md)
  case "$_base" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*)
      printf '%s' "$_base" | cut -c1-10
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# _prior_calendar_date <YYYY-MM-DD>
# <date> minus one day, UTC. Portable: GNU date (Linux/CI) via `-d`, BSD date
# (macOS) via `-j -v-1d -f`, same fallback shape as `_file_iso_mtime` above.
_prior_calendar_date() {
  date -u -d "$1 -1 day" '+%Y-%m-%d' 2>/dev/null \
    || date -u -j -v-1d -f '%Y-%m-%d' "$1" '+%Y-%m-%d' 2>/dev/null
}

# _expected_summary_date <explicit-override>
# Resolution order documented in the "STALE-SUMMARY CHECK" header comment:
# explicit override (verify's optional second positional arg) > the
# $ORCHESTRATOR_EXPECTED_DATE escape hatch > the real system UTC date. The
# fallback to system date is what makes the fix live on the workflow's
# existing one-argument `verify "$SUMMARY"` call with no YAML edit needed.
_expected_summary_date() {
  if [ -n "${1:-}" ]; then
    printf '%s' "$1"
    return 0
  fi
  if [ -n "${ORCHESTRATOR_EXPECTED_DATE:-}" ]; then
    printf '%s' "$ORCHESTRATOR_EXPECTED_DATE"
    return 0
  fi
  date -u '+%Y-%m-%d'
}

# _verify_summary_freshness <summary-path> [expected-date-override]
# See the "STALE-SUMMARY CHECK" header comment for the full rationale. Only
# ever returns 0 or 1 -- see that comment for why there is no rc=2 case here.
_verify_summary_freshness() {
  _summary="$1"
  _override="${2:-}"

  _expected=$(_expected_summary_date "$_override")
  if [ "$_expected" = any ]; then
    return 0
  fi

  _actual=$(_summary_date_from_basename "$_summary") || {
    echo "orchestrator_fastexit_gate verify: $_summary's basename carries no parsable YYYY-MM-DD date; staleness check not applicable." >&2
    return 0
  }

  if [ "$_actual" = "$_expected" ]; then
    return 0
  fi

  _yesterday=$(_prior_calendar_date "$_expected")
  if [ -n "$_yesterday" ] && [ "$_actual" = "$_yesterday" ]; then
    return 0
  fi

  echo "::error::A-FASTEXIT-VACUOUS (issue #2850): $_summary is dated $_actual but the expected run date is $_expected -- no daily summary was written for $_expected, and this STALE summary is being verified instead of it. Per run 35096884441 (2026-09-16): checkout-flattened mtimes broke an \`ls -t\` fallback into picking a 2-day-old file, and verify validated it blind. See the STALE-SUMMARY CHECK header comment above for the full mechanism." >&2
  return 1
}

# --- verify: the actual backstop ---------------------------------------

verify() {
  _summary="$1"
  _expected_date_override="${2:-}"
  if [ ! -f "$_summary" ]; then
    echo "orchestrator_fastexit_gate verify: summary file not found: $_summary" >&2
    return 2
  fi

  if ! _verify_summary_freshness "$_summary" "$_expected_date_override"; then
    return 1
  fi

  # NO-OP and FULL are mutually exclusive prefixes of the same "**Mode:**"
  # line, so these two checks can never both fire for one summary.
  if grep -qiE '^\*\*Mode:\*\* *full' "$_summary"; then
    _full_rc=0
    _verify_full_mode_published "$_summary" || _full_rc=$?
    _dispatch_rc=0
    _verify_full_mode_dispatch_artifacts "$_summary" || _dispatch_rc=$?
    _scheduled_rc=0
    if ! grep -qx '## Scheduled workflows' "$_summary"; then
      echo "::error::FULL-mode summary missing ## Scheduled workflows (issue #2634): report health or UNMEASURABLE, never omit it." >&2
      _scheduled_rc=1
    fi
    # Worst-of: rc=2 (couldn't determine, fail closed) outranks rc=1
    # (determined it's bad), which outranks rc=0. Both checks always print
    # their own ::error:: detail, so returning the worse code loses no
    # information -- it only decides the exit status.
    if [ "$_full_rc" -eq 2 ] || [ "$_dispatch_rc" -eq 2 ]; then
      return 2
    fi
    if [ "$_full_rc" -ne 0 ] || [ "$_dispatch_rc" -ne 0 ] || [ "$_scheduled_rc" -ne 0 ]; then
      return 1
    fi
    return 0
  fi

  if ! grep -qE '^\*\*Mode:\*\* NO-OP' "$_summary"; then
    echo "orchestrator_fastexit_gate verify: $_summary is not a NO-OP-mode or FULL-mode run; nothing to verify."
    return 0
  fi

  _pr_count=$(open_pr_count) || {
    echo "::error::orchestrator_fastexit_gate verify: $_summary declares NO-OP but the open-PR count could not be determined -- refusing to validate a no-op run blind." >&2
    return 2
  }
  # Belt-and-braces on top of _open_pr_count_curl's own numeric guard: even
  # if some future backend returns rc=0 with a blank/garbage count, `verify`
  # itself refuses to treat it as a trustworthy number rather than letting
  # `[ "$_pr_count" -eq 0 ]` below silently read as false under `set -e`
  # (a non-numeric operand makes `[` error, but inside an `if` condition
  # that error is suppressed and reads as "condition false" -- exactly how
  # the original defect went undetected).
  case "$_pr_count" in
    '' | *[!0-9]*)
      echo "::error::orchestrator_fastexit_gate verify: $_summary declares NO-OP but open_pr_count returned a non-numeric value ('$_pr_count') -- refusing to validate a no-op run blind." >&2
      return 2
      ;;
  esac

  _prior=$(_prior_summary_path "$_summary")
  _status_changed=0
  if [ -n "$_prior" ]; then
    _prior_iso=$(_prior_summary_timestamp "$_prior")
    _status_changed=$(_status_changed_since "$_prior_iso")
  fi

  _fail=0
  if [ "$_pr_count" -eq 0 ]; then
    echo "::error::A-FASTEXIT-VACUOUS (issue #2579): $_summary declares NO-OP but the open-PR queue is EMPTY (0 open PRs). Per the fast-exit precondition (.claude/agents/lead-orchestrator.md Step 0.5), an empty queue is NOT saturation -- it is the opposite -- and the four fast-exit conditions should never have been evaluated. A full pass was required this run." >&2
    _fail=1
  fi
  if [ "${_status_changed:-0}" -gt 0 ]; then
    echo "::error::A-FASTEXIT-VACUOUS (issue #2579): $_summary declares NO-OP but $_status_changed dev/status/*.md commit(s) landed since the prior summary (${_prior:-none}), violating Condition 2 (no status drift since prior summary)." >&2
    _fail=1
  fi

  if [ "$_fail" -eq 1 ]; then
    return 1
  fi

  echo "orchestrator_fastexit_gate verify: NO-OP run OK (open PRs: $_pr_count, dev/status/ changes since prior summary: ${_status_changed:-0})."
  return 0
}

# Sourcing with ORCHESTRATOR_FASTEXIT_GATE_LIB=1 exposes every function above
# for orchestrator_fastexit_gate_test.sh without hitting the network or
# invoking the CLI dispatcher below. EVERYTHING BELOW THIS LINE IS A SIDE
# EFFECT and must stay below it.
[ "${ORCHESTRATOR_FASTEXIT_GATE_LIB:-}" = 1 ] && return 0

case "${1:-}" in
  open_pr_count)
    open_pr_count
    ;;
  current_summary_path)
    if [ "$#" -gt 2 ]; then
      echo "usage: $0 current_summary_path [date]" >&2
      exit 2
    fi
    _current_summary_path "${2:-$(date +%F)}"
    ;;
  prior_summary_iso)
    if [ "$#" -gt 2 ]; then
      echo "usage: $0 prior_summary_iso [current-summary-path]" >&2
      exit 2
    fi
    _prior_summary_iso "${2:-}"
    ;;
  hours_since_prior_summary)
    if [ "$#" -gt 2 ]; then
      echo "usage: $0 hours_since_prior_summary [current-summary-path]" >&2
      exit 2
    fi
    _hours_since_prior_summary "${2:-}"
    ;;
  status_changed_since)
    if [ $# -lt 2 ]; then
      echo "usage: $0 status_changed_since <iso-timestamp>" >&2
      exit 2
    fi
    _status_changed_since "$2"
    ;;
  verify)
    if [ $# -lt 2 ]; then
      echo "usage: $0 verify <summary-path> [expected-date]" >&2
      exit 2
    fi
    verify "$2" "${3:-}"
    ;;
  *)
    echo "usage: $0 {open_pr_count|current_summary_path [date]|prior_summary_iso [current-summary-path]|hours_since_prior_summary [current-summary-path]|status_changed_since <iso-ts>|verify <summary-path> [expected-date]}" >&2
    exit 2
    ;;
esac
