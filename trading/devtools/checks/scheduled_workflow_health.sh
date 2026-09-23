#!/bin/sh
# scheduled_workflow_health.sh -- reports whether this repo's SCHEDULED
# (cron) GitHub Actions workflows are still succeeding (issue #2634, script
# half only -- see the header note at the bottom of this file for scope).
#
# WHY THIS EXISTS
#
#   Nothing in this repo previously monitored cron workflows. Two weekly
#   workflows rotted for weeks (one for five weeks) and a daily cron
#   silently missed a day, and in every case the rot was found only when a
#   human happened to look at the Actions tab. The check itself is cheap:
#
#     GET /repos/{owner}/{repo}/actions/workflows                  (paginated)
#     GET /repos/{owner}/{repo}/actions/workflows/{id}/runs?per_page=N*F
#
#   -- for each ACTIVE workflow, fetch one UNFILTERED page of its most
#   recent runs, keep the first N whose `event` field is "schedule" (the
#   selection is CLIENT-SIDE -- see WHY NOT event=schedule SERVER-SIDE
#   below; default N=10, F=5, see RUNS PER WORKFLOW), and classify from
#   that history, not from a single run. This script makes
#   that repeatable instead of re-typed from memory each session.
#
# WHY A SINGLE NEWEST RUN WAS NOT ENOUGH (2026-09-10..12 incident)
#
#   An earlier version of this script inspected only the single newest
#   scheduled run per workflow. That version reported the Daily
#   orchestrator workflow OK while it was in the middle of a THREE-DAY,
#   SIX-CONSECUTIVE-FAILURE outage (six scheduled runs, 2026-09-10 12:14Z
#   through 2026-09-12 15:32Z, each $0.0000 / num_turns=1 / modelUsage={}),
#   because:
#     1. it never looked past the newest run, so a failure streak was
#        invisible unless the very newest run happened to also be red, and
#     2. the newest run, at the moment the health check itself ran, was
#        the orchestrator's own CURRENTLY-EXECUTING run (status=in_progress,
#        conclusion=null) -- and the old code classified in_progress as OK
#        ("succeeded, or is still in progress"). The one workflow most in
#        need of monitoring is the one workflow that runs this very check,
#        so its own live run masking its own history was a structural
#        blind spot, not a corner case.
#   This version fetches a page of recent runs, skips leading in_progress /
#   queued runs for classification purposes (they carry no verdict yet),
#   and computes a real failure-STREAK from the newest COMPLETED run
#   backwards. See CLASSIFICATION below.
#
# CLASSIFICATION (one of, per active workflow)
#
#   RED          -- there is a non-zero streak of CONSECUTIVE failure-class
#                   completed runs (failure / cancelled / timed_out /
#                   action_required) counting back from the newest
#                   COMPLETED run -- so a lone newest-run failure (streak=1)
#                   is RED exactly as before, and a longer streak is RED
#                   regardless of what an even-newer in_progress run shows.
#                   The streak count is reported (streak=N) on the
#                   workflow's output line and folded into the SUMMARY.
#   STALE        -- the newest completed run is not RED, but its age
#                   exceeds the staleness window (default below).
#   NO-SCHEDULE  -- the workflow has zero observed scheduled runs at all
#                   (either it declares no cron trigger, or one exists but
#                   has never fired). Informational only -- NEVER
#                   contributes to a non-zero exit. Distinguishing "no cron
#                   in the YAML" from "cron exists, never fired" would
#                   require parsing workflow source, out of scope for an
#                   API-only script.
#   UNOBSERVABLE -- every one of the N most-recently-fetched scheduled runs
#                   is in_progress / queued -- i.e. there is at least one
#                   scheduled run, but NONE of the runs this script looked
#                   at have completed yet, so there is no verdict to read.
#                   This is deliberately NOT the same as OK: an
#                   in-progress run must never manufacture a green result
#                   on its own (see the incident above). Like NO-SCHEDULE,
#                   it is informational and does not force a non-zero exit
#                   -- there is no positive evidence of failure here, only
#                   an absence of evidence either way.
#   OK           -- the newest COMPLETED run's conclusion is not a failure
#                   class and it is within the staleness window. An
#                   in_progress/queued NEWEST run does not, by itself,
#                   change this: classification always falls through to
#                   the newest completed run in the fetched page. The
#                   output line still reports in_progress=1 when the
#                   newest run itself hasn't completed, so a reader can see
#                   a check is currently running without that fact
#                   overriding the real verdict.
#
#   NOTE: this script fetches and classifies from up to RUNS-PER-WORKFLOW
#   most recent scheduled runs (see below), not a single run -- this is
#   what makes the failure-streak count and the
#   in-progress-cannot-mask-a-streak guarantee possible. (An earlier
#   revision of this header said the opposite -- "this script never
#   reports a failure-streak COUNT" -- that claim went stale the moment it
#   caused the incident above and is corrected here.)
#
# RUNS PER WORKFLOW
#
#   Up to RUNS-PER-WORKFLOW (default 10) of the most recent scheduled runs
#   are kept per workflow, selected from ONE API call that fetches an
#   UNFILTERED page of `per_page=<N * RUNS_PAGE_FACTOR>` runs (default
#   10 * 5 = 50, capped at GitHub's per_page maximum of 100) -- there is no
#   additional pagination loop here, unlike the workflow-LIST call. 10 is
#   deliberately small: enough to see a multi-day failure streak (a daily
#   cron produces about one run/day; the 6-run incident above fits with
#   room to spare) without materially increasing API cost -- still exactly
#   one request per workflow. The page is over-fetched by the factor
#   because non-schedule runs (push, workflow_dispatch, pull_request)
#   now occupy page slots. Override with --runs-per-workflow /
#   SCHEDULED_WF_HEALTH_RUNS_PER_WORKFLOW and
#   SCHEDULED_WF_HEALTH_RUNS_PAGE_FACTOR.
#
# WHY NOT event=schedule SERVER-SIDE (issue #2928, 2026-09-23)
#
#   The first version of this script asked the API to filter for us:
#   `runs?event=schedule&per_page=N`. Measured on 2026-09-23 against the
#   `Dependency freshness check` workflow, that filter returned 8 runs
#   with the newest dated 2026-08-24, while the UNFILTERED list held 24
#   runs, every one `event: schedule`, the newest 2026-09-21 -- four of
#   the five most recent scheduled runs were invisible to the filtered
#   call, and the two kinds of run are metadata-identical (same event,
#   actor, branch, path, run_attempt). The observed symptom was a false
#   STALE (age_hours=724 on a workflow that had succeeded two days
#   earlier); the dangerous direction is a hidden failure streak reported
#   as OK -- the exact blind-spot class of the 2026-09-10..12 incident
#   above. The fix is to fetch unfiltered and select `.event ==
#   "schedule"` client-side; the streak logic, the in_progress skipping
#   and the floor discipline all carry over unchanged.
#
# STALENESS WINDOW
#
#   One global window applies to every workflow (default 216h / 9 days --
#   covers a weekly cron plus slack). This is a known simplification: a
#   workflow with a legitimately longer cadence than the window will
#   misreport STALE. Override with --stale-hours / SCHEDULED_WF_HEALTH_STALE_HOURS
#   for a repo/run where that matters; per-workflow windows are not
#   implemented (would need to parse each workflow's own `schedule:` cron
#   expression, out of scope for this pass). Staleness is always measured
#   from the newest COMPLETED run's created_at, never from an in_progress
#   run's -- an in_progress run's age says nothing about the last real
#   result.
#
# EXIT CODES (distinct per failure CLASS -- never collapse "couldn't
# measure" into "measured green", see DEGRADE-HONESTLY below)
#
#   0   all measured workflows are OK, NO-SCHEDULE, or UNOBSERVABLE (no
#       RED, no STALE).
#   1   at least one workflow is RED or STALE -- the real, gate-worthy signal.
#   2   cannot measure: no GH_TOKEN in the environment and no
#       SCHEDULED_WF_HEALTH_FETCH hook set, so no API call could be made at
#       all.
#   3   cannot measure: an API call failed (network error, non-2xx, or a
#       non-JSON / malformed response body).
#   64  usage error (bad CLI arguments).
#
# DEGRADE-HONESTLY (the "a check that can't fail is not a check" trap)
#
#   Exit codes 2 and 3 are deliberately DISTINCT from both 0 and 1, and
#   print a distinct "FAIL: ..." message to stderr. A monitor that reports
#   exit 0 / "all OK" when it could not actually reach the API is worse
#   than no monitor -- it launders a blind spot into a green signal. The
#   same discipline is why UNOBSERVABLE is its own class instead of being
#   folded into OK (see the incident above): a monitor that reports green
#   because the only run it looked at hadn't finished yet is the exact
#   same failure mode as exit 0 on a failed API call, just one layer
#   further from the metal. The fixture test
#   (scheduled_workflow_health_test.sh) pins all of this: a missing-token
#   fixture, an API-error fixture, and an all-in-progress fixture must
#   each produce their own distinct, never-green result.
#
# PAGINATION-IS-A-FLOOR (the other trap this repo has been burned by)
#
#   The 2026-09-02 orchestrator undercounted a failure streak 3x by
#   reading a `per_page=5` page boundary as the start of the data. This
#   script avoids that class of bug two ways:
#     1. The workflow LIST call (_list_active_workflows) actually
#        paginates to completion -- it loops until a page comes back
#        shorter than the page size, so "N active workflows" is a real
#        total, not a first-page floor. The summary line states the page
#        count fetched, so a reader isn't left guessing whether pagination
#        happened.
#     2. The per-workflow RUNS call fetches a single unfiltered page of
#        `per_page=<RUNS_PER_WORKFLOW * RUNS_PAGE_FACTOR>` runs, keeps the
#        first RUNS_PER_WORKFLOW scheduled ones, and computes the streak
#        from exactly those. If the history is exhausted (every kept
#        completed run was a failure, with no older non-failure run seen
#        to close the streak) AND there may be more history past what was
#        looked at -- either RUNS_PER_WORKFLOW scheduled runs were kept
#        (the cap was hit), or the UNFILTERED page came back full (its
#        non-schedule runs may have crowded older scheduled ones off the
#        page) -- the streak is reported as a FLOOR, printed as
#        `streak=>=N` rather than `streak=N`: the true streak could be
#        longer than what this script chose to fetch. A page that came
#        back short means the whole observed history was seen and the
#        count is exact even though no success closed the streak. This mirrors the
#        LIST call's own floor discipline (report the real count you
#        looked at, and say so explicitly when there's more you didn't
#        see) applied to a single-page fetch instead of a multi-page one.
#
#   The LIST loop is also BOUNDED (SCHEDULED_WF_HEALTH_MAX_PAGES, default
#   1000): if a propagation bug or a pathological API response ever let
#   the loop see a non-shrinking or non-numeric page count, it exits 3
#   ("cannot measure") once the bound is hit, instead of spinning forever.
#   A monitor that hangs is worse than one that fails outright -- nothing
#   alerts on a hung cron job. See _list_active_workflows.
#
# INJECTABLE HTTP CALL (for hermetic, no-network fixture testing)
#
#   Every API call goes through _api_get(), which by default shells out to
#   curl with $GH_TOKEN. Set SCHEDULED_WF_HEALTH_FETCH to the path of an
#   executable; _api_get then runs `"$SCHEDULED_WF_HEALTH_FETCH" "<path>"`
#   instead of curl, and uses that executable's stdout as the response body
#   and its exit code as success/failure. This is the same seam shape as
#   PR_GATE_STATUS_LIB in dev/scripts/pr_gate_status.sh (source-and-override
#   a backend), adapted to a single external-command hook because this
#   script has only one kind of GitHub call to fake, not three.
#
#   SCHEDULED_WF_HEALTH_NOW_EPOCH overrides "now" (unix seconds) so the
#   STALE classification is deterministic under test without depending on
#   wall-clock time.
#
# USAGE
#   sh scheduled_workflow_health.sh [--repo owner/name] [--stale-hours N] [--runs-per-workflow N]
#
# ENV
#   GH_TOKEN                              GitHub token (required unless
#                                          SCHEDULED_WF_HEALTH_FETCH is set)
#   SCHEDULED_WF_HEALTH_REPO              default repo (overridden by --repo)
#   SCHEDULED_WF_HEALTH_STALE_HOURS       default staleness window in hours
#   SCHEDULED_WF_HEALTH_RUNS_PER_WORKFLOW default scheduled runs fetched per
#                                          workflow (see RUNS PER WORKFLOW
#                                          above; overridden by
#                                          --runs-per-workflow)
#   SCHEDULED_WF_HEALTH_RUNS_PAGE_FACTOR  unfiltered runs fetched per kept
#                                          scheduled run (default 5; the
#                                          page is N*F capped at 100 -- see
#                                          RUNS PER WORKFLOW above)
#   SCHEDULED_WF_HEALTH_FETCH             injectable fetch hook (see above)
#   SCHEDULED_WF_HEALTH_NOW_EPOCH         injectable "now", unix seconds (test only)
#   SCHEDULED_WF_HEALTH_MAX_PAGES         bound on the workflow-list pagination
#                                         loop (default 1000; see
#                                         PAGINATION-IS-A-FLOOR above)

