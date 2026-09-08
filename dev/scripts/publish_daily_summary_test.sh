#!/bin/sh
# Fixture-driven tests for publish_daily_summary.sh (H-DAILY-SUMMARY-PR-LOST,
# dev/status/harness.md). Offline: every fixture is a throwaway git repo
# under mktemp; the GitHub REST calls are exercised via a mock `curl`
# injected on PATH (same technique as
# dev/scripts/orchestrator_fastexit_gate_test.sh's mock curl); `git push` is
# exercised against a LOCAL bare repo added as the `origin` remote, so
# non-dry-run scenarios need no real network either.
#
# Every guard below was mutation-verified by hand during development (same
# discipline as dev/scripts/prune_candidates_test.sh -- "a test that cannot
# fail is not a test"): a targeted, one-line mutation was applied to a
# scratch copy of publish_daily_summary.sh and the affected case(s) were
# re-run to confirm they flip to FAIL. Not shipped as a permanent
# mutation-coverage harness (that heavier machinery, per
# H-GATEPARSER-NO-MUTATION-COVERAGE, exists today only for
# pr_gate_status.sh) -- the mutation list lives where it can't go stale
# silently: in the comment directly above the scenario(s) that kill it (see
# e.g. the "-run3" fixture in scenario group 1, the payload/content
# assertions and the production-shape scenario in group 4, and the
# branch-reuse scenario in group 8). A qc-behavioral rework pass on
# 2026-09-08 (follow-up to PR #2721) ran 28 such mutations against the
# original 35-check suite, found 12 survivors, and added the scenarios
# above to close them -- see dev/status/harness.md's H-DAILY-SUMMARY-PR-LOST
# entry for the summary.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/publish_daily_summary.sh"

PASS=0
FAIL=0

check() { # name expected_rc actual_rc
  _name=$1
  _want=$2
  _got=$3
  if [ "$_got" = "$_want" ]; then
    PASS=$((PASS + 1))
    printf 'ok   %s\n' "$_name"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL %s: want rc=%s, got rc=%s\n' "$_name" "$_want" "$_got"
  fi
}

check_contains() { # name haystack needle
  _name=$1
  _haystack=$2
  _needle=$3
  if printf '%s' "$_haystack" | grep -qF -- "$_needle"; then
    PASS=$((PASS + 1))
    printf 'ok   %s\n' "$_name"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL %s: expected output to contain %s\n' "$_name" "$_needle"
    printf '%s\n' "$_haystack" | sed 's/^/        /'
  fi
}

check_not_contains() { # name haystack needle
  _name=$1
  _haystack=$2
  _needle=$3
  if printf '%s' "$_haystack" | grep -qF -- "$_needle"; then
    FAIL=$((FAIL + 1))
    printf 'FAIL %s: expected output NOT to contain %s\n' "$_name" "$_needle"
    printf '%s\n' "$_haystack" | sed 's/^/        /'
  else
    PASS=$((PASS + 1))
    printf 'ok   %s\n' "$_name"
  fi
}

# --- mock curl -------------------------------------------------------------
# Dispatches on whether the invocation is the PR-create POST (args contain a
# literal "POST", from the script's own `-X POST`) or the existing-PR-lookup
# GET. Controlled entirely by env vars set before each scenario -- see the
# per-var comments below. This mock is used ONLY by non-dry-run scenarios;
# --dry-run scenarios must never invoke curl at all (pinned by "curl calls
# itself" below, via a mock that fails the run if it is invoked).
MOCK_BIN_DIR=$(mktemp -d -t publish_daily_summary_mockbin.XXXXXX)
export MOCK_BIN_DIR
trap 'rm -rf "$MOCK_BIN_DIR" "${REPO_DIR:-}" "${BARE_DIR:-}" "${DEAD_REMOTE_DIR:-}"' EXIT

