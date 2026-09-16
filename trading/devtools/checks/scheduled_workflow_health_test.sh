#!/bin/sh
# scheduled_workflow_health_test.sh — fixture-driven, hermetic (no network)
# self-test for scheduled_workflow_health.sh (issue #2634, script half).
#
# Drives the real script entirely through its SCHEDULED_WF_HEALTH_FETCH
# injection hook (see that script's header) with small shell shims that
# return canned JSON keyed on the requested API path -- the same
# fixture-over-network-call seam PR_GATE_STATUS_LIB establishes in
# dev/scripts/pr_gate_status.sh, adapted to a single external-command hook
# since this script has one kind of GitHub call to fake (a GET), not three.
#
# Also uses SCHEDULED_WF_HEALTH_NOW_EPOCH to make the STALE classification
# deterministic without depending on wall-clock time.
#
# Assertions:
#   1. All-green fixture (two active workflows, both recent successes)
#      -> exit 0, both report OK, summary counts red=0 stale=0.
#   2. One failing workflow among two -> exit 1 (non-zero), the FAILING
#      workflow is NAMED on its own RED line and in the SUMMARY RED list;
#      the other workflow still reports OK.
#   3. A workflow whose newest scheduled run succeeded but is older than
#      the staleness window -> classified STALE, exit non-zero (1).
#   4. A workflow with zero observed scheduled runs -> classified
#      NO-SCHEDULE, and does NOT by itself cause a non-zero exit (paired
#      in the same fixture with one clean OK workflow to prove
#      NO-SCHEDULE doesn't taint the overall exit code).
#   5. No GH_TOKEN and no fetch hook -> distinct exit code 2, distinct
#      "cannot query the GitHub API at all" message -- NOT green (this is
#      the literal "a check that can't fail is not a check" trap: pins
#      that removing the ability to measure does not silently read as
#      exit 0 / all-clear).
#   6. Fetch hook itself fails (simulates a network / non-2xx error) ->
#      distinct exit code 3, distinct "GitHub API request failed" message
#      -- also NOT green. Distinct from assertion 5's code, so a caller
#      can tell "never had a token" apart from "had a token, API broke".
#   7. Fetch hook returns non-JSON garbage -> exit code 3, "was not valid
#      JSON" message -- proves a malformed response can't be mistaken for
#      an empty-but-valid one.
#   8. Pagination: 101 active workflows spread over two pages (a
#      per_page=100 first page plus a one-item second page) -> the
#      SUMMARY reports active=101 and "2 page(s) fetched", proving the
#      workflow LIST call actually paginates to completion instead of
#      reading the first page as the whole answer (the
#      PAGINATION-IS-A-FLOOR trap named in the script's own header).
#   9. --stale-hours override: the SAME run age that assertion 3
#      classifies STALE under the default window is reclassified OK when
#      a wider --stale-hours is supplied -- proves the window is actually
#      threaded through, not just documented.
#  10. Malformed --stale-hours argument -> exit 64 (usage error), distinct
#      from every "cannot measure" / "found a problem" code above.
#  11. All four RED conclusion values (failure, cancelled, timed_out,
#      action_required), one workflow each -> all four classified RED and
#      all four named in the SUMMARY RED list. Assertion 2 only exercises
#      "failure"; this closes the other three, which a prior review found
#      silently unpinned (dropping any of them from the RED set left the
#      suite green).
#  12. The workflow LIST call succeeds but the per-workflow RUNS call
#      fails (network/non-2xx) -> exit 3, "GitHub API request failed"
#      naming the runs path. This is the exact fixture shape a prior
#      review built by hand and found missing: assertions 6/7 fail on
#      *every* path, so the list call fails first and the runs-call
#      failure path (main()'s `if ! _run_line=$(_recent_scheduled_runs
#      ...)` and that function's own `if ! _resp=$(_api_get_json ...)`)
#      was never exercised, on the higher-frequency of the two call
#      sites (once per workflow vs. once per list page).
#  13. Same shape as 12, but the RUNS call returns non-JSON garbage
#      instead of failing outright -> exit 3, "was not valid JSON",
#      again on the runs path specifically.
#  14. SCHEDULED_WF_HEALTH_STALE_HOURS env var (not the --stale-hours
#      flag) reclassifies the same stale run age as OK -- the documented
#      env-var half of assertion 9's claim, which a prior review found
#      untested (only the flag was exercised).
#  15. SCHEDULED_WF_HEALTH_REPO env var is actually threaded into the API
#      path and the printed header -- a shim that only answers for a
#      specific non-default repo name proves the override takes effect,
#      not just that a header line echoes it.
#  16. Pagination is BOUNDED: a shim that always returns a full
#      (non-shrinking) page forever, with SCHEDULED_WF_HEALTH_MAX_PAGES
#      lowered so the test terminates quickly, -> exit 3 once the bound
#      is hit, rather than hanging. A prior review found the unbounded
#      loop hangs (not fails) under a propagation-severed mutation --
#      this pins the defensive bound added in response.
#  17. Six consecutive failures with no newer run on top -> RED with
#      streak=6 (streak reported exactly, since the fetched page of 10
#      came back shorter than 10 -- the workflow's entire observed
#      history was seen, so there's no floor to hedge).
#  18. THE INCIDENT SHAPE this whole rework exists to fix: the same six
#      consecutive failures as #17, but with a SEVENTH, newest run on top
#      that is still `in_progress` (conclusion null) -- the exact state
#      of the 2026-09-10..12 outage, where the health check's own
#      currently-executing run was the newest run at scan time. Must
#      still be RED, streak=6, in_progress=1. This is the regression
#      test for the bug: verified by hand to FAIL against the
#      pre-rework script (which reported OK / exit 0, see the PR
#      description for the measured before/after) and PASS against the
#      reworked one.
#  19. A single failure followed (older) by a success -> NOT RED. Streaks
#      are consecutive-from-newest: the newest completed run is a
#      success, so the streak is 0 regardless of older history. A
#      recovered workflow reads as recovered, not as "has ever failed."
#  20. Every one of the fetched runs is `in_progress` / `queued` (none
#      completed) -> classified UNOBSERVABLE, not OK, and does not by
#      itself force a non-zero exit -- there's no positive evidence of
#      failure, only an absence of any completed run to read a verdict
#      from.
#  21. THE PAGINATION-FLOOR ITSELF (a prior review found this branch
#      reachable by no assertion): a FULL page (RUNS_PER_WORKFLOW=10) of
#      10 consecutive failure-class runs, with no older non-failure run
#      to close the streak -> RED, streak reported as the FLOOR
#      `streak=>=10` (never the false-exact `streak=10`), in both the
#      per-workflow line and the SUMMARY's `(streak=>=10)` annotation.
#      Deleting the floor-detection branch makes this fetch pattern
#      misreport the false-exact count instead.
#  22. `--runs-per-workflow N` actually drives `per_page=N` on the
#      per-workflow runs request (not just the printed header line) --
#      the flag half of the RUNS PER WORKFLOW knob, mirroring assertion 9
#      for --stale-hours.
#  23. `SCHEDULED_WF_HEALTH_RUNS_PER_WORKFLOW` env var drives the same
#      `per_page=N` -- the env half, mirroring assertion 14 for
#      SCHEDULED_WF_HEALTH_STALE_HOURS (added there because a prior
#      review found the env half of --stale-hours untested; this closes
#      the structural twin for --runs-per-workflow before the same gap
#      is found the hard way).
#  24. `--runs-per-workflow 0` -> exit 64 (usage error), distinct
#      "must be a positive integer" message -- mirrors assertion 10 for
#      --stale-hours, but pins the RUNS_PER_WORKFLOW-specific explicit
#      zero rejection (unlike STALE_HOURS, 0 is disallowed here, not just
#      non-numeric input).
#  25. Staleness is measured from the newest COMPLETED run, never from an
#      in_progress run sitting on top of it: newest run is `in_progress`
#      with created_at == "now", underneath it a completed SUCCESS from
#      40 days ago -> STALE (exit non-zero), not OK. This guards the same
#      in-progress-masking class as the incident itself (assertion 18),
#      but for the STALE path instead of the RED path -- swapping the
#      staleness computation to read the newest run's timestamp instead
#      of the newest COMPLETED run's would silently reclassify this OK.
#  26. Exactly one API call per workflow: a counting shim logs every
#      requested path, and the log must show exactly one workflow-LIST
#      call plus exactly one runs call per workflow (2 workflows -> 3
#      total calls) -- pins the "one request per workflow" cost claim in
#      the RUNS PER WORKFLOW header section, which a prior review found
#      an extra per-workflow runs call would violate silently (suite
#      stayed green with a 3rd call where the contract says 2).
#
# Run: sh trading/devtools/checks/scheduled_workflow_health_test.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/scheduled_workflow_health.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: script not executable: ${SCRIPT}" >&2
  exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0