set -eu

_usage() {
  cat <<'EOF'
Usage: scheduled_workflow_health.sh [--repo owner/name] [--stale-hours N] [--runs-per-workflow N]

Reports the classification (RED / STALE / NO-SCHEDULE / UNOBSERVABLE / OK)
of every active workflow, computed from its N most recent scheduled (cron)
runs (default N=10). Exit 0 if all clear, 1 if any RED/STALE, 2/3 if the
API could not be queried at all, 64 on a usage error. See the header of
this script for the full contract.
EOF
}

REPO="${SCHEDULED_WF_HEALTH_REPO:-dayfine/trading}"
STALE_HOURS="${SCHEDULED_WF_HEALTH_STALE_HOURS:-216}"
MAX_PAGES="${SCHEDULED_WF_HEALTH_MAX_PAGES:-1000}"
RUNS_PER_WORKFLOW="${SCHEDULED_WF_HEALTH_RUNS_PER_WORKFLOW:-10}"
RUNS_PAGE_FACTOR="${SCHEDULED_WF_HEALTH_RUNS_PAGE_FACTOR:-5}"

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)
      if [ $# -lt 2 ]; then
        echo "FAIL: --repo requires an argument" >&2
        exit 64
      fi
      REPO="$2"
      shift 2
      ;;
    --repo=*)
      REPO="${1#*=}"
      shift
      ;;
    --stale-hours)
      if [ $# -lt 2 ]; then
        echo "FAIL: --stale-hours requires an argument" >&2
        exit 64
      fi
      STALE_HOURS="$2"
      shift 2
      ;;
    --stale-hours=*)
      STALE_HOURS="${1#*=}"
      shift
      ;;
    --runs-per-workflow)
      if [ $# -lt 2 ]; then
        echo "FAIL: --runs-per-workflow requires an argument" >&2
        exit 64
      fi
      RUNS_PER_WORKFLOW="$2"
      shift 2
      ;;
    --runs-per-workflow=*)
      RUNS_PER_WORKFLOW="${1#*=}"
      shift
      ;;
    -h|--help)
      _usage
      exit 0
      ;;
    *)
      echo "FAIL: unknown argument: $1" >&2
      _usage >&2
      exit 64
      ;;
  esac