cat >"$MOCK_BIN_DIR/curl" <<'EOF'
#!/bin/sh
is_post=0
payload=""
prev=""
for a in "$@"; do
  [ "$a" = "POST" ] && is_post=1
  [ "$prev" = "-d" ] && payload="$a"
  prev="$a"
done

if [ "$is_post" = 1 ]; then
  if [ -n "${MOCK_CREATE_PAYLOAD_FILE:-}" ]; then
    printf '%s' "$payload" >"$MOCK_CREATE_PAYLOAD_FILE"
  fi
  if [ "${MOCK_CREATE_FAIL:-0}" = 1 ]; then
    exit 22
  fi
  code="${MOCK_CREATE_HTTP_CODE:-201}"
  case "$code" in
    201)
      num="${MOCK_CREATE_PR_NUMBER:-42}"
      url="${MOCK_CREATE_PR_URL:-https://github.com/dayfine/trading/pull/$num}"
      body="{\"number\": $num, \"html_url\": \"$url\"}"
      ;;
    422)
      body='{"message":"Validation Failed","errors":[{"message":"A pull request already exists"}]}'
      ;;
    500-malformed)
      code=201
      body='{"no_number_field": true}'
      ;;
    *)
      body='{"message":"mock server error"}'
      ;;
  esac
  printf '%s\n%s' "$body" "$code"
else
  if [ "${MOCK_LOOKUP_FAIL:-0}" = 1 ]; then
    exit 22
  fi
  # Call-count-aware: MOCK_LOOKUP_PR_NUMBER_FROM_CALL (default 1) controls
  # from which GET-lookup invocation onward the mock reports the PR as
  # found. This lets a scenario simulate the race the 422-fallback path
  # exists for: the FIRST lookup (the idempotency pre-check in cmd_publish)
  # finds nothing, but a LATER lookup (the 422-fallback lookup, after
  # create reports "already exists") does.
  _cf="${MOCK_BIN_DIR}/.get_call_count"
  _n=0
  [ -f "$_cf" ] && _n=$(cat "$_cf")
  _n=$((_n + 1))
  echo "$_n" >"$_cf"
  _from=${MOCK_LOOKUP_PR_NUMBER_FROM_CALL:-1}
  if [ -n "${MOCK_LOOKUP_PR_NUMBER:-}" ] && [ "$_n" -ge "$_from" ]; then
    printf '[{"number": %s}]' "$MOCK_LOOKUP_PR_NUMBER"
  else
    printf '[]'
  fi
fi
EOF
chmod +x "$MOCK_BIN_DIR/curl"

cat >"$MOCK_BIN_DIR/curl-forbidden" <<'EOF'
#!/bin/sh
echo "curl invoked but forbidden in this scenario (dry-run must never touch the network)" >&2
exit 99
EOF
chmod +x "$MOCK_BIN_DIR/curl-forbidden"

_reset_mock_env() {
  unset MOCK_CREATE_FAIL MOCK_CREATE_HTTP_CODE MOCK_CREATE_PR_NUMBER \
    MOCK_CREATE_PR_URL MOCK_CREATE_PAYLOAD_FILE MOCK_LOOKUP_FAIL \
    MOCK_LOOKUP_PR_NUMBER MOCK_LOOKUP_PR_NUMBER_FROM_CALL 2>/dev/null || true
  rm -f "${MOCK_BIN_DIR}/.get_call_count"
}

# --- fixture repo ------------------------------------------------------------
# A real git repo (so branch/commit/push logic runs against real git, not a
# simulation) with a local BARE repo wired as `origin` -- `git push` succeeds
# with zero network. A second, deliberately-broken remote path is available
# for the push-failure scenario.
_init_fixture() {
  REPO_DIR=$(mktemp -d -t publish_daily_summary_repo.XXXXXX)
  BARE_DIR=$(mktemp -d -t publish_daily_summary_bare.XXXXXX)
  DEAD_REMOTE_DIR=$(mktemp -d -t publish_daily_summary_dead.XXXXXX)
  rm -rf "$DEAD_REMOTE_DIR"

  git init -q --bare "$BARE_DIR"

  (
    cd "$REPO_DIR"
    git init -q
    git config user.email t@t
    git config user.name t
    git config commit.gpgsign false
    git remote add origin "$BARE_DIR"
    mkdir -p dev/daily
    echo "seed" >README.md
    git add README.md
    git commit -q -m seed
    git push -q -u origin HEAD:main
  )
}

