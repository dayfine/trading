#!/bin/sh
# Fixture-driven tests for orchestrator_fastexit_gate.sh (issue #2579,
# A-FASTEXIT-VACUOUS). Offline: PR counts are supplied via a mock `curl`
# binary injected on PATH; dev/status/ drift is exercised against a real
# temp git repo with controlled commit dates and file mtimes -- no network.
#
# Pins the two shapes the mechanical gate exists to catch, plus the shape it
# must NOT flag:
#   - empty-queue (0 open PRs) + NO-OP summary               => FAIL (verify)
#   - status drift since prior summary + NO-OP summary        => FAIL (verify)
#   - both violated at once                                   => FAIL (verify)
#   - genuinely idle queue (PRs open, no drift) + NO-OP        => PASS (verify)
#   - drift hidden only behind an exempted orchestrator-summary
#     commit ("ops: daily orchestrator summary ...")           => PASS (verify)
#   - neither NO-OP nor FULL summary                           => PASS trivially, no PR lookup
#
# #2605 rework adds the production-failure shapes qc-behavioral found were
# unfixtured:
#   - curl itself fails (401/403/5xx-style)             => open_pr_count and
#     verify both fail CLOSED (rc=2), never a silent 0
#   - curl "succeeds" but returns non-JSON              => open_pr_count
#     fails closed (rc=2)
#   - mtimes flattened checkout-style, real drift exists => Condition 2
#     still catches it (derives the prior summary's age from its commit
#     date, not mtime)
#   - a same-day consolidated rollup (-summary.md) sits alongside the
#     per-run summary                                    => excluded from
#     _prior_summary_path, same as the workflow's own locate step
#
# #2803 adds the FULL-mode publication check (Scenarios 15-24): a FULL-mode
# summary with no open-or-merged PR for its branch, and not on origin/main,
# is the shape that let a green, costly run silently lose its only durable
# artifact. Covers: no PR + not on main => FAIL; open PR => PASS; merged PR
# => PASS; a CLOSED-BUT-UNMERGED PR => FAIL (the key mutation this suite
# exists to kill -- "any PR found" is not "published"); already on
# origin/main => PASS via a fast path that never calls curl; curl failure /
# non-JSON response while checking => fails closed (rc=2), same discipline
# as the NO-OP path; real-corpus Mode-string casing variants ("Full pass",
# "FULL_PASS") are still recognised; and the ops/daily-<basename> branch
# name is pinned end-to-end against a "-run2"-suffixed path, matching the
# real incident (dev/daily/2026-09-13-run2.md).
#
# #2810 adds the FULL-mode DISPATCH-artifact check (Scenarios 25-34,
# extended to 35-41 by the #2831 behavioral-QC rework -- see below): a
# FULL-mode summary can be genuinely published (Scenarios 15-24 all pass)
# while its OWN `## Dispatched this run` table still claims an unresolved
# dispatch -- run 34853606164 (2026-09-14) recorded three writing-agent
# rows as `_in flight_` and ended there, $18.30 for zero branches. Covers:
# a writing-agent row still reading "in flight" => FAIL; the literal
# "completed at the end of the run" placeholder anywhere in the section,
# even with no in-flight row => FAIL; all writing-agent rows resolved
# (PR # cited, or "**completed**" for a rework row whose PR is cited only
# in Track) => PASS; a QC-agent row reading "in flight at run end" (a
# review spanning a run boundary, nothing lost) => PASS -- the key
# mutation this half of the suite exists to kill, since a naive "any row
# still in flight" rule would wrongly reject the ordinary QC continuation
# shape in dev/daily/2026-09-05.md; a skip/no-dispatch row (Agent "--")
# => PASS regardless of its Outcome text; no `## Dispatched this run`
# section at all, or a table in some other (non-4-column) shape => PASS,
# silently -- nothing this check knows how to parse is not evidence of
# anything; and two real-corpus excerpts, verbatim from
# dev/daily/2026-09-14.md (the broken run) and
# dev/daily/2026-09-14-run2.md (the healthy re-dispatch), pinned to FAIL
# and PASS respectively.
#
# #2831 behavioral-QC rework (CP4) adds Scenarios 35-41: the pfx[]
# writer-agent whitelist in _verify_full_mode_dispatch_artifacts had only
# harness-maintainer genuinely isolated-tested -- feat-backtest was pinned
# only in combination with harness-maintainer, and feat-data /
# feat-weinstein / ops-data / code-health had none, so dropping any of
# those five from pfx[] left the suite green (CP4-a). Scenarios 35-39 test
# each of those five standalone. Separately, the table-shape header gate
# (the canonical `| Track | Agent | Outcome | Notes |` check) was itself
# unpinned -- removing it entirely also passed all 38 scenarios, because
# the one non-canonical-table fixture (old Scenario 30) happened to
# column-misalign away from any writer name (CP4-b). Scenario 40 uses a
# non-canonical header engineered so column 3 coincidentally holds a
# writer name, so the shape gate's effect is actually exercised -- but it
# only proves a ZERO-shared-words header is ignored. A second rework pass
# (CP4-c) found that Scenario 40 alone did not distinguish an EXACT
# canonical-string match from a looser "all four keywords present, any
# order" match -- a fuzzy-match mutant of the header check passed all 44
# scenarios through Scenario 40. Scenario 41 uses a header containing all
# four canonical words in the WRONG order, paired with a data row that
# places a writer name and "_in flight_" in the literal columns 3/4 the
# parser reads, so an exact-match check stays silent (PASS) while a fuzzy
# all-words-present check would misfire (FAIL).
#
# #2887 adds Scenarios 50-52, pinning the two defects found in
# `_prior_summary_path` after it was carried over unfixed by the #2605
# rework that fixed the identical `ls -t` trap in its sibling
# `_prior_summary_timestamp`:
#   - Defect 1 (call-site): every caller MUST pass the current-summary path
#     -- Scenario 50 pins that omitting it (the exact shape
#     lead-orchestrator.md's Condition 2/4 used before this fix) selects the
#     run's OWN just-written, uncommitted summary as "prior", while passing
#     it correctly excludes that file and finds the true prior.
#   - Defect 2 (selector): `ls -t | head -1` has no real ordering
#     information once mtimes are checkout-flattened -- Scenario 51 pins
#     that a mtime order contradicting filename-date order still selects
#     the highest-DATED file, which only holds once the selector reads
#     `dev/daily/*.md` filenames instead of `ls -t`. Scenario 52 pins that
#     the date component always decides the comparison ahead of any
#     `-runN` suffix, so a `-run2` on a later date is never shadowed by a
#     bare-dated file from an earlier date.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
GATE="$HERE/orchestrator_fastexit_gate.sh"

# Source the gate's internal functions (e.g. _prior_summary_path,
# _file_iso_mtime) directly, for scenarios that need to pin the exact PATH
# a selector chose or derive an expected value without duplicating the
# gate's own date-parsing logic. Guarded exactly like the gate's own CLI
# dispatch: with ORCHESTRATOR_FASTEXIT_GATE_LIB=1 set, sourcing defines
# every function and returns before the case-dispatch runs -- no side
# effects, no network.
ORCHESTRATOR_FASTEXIT_GATE_LIB=1
. "$GATE"
unset ORCHESTRATOR_FASTEXIT_GATE_LIB

fails=0
total=0

check() {
  _name=$1
  _want_rc=$2
  _got_rc=$3
  total=$((total + 1))
  if [ "$_got_rc" = "$_want_rc" ]; then
    printf 'ok   %s\n' "$_name"
  else
    printf 'FAIL %s: want rc=%s, got rc=%s\n' "$_name" "$_want_rc" "$_got_rc"
    fails=$((fails + 1))
  fi
}

check_bool() {
  # $1 = name, $2 = 0 (condition true) or 1 (condition false)
  _name=$1
  _ok=$2
  total=$((total + 1))
  if [ "$_ok" -eq 0 ]; then
    printf 'ok   %s\n' "$_name"
  else
    printf 'FAIL %s\n' "$_name"
    fails=$((fails + 1))
  fi
}

# --- mock curl: dispatches on whether the URL (found among "$@") contains
# a "head=" query param -- that shape is UNIQUE to daily_summary_pr_count's
# request (open_pr_count never filters by head). Two more failure-mode
# toggles simulate the production curl-backend failure shapes (#2605 rework),
# applied identically regardless of which request shape is being answered:
#   MOCK_CURL_FAIL=1     -- simulate `curl -f` on a 401/403/5xx: exit 22,
#                            NO stdout (the exact shape that made the old
#                            `curl -f ... | jq 'length'` pipeline silently
#                            report rc=0 with an empty count under `sh`,
#                            which has no `pipefail`).
#   MOCK_CURL_GARBAGE=1  -- simulate a curl "success" (exit 0) whose body
#                            jq cannot parse into a count.
#
# open_pr_count requests (no "head=") answer with a JSON array of
# $MOCK_PR_COUNT dummy elements, as before -- open_pr_count only cares about
# `jq 'length'` on the response, so the element shape is irrelevant to it.
#
# daily_summary_pr_count requests ("head=" present) answer according to
# $MOCK_DAILY_PR_STATE, with a real `state`/`merged_at` shape since
# _daily_summary_pr_count_curl's jq filter inspects both fields:
#   none              -- []  (no PR at all for this branch)
#   open              -- one PR, state=open, merged_at=null
#   merged            -- one PR, state=closed, merged_at=<non-null>
#   closed-unmerged   -- one PR, state=closed, merged_at=null (opened, then
#                        abandoned/closed WITHOUT merging -- must NOT count
#                        as published)
MOCK_BIN_DIR=$(mktemp -d -t orchestrator_fastexit_gate_mockbin.XXXXXX)
trap 'rm -rf "$MOCK_BIN_DIR" "${TMP_REPO:-}"' EXIT