done

case "$STALE_HOURS" in
  ''|*[!0-9]*)
    echo "FAIL: --stale-hours must be a positive integer, got '$STALE_HOURS'" >&2
    exit 64
    ;;
esac

case "$RUNS_PER_WORKFLOW" in
  ''|*[!0-9]*|0)
    echo "FAIL: --runs-per-workflow must be a positive integer, got '$RUNS_PER_WORKFLOW'" >&2
    exit 64
    ;;
esac

case "$RUNS_PAGE_FACTOR" in
  ''|*[!0-9]*|0)
    echo "FAIL: SCHEDULED_WF_HEALTH_RUNS_PAGE_FACTOR must be a positive integer, got '$RUNS_PAGE_FACTOR'" >&2
    exit 64
    ;;
esac
# One unfiltered page per workflow: N kept scheduled runs need up to N*F
# slots once push / dispatch / PR runs share the page (issue #2928); GitHub
# caps per_page at 100.
RUNS_PAGE=$((RUNS_PER_WORKFLOW * RUNS_PAGE_FACTOR))
[ "$RUNS_PAGE" -gt 100 ] && RUNS_PAGE=100

if ! command -v jq >/dev/null 2>&1; then
  echo "FAIL: 'jq' is not on PATH -- cannot parse GitHub API responses. Refusing to report (cannot measure)." >&2
  exit 3
