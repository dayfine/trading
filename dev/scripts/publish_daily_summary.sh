#!/bin/sh
# publish_daily_summary.sh -- plain-git + curl-REST publisher for the daily
# orchestrator summary (H-DAILY-SUMMARY-PR-LOST, dev/status/harness.md).
#
# WHY THIS EXISTS
#   `.claude/agents/lead-orchestrator.md` Step 8 publishes the daily summary
#   via:
#       git config user.email "noreply@github.com"
#       git config user.name "claude-orchestrator"
#       jj bookmark set "$BRANCH" -r @
#       jj git push -b "$BRANCH" --allow-new
#   The result, measured over five consecutive orchestrator runs
#   (2026-09-06..08, run ids 34030886835 / 34042419476 / 34127853646 /
#   34148849699 / 34224532158, conclusion "success" on every one, real cost
#   -- $20.18 on the 09-08 run alone): the orchestrator WROTE the summary
#   file (its own log: "Using daily summary: dev/daily/2026-09-08.md") but
#   never pushed it anywhere, and the workflow's own "No open
#   ops/daily-<date> PR found" fallback path confirms no PR was ever
#   opened. The file died with the ephemeral runner. Zero `ops/daily-*` PRs
#   exist since 2026-09-05 (PR #2680).
#
#   CORRECTED ROOT CAUSE (issue #2741, measured 2026-09-09 in this same
#   container image, run 34350513426): `jj git push` itself is NOT broken
#   here -- a probe branch pushed successfully with it. What Step 8 actually
#   hits is two independently-fatal bugs of its own, neither one a jj/git
#   version incompatibility: (1) it configures GIT's identity via
#   `git config user.email/user.name`, but jj does not read git's config --
#   jj needs `jj config set --user user.name/user.email`, so jj sees an
#   empty author and refuses to push; (2) it never runs `jj describe`, so
#   `@` is descriptionless, which jj also refuses to push
#   ("Won't push commit ... since it has no description and it has no
#   author and/or committer set"). Setting identity alone, or a description
#   alone, each still fails on the other half -- both must be fixed
#   together (`jj config set --user ...` then `jj describe`). This is a
#   DIFFERENT defect from H-JJ-JST-BROKEN-GHA's `jst submit` failure (that
#   one IS a real version mismatch: image git 2.34.1 vs jj's
#   `jj git fetch --porcelain` requiring git >= 2.41.0) -- the two should
#   not be conflated or fixed with the same patch. See issue #2741 for the
#   full measurement and `dev/status/harness.md`'s H-JJ-JST-BROKEN-GHA /
#   H-DAILY-SUMMARY-PR-LOST entries for the corrected record.
#
#   `.claude/agents/**` is write-gated in this runtime, so the Step 8 PROSE
#   cannot be fixed from here -- but a SCRIPT it calls can be, and per
#   `.claude/rules/pr-merge-gates.md` Rule 0's lesson ("anything that must
#   not happen while nobody is watching has to be expressed in the
#   vocabulary automation reads"), a script that fails loudly on every
#   dropped step is exactly that vocabulary. This script sidesteps the
#   whole jj-identity/description class of bug by using plain `git` (no
#   jj) end to end, so it needs no `jj config` / `jj describe` fix at all.
#
#   This script does the whole publish with plain `git` (no jj) + `curl`
#   REST (no `gh` -- confirmed absent from the orchestrator container, see
#   H-JJ-JST-BROKEN-GHA), following the backend/idempotency shape already
#   established by dev/scripts/orchestrator_fastexit_gate.sh's PR-creation
#   fallback (422 "already exists" -> look it up by head) and
#   dev/scripts/pr_gate_status.sh's curl+jq REST conventions.
#
# USAGE
#   dev/scripts/publish_daily_summary.sh resolve [--date YYYY-MM-DD]
#       Prints the resolved summary path (newest dev/daily/<date>*.md,
#       excluding *-plan.md) to stdout. Non-zero exit + a named stderr
#       message if none is found -- this is the exact failure shape that
#       went undetected for five runs, so it is pinned hardest in the test
#       suite (see publish_daily_summary_test.sh).
#
#   dev/scripts/publish_daily_summary.sh publish [--dry-run] \
#       [--summary <path>] [--date YYYY-MM-DD] [--base <branch>]
#       Resolves the summary (unless --summary is given), creates/reuses
#       branch `ops/daily-<basename>`, commits the file, pushes it, and
#       opens a PR via `POST /repos/$REPO/pulls`. Idempotent: if an open PR
#       already exists for that head, reports its number and exits 0
#       without creating a duplicate. Prints "PR #<n> <url>" on success so
#       the caller's log carries proof of publication.
#
#       --dry-run performs summary resolution, branch creation, and the
#       local commit, but skips the network-touching steps (the existing-PR
#       lookup, `git push`, and the PR-create POST) entirely. This is what
#       makes the test suite possible without network or credentials: the
#       resolution/branch/commit logic is exercised via --dry-run against
#       real throwaway git-repo fixtures, and the push/POST paths (success,
#       already-exists, and failure) are exercised in non-dry-run mode
#       against a LOCAL file:// git remote (so `git push` needs no network)
#       with a mocked `curl` injected on PATH (same technique as
#       orchestrator_fastexit_gate_test.sh's mock curl) for the GitHub API
#       calls.
#
# ENV
#   GH_TOKEN                        Required for any non-dry-run publish.
#   GITHUB_REPOSITORY               Preferred repo source (GHA sets this).
#   PUBLISH_DAILY_SUMMARY_REPO      Fallback repo override (tests, local).
#   PUBLISH_DAILY_SUMMARY_BASE      Base branch for the PR. Default: main.
#   PUBLISH_DAILY_SUMMARY_REMOTE    git remote name to push to. Default: origin.
#   PUBLISH_DAILY_SUMMARY_DAILY_DIR Directory to resolve summaries from.
#                                   Default: dev/daily.
#
# Sourcing with PUBLISH_DAILY_SUMMARY_LIB=1 exposes every function below for
# publish_daily_summary_test.sh without hitting the network or invoking the
# CLI dispatcher. EVERYTHING BELOW THE GUARD IS A SIDE EFFECT and must stay
# below it (same discipline as pr_gate_status.sh / orchestrator_fastexit_gate.sh
# -- putting a side effect above the guard makes the offline test suite make
# a real network call).