pass() { echo "  PASS: $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }

TMPDIR_ROOT="$(mktemp -d -t scheduled_workflow_health_test.XXXXXX)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# _run <fetch-shim-path> [now-epoch] [extra-arg]... — invokes the real
# script with SCHEDULED_WF_HEALTH_FETCH pointed at the shim, capturing
# combined output + exit code into globals OUT / RC. POSIX sh has no
# local return-by-value and this test never runs assertions concurrently,
# so plain globals are safe here (same pattern as
# goldens_affected_check_test.sh's _run).
_run() {
  fetch="$1"
  now="$2"
  shift 2
  set +e
  if [ -n "$now" ]; then
    OUT="$(SCHEDULED_WF_HEALTH_FETCH="$fetch" SCHEDULED_WF_HEALTH_NOW_EPOCH="$now" env -u GH_TOKEN sh "$SCRIPT" "$@" 2>&1)"
  else
    OUT="$(SCHEDULED_WF_HEALTH_FETCH="$fetch" env -u GH_TOKEN sh "$SCRIPT" "$@" 2>&1)"
  fi
  RC=$?
  set -e
}

# _write_shim <path> <<'EOF' ... EOF — helper is just `cat > "$path"`; kept
# as a named step so every fixture below reads the same way: write the
# shim body, chmod it, done.
_finish_shim() {
  chmod +x "$1"
}

echo "=== Assertion 1: all-green fixture -> exit 0, both OK ==="
SHIM1="${TMPDIR_ROOT}/fetch1.sh"
cat > "$SHIM1" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":2,"workflows":[{"id":1,"name":"Alpha Weekly","state":"active"},{"id":2,"name":"Beta Nightly","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":111,"conclusion":"success","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *"actions/workflows/2/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":222,"conclusion":"success","status":"completed","created_at":"2026-09-03T12:00:00Z"}]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM1"
NOW1="$(date -u -d "2026-09-04T06:00:00Z" +%s)"
_run "$SHIM1" "$NOW1"
if [ "$RC" -eq 0 ] \
  && echo "$OUT" | grep -q '^OK	Alpha Weekly' \
  && echo "$OUT" | grep -q '^OK	Beta Nightly' \
  && echo "$OUT" | grep -q 'red=0 stale=0'; then
  pass "assertion 1: all-green -> exit 0, both workflows OK"