fi

if [ -z "${SCHEDULED_WF_HEALTH_FETCH:-}" ] && [ -z "${GH_TOKEN:-}" ]; then
  echo "FAIL: no GH_TOKEN in the environment and no SCHEDULED_WF_HEALTH_FETCH hook set -- cannot query the GitHub API at all. Refusing to report (a monitor that reports green when it could not look is worse than no monitor)." >&2
  exit 2
fi

# _api_get <path-and-query> -- default backend: curl + GH_TOKEN against the
# GitHub REST API. Overridable wholesale via SCHEDULED_WF_HEALTH_FETCH (see
# header). Prints the raw response body to stdout; non-zero exit == failure.
_api_get() {
  _path="$1"
  if [ -n "${SCHEDULED_WF_HEALTH_FETCH:-}" ]; then
    "${SCHEDULED_WF_HEALTH_FETCH}" "$_path"
    return $?
  fi
  curl -sS -f \
    -H "Authorization: token ${GH_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/${_path}"
}

# _api_get_json <path-and-query> -- wraps _api_get with the two failure
# modes this script must never mistake for a real green result: the HTTP
# call itself failing, and the call succeeding but returning something
# that isn't valid JSON (e.g. an HTML error page, a truncated body).
# Prints the validated JSON to stdout and returns 0 on success; on any
# failure, prints a FAIL message to stderr and returns 3 (the script-wide
# "cannot measure" code for API-layer problems, distinct from the
# missing-token code 2).
#
# Deliberately RETURNS 3 rather than calling `exit 3` directly: every
# caller of this function is itself invoked via `x=$(...)` command
# substitution, which runs in a SUBSHELL. `exit` inside a subshell only
# terminates that subshell, not the whole script -- an earlier version of
# this function called `exit 3` here and the failure silently evaporated
# two subshell layers up (main()'s `_raw=$(_list_active_workflows)` saw an
# empty string and carried on as if 0 workflows existed, exit 0 -- exactly
# the "reports green when it could not look" bug this script exists to
# avoid). Every caller below propagates this return code explicitly with
# its own `if ! x=$(...); then return 3; fi` (or `exit 3` at the outermost,
# non-subshelled, layer in main()) rather than relying on errexit to
# cascade through multiple subshell boundaries.
_api_get_json() {
  _path="$1"
  if ! _resp=$(_api_get "$_path"); then
    echo "FAIL: GitHub API request failed for '${_path}' -- cannot report workflow health. Refusing to report green on a failed measurement." >&2
    return 3
  fi
  if ! printf '%s' "$_resp" | jq -e '.' >/dev/null 2>&1; then
    echo "FAIL: GitHub API response for '${_path}' was not valid JSON -- cannot report workflow health." >&2
    return 3
  fi
  printf '%s' "$_resp"
  return 0
}

