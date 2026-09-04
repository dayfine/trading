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
#     GET /repos/{owner}/{repo}/actions/workflows            (paginated)
#     GET /repos/{owner}/{repo}/actions/workflows/{id}/runs?event=schedule&per_page=1
#
#   -- for each ACTIVE workflow, look at its single newest scheduled
#   (event=schedule) run and classify it. This script makes that repeatable
#   instead of re-typed from memory each session.
#
# CLASSIFICATION (one of, per active workflow)
#
#   RED         -- newest scheduled run's conclusion is failure / cancelled
#                  / timed_out / action_required.
#   STALE       -- newest scheduled run's conclusion is not RED, but its
#                  age exceeds the staleness window (default below).
#   NO-SCHEDULE -- the workflow has zero observed scheduled runs (either it
#                  declares no cron trigger, or a cron trigger exists but
#                  has never fired yet). Informational only -- NEVER
#                  contributes to a non-zero exit. Distinguishing "no cron
#                  in the YAML" from "cron exists, never fired" would
#                  require parsing workflow source, which is out of scope
#                  for an API-only script; both read the same to an
#                  operator ("this workflow's schedule health is currently
#                  unobservable from run history").
#   OK          -- newest scheduled run succeeded (or is still in
#                  progress) and is within the staleness window.
#
#   NOTE: only the SINGLE most-recent scheduled run is inspected per
#   workflow. This script never reports a failure-streak COUNT -- see
#   "PAGINATION-IS-A-FLOOR" below for why that distinction matters here.
#
# STALENESS WINDOW
#
#   One global window applies to every workflow (default 216h / 9 days --
#   covers a weekly cron plus slack). This is a known simplification: a
#   workflow with a legitimately longer cadence than the window will
#   misreport STALE. Override with --stale-hours / SCHEDULED_WF_HEALTH_STALE_HOURS
#   for a repo/run where that matters; per-workflow windows are not
#   implemented (would need to parse each workflow's own `schedule:` cron
#   expression, out of scope for this pass).
#
# EXIT CODES (distinct per failure CLASS -- never collapse "couldn't
# measure" into "measured green", see DEGRADE-HONESTLY below)
#
#   0   all measured workflows are OK or NO-SCHEDULE (no RED, no STALE).
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
#   fixture test (scheduled_workflow_health_test.sh) pins this: a
#   missing-token fixture and an API-error fixture must each produce their
#   own distinct exit code and message, never 0.
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
#     2. The per-workflow RUNS call intentionally asks for `per_page=1` --
#        but that is NOT the same bug, because this script never claims a
#        count or streak from that call. It reports exactly what it asks
#        for: "the single newest scheduled run's conclusion", not "how
#        many of the last N runs failed". There is no floor to mislabel.
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
#   sh scheduled_workflow_health.sh [--repo owner/name] [--stale-hours N]
#
# ENV
#   GH_TOKEN                          GitHub token (required unless
#                                      SCHEDULED_WF_HEALTH_FETCH is set)
#   SCHEDULED_WF_HEALTH_REPO          default repo (overridden by --repo)
#   SCHEDULED_WF_HEALTH_STALE_HOURS   default staleness window in hours
#   SCHEDULED_WF_HEALTH_FETCH         injectable fetch hook (see above)
#   SCHEDULED_WF_HEALTH_NOW_EPOCH     injectable "now", unix seconds (test only)

set -eu

_usage() {
  cat <<'EOF'
Usage: scheduled_workflow_health.sh [--repo owner/name] [--stale-hours N]

Reports the classification (RED / STALE / NO-SCHEDULE / OK) of every
active workflow's newest scheduled (cron) run. Exit 0 if all clear,
1 if any RED/STALE, 2/3 if the API could not be queried at all, 64 on
a usage error. See the header of this script for the full contract.
EOF
}

REPO="${SCHEDULED_WF_HEALTH_REPO:-dayfine/trading}"
STALE_HOURS="${SCHEDULED_WF_HEALTH_STALE_HOURS:-216}"

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
    if ! _resp=$(_api_get_json "repos/${REPO}/actions/workflows?per_page=${_per_page}&page=${_page}"); then
      return 3
    fi
    _pages=$((_pages + 1))
    _count=$(printf '%s' "$_resp" | jq '.workflows | length')
    printf '%s' "$_resp" | jq -r '.workflows[] | select(.state == "active") | [(.id | tostring), .name] | join("\t")'
    if [ "$_count" -lt "$_per_page" ]; then
      break
    fi
    _page=$((_page + 1))
  done
  printf '__PAGES__\t%s\n' "$_pages"
  return 0
}