else
  fail "assertion 1: expected exit0/all-OK, got rc=$RC output=$OUT"
fi

echo "=== Assertion 2: one failing workflow among two -> exit non-zero, named ==="
SHIM2="${TMPDIR_ROOT}/fetch2.sh"
cat > "$SHIM2" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":2,"workflows":[{"id":1,"name":"Prune candidates weekly","state":"active"},{"id":2,"name":"Build CI image","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":111,"conclusion":"failure","status":"completed","created_at":"2026-08-31T16:26:33Z"}]}'
    ;;
  *"actions/workflows/2/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":222,"conclusion":"success","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM2"
NOW2="$(date -u -d "2026-09-04T06:00:00Z" +%s)"
_run "$SHIM2" "$NOW2"
if [ "$RC" -ne 0 ] \
  && echo "$OUT" | grep -q '^RED	Prune candidates weekly' \
  && echo "$OUT" | grep -q '^OK	Build CI image' \
  && echo "$OUT" | grep -q 'SUMMARY: RED workflows: Prune candidates weekly'; then
  pass "assertion 2: one RED workflow -> exit non-zero, named in its own line and the summary"
else
  fail "assertion 2: expected exit!=0 with RED named, got rc=$RC output=$OUT"
fi

echo "=== Assertion 3: stale-but-succeeding run -> classified STALE, exit non-zero ==="
SHIM3="${TMPDIR_ROOT}/fetch3.sh"
cat > "$SHIM3" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":1,"workflows":[{"id":1,"name":"Weekly track pacer","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":111,"conclusion":"success","status":"completed","created_at":"2026-08-01T00:00:00Z"}]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM3"
# 2026-09-10 is 40 days after the run's created_at -- well past the
# default 216h (9 day) staleness window.
NOW3="$(date -u -d "2026-09-10T00:00:00Z" +%s)"
_run "$SHIM3" "$NOW3"
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q '^STALE	Weekly track pacer'; then
  pass "assertion 3: old-but-successful run -> classified STALE, exit non-zero"
else
  fail "assertion 3: expected STALE classification and exit!=0, got rc=$RC output=$OUT"
fi

echo "=== Assertion 4: no-scheduled-runs workflow -> NO-SCHEDULE, does not force non-zero ==="
SHIM4="${TMPDIR_ROOT}/fetch4.sh"
cat > "$SHIM4" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":2,"workflows":[{"id":1,"name":"Manual-only workflow","state":"active"},{"id":2,"name":"Healthy Weekly","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[]}'
    ;;
  *"actions/workflows/2/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":222,"conclusion":"success","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM4"
NOW4="$(date -u -d "2026-09-04T06:00:00Z" +%s)"
_run "$SHIM4" "$NOW4"
if [ "$RC" -eq 0 ] \
  && echo "$OUT" | grep -q '^NO-SCHEDULE	Manual-only workflow' \
  && echo "$OUT" | grep -q 'no-schedule=1' \
  && echo "$OUT" | grep -q 'red=0 stale=0'; then
  pass "assertion 4: NO-SCHEDULE workflow classified correctly and does not force a non-zero exit"
else
  fail "assertion 4: expected exit0 with NO-SCHEDULE classification, got rc=$RC output=$OUT"
fi

echo "=== Assertion 5: no GH_TOKEN and no fetch hook -> distinct exit 2, not green ==="
set +e
OUT5="$(env -u GH_TOKEN -u SCHEDULED_WF_HEALTH_FETCH sh "$SCRIPT" 2>&1)"
RC5=$?
set -e
if [ "$RC5" -eq 2 ] && echo "$OUT5" | grep -q 'cannot query the GitHub API at all'; then
  pass "assertion 5: missing token -> exit 2, distinct message, never exit 0"
else
  fail "assertion 5: expected exit2 with the no-token message, got rc=$RC5 output=$OUT5"
fi