_now_epoch() {
  if [ -n "${SCHEDULED_WF_HEALTH_NOW_EPOCH:-}" ]; then
    printf '%s' "${SCHEDULED_WF_HEALTH_NOW_EPOCH}"
  else
    date -u +%s
  fi
}

# Prints "id<TAB>name" for every ACTIVE workflow, paginating to completion
# (see PAGINATION-IS-A-FLOOR in the header), followed by a final sentinel
# line "__PAGES__<TAB><n>" recording how many pages were fetched.
#
# The page count CANNOT be communicated via a global variable mutated
# inside this function: this function is always invoked as
# `_x=$(_list_active_workflows)` in main(), and POSIX command substitution
# runs the command in a SUBSHELL -- any variable assignment inside is
# invisible to the caller once the subshell exits. The sentinel line is
# threaded through the one channel that does survive: stdout.
_list_active_workflows() {
  _page=1
  _per_page=100
  _pages=0
  while :; do
    if [ "$_page" -gt "$MAX_PAGES" ]; then
      echo "FAIL: workflow list pagination exceeded ${MAX_PAGES} page(s) (repo=${REPO}) -- refusing to loop forever. This almost certainly means a propagation bug or a malformed/pathological API response, not a repo with tens of thousands of workflows. Refusing to report (cannot measure)." >&2
      return 3
    fi
    if ! _resp=$(_api_get_json "repos/${REPO}/actions/workflows?per_page=${_per_page}&page=${_page}"); then
      return 3
    fi
    _pages=$((_pages + 1))
    _count=$(printf '%s' "$_resp" | jq '.workflows | length')
    case "$_count" in
      ''|*[!0-9]*)
        echo "FAIL: workflow list page ${_page} (repo=${REPO}) did not yield a numeric workflow count -- cannot safely determine whether pagination is complete. Refusing to report (cannot measure)." >&2
        return 3
        ;;
    esac
    printf '%s' "$_resp" | jq -r '.workflows[] | select(.state == "active") | [(.id | tostring), .name] | join("\t")'
    if [ "$_count" -lt "$_per_page" ]; then
      break
    fi
    _page=$((_page + 1))
  done
  printf '__PAGES__\t%s\n' "$_pages"
  return 0
}