# Prints the newest scheduled run as "conclusion<TAB>status<TAB>created_at<TAB>run_id"
# or nothing if the workflow has no observed scheduled runs at all.
_newest_scheduled_run() {
  _id="$1"
  if ! _resp=$(_api_get_json "repos/${REPO}/actions/workflows/${_id}/runs?event=schedule&per_page=1"); then
    return 3
  fi
  _count=$(printf '%s' "$_resp" | jq '.workflow_runs | length')
  if [ "$_count" -eq 0 ]; then
    return 0
  fi
  printf '%s' "$_resp" | jq -r '.workflow_runs[0] | [(.conclusion // "null"), (.status // "null"), .created_at, (.id | tostring)] | join("\t")'
  return 0
}

# _classify <conclusion> <created_at-ISO8601> <now-epoch> <stale-hours>
# Echoes one of RED / STALE / OK plus an age-in-hours figure (or "n/a" if
# the timestamp couldn't be parsed), tab-separated.
_classify() {
  _conclusion="$1"
  _created_at="$2"
  _now="$3"
  _stale_hours="$4"

  case "$_conclusion" in
    failure|cancelled|timed_out|action_required)
      printf 'RED\tn/a\n'
      return 0
      ;;
  esac

  _created_epoch=""
  if _created_epoch=$(date -u -d "$_created_at" +%s 2>/dev/null); then
    :
  else
    _created_epoch=""
  fi

  if [ -z "$_created_epoch" ]; then
    printf 'OK\tn/a\n'
    return 0
  fi

  _age_seconds=$((_now - _created_epoch))
  _age_hours=$((_age_seconds / 3600))
  _stale_seconds=$((_stale_hours * 3600))
  if [ "$_age_seconds" -gt "$_stale_seconds" ]; then
    printf 'STALE\t%s\n' "$_age_hours"
  else
    printf 'OK\t%s\n' "$_age_hours"
  fi
}

main() {
  echo "scheduled_workflow_health: repo=${REPO} stale_hours=${STALE_HOURS}"

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

    if ! _run_line=$(_newest_scheduled_run "$_id"); then
      exit 3
    fi
    if [ -z "$_run_line" ]; then
      _nosched_count=$((_nosched_count + 1))
      printf 'NO-SCHEDULE\t%s\t(no scheduled runs observed)\n' "$_name"
      continue
    fi

    _conclusion=$(printf '%s' "$_run_line" | cut -f1)
    _status=$(printf '%s' "$_run_line" | cut -f2)
    _created_at=$(printf '%s' "$_run_line" | cut -f3)
    _run_id=$(printf '%s' "$_run_line" | cut -f4)

    _class_line=$(_classify "$_conclusion" "$_created_at" "$_now" "$STALE_HOURS")
    _class=$(printf '%s' "$_class_line" | cut -f1)
    _age_hours=$(printf '%s' "$_class_line" | cut -f2)

    printf '%s\t%s\trun_id=%s status=%s conclusion=%s created_at=%s age_hours=%s\n' \
      "$_class" "$_name" "$_run_id" "$_status" "$_conclusion" "$_created_at" "$_age_hours"

    case "$_class" in
      RED)
        _red_count=$((_red_count + 1))
        _red_names="${_red_names}${_red_names:+, }${_name}"
        ;;
      STALE)
        _stale_count=$((_stale_count + 1))
        _stale_names="${_stale_names}${_stale_names:+, }${_name}"
        ;;
      *)
        _ok_count=$((_ok_count + 1))
        ;;
    esac
  done

  _active_total=$((_ok_count + _red_count + _stale_count + _nosched_count))
  echo "SUMMARY: active=${_active_total} (${_total_pages} page(s) fetched, full pagination -- a real total, not a floor) ok=${_ok_count} red=${_red_count} stale=${_stale_count} no-schedule=${_nosched_count} -- each figure is a count of workflows, from ONE most-recent scheduled run per workflow, never a failure-streak count"
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