cat > "$MOCK_BIN_DIR/curl" <<'EOF'
#!/bin/sh
# Mock curl -- behavior controlled by env vars set by the test before each
# scenario (see the comment above this heredoc), dispatched by inspecting
# the URL among "$@" for a "head=" query param.
if [ "${MOCK_CURL_FAIL:-0}" = 1 ]; then
  exit 22
fi
if [ "${MOCK_CURL_GARBAGE:-0}" = 1 ]; then
  printf 'not-json-at-all'
  exit 0
fi

_url=""
for _a in "$@"; do
  case "$_a" in
    https://*) _url="$_a" ;;
  esac
done

case "$_url" in
  *head=*)
    if [ -n "${MOCK_DAILY_PR_URL_FILE:-}" ]; then
      printf '%s' "$_url" >"$MOCK_DAILY_PR_URL_FILE"
    fi
    case "${MOCK_DAILY_PR_STATE:-none}" in
      none) printf '[]' ;;
      open) printf '[{"state":"open","merged_at":null}]' ;;
      merged) printf '[{"state":"closed","merged_at":"2026-09-13T12:00:00Z"}]' ;;
      closed-unmerged) printf '[{"state":"closed","merged_at":null}]' ;;
      *) printf '[]' ;;
    esac
    exit 0
    ;;
esac

n="${MOCK_PR_COUNT:-0}"
printf '['
i=0
while [ "$i" -lt "$n" ]; do
  [ "$i" -gt 0 ] && printf ','
  printf '0'
  i=$((i + 1))
done
printf ']'
EOF
chmod +x "$MOCK_BIN_DIR/curl"

PATH="$MOCK_BIN_DIR:$PATH"
export PATH
ORCHESTRATOR_FASTEXIT_GATE_BACKEND=curl
export ORCHESTRATOR_FASTEXIT_GATE_BACKEND
GH_TOKEN=dummy-test-token
export GH_TOKEN
MOCK_CURL_FAIL=0
export MOCK_CURL_FAIL
MOCK_CURL_GARBAGE=0
export MOCK_CURL_GARBAGE
MOCK_DAILY_PR_STATE=none
export MOCK_DAILY_PR_STATE

# #2850's stale-summary check compares a summary's own date against the real
# system UTC date by default -- but every fixture in this suite uses
# synthetic dates (2026-08-26, 2026-08-27, ...) unrelated to wall-clock
# "today", so the check would reject nearly every scenario below with an
# unrelated rc=1 if left at its default. Disable it suite-wide via its own
# documented escape hatch; the "Scenario 42+" block below re-enables it
# per-scenario (by unsetting or overriding) to test the guard itself.
ORCHESTRATOR_EXPECTED_DATE=any
export ORCHESTRATOR_EXPECTED_DATE

# --- fixture repo -------------------------------------------------------
# dev/status/ commit before the prior summary (T0), the prior summary itself
# (T1, mtime), an optional dev/status/ commit AFTER the prior summary (T2,
# representing drift), and the current summary being evaluated (T3, mtime).
TMP_REPO=$(mktemp -d -t orchestrator_fastexit_gate_repo.XXXXXX)
(
  cd "$TMP_REPO"
  git init -q
  git config user.email test@example.com
  git config user.name "Test"
  mkdir -p dev/status dev/daily

  echo "initial" > dev/status/harness.md
  git add dev/status/harness.md
  GIT_AUTHOR_DATE="2026-08-20T00:00:00" GIT_COMMITTER_DATE="2026-08-20T00:00:00" \
    git commit -q -m "harness: seed status file"

  # Prior summary, mtime after the seed commit.
  cat > dev/daily/2026-08-26.md <<'MD'
# Status - 2026-08-26 [run 1]

**Mode:** FULL

## Scheduled workflows
all OK (1 measured; exit 0)
MD
  touch -t 202608260000 dev/daily/2026-08-26.md
)

_reset_summary() {
  # $1 = mode ("NO-OP" or "FULL")
  cat > "$TMP_REPO/dev/daily/2026-08-27.md" <<MD
# Status - 2026-08-27 [run 1]

**Mode:** $1

## Scheduled workflows
all OK (1 measured; exit 0)
MD
  touch -t 202608270000 "$TMP_REPO/dev/daily/2026-08-27.md"
}

_add_status_drift_commit() {
  # $1 = commit subject (used to test the exemption)
  (
    cd "$TMP_REPO"
    echo "updated $(date +%s)" >> dev/status/harness.md
    git add dev/status/harness.md
    GIT_AUTHOR_DATE="2026-08-26T18:00:00" GIT_COMMITTER_DATE="2026-08-26T18:00:00" \
      git commit -q -m "$1"
  )
}

_reset_repo_no_drift() {
  # Reset dev/status/harness.md's commit history back to just the seed
  # commit (T0, before the prior summary) -- used by scenarios that must
  # see zero drift. Also clears any commit `_write_and_commit_prior_summary`
  # added in an earlier scenario, since `git reset --hard` to the root
  # commit removes files that only existed in later, now-discarded commits.
  # Also drops any refs/remotes/origin/main left by `_set_origin_main` in a
  # prior scenario -- `git reset --hard` on the CURRENT branch doesn't touch
  # that ref itself, so without this it would silently leak into the next
  # FULL-mode scenario and make `_daily_summary_on_main` answer true when
  # the scenario means to test the "not on main yet" path.
  (
    cd "$TMP_REPO"
    git reset -q --hard "$(git rev-list --max-parents=0 HEAD)"
    git update-ref -d refs/remotes/origin/main 2>/dev/null || true
  )
}

# _set_origin_main <mode> [summary-relpath]
# Points refs/remotes/origin/main at a fresh commit representing "what's on
# origin/main right now", entirely via plumbing (read-tree/write-tree/
# commit-tree/update-ref against a throwaway index) -- never touches the
# fixture's real HEAD, branch, working tree, or index. Two shapes:
#   with-summary    -- the tree contains ONLY <summary-relpath>, whose
#                       content is read from its current on-disk copy in
#                       $TMP_REPO (so it matches whatever the scenario
#                       already wrote via _reset_summary). Models "the
#                       summary already merged to main".
#   without-summary -- an EMPTY tree. Models the common/healthy case: verify
#                       runs BEFORE the workflow's own auto-merge step, so
#                       origin/main normally does NOT have the summary yet
#                       even on a run that will end up fine.
_set_origin_main() {
  _som_mode="$1"
  _som_relpath="${2:-}"
  (
    cd "$TMP_REPO"
    _som_index=$(mktemp -u -t fastexit_gate_scratch_index.XXXXXX)
    GIT_INDEX_FILE="$_som_index" git read-tree --empty
    if [ "$_som_mode" = "with-summary" ]; then
      GIT_INDEX_FILE="$_som_index" GIT_WORK_TREE="$TMP_REPO" git add -- "$_som_relpath"
    fi
    _som_tree=$(GIT_INDEX_FILE="$_som_index" git write-tree)
    _som_commit=$(git commit-tree "$_som_tree" -m "origin/main scratch snapshot")
    git update-ref refs/remotes/origin/main "$_som_commit"
    rm -f "$_som_index"
  )
}

_write_and_commit_prior_summary() {
  # (Re)creates dev/daily/2026-08-26.md and commits it with a controlled
  # COMMIT date (2026-08-26T00:00:00), independent of whatever its mtime
  # ends up being. Used by fixtures that need the prior summary's real age
  # (per `_prior_summary_timestamp`'s git-log derivation) to differ from
  # its mtime -- e.g. after mtimes are flattened checkout-style.
  (
    cd "$TMP_REPO"
    cat > dev/daily/2026-08-26.md <<'MD'
# Status - 2026-08-26 [run 1]

**Mode:** FULL

## Scheduled workflows
all OK (1 measured; exit 0)
MD
    touch -t 202608260000 dev/daily/2026-08-26.md
    git add dev/daily/2026-08-26.md
    GIT_AUTHOR_DATE="2026-08-26T00:00:00" GIT_COMMITTER_DATE="2026-08-26T00:00:00" \
      git commit -q -m "ops: daily orchestrator summary 2026-08-26 [run 1]"
  )
}

_run_verify() {
  # $1 = summary path (relative to $TMP_REPO)
  (
    cd "$TMP_REPO"
    "$GATE" verify "$1"
  ) >/tmp/orchestrator_fastexit_gate_test.out 2>&1
}