# Prints a FIRST line "page_full<TAB>0|1" (1 when the unfiltered page came
# back full, i.e. RUNS_PAGE runs -- older scheduled runs may exist past it;
# see PAGINATION-IS-A-FLOOR item 2), then up to RUNS_PER_WORKFLOW most
# recent SCHEDULED runs, newest first (the GitHub API's natural order),
# one per line as "conclusion<TAB>status<TAB>created_at<TAB>run_id" -- or
# no run lines at all if the page holds zero scheduled runs. A single
# UNFILTERED API call (`per_page=${RUNS_PAGE}`), selecting `.event ==
# "schedule"` client-side; see WHY NOT event=schedule SERVER-SIDE and RUNS
# PER WORKFLOW in the header for why, and how the floor case is reported.
_recent_scheduled_runs() {
  _id="$1"
  if ! _resp=$(_api_get_json "repos/${REPO}/actions/workflows/${_id}/runs?per_page=${RUNS_PAGE}"); then
    return 3
  fi
  _fetched=$(printf '%s' "$_resp" | jq '.workflow_runs | length')
  case "$_fetched" in
    ''|*[!0-9]*)
      echo "FAIL: runs response for workflow ${_id} has no numeric workflow_runs length (got '${_fetched}') -- cannot measure" >&2
      return 3
      ;;
  esac
  if [ "$_fetched" -ge "$RUNS_PAGE" ]; then
    printf 'page_full\t1\n'
  else
    printf 'page_full\t0\n'
  fi
  if [ "$_fetched" -eq 0 ]; then
    return 0
  fi
  printf '%s' "$_resp" | jq -r --argjson n "$RUNS_PER_WORKFLOW" '[.workflow_runs[] | select(.event == "schedule")] | .[:$n][] | [(.conclusion // "null"), (.status // "null"), .created_at, (.id | tostring)] | join("\t")'
  return 0
}

