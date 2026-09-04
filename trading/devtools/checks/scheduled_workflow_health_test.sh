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
  *"actions/workflows/1/runs?event=schedule&per_page=1")
    echo '{"workflow_runs":[{"id":111,"conclusion":"success","status":"completed","created_at":"2026-09-04T00:00:00Z"}]}'
    ;;
  *"actions/workflows/2/runs?event=schedule&per_page=1")
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
  *"actions/workflows/1/runs?event=schedule&per_page=1")
    echo '{"workflow_runs":[{"id":111,"conclusion":"failure","status":"completed","created_at":"2026-08-31T16:26:33Z"}]}'
    ;;
  *"actions/workflows/2/runs?event=schedule&per_page=1")
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
  *"actions/workflows/1/runs?event=schedule&per_page=1")
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
  *"actions/workflows/1/runs?event=schedule&per_page=1")
    echo '{"workflow_runs":[]}'
    ;;
  *"actions/workflows/2/runs?event=schedule&per_page=1")
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

echo ""
echo "=== Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed ==="
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
echo "OK: scheduled_workflow_health_test -- all assertions passed."
