#!/bin/sh
# orchestrator_merge_gate_test.sh -- offline fixture test for the inline-shell
# function `merge_pr_when_clean` in .github/workflows/orchestrator.yml
# (issue #2913 rework, PR #2939 behavioral QC).
#
# WHY THIS EXISTS
#   `merge_pr_when_clean` has had three defect passes (#2517 -> #2429 ->
#   #2913), each fixed with a longer comment and verified only by the next
#   live orchestrator run. workflow_shell_check.sh's own header says it does
#   NOT catch the defect class that motivated it, so "static gates green" is
#   documented as insufficient evidence for this function specifically. The
#   #2913 fix adds a guard ("update-branch at most twice per PR, so a base
#   that keeps moving cannot loop us") whose failure mode is silent
#   non-publication and which the next 2-slot cron run will not exercise.
#   Per orchestrator_fastexit_gate_test_runner.sh: a guard whose own tests
#   never run in CI is no better than no guard at all.
#
# HOW
#   The function is EXTRACTED from the workflow YAML at run time (awk range
#   on its `name() {` ... `}` lines, de-indented), so the test always pins
#   the shipped text, never a copy. Anti-vacuity guards fail the run if the
#   extraction is empty, does not parse, or lost the #2913 markers -- a YAML
#   re-indent cannot turn this suite into a silent pass. A mock `curl` on
#   PATH answers the three API shapes the function issues (GET the PR,
#   PUT update-branch, PUT merge) from a scripted sequence of
#   mergeable_state values; a mock `sleep` records its argument and returns
#   at once, so the 300-poll budget runs in seconds. Every scenario asserts
#   that the function's STDOUT is exactly `true` or `false` (callers capture
#   it with `$(...)`) and counts the API calls by kind.
#
# Run: sh dev/scripts/orchestrator_merge_gate_test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$HERE/../.." && pwd)
WORKFLOW="$REPO_ROOT/.github/workflows/orchestrator.yml"

PASS=0
FAIL=0
check() { # name expected actual
  if [ "$3" = "$2" ]; then PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"
  else FAIL=$((FAIL + 1)); printf 'FAIL %s: want [%s], got [%s]\n' "$1" "$2" "$3"; fi
}
check_contains() { # name haystack needle
  if printf '%s' "$2" | grep -qF -- "$3"; then PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"
  else FAIL=$((FAIL + 1)); printf 'FAIL %s: expected to contain [%s]\n' "$1" "$3"; printf '%s\n' "$2" | sed 's/^/        /'; fi
}