set -eu

REPO="${GITHUB_REPOSITORY:-${PUBLISH_DAILY_SUMMARY_REPO:-dayfine/trading}}"
BASE_BRANCH="${PUBLISH_DAILY_SUMMARY_BASE:-main}"
REMOTE="${PUBLISH_DAILY_SUMMARY_REMOTE:-origin}"
DAILY_DIR="${PUBLISH_DAILY_SUMMARY_DAILY_DIR:-dev/daily}"

# --- resolution ----------------------------------------------------------

# _resolve_summary_path [<date>]
# Newest dev/daily/<date>*.md (mtime order, matching the convention already
# used by orchestrator_fastexit_gate.sh's _prior_summary_path), excluding
# *-plan.md. <date> defaults to today (UTC). Prints the path on success;
# on failure, prints NOTHING to stdout and a named error to stderr, then
# returns non-zero -- never a silent empty success. This is the guard that
# matters most: the production failure this script fixes was a summary that
# WAS written but never published, and the mirror-image bug (silently
# reporting success when nothing was found) would recreate the exact same
# invisible-failure shape this script exists to close.
_resolve_summary_path() {
  _date="${1:-$(date -u +%Y-%m-%d)}"
  if [ ! -d "$DAILY_DIR" ]; then
    echo "publish_daily_summary: no such directory: $DAILY_DIR" >&2
    return 1
  fi
  _match=$(ls -t "$DAILY_DIR/${_date}"*.md 2>/dev/null | grep -v -- '-plan\.md$' | head -1 || true)
  if [ -z "$_match" ]; then
    echo "publish_daily_summary: no summary file found for date $_date under $DAILY_DIR (looked for ${_date}*.md, excluding *-plan.md)" >&2
    return 1
  fi
  printf '%s\n' "$_match"
}

# _branch_name_for <summary-path> -- ops/daily-<basename-without-.md>
_branch_name_for() {
  _base=$(basename "$1" .md)
  printf 'ops/daily-%s\n' "$_base"
}