# _classify_recent_runs <runs-newest-first-multiline> <now-epoch> <stale-hours> [<page-full 0|1>]
#
# Reads the run history (as produced by _recent_scheduled_runs, newest
# first) and echoes ONE tab-separated line:
#
#   CLASS<TAB>STREAK<TAB>AGE_HOURS<TAB>NEWEST_INPROGRESS<TAB>NEWEST_CONCLUSION<TAB>NEWEST_STATUS<TAB>NEWEST_CREATED_AT<TAB>NEWEST_RUN_ID
#
# CLASS is one of RED / STALE / OK / UNOBSERVABLE (never NO-SCHEDULE --
# that's decided by the caller before this function is even invoked, on
# whether _recent_scheduled_runs returned anything at all).
#
# Algorithm (see the header's CLASSIFICATION + WHY A SINGLE NEWEST RUN WAS
# NOT ENOUGH sections for the incident this exists to fix):
#   1. Runs with status != "completed" (in_progress, queued, ...) carry no
#      verdict yet and are skipped entirely for streak/staleness purposes
#      -- but the very newest run's own status/conclusion/created_at/id
#      are still captured and reported, so the output line can say
#      "in_progress=1" without that fact overriding the real verdict.
#   2. STREAK counts CONSECUTIVE failure-class completed runs starting
#      from the newest completed run backwards. The count stops
#      incrementing at the first completed run whose conclusion is not a
#      failure class (a closed streak); it also stops if the page runs out
#      before a close is found, in which case STREAK is reported as a
#      FLOOR, printed as streak=>=N (see the floor check in the RED branch
#      below / PAGINATION-IS-A-FLOOR in the top header).
#   3. If no completed run was found at all (every fetched run is still
#      in_progress/queued) -> UNOBSERVABLE. This is the exact incident
#      shape: a live in_progress run must never manufacture OK.
#   4. Else if STREAK >= 1 -> RED.
#   5. Else -> classify OK/STALE from the newest completed run's age,
#      exactly as the old single-run `_classify` did.
_classify_recent_runs() {
  _runs_text="$1"
  _now="$2"
  _stale_hours="$3"
  _page_full="${4:-0}"

  _old_ifs="$IFS"
  IFS='
'
  set -- $_runs_text
  IFS="$_old_ifs"

  _newest_conclusion="null"
  _newest_status="null"
  _newest_created_at=""
  _newest_run_id=""
  _newest_inprogress=0
  _found_completed=0
  _completed_count=0
  _first_completed_conclusion=""
  _first_completed_created_at=""
  _streak=0
  _streak_open=1
  _idx=0

  for _rline in "$@"; do
    _idx=$((_idx + 1))
    _rc=$(printf '%s' "$_rline" | cut -f1)
    _rs=$(printf '%s' "$_rline" | cut -f2)
    _rcat=$(printf '%s' "$_rline" | cut -f3)
    _rid=$(printf '%s' "$_rline" | cut -f4)

    if [ "$_idx" -eq 1 ]; then
      _newest_conclusion="$_rc"
      _newest_status="$_rs"
      _newest_created_at="$_rcat"
      _newest_run_id="$_rid"
      case "$_rs" in
        completed) : ;;
        *) _newest_inprogress=1 ;;
      esac
    fi

    if [ "$_rs" != "completed" ]; then
      # No verdict yet -- skip for streak/staleness, but keep scanning:
      # an older run further back in the page may still be completed.
      continue
    fi

    _completed_count=$((_completed_count + 1))
    if [ "$_found_completed" -eq 0 ]; then
      _found_completed=1
      _first_completed_conclusion="$_rc"
      _first_completed_created_at="$_rcat"
    fi

    if [ "$_streak_open" -eq 1 ]; then
      case "$_rc" in
        failure|cancelled|timed_out|action_required)
          _streak=$((_streak + 1))
          ;;
        *)
          _streak_open=0
          ;;
      esac
    fi
  done

  if [ "$_found_completed" -eq 0 ]; then
    printf 'UNOBSERVABLE\tn/a\tn/a\t%s\t%s\t%s\t%s\t%s\n' \
      "$_newest_inprogress" "$_newest_conclusion" "$_newest_status" "$_newest_created_at" "$_newest_run_id"
    return 0
  fi

  if [ "$_streak" -ge 1 ]; then
    _streak_str="$_streak"
    if [ "$_streak_open" -eq 1 ] \
      && [ "$_streak" -eq "$_completed_count" ] \
      && { [ "$_idx" -eq "$RUNS_PER_WORKFLOW" ] || [ "$_page_full" -eq 1 ]; }; then
      # Every completed scheduled run we kept was a failure (the streak
      # was never closed) AND there may be more history past what was
      # looked at -- either the kept set hit the RUNS_PER_WORKFLOW cap, or
      # the UNFILTERED page came back full (issue #2928: non-schedule
      # runs share the page and may have crowded older scheduled ones
      # off it). Report it as a floor, not an exact count
      # (PAGINATION-IS-A-FLOOR). If fewer than RUNS_PER_WORKFLOW were
      # kept AND the page came back short, we've seen the workflow's
      # entire observed run history and the count is exact even though
      # the streak was never "closed" by a success.
      _streak_str=">=${_streak}"
    fi
    printf 'RED\t%s\tn/a\t%s\t%s\t%s\t%s\t%s\n' \
      "$_streak_str" "$_newest_inprogress" "$_newest_conclusion" "$_newest_status" "$_newest_created_at" "$_newest_run_id"
    return 0
  fi

  _created_epoch=""
  if _created_epoch=$(date -u -d "$_first_completed_created_at" +%s 2>/dev/null); then
    :
  else
    _created_epoch=""
  fi

  if [ -z "$_created_epoch" ]; then
    printf 'OK\t0\tn/a\t%s\t%s\t%s\t%s\t%s\n' \
      "$_newest_inprogress" "$_newest_conclusion" "$_newest_status" "$_newest_created_at" "$_newest_run_id"
    return 0
  fi

  _age_seconds=$((_now - _created_epoch))
  _age_hours=$((_age_seconds / 3600))
  _stale_seconds=$((_stale_hours * 3600))
  if [ "$_age_seconds" -gt "$_stale_seconds" ]; then
    printf 'STALE\t0\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$_age_hours" "$_newest_inprogress" "$_newest_conclusion" "$_newest_status" "$_newest_created_at" "$_newest_run_id"
  else
    printf 'OK\t0\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$_age_hours" "$_newest_inprogress" "$_newest_conclusion" "$_newest_status" "$_newest_created_at" "$_newest_run_id"
  fi
}