WORK=$(mktemp -d -t orchestrator_merge_gate_test.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
FN="$WORK/merge_pr_when_clean.sh"
MOCK_BIN="$WORK/bin"
mkdir -p "$MOCK_BIN"

# --- extraction + anti-vacuity ---------------------------------------------
[ -f "$WORKFLOW" ] || { echo "FAIL: workflow not found at $WORKFLOW" >&2; exit 1; }
awk '/merge_pr_when_clean\(\) \{/,/^          \}$/' "$WORKFLOW" | sed 's/^          //' >"$FN"
_lines=$(wc -l <"$FN" | tr -d ' ')
[ "$_lines" -ge 20 ] || { echo "FAIL: extracted merge_pr_when_clean is $_lines lines -- the awk range no longer matches the workflow (re-indented? renamed?)" >&2; exit 1; }
sh -n "$FN" || { echo "FAIL: extracted merge_pr_when_clean does not parse" >&2; exit 1; }
grep -q 'update-branch' "$FN" || { echo "FAIL: extracted function has no update-branch call (#2913 fix missing)" >&2; exit 1; }
grep -q '_UPDATE_BRANCH_CALLS' "$FN" || { echo "FAIL: extracted function has no _UPDATE_BRANCH_CALLS bound (#2913 guard missing)" >&2; exit 1; }
grep -q '/merge"' "$FN" || { echo "FAIL: extracted function has no PUT /merge" >&2; exit 1; }
echo "extracted merge_pr_when_clean: $_lines lines, parses, carries the #2913 markers"

# --- mocks -------------------------------------------------------------------
# curl: the URL is the last argument; a PUT carries `-X PUT`. GET answers
# from $MOCK_STATES_FILE, one mergeable_state per line, consumed in order;
# once exhausted the last line repeats forever. mergeable is true iff the
# state is "clean".
cat >"$MOCK_BIN/curl" <<'EOF'
#!/bin/sh
url=""; put=0; prev=""
for a in "$@"; do [ "$prev" = "-X" ] && [ "$a" = "PUT" ] && put=1; prev="$a"; url="$a"; done
echo "$url" >>"$MOCK_CALL_LOG"
case "$url" in
  */update-branch)
    echo "update-branch" >>"$MOCK_KIND_LOG"
    if [ "${MOCK_UPDATE_NONJSON:-0}" = 1 ]; then printf 'not json at all'; else printf '{"message":"Updating pull request branch.","url":"%s"}' "$url"; fi
    ;;
  */merge)
    echo "merge" >>"$MOCK_KIND_LOG"
    if [ "${MOCK_MERGE_REFUSE:-0}" = 1 ]; then printf '{"merged":false,"message":"refused by mock"}'; else printf '{"merged":true,"sha":"deadbeef"}'; fi
    ;;
  *)
    echo "get" >>"$MOCK_KIND_LOG"
    n=0; [ -f "$MOCK_GET_COUNT" ] && n=$(cat "$MOCK_GET_COUNT"); n=$((n + 1)); echo "$n" >"$MOCK_GET_COUNT"
    total=$(wc -l <"$MOCK_STATES_FILE" | tr -d ' ')
    [ "$n" -gt "$total" ] && n=$total
    state=$(sed -n "${n}p" "$MOCK_STATES_FILE")
    if [ "$state" = "clean" ]; then m=true; else m=false; fi
    printf '{"mergeable":%s,"mergeable_state":"%s"}' "$m" "$state"
    ;;
esac
EOF
cat >"$MOCK_BIN/sleep" <<'EOF'
#!/bin/sh
echo "$1" >>"$MOCK_SLEEP_LOG"
EOF
chmod +x "$MOCK_BIN/curl" "$MOCK_BIN/sleep"

# _run <shell> <states...> -- runs merge_pr_when_clean 123 under <shell> with
# the mocks on PATH; sets OUT (stdout, exactly as a caller's $(...) sees it),
# ERR (stderr text), N_GET / N_UPDATE / N_MERGE (call counts) and SLEEPS.
_run() {
  _shell=$1; shift
  MOCK_STATES_FILE="$WORK/states"; MOCK_CALL_LOG="$WORK/calls"; MOCK_KIND_LOG="$WORK/kinds"
  MOCK_GET_COUNT="$WORK/getcount"; MOCK_SLEEP_LOG="$WORK/sleeps"
  export MOCK_STATES_FILE MOCK_CALL_LOG MOCK_KIND_LOG MOCK_GET_COUNT MOCK_SLEEP_LOG
  rm -f "$MOCK_CALL_LOG" "$MOCK_KIND_LOG" "$MOCK_GET_COUNT" "$MOCK_SLEEP_LOG"; : >"$MOCK_KIND_LOG"; : >"$MOCK_SLEEP_LOG"
  printf '%s\n' "$@" >"$MOCK_STATES_FILE"
  case "$_shell" in
    bash) _prelude='set -euo pipefail' ;;
    *) _prelude='set -eu' ;;
  esac
  OUT=$(PATH="$MOCK_BIN:$PATH" GH_TOKEN=test-token REPO=o/r "$_shell" -c "$_prelude; . '$FN'; merge_pr_when_clean 123" 2>"$WORK/err") || true
  ERR=$(cat "$WORK/err")
  N_GET=$(grep -c '^get$' "$MOCK_KIND_LOG" || true)
  N_UPDATE=$(grep -c '^update-branch$' "$MOCK_KIND_LOG" || true)
  N_MERGE=$(grep -c '^merge$' "$MOCK_KIND_LOG" || true)
  SLEEPS=$(tr '\n' ' ' <"$MOCK_SLEEP_LOG" | sed 's/ $//')
}