# --- GitHub REST (curl only -- `gh` is confirmed absent from the GHA
# orchestrator container per H-JJ-JST-BROKEN-GHA; no dual-backend needed) --

# _find_open_pr_for_head <branch>
# Prints the PR number if an open PR exists for that head, empty string
# (rc 0) if none does, or returns non-zero if the lookup itself failed
# (network/auth) -- the caller must not confuse "found nothing" with
# "could not check".
_find_open_pr_for_head() {
  _branch="$1"
  _owner="${REPO%%/*}"
  _resp=$(
    curl -sS -f \
      -H "Authorization: Bearer ${GH_TOKEN:-}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${REPO}/pulls?state=open&head=${_owner}:${_branch}"
  ) || return 2
  _num=$(printf '%s' "$_resp" | jq -r '.[0].number // empty') || return 2
  printf '%s' "$_num"
}

# _create_pr <branch> <title> <body-file>
# On success prints "<number> <url>" and returns 0. On a 422 ("already
# exists") falls back to _find_open_pr_for_head, matching the shape already
# documented for Step 8 in lead-orchestrator.md and mirrored from
# orchestrator_fastexit_gate.sh's own PR-fallback comment. Returns non-zero
# on any outcome that leaves no usable PR number -- never silently "done".
_create_pr() {
  _branch="$1"
  _title="$2"
  _body_file="$3"
  _payload=$(
    jq -n --arg title "$_title" --arg head "$_branch" --arg base "$BASE_BRANCH" \
      --rawfile body "$_body_file" \
      '{title: $title, head: $head, base: $base, body: $body}'
  )
  _http=$(
    curl -sS -w '\n%{http_code}' \
      -H "Authorization: Bearer ${GH_TOKEN:-}" \
      -H "Accept: application/vnd.github+json" \
      -X POST -d "$_payload" \
      "https://api.github.com/repos/${REPO}/pulls"
  ) || {
    echo "publish_daily_summary: PR create request itself failed (network/curl error)" >&2
    return 1
  }
  _code=$(printf '%s' "$_http" | tail -1)
  _body=$(printf '%s' "$_http" | sed '$d')

  case "$_code" in
    201)
      _num=$(printf '%s' "$_body" | jq -r '.number // empty')
      _url=$(printf '%s' "$_body" | jq -r '.html_url // empty')
      if [ -z "$_num" ]; then
        echo "publish_daily_summary: PR create returned HTTP 201 but no PR number in the response body -- treating as a failure, not a success" >&2
        return 1
      fi
      printf '%s %s' "$_num" "$_url"
      return 0
      ;;
    422)
      _num=$(_find_open_pr_for_head "$_branch") || {
        echo "publish_daily_summary: PR create returned 422 (already exists) and the fallback lookup-by-head itself failed" >&2
        return 1
      }
      if [ -z "$_num" ]; then
        echo "publish_daily_summary: PR create returned 422 (already exists) but lookup-by-head found no open PR for $_branch" >&2
        return 1
      fi
      printf '%s %s' "$_num" ""
      return 0
      ;;
    *)
      echo "publish_daily_summary: PR create failed, HTTP $_code: $_body" >&2
      return 1
      ;;
  esac
}

# --- publish ---------------------------------------------------------------