# --- Scenario 1: neither NO-OP nor FULL mode -> PASS trivially, no PR
# lookup at all (uses a real corpus mode string, "LIGHT COORDINATION", per
# dev/daily/2026-07-06.md -- distinct from the FULL-mode scenarios added
# below, which exercise the #2803 publication check this mode deliberately
# is NOT subject to; see the "KNOWN GAP" paragraph in the script header).
MOCK_PR_COUNT=0
export MOCK_PR_COUNT
_reset_repo_no_drift
_reset_summary "LIGHT COORDINATION"
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "neither-NO-OP-nor-FULL summary short-circuits to PASS" 0 "$rc"

# --- Scenario 2: NO-OP + empty queue + no drift -> FAIL (the #2579 bug) --
MOCK_PR_COUNT=0
_reset_repo_no_drift
_reset_summary NO-OP
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "NO-OP with 0 open PRs is rejected" 1 "$rc"
if grep -q 'A-FASTEXIT-VACUOUS' /tmp/orchestrator_fastexit_gate_test.out; then _cite_ok=0; else _cite_ok=1; fi
check_bool "rejection cites A-FASTEXIT-VACUOUS" "$_cite_ok"

# --- Scenario 3: NO-OP + PRs open + no drift -> PASS (legitimate no-op) --
MOCK_PR_COUNT=3
_reset_repo_no_drift
_reset_summary NO-OP
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "NO-OP with open PRs and no status drift is accepted" 0 "$rc"

# --- Scenario 4: NO-OP + PRs open + status drift -> FAIL (Condition 2) --
MOCK_PR_COUNT=3
_reset_repo_no_drift
_add_status_drift_commit "harness: unrelated status edit"
_reset_summary NO-OP
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "NO-OP with dev/status/ drift since prior summary is rejected" 1 "$rc"

# --- Scenario 5: NO-OP + empty queue + status drift -> FAIL (both) ------
MOCK_PR_COUNT=0
_reset_repo_no_drift
_add_status_drift_commit "harness: another unrelated status edit"
_reset_summary NO-OP
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "NO-OP with both violations at once is rejected" 1 "$rc"

# --- Scenario 6: drift hidden only behind an exempted orchestrator-summary
# commit ("ops: daily orchestrator summary ...") -> PASS (exemption honored) --
MOCK_PR_COUNT=3
_reset_repo_no_drift
_add_status_drift_commit "ops: daily orchestrator summary 2026-08-26"
_reset_summary NO-OP
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "drift behind an exempted summary-landing commit is not counted" 0 "$rc"

# --- Scenario 7: open_pr_count in isolation (direct curl-backend parse) --
MOCK_PR_COUNT=7
_got=$("$GATE" open_pr_count)
check "open_pr_count parses the curl-backend response directly" 7 "$_got"

# --- Scenario 8: an unrecognised backend override is refused, not silently
# treated as "0 open PRs" (which would be indistinguishable from a real
# empty queue -- the exact false-clean this script exists to prevent).
rc=0
( ORCHESTRATOR_FASTEXIT_GATE_BACKEND=neither
  export ORCHESTRATOR_FASTEXIT_GATE_BACKEND
  "$GATE" open_pr_count ) >/dev/null 2>&1 || rc=$?
check "an unrecognised backend override is refused, not silently 0" 2 "$rc"

# --- Scenario 9: status_changed_since as a direct CLI subcommand --------
_reset_repo_no_drift
_add_status_drift_commit "harness: direct-subcommand drift fixture"
_got=$(cd "$TMP_REPO" && "$GATE" status_changed_since "2026-08-26T00:00:00")
check "status_changed_since reports the drift count directly" 1 "$_got"

# =========================================================================
# CP1/CP4 (#2605 rework): the curl backend must fail CLOSED, not open, when
# it cannot produce a trustworthy PR count -- both for a bare curl failure
# and for a curl "success" that returns something jq cannot turn into a
# count. Before the fix, `curl -f ... | jq 'length'` under `sh` (no
# pipefail) let a failing curl through as rc=0 with an EMPTY count, and
# `verify`'s own `[ "$_pr_count" -eq 0 ]` swallowed the resulting shell
# error inside its `if`, silently reading the violation as "false".
# =========================================================================

# --- Scenario 10: open_pr_count fails closed (not silently 0) when curl
# itself fails (401/403/5xx-style: curl -f exits non-zero, no stdout) -----
MOCK_CURL_FAIL=1
export MOCK_CURL_FAIL
rc=0
_out=$("$GATE" open_pr_count 2>&1) || rc=$?
check "open_pr_count fails closed when curl itself fails" 2 "$rc"
MOCK_CURL_FAIL=0
export MOCK_CURL_FAIL

# --- Scenario 11: verify on a NO-OP summary fails closed (not silently
# blessed) when curl -- the ONLY backend the GHA orchestrator container has
# (it has no `gh`) -- is failing. This is the production path, not a
# hypothetical: it is exactly the shape a rotated/expired BOT_GITHUB_TOKEN
# or a transient API failure produces. -----------------------------------
MOCK_PR_COUNT=3
_reset_repo_no_drift
_reset_summary NO-OP
MOCK_CURL_FAIL=1
export MOCK_CURL_FAIL
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "verify fails closed on a NO-OP summary when curl itself fails" 2 "$rc"
MOCK_CURL_FAIL=0
export MOCK_CURL_FAIL

# --- Scenario 12: open_pr_count fails closed (not silently 0) when curl
# "succeeds" (exit 0) but returns a body jq cannot parse into a count -----
MOCK_CURL_GARBAGE=1
export MOCK_CURL_GARBAGE
rc=0
_out=$("$GATE" open_pr_count 2>&1) || rc=$?
check "open_pr_count fails closed on a non-JSON curl response" 2 "$rc"
MOCK_CURL_GARBAGE=0
export MOCK_CURL_GARBAGE

# =========================================================================
# CP2 (#2605 rework): Condition 2 must derive the prior summary's age from
# its COMMIT date, not its mtime -- `actions/checkout@v4` (the tree the GHA
# orchestrator job actually runs on) writes every file at checkout time and
# does not preserve mtimes, so an mtime-based comparison is structurally
# blind on the runner it ships to. Also: `_prior_summary_path` must exclude
# the same-day consolidated rollup (`-summary.md`), matching the workflow's
# own locate step, or the run's own rollup can be picked as "prior".
# =========================================================================