echo "=== Assertion 6: fetch hook itself fails -> distinct exit 3, not green ==="
SHIM6="${TMPDIR_ROOT}/fetch6.sh"
cat > "$SHIM6" <<'EOF'
#!/bin/sh
echo "simulated network failure" >&2
exit 22
EOF
_finish_shim "$SHIM6"
_run "$SHIM6" ""
if [ "$RC" -eq 3 ] && echo "$OUT" | grep -q 'GitHub API request failed'; then
  pass "assertion 6: API call failure -> exit 3, distinct message, never exit 0"
else
  fail "assertion 6: expected exit3 with the API-failure message, got rc=$RC output=$OUT"
fi

echo "=== Assertion 7: fetch hook returns non-JSON garbage -> exit 3 ==="
SHIM7="${TMPDIR_ROOT}/fetch7.sh"
cat > "$SHIM7" <<'EOF'
#!/bin/sh
echo "<html>not json</html>"
EOF
_finish_shim "$SHIM7"
_run "$SHIM7" ""
if [ "$RC" -eq 3 ] && echo "$OUT" | grep -q 'was not valid JSON'; then
  pass "assertion 7: malformed (non-JSON) response -> exit 3, distinct message"
else
  fail "assertion 7: expected exit3 with the malformed-JSON message, got rc=$RC output=$OUT"
fi

echo "=== Assertion 8: pagination -- 101 active workflows across 2 pages, no floor ==="
SHIM8="${TMPDIR_ROOT}/fetch8.sh"
cat > "$SHIM8" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"&page=1")
    i=1
    wfs=""
    while [ "$i" -le 100 ]; do
      wfs="${wfs}${wfs:+,}{\"id\":${i},\"name\":\"wf${i}\",\"state\":\"active\"}"
      i=$((i + 1))
    done
    printf '{"total_count":101,"workflows":[%s]}' "$wfs"
    ;;
  *"&page=2")
    echo '{"total_count":101,"workflows":[{"id":101,"name":"wf101","state":"active"}]}'
    ;;
  *"runs?event=schedule"*)
    echo '{"workflow_runs":[]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM8"
_run "$SHIM8" ""
if [ "$RC" -eq 0 ] \
  && echo "$OUT" | grep -q 'active=101 (2 page(s) fetched'; then
  pass "assertion 8: pagination fetches BOTH pages -- active=101 with 2 pages fetched, not a page-1 floor of 100"
else
  fail "assertion 8: expected active=101 with 2 page(s) fetched, got rc=$RC output=$OUT"
fi

echo "=== Assertion 9: --stale-hours override reclassifies the same age as OK ==="
# Same fixture/age as assertion 3 (40 days old), but with a staleness
# window wide enough (2000h ~= 83 days) to cover it -- proves the flag is
# actually threaded into the classification, not just documented.
_run "$SHIM3" "$NOW3" --stale-hours 2000
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q '^OK	Weekly track pacer'; then
  pass "assertion 9: --stale-hours override reclassifies the same run age as OK"
else
  fail "assertion 9: expected OK classification under widened staleness window, got rc=$RC output=$OUT"
fi

echo "=== Assertion 10: malformed --stale-hours -> exit 64 (usage error) ==="
_run "$SHIM1" "" --stale-hours notanumber
if [ "$RC" -eq 64 ] && echo "$OUT" | grep -q 'must be a positive integer'; then
  pass "assertion 10: malformed --stale-hours -> exit 64, distinct usage-error message"
else
  fail "assertion 10: expected exit64 with the usage-error message, got rc=$RC output=$OUT"
fi

echo "=== Assertion 11: all four RED conclusion values classify RED, not just 'failure' ==="
SHIM11="${TMPDIR_ROOT}/fetch11.sh"
cat > "$SHIM11" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":4,"workflows":[{"id":1,"name":"Failure wf","state":"active"},{"id":2,"name":"Cancelled wf","state":"active"},{"id":3,"name":"Timed out wf","state":"active"},{"id":4,"name":"Action required wf","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":111,"conclusion":"failure","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *"actions/workflows/2/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":222,"conclusion":"cancelled","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *"actions/workflows/3/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":333,"conclusion":"timed_out","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *"actions/workflows/4/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":444,"conclusion":"action_required","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM11"
NOW11="$(date -u -d "2026-09-04T06:00:00Z" +%s)"
_run "$SHIM11" "$NOW11"
if [ "$RC" -ne 0 ] \
  && echo "$OUT" | grep -q '^RED	Failure wf' \
  && echo "$OUT" | grep -q '^RED	Cancelled wf' \
  && echo "$OUT" | grep -q '^RED	Timed out wf' \
  && echo "$OUT" | grep -q '^RED	Action required wf' \
  && echo "$OUT" | grep -q 'red=4'; then
  pass "assertion 11: failure/cancelled/timed_out/action_required all classify RED"
else
  fail "assertion 11: expected all four conclusions RED, got rc=$RC output=$OUT"
fi