_write_summary() { # date [suffix] [mtime YYYYMMDDhhmm]
  _date=$1
  _suffix=${2:-}
  _mtime=${3:-}
  _path="$REPO_DIR/dev/daily/${_date}${_suffix}.md"
  printf '# Status - %s\n\n**Mode:** FULL\n' "$_date" >"$_path"
  [ -n "$_mtime" ] && touch -t "$_mtime" "$_path"
  printf '%s' "$_path"
}

_run_resolve() { # date
  (cd "$REPO_DIR" && "$SCRIPT" resolve --date "$1")
}

_run_publish_live() { # args...
  (
    cd "$REPO_DIR"
    PATH="$MOCK_BIN_DIR:$PATH"
    GH_TOKEN=dummy-test-token
    export GH_TOKEN
    "$SCRIPT" publish "$@"
  )
}

# _remote_file_content <branch> <path-relative-to-repo-root>
# Reads a file's CONTENT off the bare remote at a given branch, via
# `git show`. Deliberately used instead of `git branch --list <name>` for
# "did the publish actually land" assertions: `branch --list` only pins that
# a ref with that NAME exists, which is silent to a mutation that pushes an
# empty/wrong tree under the right branch name (e.g. a `git reset --hard`
# right before `git push`). Prints nothing (not an error) if the branch or
# path doesn't exist, so callers can check_contains against an empty string.
_remote_file_content() { # branch path
  git --git-dir="$BARE_DIR" show "$1:$2" 2>/dev/null || true
}

# =============================================================================
# Scenario group 1: resolution
# =============================================================================
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
_write_summary 2026-09-08 "-plan" 202609081000 >/dev/null

_out=$(_run_resolve 2026-09-08)
check_contains "resolve picks the real summary, not -plan.md" "$_out" "dev/daily/2026-09-08.md"
check_not_contains "resolve excludes -plan.md" "$_out" "2026-09-08-plan.md"

# -run2 suffix, written LATER (newer mtime) -- must win over the plain file.
_write_summary 2026-09-08 "-run2" 202609081100 >/dev/null
_out=$(_run_resolve 2026-09-08)
check_contains "resolve picks the newest -runN variant by mtime" "$_out" "2026-09-08-run2.md"

# -run3 suffix, written EVEN LATER (newest mtime of all) but "-run2" SORTS
# FIRST under a naive lexical `ls` (ascending: "2" < "3"). This is the check
# that actually pins mtime ordering: under `ls -t` (mtime desc) -run3 wins
# because it genuinely has the newest mtime; a mutant that drops the `-t`
# flag (`ls -t` -> `ls`) would incorrectly resolve to -run2, which sorts
# first alphabetically but is NOT the newest file. Without this fixture, the
# previous single -run2-vs-plain check happened to agree under BOTH orderings
# (mtime and lexical both picked -run2), so the `ls -t` -> `ls` mutation
# survived at 35/35 -- exactly the real-world shape on main today
# (2026-07-28-run2/3/4.md, where the mtime-correct answer is run4 and the
# lexical-first answer is run2).
_write_summary 2026-09-08 "-run3" 202609081200 >/dev/null
_out=$(_run_resolve 2026-09-08)
check_contains "resolve picks -run3 by mtime even though -run2 sorts first lexically" "$_out" "2026-09-08-run3.md"
check_not_contains "resolve does not fall back to the lexically-first -run2" "$_out" "run2.md"

