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
#   - non-NO-OP summary                                        => PASS trivially, no PR lookup
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
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
GATE="$HERE/orchestrator_fastexit_gate.sh"

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

# --- mock curl: returns a JSON array of $MOCK_PR_COUNT elements regardless
# of the URL/headers it's called with -- open_pr_count only cares about
# `jq 'length'` on the response. Two more failure-mode toggles simulate the
# production curl-backend failure shapes (#2605 rework):
#   MOCK_CURL_FAIL=1     -- simulate `curl -f` on a 401/403/5xx: exit 22,
#                            NO stdout (the exact shape that made the old
#                            `curl -f ... | jq 'length'` pipeline silently
#                            report rc=0 with an empty count under `sh`,
#                            which has no `pipefail`).
#   MOCK_CURL_GARBAGE=1  -- simulate a curl "success" (exit 0) whose body
#                            jq cannot parse into a count.
MOCK_BIN_DIR=$(mktemp -d -t orchestrator_fastexit_gate_mockbin.XXXXXX)
trap 'rm -rf "$MOCK_BIN_DIR" "${TMP_REPO:-}"' EXIT

cat > "$MOCK_BIN_DIR/curl" <<'EOF'
#!/bin/sh
# Mock curl -- ignores its real arguments; behavior controlled by env vars
# set by the test before each scenario (see the comment above this heredoc).
if [ "${MOCK_CURL_FAIL:-0}" = 1 ]; then
  exit 22
fi
if [ "${MOCK_CURL_GARBAGE:-0}" = 1 ]; then
  printf 'not-json-at-all'
  exit 0
fi
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
MD
  touch -t 202608260000 dev/daily/2026-08-26.md
)

_reset_summary() {
  # $1 = mode ("NO-OP" or "FULL")
  cat > "$TMP_REPO/dev/daily/2026-08-27.md" <<MD
# Status - 2026-08-27 [run 1]

**Mode:** $1
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
  (
    cd "$TMP_REPO"
    git reset -q --hard "$(git rev-list --max-parents=0 HEAD)"
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

# --- Scenario 1: not a NO-OP summary -> PASS trivially, no PR lookup ----
MOCK_PR_COUNT=0
export MOCK_PR_COUNT
_reset_repo_no_drift
_reset_summary FULL
rc=0
_run_verify dev/daily/2026-08-27.md || rc=$?
check "non-NO-OP summary short-circuits to PASS" 0 "$rc"

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

printf '\n%d/%d checks passed\n' "$((total - fails))" "$total"
if [ "$fails" -gt 0 ]; then
  exit 1
fi
exit 0