echo "=== Assertion 12: list call OK, per-workflow RUNS call fails -> exit 3, not NO-SCHEDULE ==="
SHIM12="${TMPDIR_ROOT}/fetch12.sh"
cat > "$SHIM12" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":2,"workflows":[{"id":1,"name":"Prune candidates weekly","state":"active"},{"id":2,"name":"Weekly track pacer","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo "simulated network failure on runs call" >&2
    exit 22
    ;;
  *"actions/workflows/2/runs?event=schedule&per_page=10")
    echo "simulated network failure on runs call" >&2
    exit 22
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM12"
_run "$SHIM12" ""
if [ "$RC" -eq 3 ] \
  && echo "$OUT" | grep -q 'GitHub API request failed' \
  && echo "$OUT" | grep -q 'runs?event=schedule' \
  && ! echo "$OUT" | grep -q 'NO-SCHEDULE'; then
  pass "assertion 12: RUNS call failure (list succeeded) -> exit 3, never silently reclassified NO-SCHEDULE"
else
  fail "assertion 12: expected exit3 naming the runs path and no NO-SCHEDULE line, got rc=$RC output=$OUT"
fi

echo "=== Assertion 13: list call OK, per-workflow RUNS call returns non-JSON -> exit 3 ==="
SHIM13="${TMPDIR_ROOT}/fetch13.sh"
cat > "$SHIM13" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":1,"workflows":[{"id":1,"name":"Weekly start sweep (BAH SPY)","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo "<html>not json</html>"
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM13"
_run "$SHIM13" ""
if [ "$RC" -eq 3 ] \
  && echo "$OUT" | grep -q 'was not valid JSON' \
  && echo "$OUT" | grep -q 'runs?event=schedule' \
  && ! echo "$OUT" | grep -q 'NO-SCHEDULE'; then
  pass "assertion 13: RUNS call malformed JSON (list succeeded) -> exit 3, never silently reclassified NO-SCHEDULE"
else
  fail "assertion 13: expected exit3 naming the runs path and no NO-SCHEDULE line, got rc=$RC output=$OUT"
fi

echo "=== Assertion 14: SCHEDULED_WF_HEALTH_STALE_HOURS env var reclassifies the same age as OK ==="
# Same fixture/age as assertion 3/9 (40 days old), but the widened window
# is supplied via the ENV VAR this time, not the --stale-hours flag --
# closes the documented-but-untested env-var half of assertion 9's claim.
set +e
OUT14="$(SCHEDULED_WF_HEALTH_FETCH="$SHIM3" SCHEDULED_WF_HEALTH_NOW_EPOCH="$NOW3" SCHEDULED_WF_HEALTH_STALE_HOURS=2000 env -u GH_TOKEN sh "$SCRIPT" 2>&1)"
RC14=$?
set -e
if [ "$RC14" -eq 0 ] && echo "$OUT14" | grep -q '^OK	Weekly track pacer'; then
  pass "assertion 14: SCHEDULED_WF_HEALTH_STALE_HOURS env var reclassifies the same run age as OK"
else
  fail "assertion 14: expected OK classification under widened env-var staleness window, got rc=$RC14 output=$OUT14"
fi

echo "=== Assertion 15: SCHEDULED_WF_HEALTH_REPO env var is threaded into the API path ==="
SHIM15="${TMPDIR_ROOT}/fetch15.sh"
cat > "$SHIM15" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"repos/some-org/some-other-repo/actions/workflows?per_page=100&page=1")
    echo '{"total_count":1,"workflows":[{"id":1,"name":"Override repo wf","state":"active"}]}'
    ;;
  *"repos/some-org/some-other-repo/actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":111,"conclusion":"success","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *)
    echo "unmatched path (REPO override not threaded through?): $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM15"
set +e
OUT15="$(SCHEDULED_WF_HEALTH_FETCH="$SHIM15" SCHEDULED_WF_HEALTH_NOW_EPOCH="$NOW1" SCHEDULED_WF_HEALTH_REPO="some-org/some-other-repo" env -u GH_TOKEN sh "$SCRIPT" 2>&1)"
RC15=$?
set -e
if [ "$RC15" -eq 0 ] \
  && echo "$OUT15" | grep -q 'repo=some-org/some-other-repo' \
  && echo "$OUT15" | grep -q '^OK	Override repo wf'; then
  pass "assertion 15: SCHEDULED_WF_HEALTH_REPO env var is threaded into both the header and the API path"
else
  fail "assertion 15: expected exit0 against the overridden repo, got rc=$RC15 output=$OUT15"
fi

echo "=== Assertion 16: pagination loop is bounded, not infinite ==="
# A shim that always returns a FULL (non-shrinking) page, forever -- with
# SCHEDULED_WF_HEALTH_MAX_PAGES lowered so the test terminates quickly
# instead of waiting out the production default (1000). Wrapped in
# `timeout` as a hard backstop: if the bound regresses, this assertion
# must fail loudly rather than hang the whole suite.
SHIM16="${TMPDIR_ROOT}/fetch16.sh"
cat > "$SHIM16" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page="*)
    i=1
    wfs=""
    while [ "$i" -le 100 ]; do
      wfs="${wfs}${wfs:+,}{\"id\":${i},\"name\":\"wf${i}\",\"state\":\"active\"}"
      i=$((i + 1))
    done
    printf '{"total_count":999999,"workflows":[%s]}' "$wfs"
    ;;
  *"runs?event=schedule"*)
    echo '{"workflow_runs":[]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM16"