main() {
  echo "scheduled_workflow_health: repo=${REPO} stale_hours=${STALE_HOURS} runs_per_workflow=${RUNS_PER_WORKFLOW}"

  if ! _raw=$(_list_active_workflows); then
    # _list_active_workflows already wrote the FAIL message to stderr
    # (via _api_get_json); the outer script exit here is the propagation
    # step, not a duplicate diagnostic. See the propagation note on
    # _api_get_json above.
    exit 3
  fi
  _total_pages=$(printf '%s\n' "$_raw" | awk -F'\t' '$1 == "__PAGES__" { print $2 }')
  _workflows=$(printf '%s\n' "$_raw" | awk -F'\t' '$1 != "__PAGES__"')

  _ok_count=0
  _red_count=0
  _stale_count=0
  _nosched_count=0
  _unobs_count=0
  _red_names=""
  _stale_names=""

  _now="$(_now_epoch)"

  if [ -z "$_workflows" ]; then
    echo "SUMMARY: 0 active workflows found (repo=${REPO}, ${_total_pages} page(s) fetched -- a real total, not a first-page floor)"
    exit 0
  fi

  # Split $_workflows into positional parameters ONCE, on newline, then
  # restore IFS immediately. `for _line in "$@"` below iterates over
  # already-quoted positional params, so no IFS juggling is needed inside
  # the loop body (a prior version tried to toggle IFS per-iteration
  # instead -- fragile, since POSIX `for x in $unquoted` only re-splits
  # once, at loop entry, not per iteration; toggling IFS inside the body
  # accomplished nothing and was a trap for the next edit).
  _old_ifs="$IFS"
  IFS='
'
  set -- $_workflows
  IFS="$_old_ifs"

  for _line in "$@"; do
    _id=$(printf '%s' "$_line" | cut -f1)
    _name=$(printf '%s' "$_line" | cut -f2)

    if ! _fetch_out=$(_recent_scheduled_runs "$_id"); then
      exit 3
    fi
    _page_full=$(printf '%s\n' "$_fetch_out" | head -1 | cut -f2)
    _run_line=$(printf '%s\n' "$_fetch_out" | tail -n +2)
    if [ -z "$_run_line" ]; then
      _nosched_count=$((_nosched_count + 1))
      printf 'NO-SCHEDULE\t%s\t(no scheduled runs observed)\n' "$_name"
      continue
    fi

    _class_line=$(_classify_recent_runs "$_run_line" "$_now" "$STALE_HOURS" "$_page_full")
    _class=$(printf '%s' "$_class_line" | cut -f1)
    _streak=$(printf '%s' "$_class_line" | cut -f2)
    _age_hours=$(printf '%s' "$_class_line" | cut -f3)
    _inprogress=$(printf '%s' "$_class_line" | cut -f4)
    _conclusion=$(printf '%s' "$_class_line" | cut -f5)
    _status=$(printf '%s' "$_class_line" | cut -f6)
    _created_at=$(printf '%s' "$_class_line" | cut -f7)
    _run_id=$(printf '%s' "$_class_line" | cut -f8)

    # The newest run may still be in progress; report the completed run that
    # actually supplied the health verdict separately for summary consumers.
    _completed_run_id=$(printf '%s\n' "$_run_line" | awk -F '\t' '$2 == "completed" {print $4; exit}')
    printf '%s\t%s\trun_id=%s status=%s conclusion=%s created_at=%s age_hours=%s streak=%s in_progress=%s newest_completed_run_id=%s\n' \
      "$_class" "$_name" "$_run_id" "$_status" "$_conclusion" "$_created_at" "$_age_hours" "$_streak" "$_inprogress" "${_completed_run_id:-none}"

    case "$_class" in
      RED)
        _red_count=$((_red_count + 1))
        _red_names="${_red_names}${_red_names:+, }${_name}(streak=${_streak})"
        ;;
      STALE)
        _stale_count=$((_stale_count + 1))
        _stale_names="${_stale_names}${_stale_names:+, }${_name}"
        ;;
      UNOBSERVABLE)
        _unobs_count=$((_unobs_count + 1))
        ;;
      *)
        _ok_count=$((_ok_count + 1))
        ;;
    esac
  done

  _active_total=$((_ok_count + _red_count + _stale_count + _nosched_count + _unobs_count))
  echo "SUMMARY: active=${_active_total} (${_total_pages} page(s) fetched, full pagination -- a real total, not a floor) ok=${_ok_count} red=${_red_count} stale=${_stale_count} no-schedule=${_nosched_count} unobservable=${_unobs_count} -- red/stale/ok/unobservable are each computed from up to ${RUNS_PER_WORKFLOW} most-recent scheduled runs per workflow (not just the newest); red includes a per-workflow failure-streak count (see each RED line's streak=N, or streak=>=N when the fetched page was exhausted before the streak closed)"
  if [ "$_red_count" -gt 0 ]; then
    echo "SUMMARY: RED workflows: ${_red_names}"
  fi
  if [ "$_stale_count" -gt 0 ]; then
    echo "SUMMARY: STALE workflows: ${_stale_names}"
  fi

  if [ "$_red_count" -gt 0 ] || [ "$_stale_count" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

main