rc=0
_out=$(_run_resolve 1999-01-01 2>&1) || rc=$?
check "resolve with no match fails non-zero" 1 "$rc"
check_contains "resolve-with-no-match names the error" "$_out" "no summary file found for date 1999-01-01"

# =============================================================================
# Scenario group 2: --dry-run does the local git work, touches no network
# =============================================================================
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")

rc=0
_out=$(
  cd "$REPO_DIR"
  "$SCRIPT" publish --dry-run --date 2026-09-08 2>&1
) || rc=$?
check "dry-run publish succeeds" 0 "$rc"
check_contains "dry-run reports the resolved branch" "$_out" "branch=ops/daily-2026-09-08"
check_contains "dry-run skips push and PR create" "$_out" "--dry-run, skipping push and PR create"
_branch_after=$(cd "$REPO_DIR" && git rev-parse --abbrev-ref HEAD)
check "dry-run actually created and switched to the branch" "ops/daily-2026-09-08" "$_branch_after"

# dry-run must never invoke curl at all, even if a (broken) curl is on PATH --
# use a curl that hard-fails if invoked; if dry-run's existing-PR-lookup skip
# is ever removed, this scenario goes red.
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
_forbidcurl_dir=$(mktemp -d -t publish_daily_summary_forbidcurl.XXXXXX)
cp "$MOCK_BIN_DIR/curl-forbidden" "$_forbidcurl_dir/curl"
rc=0
_out=$(
  cd "$REPO_DIR"
  PATH="$_forbidcurl_dir:$PATH"
  "$SCRIPT" publish --dry-run --date 2026-09-08 2>&1
) || rc=$?
rm -rf "$_forbidcurl_dir"
check "dry-run never invokes curl (forbidden-curl shim survives)" 0 "$rc"

# =============================================================================
# Scenario group 3: no summary file -> publish fails non-zero (the exact
# failure shape that went undetected for five orchestrator runs)
# =============================================================================
_init_fixture
rc=0
_out=$(
  cd "$REPO_DIR"
  "$SCRIPT" publish --dry-run --date 2026-09-08 2>&1
) || rc=$?
check "publish with no summary file fails non-zero" 1 "$rc"
check_contains "publish-with-no-summary names the error" "$_out" "no summary file found"

# =============================================================================
# Scenario group 4: non-dry-run happy path -- push succeeds, PR created
# =============================================================================
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
_reset_mock_env
MOCK_CREATE_PR_NUMBER=123
MOCK_CREATE_PR_URL=https://github.com/dayfine/trading/pull/123
_payload_file=$(mktemp -t publish_daily_summary_payload.XXXXXX)
MOCK_CREATE_PAYLOAD_FILE="$_payload_file"
export MOCK_CREATE_PR_NUMBER MOCK_CREATE_PR_URL MOCK_CREATE_PAYLOAD_FILE
rc=0
_out=$(_run_publish_live --date 2026-09-08 2>&1) || rc=$?
check "live publish (push+create) succeeds" 0 "$rc"
check_contains "live publish prints the PR number and url" "$_out" "PR #123 https://github.com/dayfine/trading/pull/123"
# CONTENT assertion, not `git branch --list` -- a `branch --list` check only
# pins that a ref named ops/daily-2026-09-08 exists, which is silent to a
# mutant that pushes an empty/reset tree under that name (e.g. `git reset
# --hard "$REMOTE/$BASE_BRANCH"` immediately before `git push`): the branch
# would still exist, `branch --list` would still match, and the suite would
# still read green while the summary itself never reached the remote.
_pushed_content=$(_remote_file_content ops/daily-2026-09-08 dev/daily/2026-09-08.md)
check_contains "the pushed branch carries the summary CONTENT, not just the branch name" "$_pushed_content" "Status - 2026-09-08"
# The mock curl writes the POST payload to $MOCK_CREATE_PAYLOAD_FILE (see the
# mock's definition above) -- assert head/base/title so a wrong `head` (which
# would open a PR from the wrong branch, another silent-drop shape) is caught.
_payload_head=$(jq -r '.head' "$_payload_file")
_payload_base=$(jq -r '.base' "$_payload_file")
_payload_title=$(jq -r '.title' "$_payload_file")
check "PR-create payload head is the daily branch" "ops/daily-2026-09-08" "$_payload_head"
check "PR-create payload base is the default base branch" "main" "$_payload_base"
check "PR-create payload title names the summary date" "ops: daily summary 2026-09-08" "$_payload_title"
rm -f "$_payload_file"
_reset_mock_env