# --- Scenario 13: Condition 2 still detects real drift when every
# dev/daily mtime is flattened to "now", exactly as actions/checkout does.
# If `verify` were still reading mtime (the pre-fix behavior), the prior
# summary would read as "written seconds ago" and report zero drift no
# matter how much real drift landed in between. -------------------------
MOCK_PR_COUNT=3
_reset_repo_no_drift
_write_and_commit_prior_summary
_add_status_drift_commit "harness: real drift after the prior summary, mtime-flattened repo"
_reset_summary NO-OP
(cd "$TMP_REPO" && touch dev/daily/*.md)
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "Condition 2 detects drift via commit date when mtimes are checkout-flattened" 1 "$rc"
# #2835: the public command must delegate to the same timestamp recipe.
expected_iso=$(cd "$TMP_REPO" && git log -1 --format='%cI' -- dev/daily/2026-08-26.md)
actual_iso=$(cd "$TMP_REPO" && sh "$GATE" prior_summary_iso dev/daily/2026-08-27.md)
check "prior_summary_iso CLI prefers commit time over checkout mtime" "$expected_iso" "$actual_iso"
# Rework iteration 1 (behavioral review 5229033230): the current-summary exclusion must be load-bearing.
# With every mtime flattened, `ls -t` tie-breaks to the prior anyway; make the current file strictly the
# newest so only the exclusion can select the prior. Fails under `_prior_summary_path ""`.
(cd "$TMP_REPO" && touch -t 202612310000 dev/daily/2026-08-27.md)
actual_iso=$(cd "$TMP_REPO" && sh "$GATE" prior_summary_iso dev/daily/2026-08-27.md)
check "prior_summary_iso CLI excludes the current summary from selection" "$expected_iso" "$actual_iso"
rc=0
(cd "$TMP_REPO" && sh "$GATE" prior_summary_iso a b) >/dev/null 2>&1 || rc=$?
check "prior_summary_iso CLI rejects extra arguments" 2 "$rc"
mkdir -p "$TMP_REPO/no-summary"
actual_iso=$(cd "$TMP_REPO/no-summary" && sh "$GATE" prior_summary_iso)
check "prior_summary_iso CLI has empty output when no summary exists" "" "$actual_iso"


# --- Scenario 14: _prior_summary_path excludes the same-day consolidated
# rollup (dev/daily/<DATE>-summary.md), matching the workflow's own locate
# step. Without this exclusion, `ls -t` can select the CURRENT run's own
# rollup (written LAST, minutes after the per-run summary) as "prior",
# comparing a timestamp against itself and independently zeroing the drift
# window -- real drift landed, but it goes undetected. -------------------
MOCK_PR_COUNT=3
_reset_repo_no_drift
_write_and_commit_prior_summary
_add_status_drift_commit "harness: real drift, obscured-by-rollup fixture"
_reset_summary NO-OP
(
  cd "$TMP_REPO"
  cat > dev/daily/2026-08-27-summary.md <<MD
# Status - 2026-08-27 [rollup]

**Mode:** NO-OP
MD
  touch -t 202608271200 dev/daily/2026-08-27-summary.md
)
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "same-day consolidated rollup is excluded from _prior_summary_path" 1 "$rc"

# =========================================================================
# FULL-mode publication check (issue #2803): a FULL-mode summary with no
# open-or-merged PR for its ops/daily-<basename> branch, and not yet on
# origin/main, means the run's only durable artifact never got published --
# the exact shape run 34768165769 (2026-09-13 evening) hit while staying
# fully green. See the "FULL-MODE PUBLICATION CHECK" header comment in
# orchestrator_fastexit_gate.sh for the full predicate and its ordering-
# constraint rationale.
# =========================================================================

# --- Scenario 15: FULL mode, no PR for the branch, not on origin/main ->
# FAIL, citing the failure class by issue number so a reader of the CI log
# knows exactly what broke and why. -------------------------------------
MOCK_DAILY_PR_STATE=none
export MOCK_DAILY_PR_STATE
_reset_repo_no_drift
_set_origin_main without-summary
_reset_summary FULL
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "FULL mode with no PR and not on main is rejected" 1 "$rc"
if grep -q '#2803' /tmp/orchestrator_fastexit_gate_test.out; then _cite_ok=0; else _cite_ok=1; fi
check_bool "rejection cites issue #2803" "$_cite_ok"

# --- Scenario 16: FULL mode, an OPEN PR exists for the branch -> PASS ----
MOCK_DAILY_PR_STATE=open
_reset_repo_no_drift
_set_origin_main without-summary
_reset_summary FULL
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "FULL mode with an open PR for its branch is accepted" 0 "$rc"

# --- Scenario 17: FULL mode, the PR for the branch already MERGED (state
# closed, merged_at set) -> PASS. This is the ordinary post-merge shape;
# `state=all` + the merged_at check is what makes this distinguishable from
# scenario 18 below. -------------------------------------------------------
MOCK_DAILY_PR_STATE=merged
_reset_repo_no_drift
_set_origin_main without-summary
_reset_summary FULL
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "FULL mode with a merged PR for its branch is accepted" 0 "$rc"

# --- Scenario 18: FULL mode, a PR for the branch was opened then CLOSED
# WITHOUT merging -> FAIL. This is the mutation this suite exists to kill:
# a naive "any PR found regardless of state" check would wrongly pass here
# -- an abandoned, unmerged PR is exactly as much a loss as never opening
# one at all. ---------------------------------------------------------------
MOCK_DAILY_PR_STATE=closed-unmerged
_reset_repo_no_drift
_set_origin_main without-summary
_reset_summary FULL
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "FULL mode with only a closed-unmerged PR is rejected" 1 "$rc"

# --- Scenario 19: FULL mode, the summary is ALREADY on origin/main -> PASS
# via the fast path, without ever calling curl. MOCK_CURL_FAIL=1 here is
# deliberate: if the production code called daily_summary_pr_count despite
# already finding the file on origin/main, this scenario would flip to
# rc=2 and expose the bug -- proving the short-circuit actually short-
# circuits, not just that it happens to return the right answer. ----------
MOCK_DAILY_PR_STATE=none
_reset_repo_no_drift
_reset_summary FULL
_set_origin_main with-summary dev/daily/2026-08-27.md
MOCK_CURL_FAIL=1
export MOCK_CURL_FAIL
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "FULL mode already on origin/main passes without calling curl" 0 "$rc"
MOCK_CURL_FAIL=0
export MOCK_CURL_FAIL

# --- Scenario 20: FULL mode, curl itself fails while checking the PR
# status -> fails closed (rc=2), never silently treated as "not published"
# (rc=1) or "published" (rc=0) -- mirrors Scenario 11's NO-OP-path coverage
# of the same production failure shape (an expired/rotated GH_TOKEN). ------
MOCK_DAILY_PR_STATE=open
_reset_repo_no_drift
_set_origin_main without-summary
_reset_summary FULL
MOCK_CURL_FAIL=1
export MOCK_CURL_FAIL
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "FULL mode fails closed when curl itself fails" 2 "$rc"
MOCK_CURL_FAIL=0
export MOCK_CURL_FAIL

# --- Scenario 21: FULL mode, curl "succeeds" but returns a body jq cannot
# parse into a count for the daily-summary-PR query -> fails closed. -------
MOCK_DAILY_PR_STATE=open
_reset_repo_no_drift
_set_origin_main without-summary
_reset_summary FULL
MOCK_CURL_GARBAGE=1
export MOCK_CURL_GARBAGE
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "FULL mode fails closed on a non-JSON curl response" 2 "$rc"
MOCK_CURL_GARBAGE=0
export MOCK_CURL_GARBAGE

# --- Scenario 22: case-insensitive / real-corpus Mode string variants are
# still recognised as FULL-mode -- "Full pass" (mixed case, matches
# dev/daily/2026-05-01-run2.md's actual wording) with no PR -> FAIL. -------
MOCK_DAILY_PR_STATE=none
_reset_repo_no_drift
_set_origin_main without-summary
_reset_summary "Full pass -- Step 0.5 fast-exit declined"
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "mixed-case 'Full pass' Mode string is recognised as FULL and rejected without a PR" 1 "$rc"

# --- Scenario 23: "FULL_PASS" (underscore variant, matches
# dev/daily/2026-05-23.md's wording) with an open PR -> PASS. --------------
MOCK_DAILY_PR_STATE=open
_reset_repo_no_drift
_set_origin_main without-summary
_reset_summary "FULL_PASS"
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "'FULL_PASS' Mode string is recognised as FULL and accepted with an open PR" 0 "$rc"

# --- Scenario 24: branch derivation matches the real incident shape -- a
# "-run2" suffixed summary path derives branch ops/daily-2026-08-27-run2,
# pinned by capturing the actual URL the mock curl received (not just the
# pass/fail outcome, which a wrong branch name could still accidentally
# produce if MOCK_DAILY_PR_STATE happens to match). ------------------------
MOCK_DAILY_PR_STATE=none
_reset_repo_no_drift
_set_origin_main without-summary
(
  cd "$TMP_REPO"
  cat > dev/daily/2026-08-27-run2.md <<'MD'
# Status - 2026-08-27 [run 2]

**Mode:** FULL

## Scheduled workflows
all OK (1 measured; exit 0)
MD
)
MOCK_DAILY_PR_URL_FILE=$(mktemp -t orchestrator_fastexit_gate_url.XXXXXX)
export MOCK_DAILY_PR_URL_FILE
rc=0
_run_verify dev/daily/2026-08-27-run2.md || rc=$?
check "a -run2 suffixed summary with no PR is rejected (matches the #2803 incident shape)" 1 "$rc"
if grep -qF 'head=dayfine:ops/daily-2026-08-27-run2&state=all' "$MOCK_DAILY_PR_URL_FILE"; then
  _branch_ok=0
else
  _branch_ok=1
fi
check_bool "branch derivation strips only .md and matches ops/daily-2026-08-27-run2" "$_branch_ok"
rm -f "$MOCK_DAILY_PR_URL_FILE"
unset MOCK_DAILY_PR_URL_FILE

MOCK_DAILY_PR_STATE=none
export MOCK_DAILY_PR_STATE

# =========================================================================
# FULL-mode DISPATCH-artifact check (issue #2810): a FULL-mode summary can
# be genuinely PUBLISHED (an open PR exists for its branch -- Scenarios
# 15-24 all pass) while its own `## Dispatched this run` table still
# claims a dispatch that never resolved. See the "FULL-MODE
# DISPATCH-ARTIFACT CHECK" header comment in orchestrator_fastexit_gate.sh
# for the full predicate. Every scenario below uses an OPEN PR for the
# summary's own branch (MOCK_DAILY_PR_STATE=open) so the publication check
# always passes -- any FAIL below is attributable to the dispatch-artifact
# check alone, never a confound with the #2803 half.
# =========================================================================

# _write_dispatch_summary <dispatch-section-body>
# Writes a FULL-mode dev/daily/2026-08-27.md whose `## Dispatched this run`
# section is exactly <dispatch-section-body> (verbatim, already including
# any table markup and/or trailing prose). Mirrors _reset_summary's
# fixture shape but adds the section under test.
_write_dispatch_summary() {
  (
    cd "$TMP_REPO"
    {
      printf '# Status - 2026-08-27 [run 1]\n\n'
      printf '**Mode:** FULL\n\n## Scheduled workflows\nall OK (1 measured; exit 0)\n\n'
      printf '## Dispatched this run\n\n'
      printf '%s\n' "$1"
    } >dev/daily/2026-08-27.md
    touch -t 202608270000 dev/daily/2026-08-27.md
  )
}

MOCK_DAILY_PR_STATE=open
export MOCK_DAILY_PR_STATE

# --- Scenario 25: a writing-agent row still reads "in flight" (the run
# 34853606164 shape, minus the placeholder -- isolates the row-level
# signature from the section-level one tested in Scenario 27). ----------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| harness | harness-maintainer | _in flight_ | `verify` asserts a FULL-mode summary was published (#2803) |
| cleanup | — | **skipped** | nothing to do |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "an unresolved writing-agent 'in flight' row is rejected" 1 "$rc"
if grep -q '#2810' /tmp/orchestrator_fastexit_gate_test.out; then _cite_ok=0; else _cite_ok=1; fi
check_bool "rejection cites issue #2810" "$_cite_ok"

# --- Scenario 26: every writing-agent row resolved (a real PR cited) ->
# PASS. ------------------------------------------------------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| harness | harness-maintainer | **PR #2812** | completed cleanly |
| ops-data | — | **skipped** | data-gaps.md unchanged |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "a fully-resolved dispatch table is accepted" 0 "$rc"

# --- Scenario 27: the literal turn-ended-mid-dispatch placeholder, with
# NO writing-agent row at all (isolates the section-level signature from
# the row-level one tested in Scenario 25) -> FAIL. -----------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| cleanup | — | **skipped** | nothing to do |

_(This section is completed at the end of the run.)_'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "the turn-ended-mid-dispatch placeholder alone is rejected" 1 "$rc"

# --- Scenario 28: a QC re-review row reading "in flight at run end" (a
# review spanning a run boundary, per .claude/rules/pr-gate-loop.md -- the
# PR under review already exists, nothing was lost) -> PASS. This is the
# key mutation this half of the suite exists to kill: a naive "any row
# still in flight" rule would wrongly reject this, the ordinary shape
# recorded verbatim in dev/daily/2026-09-05.md. ---------------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| harness (#2676) | qc-structural (re) | in flight at run end | prior verdict stale by definition |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "a QC re-review 'in flight at run end' row is accepted (not a writing agent)" 0 "$rc"

# --- Scenario 29: a skip/no-dispatch row (Agent "--") whose NOTES column
# happens to mention "in flight" as context, not as this row's own claim
# -> PASS. Lifted verbatim from dev/daily/2026-09-14-run2.md's real
# "not dispatched" row. ---------------------------------------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| backtest-infra / PIT universe | — | **not dispatched** | Fenced LOCAL: "PIT universe migration in flight LOCAL, do not dispatch" |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "a skip row is accepted even when its Notes column mentions 'in flight'" 0 "$rc"

# --- Scenario 30: a table in a different (non-canonical) shape -> PASS,
# silently -- nothing this check knows how to parse is not evidence of
# anything. Also exercises that an "in flight"-looking Outcome inside a
# non-canonical table is correctly never inspected. -----------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| PR | Branch | Author | Tip SHA | Status |
|----|--------|--------|---------|--------|
| #123 | feat/x | someone | abcdef0 | in flight |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "a non-canonical table shape is ignored (PASS, silent)" 0 "$rc"

# --- Scenario 31: a rework-iteration row citing its PR only in the TRACK
# column ("harness (#2749)"), Outcome = "**completed**" with no PR/branch
# of its own -> PASS. Pins the design decision that an artifact need not
# be re-cited in Outcome when it already exists (see the header comment's
# "WHY SCOPED TO WRITING AGENTS" rationale) -- the row this check must NOT
# treat as a violation. ---------------------------------------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| harness (#2749) | harness-maintainer | **completed** | rework iteration 1 |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "a rework-iteration row citing its PR only in Track is accepted" 0 "$rc"

# --- Scenario 32: real-corpus excerpt, VERBATIM from dev/daily/2026-09-14.md
# (the actual broken run 34853606164) -> FAIL. -----------------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| harness | harness-maintainer | _in flight_ | `verify` asserts a FULL-mode summary was actually published (#2803) |
| trade-audit | feat-backtest | _in flight_ | pin R7 = `Fail` for a `force_liquidation` exit (#2800 follow-up) |
| harness | harness-maintainer | _in flight_ | warn-level quality-score digit/adjective lexicon (H-QC-SCORE-ADJECTIVE-LEXICON) |
| cleanup | — | **skipped** | Backlog holds no actionable work |
| ops-data | — | **skipped** | data-gaps.md last touched 2026-05-03 (134 days); EODHD_API_KEY unset |

_(This section is completed at the end of the run.)_'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "real-corpus excerpt from the broken 2026-09-14.md run is rejected" 1 "$rc"

# --- Scenario 33: real-corpus excerpt, VERBATIM from
# dev/daily/2026-09-14-run2.md (the actual healthy re-dispatch that
# followed) -> PASS. -------------------------------------------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| harness | harness-maintainer | **PR #2812** | verify asserts a FULL-mode summary was published (#2803) |
| harness | harness-maintainer | **PR #2814** | Warn-level quality-score digit/adjective lexicon |
| trade-audit | feat-backtest | **PR #2813** | R7 + force_liquidation |
| backtest-infra / PIT universe | — | **not dispatched** | Fenced LOCAL: PIT universe migration in flight LOCAL, do not dispatch |
| cleanup | — | **skipped** | Backlog audited 2026-09-09, no actionable work |
| ops-data | — | **skipped** | gap file is 134 days stale |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "real-corpus excerpt from the healthy 2026-09-14-run2.md run is accepted" 0 "$rc"

# --- Scenario 34: an Agent value that contains a writing-agent name as a
# SUBSTRING but does not START with it -> PASS. Pins prefix (not
# substring) matching: an Agent like a QC-style annotation referencing
# "ops-data" mid-string must not be treated as the ops-data writing agent
# itself. -------------------------------------------------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| ops-data | reviewer-of-ops-data-output | in flight | not an ops-data dispatch, a review annotation |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "an Agent containing a writer name as a substring (not a prefix) is not treated as a writer" 0 "$rc"

# --- Scenarios 35-39: each writing agent named in the pfx[] whitelist,
# tested ISOLATED (mirroring Scenario 25's single-row shape) -- rework
# per QC finding CP4-a: the six-name list at
# orchestrator_fastexit_gate.sh's `split("feat-backtest feat-data
# feat-weinstein harness-maintainer ops-data code-health", pfx, " ")`
# only had harness-maintainer genuinely isolated-tested; feat-backtest was
# pinned only in COMBINATION with harness-maintainer (old Scenario 32), and
# feat-data / feat-weinstein / ops-data / code-health had zero coverage at
# all -- removing any of those five from pfx[] left the whole suite green.
# Each of the five below fails standalone if its name is dropped from
# pfx[]. -------------------------------------------------------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| trade-audit | feat-backtest | _in flight_ | pin R7 = `Fail` for a `force_liquidation` exit |
| cleanup | — | **skipped** | nothing to do |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "feat-backtest alone (no other writer row) with an unresolved 'in flight' row is rejected" 1 "$rc"

_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| data-foundations | feat-data | _in flight_ | extend deep universe coverage |
| cleanup | — | **skipped** | nothing to do |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "feat-data alone with an unresolved 'in flight' row is rejected" 1 "$rc"

_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| weinstein-base | feat-weinstein | _in flight_ | short-side risk control |
| cleanup | — | **skipped** | nothing to do |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "feat-weinstein alone with an unresolved 'in flight' row is rejected" 1 "$rc"

_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| ops | ops-data | _in flight_ | rebuild universe inventory |
| cleanup | — | **skipped** | nothing to do |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "ops-data alone with an unresolved 'in flight' row is rejected" 1 "$rc"

_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Track | Agent | Outcome | Notes |
|-------|-------|---------|-------|
| cleanup | code-health | _in flight_ | function-length finding |
| ops-data | — | **skipped** | data-gaps.md unchanged |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "code-health alone with an unresolved 'in flight' row is rejected" 1 "$rc"

# --- Scenario 40: a NON-canonical table header whose column layout would
# coincidentally place a writer name in the "Agent" position (column 3) if
# the table-shape gate were absent -> PASS. Rework per QC finding CP4-b:
# the old Scenario 30 fixture (`| PR | Branch | Author | Tip SHA | Status |`)
# happened to column-misalign so column 3 ("Author") held a non-writer
# value ("someone"), so removing the shape gate entirely (treating any
# first `|`-row as the header) ALSO passed all 38 scenarios -- Scenario 30
# pinned only "this one fixture passes", not "the guard rejects a
# wrong-shaped table that would otherwise false-positive". This fixture's
# column 3 ("Assignee") holds "ops-data" with Outcome "in flight" in
# column 4 -- exactly the shape that would wrongly fail under the gate-
# removed mutation, and correctly stays silent (PASS) under the real
# canonical-header check. --------------------------------------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| PR | Assignee | Status | Comment |
|----|----------|--------|---------|
| #500 | ops-data | in flight | unrelated non-canonical table, must not be inspected |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "a non-canonical table whose column 3 coincidentally holds a writer name is ignored (PASS, silent)" 0 "$rc"

# --- Scenario 41: a header containing all four canonical words, but NOT in
# canonical column order, paired with a data row that places a writer name
# and "_in flight_" in the fixed positional columns the parser reads
# (literal column 3 / column 4) -> PASS, silent. Rework per QC finding
# CP4-c: Scenario 40 proves a header sharing ZERO words with the canonical
# form is ignored, but does not prove the check enforces exact canonical
# equality (column order + exact wording) rather than a looser "all four
# keywords present, any order" match -- a mutant that loosens
# `norm == "|track|agent|outcome|notes|"` to an all-four-words-present test
# passes every scenario through 40. This header ("| Agent | Outcome |
# Track | Notes |") contains all four words yet in the wrong order, so
# `norm` never equals the canonical string and `intable` must stay 0 under
# the real (exact-match) check; the data row's literal column 3 holds
# "feat-backtest" and column 4 holds "_in flight_" -- exactly the shape
# that, if the gate were fuzzy, would misread this non-canonical table as
# the real dispatch table and reject it. ------------------------------------
_reset_repo_no_drift
_set_origin_main without-summary
_write_dispatch_summary '| Agent | Outcome | Track | Notes |
|-------|--------|-------|-------|
| trade-audit | feat-backtest | _in flight_ | pin R7 = `Fail` for a `force_liquidation` exit |'
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "a header with all four canonical words in the wrong order is ignored -- exact-match, not fuzzy all-words-present (PASS, silent)" 0 "$rc"

MOCK_DAILY_PR_STATE=none
export MOCK_DAILY_PR_STATE

# #2634: published FULL summaries cannot silently omit scheduled health.
MOCK_DAILY_PR_STATE=open
_reset_summary FULL
sed '/^## Scheduled workflows$/d' "$TMP_REPO/dev/daily/2026-08-27.md" > "$TMP_REPO/missing.md"
rc=0
_run_verify missing.md || rc=$?
check "FULL missing scheduled-workflow section fails" 1 "$rc"
_reset_summary FULL
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "FULL scheduled-workflow section passes" 0 "$rc"
# Negative boundary (qc-behavioral, rework iteration 1): the requirement is FULL-scoped. A legitimate
# NO-OP run never executes Step 6.4 and renders no section, so a NO-OP summary in the Scenario-3
# configuration (open PRs, no drift) with the heading stripped must still verify rc 0. Goes red if the
# guard is hoisted above the **Mode:** FULL branch.
MOCK_DAILY_PR_STATE=none
MOCK_PR_COUNT=3
_reset_repo_no_drift
_reset_summary NO-OP
sed '/^## Scheduled workflows$/d' "$TMP_REPO/dev/daily/2026-08-27.md" > "$TMP_REPO/noop-missing.md"
rc=0
_run_verify noop-missing.md || rc=$?
check "non-FULL summary is exempt from the scheduled-workflow section" 0 "$rc"
MOCK_DAILY_PR_STATE=open

# =========================================================================
# STALE-SUMMARY CHECK (issue #2850): `verify` must refuse to validate a
# summary whose own basename date doesn't match the expected run date. Run
# 35096884441 (2026-09-16) hit this for real: no dev/daily/2026-09-16*.md
# existed (checkout-flattened mtimes broke the workflow's `ls -t` fallback
# into picking the OLDEST file instead of the newest -- see the
# STALE-SUMMARY CHECK header comment in orchestrator_fastexit_gate.sh), and
# `verify` validated a 2-day-old dev/daily/2026-09-14.md as if it were
# today's run. Scenarios 42-49 cover: stale-by-2-days rejected (via the CLI
# override, deterministic); exactly-today accepted; the day before accepted
# (midnight-straddle tolerance); the ORCHESTRATOR_EXPECTED_DATE=any escape
# hatch bypassing the check on a badly-stale (multi-year) date, contrasted
# with the SAME fixture failing once the hatch is off (proves the pass
# above is the hatch's doing, not an unrelated bug); an unparsable basename
# treated as a silent pass-through, not a violation; and -- the load-bearing
# proof for this issue -- the check firing via the EXISTING ONE-ARGUMENT
# `verify <path>` call shape the workflow actually uses, with no override
# argument and no env var, falling back to the real system UTC date.
# =========================================================================

MOCK_PR_COUNT=3
_reset_repo_no_drift

_write_daily_fixture() {
  # $1 = relative path under $TMP_REPO, $2 = mode string
  (
    cd "$TMP_REPO"
    cat > "$1" <<MD
# Status - $1 [run 1]

**Mode:** $2

## Scheduled workflows
all OK (1 measured; exit 0)
MD
  )
}

# --- Scenario 42: stale by 2 days (CLI override, deterministic) -> FAIL --
_write_daily_fixture dev/daily/2026-09-14.md NO-OP
rc=0
( cd "$TMP_REPO" && "$GATE" verify dev/daily/2026-09-14.md 2026-09-16 ) \
  >/tmp/orchestrator_fastexit_gate_test.out 2>&1 || rc=$?
check "a summary dated 2 days before the expected date is rejected" 1 "$rc"
if grep -q '#2850' /tmp/orchestrator_fastexit_gate_test.out; then _cite_ok=0; else _cite_ok=1; fi
check_bool "staleness rejection cites issue #2850" "$_cite_ok"

# --- Scenario 43: dated exactly the expected date -> PASS ----------------
_write_daily_fixture dev/daily/2026-09-16.md NO-OP
rc=0
( cd "$TMP_REPO" && "$GATE" verify dev/daily/2026-09-16.md 2026-09-16 ) \
  >/tmp/orchestrator_fastexit_gate_test.out 2>&1 || rc=$?
check "a summary dated exactly the expected date is accepted" 0 "$rc"

# --- Scenario 44: dated the day before the expected date (UTC-midnight
# straddle) -> PASS --------------------------------------------------------
_write_daily_fixture dev/daily/2026-09-15.md NO-OP
rc=0
( cd "$TMP_REPO" && "$GATE" verify dev/daily/2026-09-15.md 2026-09-16 ) \
  >/tmp/orchestrator_fastexit_gate_test.out 2>&1 || rc=$?
check "a summary dated the day before the expected date is accepted (midnight straddle)" 0 "$rc"

# --- Scenario 45: ORCHESTRATOR_EXPECTED_DATE=any bypasses the check even on
# a badly (multi-year) stale summary -> PASS ------------------------------
_write_daily_fixture dev/daily/2020-01-01.md NO-OP
rc=0
( cd "$TMP_REPO"
  ORCHESTRATOR_EXPECTED_DATE=any
  export ORCHESTRATOR_EXPECTED_DATE
  "$GATE" verify dev/daily/2020-01-01.md
) >/tmp/orchestrator_fastexit_gate_test.out 2>&1 || rc=$?
check "ORCHESTRATOR_EXPECTED_DATE=any bypasses the staleness check" 0 "$rc"

# --- Scenario 46: the SAME badly-stale fixture, hatch off (explicit
# override instead) -> FAIL. Contrasts directly with Scenario 45: proves
# that scenario's PASS is the escape hatch's doing, not some unrelated gap
# that would have passed this fixture regardless. --------------------------
rc=0
( cd "$TMP_REPO" && "$GATE" verify dev/daily/2020-01-01.md 2026-09-16 ) \
  >/tmp/orchestrator_fastexit_gate_test.out 2>&1 || rc=$?
check "the same badly-stale summary without the escape hatch is rejected" 1 "$rc"

# --- Scenario 47: unparsable basename -> silent pass-through, not a
# violation (matches the DISPATCH-ARTIFACT check's table-shape-gate
# precedent: an input shape this check doesn't recognise is not evidence of
# anything). -----------------------------------------------------------
_write_daily_fixture not-a-daily-summary.md NO-OP
rc=0
( cd "$TMP_REPO" && "$GATE" verify not-a-daily-summary.md 2026-09-16 ) \
  >/tmp/orchestrator_fastexit_gate_test.out 2>&1 || rc=$?
check "an unparsable basename is a silent pass-through, not a violation" 0 "$rc"

# --- Scenario 48/49: the EXISTING ONE-ARGUMENT `verify <path>` call shape
# (no override argument, no ORCHESTRATOR_EXPECTED_DATE) -- the exact call
# .github/workflows/orchestrator.yml makes and cannot be edited to add a
# second argument to. Falls back to the real system UTC date, so these two
# scenarios are dynamic (computed from the real clock) rather than pinned
# to a fixed calendar date. -------------------------------------------------
_today=$(date -u '+%Y-%m-%d')
_two_days_ago=$(date -u -d "$_today - 2 day" '+%Y-%m-%d' 2>/dev/null \
  || date -u -j -v-2d -f '%Y-%m-%d' "$_today" '+%Y-%m-%d')

_write_daily_fixture "dev/daily/${_two_days_ago}.md" NO-OP
rc=0
( cd "$TMP_REPO"
  unset ORCHESTRATOR_EXPECTED_DATE
  "$GATE" verify "dev/daily/${_two_days_ago}.md"
) >/tmp/orchestrator_fastexit_gate_test.out 2>&1 || rc=$?
check "one-argument verify call (no override, real system date) rejects a 2-day-stale summary" 1 "$rc"

_write_daily_fixture "dev/daily/${_today}.md" NO-OP
rc=0
( cd "$TMP_REPO"
  unset ORCHESTRATOR_EXPECTED_DATE
  "$GATE" verify "dev/daily/${_today}.md"
) >/tmp/orchestrator_fastexit_gate_test.out 2>&1 || rc=$?
check "one-argument verify call (no override, real system date) accepts a summary dated today" 0 "$rc"

# =========================================================================
# issue #2887: `_prior_summary_path` was carried over with the identical
# `ls -t | head -1` idiom its sibling `_prior_summary_timestamp` had already
# been fixed away from (#2605), and its callers in lead-orchestrator.md
# Conditions 2/4 never passed the current-summary exclusion argument at
# all. Scenarios 50-52 use dev/daily/2026-12-*.md dates -- strictly later
# than every fixture date used anywhere else in this suite, including the
# dynamic ${_today}/${_two_days_ago} files just above -- so the accumulated,
# never-deleted, untracked dev/daily/ debris from scenarios 1-49 can never
# be mistaken for the file under test.
# =========================================================================

# --- Scenario 50: the no-arg `prior_summary_iso` call (Defect 1) selects
# the run's OWN just-written, uncommitted summary once it exists on disk --
# exactly the failure mode Step 0.5 Conditions 2 and 4 hit before this fix,
# since neither passed the current-summary argument. Passing it correctly
# excludes the current file and finds the true (committed) prior instead. -
_reset_repo_no_drift
(
  cd "$TMP_REPO"
  cat > dev/daily/2026-12-01.md <<'MD'
# Status - 2026-12-01 [run 1]

**Mode:** FULL
MD
  git add dev/daily/2026-12-01.md
  GIT_AUTHOR_DATE="2026-12-01T00:00:00" GIT_COMMITTER_DATE="2026-12-01T00:00:00" \
    git commit -q -m "ops: daily orchestrator summary 2026-12-01 [run 1]"
)
(
  cd "$TMP_REPO"
  cat > dev/daily/2026-12-02.md <<'MD'
# Status - 2026-12-02 [run 1]

**Mode:** FULL
MD
  # Deliberately left UNCOMMITTED -- models a summary written before the
  # run's own commit-and-push step (the write-early escalation under
  # consideration; see issue #2887's Defect 1).
  touch -t 202612020000 dev/daily/2026-12-02.md
)
expected_prior_iso=$(cd "$TMP_REPO" && git log -1 --format='%cI' -- dev/daily/2026-12-01.md)
with_arg_iso=$(cd "$TMP_REPO" && "$GATE" prior_summary_iso dev/daily/2026-12-02.md)
check "prior_summary_iso WITH the current-summary arg finds the true prior, never the current file" \
  "$expected_prior_iso" "$with_arg_iso"

no_arg_iso=$(cd "$TMP_REPO" && "$GATE" prior_summary_iso)
own_file_iso=$(cd "$TMP_REPO" && _file_iso_mtime dev/daily/2026-12-02.md)
check "prior_summary_iso WITHOUT the current-summary arg selects the run's own just-written file instead (Defect 1 vacuity)" \
  "$own_file_iso" "$no_arg_iso"
if [ "$no_arg_iso" = "$expected_prior_iso" ]; then _vacuous_ok=1; else _vacuous_ok=0; fi
check_bool "the no-arg result differs from the true prior -- proves the vacuity, not a coincidental match" "$_vacuous_ok"

# --- Scenario 51: `_prior_summary_path` selects the highest-DATED file
# even when mtime order flatly contradicts filename-date order (Defect 2)
# -- the exact shape `actions/checkout` produces, where every tracked file
# gets one checkout-time mtime and real chronological ordering is lost.
# Would FAIL against the pre-fix `ls -t | head -1` selector, which would
# instead return dev/daily/2026-12-11.md (the newest MTIME, oldest date). --
_reset_repo_no_drift
(
  cd "$TMP_REPO"
  for d in 2026-12-11 2026-12-12 2026-12-13; do
    cat > "dev/daily/${d}.md" <<MD
# Status - ${d} [run 1]

**Mode:** FULL
MD
  done
  # mtime order is the exact INVERSE of filename-date order.
  touch -t 202612310000 dev/daily/2026-12-11.md   # oldest date, newest mtime
  touch -t 202606150000 dev/daily/2026-12-12.md   # middle date, middle mtime
  touch -t 202601010000 dev/daily/2026-12-13.md   # newest date, OLDEST mtime
)
selected=$(cd "$TMP_REPO" && _prior_summary_path "")
check "the selector picks the highest-DATED file even though it has the oldest mtime" \
  "dev/daily/2026-12-13.md" "$selected"

# --- Scenario 52: the filename date always decides the comparison ahead of
# any -runN suffix across different dates -- a later date's -run2 file is
# never shadowed by an earlier date's bare file. (Same-day bare-vs-runN
# ordering is a separate, narrower subtlety not exercised here: under plain
# lexicographic sort "YYYY-MM-DD.md" sorts AFTER "YYYY-MM-DD-runN.md" for
# the IDENTICAL date, since "." > "-"; that only matters comparing files
# from the same date and is not the cross-date shape Defect 2 was measured
# against.) -----------------------------------------------------------
(
  cd "$TMP_REPO"
  cat > dev/daily/2026-12-21.md <<'MD'
# Status - 2026-12-21 [run 1]

**Mode:** FULL
MD
  cat > dev/daily/2026-12-22-run2.md <<'MD'
# Status - 2026-12-22 [run 2]

**Mode:** FULL
MD
)
selected=$(cd "$TMP_REPO" && _prior_summary_path "")
check "a later date's -run2 file sorts after an earlier date's bare file" \
  "dev/daily/2026-12-22-run2.md" "$selected"

# =========================================================================
# Behavioral-QC rework (CP4, issue #2887): `_prior_summary_path`'s own
# `_current` exclusion argument (Scenario 50) is only correct if the
# CALLER derives that argument correctly -- and lead-orchestrator.md's own
# RUN_COUNT/N formula (Step 0.5 Condition 2/4, the no-op exit procedure,
# and Step 7) was unexecutable Markdown prose, never pinned by this suite,
# that RE-COUNTS an uncommitted same-day summary once write-early makes one
# exist on disk before the formula runs -- producing an off-by-one
# CURRENT_SUMMARY_PATH that names a file that doesn't exist, so the
# exclusion argument excludes nothing and Defect 1 (Scenario 50) recurs.
# Extracting the formula into `current_summary_path` (this script, the
# single source of truth all four Markdown call sites now share) makes it
# directly pinnable. Scenarios 53-56 use dev/daily/2027-01-*.md dates --
# strictly later than every date used above, so accumulated debris from
# earlier scenarios can never be mistaken for the file under test.
# =========================================================================

# --- Scenario 53: no same-day summary at all -> the bare, unsuffixed path.
_reset_repo_no_drift
result=$(cd "$TMP_REPO" && "$GATE" current_summary_path 2027-01-05)
check "current_summary_path with no same-day summary returns the bare-date path" \
  "dev/daily/2027-01-05.md" "$result"

# --- Scenario 54: one COMMITTED same-day summary (a genuine earlier run
# today) -> the count includes it, so this run is -run2.
(
  cd "$TMP_REPO"
  cat > dev/daily/2027-01-06.md <<'MD'
# Status - 2027-01-06 [run 1]

**Mode:** FULL
MD
  git add dev/daily/2027-01-06.md
  GIT_AUTHOR_DATE="2027-01-06T00:00:00" GIT_COMMITTER_DATE="2027-01-06T00:00:00" \
    git commit -q -m "ops: daily orchestrator summary 2027-01-06 [run 1]"
)
result=$(cd "$TMP_REPO" && "$GATE" current_summary_path 2027-01-06)
check "current_summary_path with one COMMITTED same-day summary returns -run2" \
  "dev/daily/2027-01-06-run2.md" "$result"

# --- Scenario 55: a write-early skeleton for THIS run already sits at the
# bare-date path, UNCOMMITTED -- current_summary_path must still return the
# bare-date path, not -run2, since the on-disk file is this run's own, not
# a genuine second run. Would FAIL against the pre-fix `ls | wc -l` count,
# which counts any file on disk regardless of git-tracked status (the exact
# off-by-one measured in the CP4 review: RUN_COUNT=1 N=2 where the correct
# answer is RUN_COUNT=0 N=1).
(
  cd "$TMP_REPO"
  cat > dev/daily/2027-01-07.md <<'MD'
# Status - 2027-01-07 [run 1]

**Mode:** FULL
MD
  # Deliberately left UNCOMMITTED -- models Step 1 having already written
  # this run's own skeleton before this formula runs (write-early).
)
result=$(cd "$TMP_REPO" && "$GATE" current_summary_path 2027-01-07)
check "current_summary_path is NOT defeated by its own uncommitted write-early skeleton (issue #2887 CP4)" \
  "dev/daily/2027-01-07.md" "$result"

# --- Scenario 56: one COMMITTED prior run PLUS this run's own uncommitted
# write-early skeleton (already correctly named -run2) both present at
# once -- the count must still be driven by the committed file alone, so
# the derived path agrees with the skeleton's own name rather than
# over-counting to -run3.
(
  cd "$TMP_REPO"
  cat > dev/daily/2027-01-08.md <<'MD'
# Status - 2027-01-08 [run 1]

**Mode:** FULL
MD
  git add dev/daily/2027-01-08.md
  GIT_AUTHOR_DATE="2027-01-08T00:00:00" GIT_COMMITTER_DATE="2027-01-08T00:00:00" \
    git commit -q -m "ops: daily orchestrator summary 2027-01-08 [run 1]"
  # This run's own write-early skeleton for run 2, UNCOMMITTED.
  cat > dev/daily/2027-01-08-run2.md <<'MD'
# Status - 2027-01-08 [run 2]

**Mode:** FULL
MD
)
result=$(cd "$TMP_REPO" && "$GATE" current_summary_path 2027-01-08)
check "current_summary_path counts only the committed run, ignoring its own uncommitted run2 skeleton" \
  "dev/daily/2027-01-08-run2.md" "$result"

# =========================================================================
# `hours_since_prior_summary` replaces Step 0.5's escape-hatch `ls -t
# dev/daily/*.md | head -1` + raw mtime arithmetic (advisory 2 of the CP4
# rework review): that inline block picks "most recent by mtime" with no
# exclusion of the current run's own file, so a write-early skeleton --
# freshly written, therefore the newest mtime by construction -- reads as
# zero hours old and silently defeats the "first run of the day always
# does a full pass" guarantee. Scenarios 57-60 use dev/daily/2027-02-*.md
# dates, later than every fixture used above.
# =========================================================================

# --- Scenario 57: no prior summary anywhere -> empty output (first run
# ever), same "empty means no prior" contract as prior_summary_iso.
mkdir -p "$TMP_REPO/no-daily-summary/dev/daily"
result=$(cd "$TMP_REPO/no-daily-summary" && "$GATE" hours_since_prior_summary dev/daily/2027-02-01.md)
check "hours_since_prior_summary with no prior summary anywhere returns empty" \
  "" "$result"

# --- Scenario 58: WITHOUT the current-summary exclusion, a write-early
# skeleton for THIS run (uncommitted, freshly written) is selected as its
# own "prior" and reads as ~0 hours old -- the vacuity this subcommand
# exists to prevent once Step 0.5 calls it.
_reset_repo_no_drift
(
  cd "$TMP_REPO"
  cat > dev/daily/2027-02-01.md <<'MD'
# Status - 2027-02-01 [run 1]

**Mode:** FULL
MD
  git add dev/daily/2027-02-01.md
  GIT_AUTHOR_DATE="2020-01-01T00:00:00" GIT_COMMITTER_DATE="2020-01-01T00:00:00" \
    git commit -q -m "ops: daily orchestrator summary 2027-02-01 [run 1]"
  # This run's own write-early skeleton, UNCOMMITTED.
  cat > dev/daily/2027-02-02.md <<'MD'
# Status - 2027-02-02 [run 1]

**Mode:** FULL
MD
)
without_exclusion=$(cd "$TMP_REPO" && "$GATE" hours_since_prior_summary)
if [ "$without_exclusion" -lt 1 ]; then _no_excl_ok=0; else _no_excl_ok=1; fi
check_bool "hours_since_prior_summary WITHOUT the current-summary arg reads near-zero (selects its own just-written skeleton)" \
  "$_no_excl_ok"

# --- Scenario 59: WITH the current-summary exclusion, the same fixture
# correctly finds the true prior (committed 2020-01-01) and reports it as
# comfortably >= 24 hours old -- proving the exclusion, not a coincidence
# of "any old file", is what makes the escape hatch fire correctly.
with_exclusion=$(cd "$TMP_REPO" && "$GATE" hours_since_prior_summary dev/daily/2027-02-02.md)
if [ "$with_exclusion" -ge 24 ]; then _excl_ok=0; else _excl_ok=1; fi
check_bool "hours_since_prior_summary WITH the current-summary arg correctly finds the true (old) prior, >= 24h" \
  "$_excl_ok"

# --- Scenario 60: a prior summary committed only moments ago (this test's
# own real wall-clock "now") reads as comfortably under 24 hours -- the
# other side of the boundary the Step 0.5 escape hatch branches on.
_reset_repo_no_drift
(
  cd "$TMP_REPO"
  cat > dev/daily/2027-02-10.md <<'MD'
# Status - 2027-02-10 [run 1]

**Mode:** FULL
MD
  git add dev/daily/2027-02-10.md
  git commit -q -m "ops: daily orchestrator summary 2027-02-10 [run 1]"
)
recent=$(cd "$TMP_REPO" && "$GATE" hours_since_prior_summary dev/daily/2027-02-11.md)
if [ "$recent" -lt 24 ]; then _recent_ok=0; else _recent_ok=1; fi
check_bool "hours_since_prior_summary for a just-committed prior reads well under 24h" \
  "$_recent_ok"

# Render all health exit classes from captured fixtures, without network access.
health_fixture="$TMP_REPO/health.log"
printf 'OK\tweekly\trun_id=12\nNO-SCHEDULE\tmanual\t(no runs)\nSUMMARY: ok=1\n' > "$health_fixture"
rendered=$(sh "$HERE/scheduled_workflow_summary.sh" 0 "$health_fixture")
check "renderer always emits fixed heading" 1 "$(printf '%s\n' "$rendered" | grep -c '^## Scheduled workflows$')"
check "renderer counts measured OK only" 1 "$(printf '%s\n' "$rendered" | grep -c '^all OK (1 measured; exit 0)$')"
printf 'RED\tweekly\tnewest_completed_run_id=11\nSTALE\tdaily\tnewest_completed_run_id=9\n' > "$health_fixture"
rendered=$(sh "$HERE/scheduled_workflow_summary.sh" 1 "$health_fixture")
check "renderer preserves RED completed id" 1 "$(printf '%s\n' "$rendered" | grep -c 'RED.*weekly.*newest_completed_run_id=11')"
check "renderer preserves STALE completed id" 1 "$(printf '%s\n' "$rendered" | grep -c 'STALE.*daily.*newest_completed_run_id=9')"
for health_rc in 2 3; do
  printf 'FAIL: measurement unavailable\n' > "$health_fixture"
  rendered=$(sh "$HERE/scheduled_workflow_summary.sh" "$health_rc" "$health_fixture")
  check "renderer exit $health_rc is unmeasurable" 1 "$(printf '%s\n' "$rendered" | grep -c "^UNMEASURABLE (exit $health_rc:")"
  check "renderer exit $health_rc retains reason" 1 "$(printf '%s\n' "$rendered" | grep -c 'FAIL: measurement unavailable')"
done
printf 'UNOBSERVABLE\tweekly\tno completed run\nSUMMARY: ok=0\n' > "$health_fixture"
rendered=$(sh "$HERE/scheduled_workflow_summary.sh" 0 "$health_fixture")
check "renderer cannot call unobservable all OK" 1 "$(printf '%s\n' "$rendered" | grep -c '^UNMEASURABLE')"
# A crowded-only exit-0 report (issue #2941) must render UNMEASURABLE, never
# "all OK" -- the exact silent-green case this issue exists to close. Dropping
# the `|| grep -q '^NO-SCHEDULE-CROWDED'` clause from the renderer's case-0
# branch leaves both checks below red.
printf 'NO-SCHEDULE-CROWDED\tweekly\t(page of 50 runs held no scheduled run -- crowded; raise SCHEDULED_WF_HEALTH_RUNS_PAGE_FACTOR)\nSUMMARY: active=1 (1 page(s) fetched, full pagination -- a real total, not a floor) ok=0 red=0 stale=0 no-schedule=0 no-schedule-crowded=1 unobservable=0\n' > "$health_fixture"
rendered=$(sh "$HERE/scheduled_workflow_summary.sh" 0 "$health_fixture")
check "renderer treats a crowded-only report as UNMEASURABLE" 1 "$(printf '%s\n' "$rendered" | grep -c '^UNMEASURABLE')"
check "renderer never calls a crowded-only report all OK" 0 "$(printf '%s\n' "$rendered" | grep -c '^all OK')"
# Mixed OK + crowded: the crowded workflow still forces UNMEASURABLE, but the
# genuinely-measured OK workflow is still counted in the "measured OK" tally.
printf 'OK\tweekly\trun_id=12\nNO-SCHEDULE-CROWDED\tdaily\t(page of 50 runs held no scheduled run -- crowded; raise SCHEDULED_WF_HEALTH_RUNS_PAGE_FACTOR)\nSUMMARY: active=2 (1 page(s) fetched, full pagination -- a real total, not a floor) ok=1 red=0 stale=0 no-schedule=0 no-schedule-crowded=1 unobservable=0\n' > "$health_fixture"
rendered=$(sh "$HERE/scheduled_workflow_summary.sh" 0 "$health_fixture")
check "renderer treats mixed OK+crowded report as UNMEASURABLE, not all OK" 1 "$(printf '%s\n' "$rendered" | grep -c '^UNMEASURABLE')"
check "renderer mixed OK+crowded still reports the 1 measured OK" 1 "$(printf '%s\n' "$rendered" | grep -c '1 measured OK')"
: > "$health_fixture"
rendered=$(sh "$HERE/scheduled_workflow_summary.sh" 0 "$health_fixture")
check "renderer missing report is unmeasurable" 1 "$(printf '%s\n' "$rendered" | grep -c '^UNMEASURABLE')"

printf '\n%d/%d checks passed\n' "$((total - fails))" "$total"
if [ "$fails" -gt 0 ]; then
  exit 1
fi
exit 0