_suite() { # shell
  S=$1
  echo "=== under $S ==="

  # 1. clean immediately: one poll, no update-branch, one merge, stdout true.
  _run "$S" clean
  check "[$S] clean: stdout is exactly true" "true" "$OUT"
  check "[$S] clean: one GET" "1" "$N_GET"
  check "[$S] clean: zero update-branch calls" "0" "$N_UPDATE"
  check "[$S] clean: one PUT /merge" "1" "$N_MERGE"

  # 2. behind -> unknown -> clean: exactly one update-branch, its message on
  #    stderr, a 30 s wait, then the merge. Contract 1 of #2913.
  _run "$S" behind unknown clean
  check "[$S] behind-then-clean: stdout is exactly true" "true" "$OUT"
  check "[$S] behind-then-clean: exactly one update-branch call" "1" "$N_UPDATE"
  check "[$S] behind-then-clean: one PUT /merge" "1" "$N_MERGE"
  check_contains "[$S] behind-then-clean: stderr names attempt 1 of 2" "$ERR" "PUT /update-branch (attempt 1 of 2)"
  check_contains "[$S] behind-then-clean: stderr carries the API message" "$ERR" "Updating pull request branch."
  check_contains "[$S] behind-then-clean: a 30 s wait follows the update" "$SLEEPS" "30"

  # 3. behind forever: the bound -- exactly two update-branch calls, no
  #    merge, the budget exhausts, stdout false, warning names the state.
  #    Contract 4 (a base that keeps moving cannot loop us).
  _run "$S" behind
  check "[$S] behind-forever: stdout is exactly false" "false" "$OUT"
  check "[$S] behind-forever: exactly two update-branch calls" "2" "$N_UPDATE"
  check "[$S] behind-forever: zero PUT /merge" "0" "$N_MERGE"
  check "[$S] behind-forever: the 300-poll budget was spent" "300" "$N_GET"
  check_contains "[$S] behind-forever: timeout warning names mergeable_state=behind" "$ERR" "mergeable_state=behind"
  check_contains "[$S] behind-forever: timeout warning says the budget was exhausted" "$ERR" "poll budget"

  # 4. blocked forever (CI red / review missing): pre-#2913 path unchanged --
  #    no update-branch, budget exhausts, stdout false.
  _run "$S" blocked
  check "[$S] blocked-forever: stdout is exactly false" "false" "$OUT"
  check "[$S] blocked-forever: zero update-branch calls" "0" "$N_UPDATE"
  check "[$S] blocked-forever: zero PUT /merge" "0" "$N_MERGE"
  check_contains "[$S] blocked-forever: timeout warning names mergeable_state=blocked" "$ERR" "mergeable_state=blocked"

  # 5. merge refused: stdout false, the refusal warning, rc still 0 (soft).
  MOCK_MERGE_REFUSE=1; export MOCK_MERGE_REFUSE
  _run "$S" clean
  unset MOCK_MERGE_REFUSE
  check "[$S] merge-refused: stdout is exactly false" "false" "$OUT"
  check_contains "[$S] merge-refused: refusal warning" "$ERR" "PUT /merge refused"

  # 6. update-branch answers non-JSON: the jq inside the log line must not
  #    abort the function (it sits in an echo argument, not an assignment);
  #    the poll continues and the merge still lands.
  MOCK_UPDATE_NONJSON=1; export MOCK_UPDATE_NONJSON
  _run "$S" behind clean
  unset MOCK_UPDATE_NONJSON
  check "[$S] update-nonjson: stdout is still exactly true" "true" "$OUT"
  check "[$S] update-nonjson: one update-branch call" "1" "$N_UPDATE"
  check "[$S] update-nonjson: one PUT /merge" "1" "$N_MERGE"
}

_suite sh
if command -v bash >/dev/null 2>&1; then _suite bash; else echo "note: bash not on PATH, bash -euo pipefail pass skipped"; fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
echo "OK: orchestrator_merge_gate_test -- merge_pr_when_clean contracts pinned."