# Production shape: the summary is written but NOT pre-committed. Every
# other live scenario in this suite pre-commits the summary before invoking
# publish -- which means the script's OWN `git add` + `git commit` branch
# (the actual production code path; the orchestrator always leaves the
# summary as a new, uncommitted file) was previously never exercised at
# all. Replacing that branch with `return 1` still left the suite at 35/35
# green. This scenario also independently kills a `git reset --hard` before
# `git push` mutant, because it asserts CONTENT on the remote, not branch
# existence.
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
# deliberately no `git add` / `git commit` here -- production shape
_reset_mock_env
MOCK_CREATE_PR_NUMBER=456
MOCK_CREATE_PR_URL=https://github.com/dayfine/trading/pull/456
export MOCK_CREATE_PR_NUMBER MOCK_CREATE_PR_URL
rc=0
_out=$(_run_publish_live --date 2026-09-08 2>&1) || rc=$?
check "live publish of an UNCOMMITTED summary (production shape) succeeds" 0 "$rc"
check_contains "production-shape publish prints the PR number" "$_out" "PR #456 https://github.com/dayfine/trading/pull/456"
_pushed_content=$(_remote_file_content ops/daily-2026-09-08 dev/daily/2026-09-08.md)
check_contains "production-shape publish: pushed branch carries the summary content" "$_pushed_content" "Status - 2026-09-08"
_reset_mock_env

# =============================================================================
# Scenario group 5: idempotency -- an already-open PR is reported, not
# duplicated, and no git branch work happens at all
# =============================================================================
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
_start_branch=$(cd "$REPO_DIR" && git rev-parse --abbrev-ref HEAD)
_reset_mock_env
MOCK_LOOKUP_PR_NUMBER=77
export MOCK_LOOKUP_PR_NUMBER
rc=0
_out=$(_run_publish_live --date 2026-09-08 2>&1) || rc=$?
check "publish with an existing open PR succeeds (idempotent)" 0 "$rc"
check_contains "existing-PR path reports the PR number" "$_out" "PR already open for ops/daily-2026-09-08: #77"
_branch_after=$(cd "$REPO_DIR" && git rev-parse --abbrev-ref HEAD)
check "existing-PR path does not touch branches" "$_start_branch" "$_branch_after"
_reset_mock_env

# 422-on-create ("already exists") falls back to the lookup and still
# succeeds, AFTER the push (branch really does land on the remote). Uses
# MOCK_LOOKUP_PR_NUMBER_FROM_CALL=2 to simulate the race this path exists
# for: the pre-check lookup (call 1) finds nothing, create then reports
# 422, and the FALLBACK lookup (call 2) is the one that finds it.
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
_reset_mock_env
MOCK_CREATE_HTTP_CODE=422
MOCK_LOOKUP_PR_NUMBER=88
MOCK_LOOKUP_PR_NUMBER_FROM_CALL=2
export MOCK_CREATE_HTTP_CODE MOCK_LOOKUP_PR_NUMBER MOCK_LOOKUP_PR_NUMBER_FROM_CALL
rc=0
_out=$(_run_publish_live --date 2026-09-08 2>&1) || rc=$?
check "422-already-exists on create falls back to lookup and succeeds" 0 "$rc"
check_contains "422 fallback reports the found PR number" "$_out" "88"
_pushed_content=$(_remote_file_content ops/daily-2026-09-08 dev/daily/2026-09-08.md)
check_contains "422 fallback still landed the push (content, not just the branch name) before falling back" "$_pushed_content" "Status - 2026-09-08"
_reset_mock_env