set +e
OUT16="$(SCHEDULED_WF_HEALTH_FETCH="$SHIM16" SCHEDULED_WF_HEALTH_MAX_PAGES=3 env -u GH_TOKEN timeout 30 sh "$SCRIPT" 2>&1)"
RC16=$?
set -e
if [ "$RC16" -eq 3 ] && echo "$OUT16" | grep -q 'pagination exceeded 3 page(s)'; then
  pass "assertion 16: unbounded-looking pagination is bounded -- exits 3 instead of hanging"
else
  fail "assertion 16: expected exit3 with the pagination-bound message, got rc=$RC16 output=$OUT16"
fi

echo "=== Assertion 17: six consecutive failures, no newer run -> RED streak=6 (exact) ==="
SHIM17="${TMPDIR_ROOT}/fetch17.sh"
cat > "$SHIM17" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":1,"workflows":[{"id":1,"name":"Daily orchestrator","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[
      {"id":699,"conclusion":"failure","status":"completed","created_at":"2026-09-12T15:32:00Z"},
      {"id":698,"conclusion":"failure","status":"completed","created_at":"2026-09-12T11:37:00Z"},
      {"id":697,"conclusion":"failure","status":"completed","created_at":"2026-09-11T16:29:00Z"},
      {"id":696,"conclusion":"failure","status":"completed","created_at":"2026-09-11T12:13:00Z"},
      {"id":695,"conclusion":"failure","status":"completed","created_at":"2026-09-10T16:24:00Z"},
      {"id":694,"conclusion":"failure","status":"completed","created_at":"2026-09-10T12:14:00Z"}
    ]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM17"
NOW17="$(date -u -d "2026-09-12T16:00:00Z" +%s)"
_run "$SHIM17" "$NOW17"
if [ "$RC" -ne 0 ] \
  && echo "$OUT" | grep -q '^RED	Daily orchestrator' \
  && echo "$OUT" | grep -q 'streak=6 ' \
  && ! echo "$OUT" | grep -q 'streak=6+' \
  && ! echo "$OUT" | grep -q 'streak=>=6'; then
  pass "assertion 17: six consecutive failures -> RED, streak=6 (exact, page came back short)"
else
  fail "assertion 17: expected RED with exact streak=6, got rc=$RC output=$OUT"
fi

echo "=== Assertion 18: THE INCIDENT SHAPE -- 6 failures + newest in_progress -> still RED streak=6 ==="
# This is the exact regression this rework exists to fix: verified by hand
# (see PR description) that this fixture produces OK/exit0 against the
# pre-rework script (single newest-run inspection classified the
# in_progress newest run as OK, silently masking the 6-failure streak
# underneath it) and RED/streak=6/exit-non-zero against the reworked one.
SHIM18="${TMPDIR_ROOT}/fetch18.sh"
cat > "$SHIM18" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":1,"workflows":[{"id":1,"name":"Daily orchestrator","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[
      {"id":700,"conclusion":null,"status":"in_progress","created_at":"2026-09-12T15:32:00Z"},
      {"id":699,"conclusion":"failure","status":"completed","created_at":"2026-09-12T15:32:00Z"},
      {"id":698,"conclusion":"failure","status":"completed","created_at":"2026-09-12T11:37:00Z"},
      {"id":697,"conclusion":"failure","status":"completed","created_at":"2026-09-11T16:29:00Z"},
      {"id":696,"conclusion":"failure","status":"completed","created_at":"2026-09-11T12:13:00Z"},
      {"id":695,"conclusion":"failure","status":"completed","created_at":"2026-09-10T16:24:00Z"},
      {"id":694,"conclusion":"failure","status":"completed","created_at":"2026-09-10T12:14:00Z"}
    ]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM18"
NOW18="$(date -u -d "2026-09-12T15:40:00Z" +%s)"
_run "$SHIM18" "$NOW18"
if [ "$RC" -ne 0 ] \
  && echo "$OUT" | grep -q '^RED	Daily orchestrator' \
  && echo "$OUT" | grep -q 'streak=6 in_progress=1' \
  && echo "$OUT" | grep -q 'status=in_progress' \
  && echo "$OUT" | grep -q 'newest_completed_run_id=699'; then
  pass "assertion 18: incident shape (6 failures + in_progress newest) -> RED streak=6 in_progress=1, not masked"
else
  fail "assertion 18: expected RED streak=6 in_progress=1 (the incident this rework fixes), got rc=$RC output=$OUT"
fi

echo "=== Assertion 19: single failure, then (older) a success -> NOT RED, recovered ==="
SHIM19="${TMPDIR_ROOT}/fetch19.sh"
cat > "$SHIM19" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":1,"workflows":[{"id":1,"name":"Recovered Weekly","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[
      {"id":902,"conclusion":"success","status":"completed","created_at":"2026-09-04T00:00:00Z"},
      {"id":901,"conclusion":"failure","status":"completed","created_at":"2026-08-28T00:00:00Z"}
    ]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM19"