cmd_publish() {
  _dry_run=0
  _summary=""
  _date=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run)
        _dry_run=1
        shift
        ;;
      --summary)
        [ $# -ge 2 ] || { echo "publish_daily_summary publish: --summary needs a value" >&2; return 2; }
        _summary="$2"
        shift 2
        ;;
      --date)
        [ $# -ge 2 ] || { echo "publish_daily_summary publish: --date needs a value" >&2; return 2; }
        _date="$2"
        shift 2
        ;;
      --base)
        [ $# -ge 2 ] || { echo "publish_daily_summary publish: --base needs a value" >&2; return 2; }
        BASE_BRANCH="$2"
        shift 2
        ;;
      *)
        echo "publish_daily_summary publish: unknown argument: $1" >&2
        return 2
        ;;
    esac
  done

  if [ "$_dry_run" -eq 0 ] && [ -z "${GH_TOKEN:-}" ]; then
    echo "publish_daily_summary: GH_TOKEN is not set -- refusing to attempt a real publish (use --dry-run to exercise the logic without credentials)" >&2
    return 1
  fi

  if [ -z "$_summary" ]; then
    _summary=$(_resolve_summary_path "$_date") || return 1
  fi
  if [ ! -f "$_summary" ]; then
    echo "publish_daily_summary: summary file does not exist: $_summary" >&2
    return 1
  fi

  _branch=$(_branch_name_for "$_summary")
  _base_name=$(basename "$_summary" .md)
  _title="ops: daily summary $_base_name"

  echo "publish_daily_summary: resolved summary=$_summary branch=$_branch base=$BASE_BRANCH"

  if [ "$_dry_run" -eq 0 ]; then
    _existing=$(_find_open_pr_for_head "$_branch") || {
      echo "publish_daily_summary: could not check for an existing PR for $_branch (network/auth failure) -- refusing to proceed blind" >&2
      return 1
    }
    if [ -n "$_existing" ]; then
      echo "publish_daily_summary: PR already open for $_branch: #$_existing"
      return 0
    fi
  else
    echo "publish_daily_summary: --dry-run, skipping existing-PR lookup"
  fi

  if git rev-parse --verify --quiet "$_branch" >/dev/null; then
    git switch -q "$_branch" || {
      echo "publish_daily_summary: failed to switch to existing branch $_branch" >&2
      return 1
    }
  else
    git switch -q -c "$_branch" || {
      echo "publish_daily_summary: failed to create branch $_branch" >&2
      return 1
    }
  fi

  if [ -n "$(git status --porcelain -- "$_summary")" ]; then
    git add "$_summary"
    git commit -q -m "$_title" || {
      echo "publish_daily_summary: commit failed on $_branch" >&2
      return 1
    }
  else
    echo "publish_daily_summary: $_summary already committed on $_branch, nothing to add"
  fi

  if [ "$_dry_run" -eq 1 ]; then
    echo "publish_daily_summary: --dry-run, skipping push and PR create"
    return 0
  fi

  if ! git push -u "$REMOTE" "$_branch"; then
    echo "publish_daily_summary: git push failed for $_branch -- the summary is committed LOCALLY but NOT published. This is the exact failure shape H-DAILY-SUMMARY-PR-LOST exists to surface loudly instead of losing silently." >&2
    return 1
  fi

  _body_file=$(mktemp)
  printf 'Automated publish of %s by dev/scripts/publish_daily_summary.sh.\n' "$_summary" >"$_body_file"

  _pr_out=$(_create_pr "$_branch" "$_title" "$_body_file") || {
    rm -f "$_body_file"
    echo "publish_daily_summary: PR creation failed -- branch $_branch is pushed but has NO PR. Do not treat the push alone as success." >&2
    return 1
  }
  rm -f "$_body_file"

  _pr_num=$(printf '%s' "$_pr_out" | awk '{print $1}')
  _pr_url=$(printf '%s' "$_pr_out" | awk '{print $2}')
  if [ -z "$_pr_num" ]; then
    echo "publish_daily_summary: PR creation reported no PR number -- treating as a failure" >&2
    return 1
  fi

  echo "publish_daily_summary: PR #$_pr_num ${_pr_url}"
  return 0
}

# Sourcing with PUBLISH_DAILY_SUMMARY_LIB=1 exposes every function above for
# publish_daily_summary_test.sh without hitting the network or invoking the
# CLI dispatcher below. EVERYTHING BELOW THIS LINE IS A SIDE EFFECT and must
# stay below it.
[ "${PUBLISH_DAILY_SUMMARY_LIB:-}" = 1 ] && return 0

case "${1:-}" in
  resolve)
    shift
    _date=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --date)
          [ $# -ge 2 ] || { echo "publish_daily_summary resolve: --date needs a value" >&2; exit 2; }
          _date="$2"
          shift 2
          ;;
        *)
          echo "publish_daily_summary resolve: unknown argument: $1" >&2
          exit 2
          ;;
      esac
    done
    _resolve_summary_path "$_date"
    ;;
  publish)
    shift
    cmd_publish "$@"
    ;;
  *)
    echo "usage: $0 {resolve [--date YYYY-MM-DD] | publish [--dry-run] [--summary <path>] [--date YYYY-MM-DD] [--base <branch>]}" >&2
    exit 2
    ;;
esac