# =============================================================================
# Scenario group 6: failures are LOUD (non-zero), never silent
# =============================================================================

# push itself fails (origin points nowhere).
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
(cd "$REPO_DIR" && git remote set-url origin "$DEAD_REMOTE_DIR")
_reset_mock_env
rc=0
_out=$(_run_publish_live --date 2026-09-08 2>&1) || rc=$?
check "a failing git push is non-zero" 1 "$rc"
check_contains "push-failure names the exact risk (committed but not published)" "$_out" "committed LOCALLY but NOT published"

# PR-create request itself fails (curl error) after a successful push.
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
_reset_mock_env
MOCK_CREATE_FAIL=1
export MOCK_CREATE_FAIL
rc=0
_out=$(_run_publish_live --date 2026-09-08 2>&1) || rc=$?
check "a failing PR-create request is non-zero" 1 "$rc"
check_contains "create-failure names the exact risk (pushed but no PR)" "$_out" "pushed but has NO PR"
_pushed_content=$(_remote_file_content ops/daily-2026-09-08 dev/daily/2026-09-08.md)
check_contains "create-failure scenario still really pushed the branch's CONTENT" "$_pushed_content" "Status - 2026-09-08"
_reset_mock_env

# PR-create "succeeds" (201) but the response has no usable number.
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
_reset_mock_env
MOCK_CREATE_HTTP_CODE=500-malformed
export MOCK_CREATE_HTTP_CODE
rc=0
_out=$(_run_publish_live --date 2026-09-08 2>&1) || rc=$?
check "a 201 response missing a PR number is treated as failure" 1 "$rc"
check_contains "malformed-201 names the risk" "$_out" "no PR number in the response body"
_reset_mock_env

# The existing-PR lookup itself fails (network/auth) -- must refuse to
# proceed blind, not silently assume "no existing PR".
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
_reset_mock_env
MOCK_LOOKUP_FAIL=1
export MOCK_LOOKUP_FAIL
rc=0
_out=$(_run_publish_live --date 2026-09-08 2>&1) || rc=$?
check "a failing existing-PR lookup refuses to proceed blind" 1 "$rc"
check_contains "lookup-failure names the risk" "$_out" "refusing to proceed blind"
_reset_mock_env

# =============================================================================
# Scenario group 7: GH_TOKEN required for any real publish; --dry-run needs
# no credentials at all.
# =============================================================================
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
rc=0
_out=$(
  cd "$REPO_DIR"
  PATH="$MOCK_BIN_DIR:$PATH"
  unset GH_TOKEN
  "$SCRIPT" publish --date 2026-09-08 2>&1
) || rc=$?
check "publish without GH_TOKEN refuses non-zero" 1 "$rc"
check_contains "missing-GH_TOKEN names the fix" "$_out" "GH_TOKEN is not set"

rc=0
_out=$(
  cd "$REPO_DIR"
  unset GH_TOKEN
  "$SCRIPT" publish --dry-run --date 2026-09-08 2>&1
) || rc=$?
check "dry-run publish needs no GH_TOKEN" 0 "$rc"

# =============================================================================
# Scenario group 8: --summary override, --base override, and branch reuse
# =============================================================================