NOW19="$(date -u -d "2026-09-04T06:00:00Z" +%s)"
_run "$SHIM19" "$NOW19"
if [ "$RC" -eq 0 ] \
  && echo "$OUT" | grep -q '^OK	Recovered Weekly' \
  && echo "$OUT" | grep -q 'streak=0'; then
  pass "assertion 19: newest run recovered (success) after an older failure -> not RED, streak=0"
else
  fail "assertion 19: expected OK/streak=0 for a recovered workflow, got rc=$RC output=$OUT"
fi

echo "=== Assertion 20: every fetched run is in_progress/queued -> UNOBSERVABLE, not OK ==="
SHIM20="${TMPDIR_ROOT}/fetch20.sh"
cat > "$SHIM20" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":2,"workflows":[{"id":1,"name":"Mid-flight sweep","state":"active"},{"id":2,"name":"Healthy Weekly","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[
      {"id":800,"conclusion":null,"status":"in_progress","created_at":"2026-09-12T15:00:00Z"},
      {"id":799,"conclusion":null,"status":"queued","created_at":"2026-09-12T14:55:00Z"}
    ]}'
    ;;
  *"actions/workflows/2/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":222,"conclusion":"success","status":"completed","created_at":"2026-09-12T00:00:00Z"}]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM20"
NOW20="$(date -u -d "2026-09-12T15:10:00Z" +%s)"
_run "$SHIM20" "$NOW20"
if [ "$RC" -eq 0 ] \
  && echo "$OUT" | grep -q '^UNOBSERVABLE	Mid-flight sweep' \
  && ! echo "$OUT" | grep -q '^OK	Mid-flight sweep' \
  && echo "$OUT" | grep -q '^OK	Healthy Weekly' \
  && echo "$OUT" | grep -q 'unobservable=1'; then
  pass "assertion 20: all-in-progress workflow -> UNOBSERVABLE (never OK), does not force non-zero exit"
else
  fail "assertion 20: expected UNOBSERVABLE (not OK) and exit0, got rc=$RC output=$OUT"
fi

echo "=== Assertion 21: full page (10) of consecutive failures -> RED, streak reported as a FLOOR (>=10) ==="
SHIM21="${TMPDIR_ROOT}/fetch21.sh"
cat > "$SHIM21" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":1,"workflows":[{"id":1,"name":"Full-page failures","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[
      {"id":810,"conclusion":"failure","status":"completed","created_at":"2026-09-12T15:32:00Z"},
      {"id":809,"conclusion":"failure","status":"completed","created_at":"2026-09-12T11:32:00Z"},
      {"id":808,"conclusion":"failure","status":"completed","created_at":"2026-09-12T07:32:00Z"},
      {"id":807,"conclusion":"failure","status":"completed","created_at":"2026-09-12T03:32:00Z"},
      {"id":806,"conclusion":"failure","status":"completed","created_at":"2026-09-11T23:32:00Z"},
      {"id":805,"conclusion":"failure","status":"completed","created_at":"2026-09-11T19:32:00Z"},
      {"id":804,"conclusion":"failure","status":"completed","created_at":"2026-09-11T15:32:00Z"},
      {"id":803,"conclusion":"failure","status":"completed","created_at":"2026-09-11T11:32:00Z"},
      {"id":802,"conclusion":"failure","status":"completed","created_at":"2026-09-11T07:32:00Z"},
      {"id":801,"conclusion":"failure","status":"completed","created_at":"2026-09-11T03:32:00Z"}
    ]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM21"
NOW21="$(date -u -d "2026-09-12T16:00:00Z" +%s)"
_run "$SHIM21" "$NOW21"
if [ "$RC" -ne 0 ] \
  && echo "$OUT" | grep -q '^RED	Full-page failures' \
  && echo "$OUT" | grep -q 'streak=>=10' \
  && echo "$OUT" | grep -q 'SUMMARY: RED workflows: Full-page failures(streak=>=10)'; then
  pass "assertion 21: full page of 10 failures -> RED, streak reported as a floor (>=10), never the false-exact count"
else
  fail "assertion 21: expected RED with streak=>=10 floor in both the line and the SUMMARY, got rc=$RC output=$OUT"
fi

echo "=== Assertion 22: --runs-per-workflow flag drives per_page on the runs request ==="
SHIM22="${TMPDIR_ROOT}/fetch22.sh"
cat > "$SHIM22" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":1,"workflows":[{"id":1,"name":"Runs-per-workflow flag wf","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=3")
    echo '{"workflow_runs":[{"id":111,"conclusion":"success","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *)
    echo "unmatched path (--runs-per-workflow not threaded through?): $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM22"
_run "$SHIM22" "$NOW1" --runs-per-workflow 3
if [ "$RC" -eq 0 ] \
  && echo "$OUT" | grep -q 'runs_per_workflow=3' \
  && echo "$OUT" | grep -q '^OK	Runs-per-workflow flag wf'; then
  pass "assertion 22: --runs-per-workflow 3 drives per_page=3 on the runs request"
else
  fail "assertion 22: expected exit0 against the per_page=3 shim, got rc=$RC output=$OUT"
fi

