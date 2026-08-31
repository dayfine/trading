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
# `jq 'length'` on the response.
MOCK_BIN_DIR=$(mktemp -d -t orchestrator_fastexit_gate_mockbin.XXXXXX)
trap 'rm -rf "$MOCK_BIN_DIR" "${TMP_REPO:-}"' EXIT

cat > "$MOCK_BIN_DIR/curl" <<'EOF'
#!/bin/sh
# Mock curl -- ignores its real arguments, emits a JSON array whose length
# is $MOCK_PR_COUNT (set by the test before each scenario).
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
  # see zero drift.
  (
    cd "$TMP_REPO"
    git reset -q --hard "$(git rev-list --max-parents=0 HEAD)"
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

printf '\n%d/%d checks passed\n' "$((total - fails))" "$total"
if [ "$fails" -gt 0 ]; then
  exit 1
fi
exit 0