# --summary skips date-based resolution entirely and publishes the given
# path directly, even though the file is untracked (production shape again).
_init_fixture
_explicit_path=$(_write_summary 2026-09-08 "-adhoc" 202609080900)
_reset_mock_env
MOCK_CREATE_PR_NUMBER=901
MOCK_CREATE_PR_URL=https://github.com/dayfine/trading/pull/901
export MOCK_CREATE_PR_NUMBER MOCK_CREATE_PR_URL
rc=0
_out=$(_run_publish_live --summary "$_explicit_path" 2>&1) || rc=$?
check "publish --summary succeeds against the explicit path" 0 "$rc"
check_contains "publish --summary resolves to the given file, not date-based lookup" "$_out" "branch=ops/daily-2026-09-08-adhoc"
_pushed_content=$(_remote_file_content ops/daily-2026-09-08-adhoc dev/daily/2026-09-08-adhoc.md)
check_contains "publish --summary: pushed branch carries the explicit file's content" "$_pushed_content" "Status - 2026-09-08"
_reset_mock_env

# --base overrides the PR-create payload's base branch (pure payload
# override; it does not require a real "release" ref to exist).
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
_reset_mock_env
MOCK_CREATE_PR_NUMBER=902
_payload_file=$(mktemp -t publish_daily_summary_payload.XXXXXX)
MOCK_CREATE_PAYLOAD_FILE="$_payload_file"
export MOCK_CREATE_PR_NUMBER MOCK_CREATE_PAYLOAD_FILE
rc=0
_out=$(_run_publish_live --date 2026-09-08 --base release 2>&1) || rc=$?
check "publish --base succeeds" 0 "$rc"
_payload_base=$(jq -r '.base' "$_payload_file")
check "publish --base is reflected in the PR-create payload" "release" "$_payload_base"
rm -f "$_payload_file"
_reset_mock_env

# branch reuse: the local branch already exists from a PRIOR failed attempt
# (branch created + pushed, but PR-create itself failed, so no PR is open
# for it) -- a rerun must SWITCH to (not attempt to `git switch -c`, which
# errors on an existing branch) the existing branch, pick up updated summary
# content, and complete the publish.
_init_fixture
_write_summary 2026-09-08 "" 202609080900 >/dev/null
(cd "$REPO_DIR" && git add dev/daily && git commit -q -m "add summary")
_main_branch=$(cd "$REPO_DIR" && git rev-parse --abbrev-ref HEAD)
_reset_mock_env
MOCK_CREATE_FAIL=1
export MOCK_CREATE_FAIL
rc=0
_run_publish_live --date 2026-09-08 >/dev/null 2>&1 || rc=$?
check "branch-reuse setup: first attempt fails at PR-create as expected" 1 "$rc"
_reset_mock_env

(cd "$REPO_DIR" && git switch -q "$_main_branch")
printf '# Status - 2026-09-08\n\n**Mode:** FULL (rerun)\n' >"$REPO_DIR/dev/daily/2026-09-08.md"
MOCK_CREATE_PR_NUMBER=904
MOCK_CREATE_PR_URL=https://github.com/dayfine/trading/pull/904
export MOCK_CREATE_PR_NUMBER MOCK_CREATE_PR_URL
rc=0
_out=$(_run_publish_live --date 2026-09-08 2>&1) || rc=$?
check "branch-reuse: rerun against the existing local branch succeeds" 0 "$rc"
check_contains "branch-reuse: rerun creates the PR on the SAME branch" "$_out" "PR #904 https://github.com/dayfine/trading/pull/904"
_pushed_content=$(_remote_file_content ops/daily-2026-09-08 dev/daily/2026-09-08.md)
check_contains "branch-reuse: rerun's updated content actually reached the remote" "$_pushed_content" "FULL (rerun)"
_reset_mock_env

# =============================================================================
# Scenario group 9: CLI argument hygiene
# =============================================================================
rc=0
"$SCRIPT" bogus-command >/dev/null 2>&1 || rc=$?
check "unknown top-level command exits 2" 2 "$rc"

rc=0
(cd "${REPO_DIR:-/tmp}" && "$SCRIPT" publish --summary 2>/dev/null) || rc=$?
check "publish --summary missing its value exits 2" 2 "$rc"

printf '\n%d/%d checks passed\n' "$PASS" "$((PASS + FAIL))"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