echo "=== Assertion 23: SCHEDULED_WF_HEALTH_RUNS_PER_WORKFLOW env var drives per_page on the runs request ==="
SHIM23="${TMPDIR_ROOT}/fetch23.sh"
cat > "$SHIM23" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":1,"workflows":[{"id":1,"name":"Runs-per-workflow env wf","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=5")
    echo '{"workflow_runs":[{"id":111,"conclusion":"success","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *)
    echo "unmatched path (RUNS_PER_WORKFLOW env not threaded through?): $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM23"
set +e
OUT23="$(SCHEDULED_WF_HEALTH_FETCH="$SHIM23" SCHEDULED_WF_HEALTH_NOW_EPOCH="$NOW1" SCHEDULED_WF_HEALTH_RUNS_PER_WORKFLOW=5 env -u GH_TOKEN sh "$SCRIPT" 2>&1)"
RC23=$?
set -e
if [ "$RC23" -eq 0 ] \
  && echo "$OUT23" | grep -q 'runs_per_workflow=5' \
  && echo "$OUT23" | grep -q '^OK	Runs-per-workflow env wf'; then
  pass "assertion 23: SCHEDULED_WF_HEALTH_RUNS_PER_WORKFLOW=5 env var drives per_page=5 on the runs request"
else
  fail "assertion 23: expected exit0 against the per_page=5 shim via env var, got rc=$RC23 output=$OUT23"
fi

echo "=== Assertion 24: --runs-per-workflow 0 -> exit 64 (usage error) ==="
_run "$SHIM1" "" --runs-per-workflow 0
if [ "$RC" -eq 64 ] && echo "$OUT" | grep -q 'must be a positive integer'; then
  pass "assertion 24: --runs-per-workflow 0 -> exit 64, distinct usage-error message"
else
  fail "assertion 24: expected exit64 with the usage-error message for runs-per-workflow=0, got rc=$RC output=$OUT"
fi

echo "=== Assertion 25: newest run in_progress \"now\", underlying completed run 40 days old -> STALE, not OK ==="
SHIM25="${TMPDIR_ROOT}/fetch25.sh"
cat > "$SHIM25" <<'EOF'
#!/bin/sh
path="$1"
case "$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":1,"workflows":[{"id":1,"name":"Masked stale wf","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[
      {"id":902,"conclusion":null,"status":"in_progress","created_at":"2026-09-12T15:55:00Z"},
      {"id":901,"conclusion":"success","status":"completed","created_at":"2026-08-03T00:00:00Z"}
    ]}'
    ;;
  *)
    echo "unmatched path: $path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM25"
NOW25="$(date -u -d "2026-09-12T16:00:00Z" +%s)"
_run "$SHIM25" "$NOW25"
if [ "$RC" -ne 0 ] \
  && echo "$OUT" | grep -q '^STALE	Masked stale wf' \
  && echo "$OUT" | grep -q 'in_progress=1' \
  && ! echo "$OUT" | grep -q '^OK	Masked stale wf'; then
  pass "assertion 25: staleness measured from the newest COMPLETED run, not masked by a fresher in_progress run on top"
else
  fail "assertion 25: expected STALE (not OK) despite an in_progress newest run, got rc=$RC output=$OUT"
fi

echo "=== Assertion 26: exactly one API call per workflow (list once, runs once per workflow) ==="
SHIM26="${TMPDIR_ROOT}/fetch26.sh"
CALL_LOG26="${TMPDIR_ROOT}/call_log26.txt"
: > "$CALL_LOG26"
cat > "$SHIM26" <<EOF
#!/bin/sh
path="\$1"
echo "\$path" >> "$CALL_LOG26"
case "\$path" in
  *"actions/workflows?per_page=100&page=1")
    echo '{"total_count":2,"workflows":[{"id":1,"name":"Call-count wf one","state":"active"},{"id":2,"name":"Call-count wf two","state":"active"}]}'
    ;;
  *"actions/workflows/1/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":111,"conclusion":"success","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *"actions/workflows/2/runs?event=schedule&per_page=10")
    echo '{"workflow_runs":[{"id":222,"conclusion":"success","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *)
    echo "unmatched path: \$path" >&2
    exit 1
    ;;
esac
EOF
_finish_shim "$SHIM26"
_run "$SHIM26" "$NOW1"
_list_calls26=$(grep -c 'actions/workflows?per_page=100&page=1$' "$CALL_LOG26" || true)
_runs_calls26=$(grep -c 'runs?event=schedule&per_page=10$' "$CALL_LOG26" || true)
_total_calls26=$(wc -l < "$CALL_LOG26" | tr -d ' ')
if [ "$RC" -eq 0 ] \
  && [ "$_list_calls26" -eq 1 ] \
  && [ "$_runs_calls26" -eq 2 ] \
  && [ "$_total_calls26" -eq 3 ]; then
  pass "assertion 26: exactly one list call and exactly one runs call per workflow (3 total for 2 workflows)"
else
  fail "assertion 26: expected 1 list call + 2 runs calls (3 total), got list=$_list_calls26 runs=$_runs_calls26 total=$_total_calls26 (rc=$RC)"
fi

echo ""
echo "=== Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed ==="
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
echo "OK: scheduled_workflow_health_test -- all assertions passed."
