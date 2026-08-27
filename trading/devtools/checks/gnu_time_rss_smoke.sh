#!/bin/sh
# gnu_time_rss_smoke.sh -- fixture-driven regression test for the SHARED
# _parse_gnu_time_rss() helper in dev/lib/gnu_time_rss.sh (issues #2553,
# #2559).
#
# Bug: `rss_value=$(tr -d '\n' <"$rss_path")` stripped ALL newlines from the
# GNU /usr/bin/time output file. On a zero-exit cell that file is a single
# line (the %M value alone) and this is harmless. On a NON-ZERO-exit cell,
# GNU time additionally writes a leading status line ("Command exited with
# non-zero status 1"), and stripping newlines fuses the trailing status
# digit onto the RSS digits -- "...status 1" + "745192" -> "1745192", off by
# ~1GB, and only on FAILING cells, exactly when someone reads the number.
#
# Fix: read the LAST line of the file (`tail -n 1`), which is always the %M
# value regardless of whether a status line precedes it.
#
# History: the fix originally landed ONLY in
# dev/scripts/golden_sp500_postsubmit.sh (#2553), as a private
# _parse_gnu_time_rss() function, tested by dot-sourcing that one script.
# #2559 found the identical bug still present in five sibling scripts
# (perf_tier1_smoke.sh -- which backs the REQUIRED perf-tier1-smoke PR gate
# -- perf_tier2_nightly.sh, perf_tier3_weekly.sh, perf_tier4_release_gate.sh,
# run_tier4_release_gate.sh) because the helper had never been shared.
# _parse_gnu_time_rss() is now extracted to dev/lib/gnu_time_rss.sh and
# sourced by all six call sites; this test exercises the shared
# implementation ONCE rather than duplicating fixture coverage per caller.
#
# Assertions against the shared helper:
#   1. Failing-cell shape (status line + value) -> value only, no fused digit.
#   2. Passing-cell shape (bare value, no status line) -> value unchanged.
#   3. UNAVAILABLE sentinel (no GNU time available) -> passes through unchanged.
#   4. Killed-by-signal shape (status line names a signal, not an exit code)
#      -> value only, same as assertion 1.
#
# Change-detector verification performed when this test was generalized
# (#2559): the shared helper's body was temporarily reverted to the old
# buggy `tr -d '\n' <"$1"` form -- assertions 1 and 4 (the two shapes with a
# leading GNU-time status line) went RED with the exact fused-digit output
# ("1745192" / "92450164"), assertions 2 and 3 stayed GREEN (single-line
# inputs are unaffected by either implementation) -- then the helper was
# restored byte-identical and all four assertions went GREEN again.
#
# Assertion 5 below additionally pins that every one of the six known call
# sites sources the shared library (not a re-inlined copy) -- this is what
# actually prevents the six-way duplication #2559 fixed from recurring.
#
# Run:
#   sh trading/devtools/checks/gnu_time_rss_smoke.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="gnu_time_rss_smoke"
PASS=0
FAIL=0

ok() {
  printf 'OK: %s\n' "$1"
  PASS=$((PASS + 1))
}

bad() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

REPO_ROOT_REAL="$(repo_root)"
LIB="${REPO_ROOT_REAL}/dev/lib/gnu_time_rss.sh"
[ -f "$LIB" ] || die "${LABEL}: $LIB does not exist"

# Source the shared library directly -- it defines _parse_gnu_time_rss()
# with no side effects and no discovery / scenario_runner logic to guard
# against, unlike the pre-#2559 dot-source-a-whole-script approach.
. "$LIB"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

# ---------------------------------------------------------------------------
# Assertion 1: failing-cell shape -- GNU time's non-zero-exit status line
# precedes the %M value. This is the exact fused-digit repro: a naive
# `tr -d '\n'` over this file produces "1745192", not "745192".
# ---------------------------------------------------------------------------
F1="${WORK}/failing.peak_rss"
printf 'Command exited with non-zero status 1\n745192\n' >"$F1"
V1="$(_parse_gnu_time_rss "$F1")"
if [ "$V1" = "745192" ]; then
  ok "${LABEL} — failing-cell shape: parsed '745192' cleanly (no fused status digit)"
else
  bad "${LABEL} — failing-cell shape: expected '745192', got '${V1}'"
fi

# ---------------------------------------------------------------------------
# Assertion 2: passing-cell shape -- the file is just the %M value.
# ---------------------------------------------------------------------------
F2="${WORK}/passing.peak_rss"
printf '743468\n' >"$F2"
V2="$(_parse_gnu_time_rss "$F2")"
if [ "$V2" = "743468" ]; then
  ok "${LABEL} — passing-cell shape: bare value parsed unchanged"
else
  bad "${LABEL} — passing-cell shape: expected '743468', got '${V2}'"
fi

# ---------------------------------------------------------------------------
# Assertion 3: UNAVAILABLE sentinel (no GNU /usr/bin/time on this host) is a
# single line and must pass through unchanged.
# ---------------------------------------------------------------------------
F3="${WORK}/unavailable.peak_rss"
printf 'UNAVAILABLE\n' >"$F3"
V3="$(_parse_gnu_time_rss "$F3")"
if [ "$V3" = "UNAVAILABLE" ]; then
  ok "${LABEL} — UNAVAILABLE sentinel: passes through unchanged"
else
  bad "${LABEL} — UNAVAILABLE sentinel: expected 'UNAVAILABLE', got '${V3}'"
fi

# ---------------------------------------------------------------------------
# Assertion 4: killed-by-signal shape -- GNU time's status line names a
# signal instead of an exit code, same two-line shape as assertion 1.
# ---------------------------------------------------------------------------
F4="${WORK}/killed.peak_rss"
printf 'Command terminated by signal 9\n2450164\n' >"$F4"
V4="$(_parse_gnu_time_rss "$F4")"
if [ "$V4" = "2450164" ]; then
  ok "${LABEL} — killed-by-signal shape: parsed '2450164' cleanly"
else
  bad "${LABEL} — killed-by-signal shape: expected '2450164', got '${V4}'"
fi

# ---------------------------------------------------------------------------
# Assertion 5: every known GNU-time RSS caller sources the shared library
# (dev/lib/gnu_time_rss.sh) rather than carrying its own inlined copy of the
# parse logic. This is the mechanical guard against the #2559 regression
# (the fix landing once in #2553 and quietly failing to propagate to five
# siblings) recurring a third time.
# ---------------------------------------------------------------------------
CALL_SITES="dev/scripts/golden_sp500_postsubmit.sh
dev/scripts/perf_tier1_smoke.sh
dev/scripts/perf_tier2_nightly.sh
dev/scripts/perf_tier3_weekly.sh
dev/scripts/perf_tier4_release_gate.sh
dev/scripts/run_tier4_release_gate.sh"

OLD_IFS="$IFS"
IFS='
'
for rel in $CALL_SITES; do
  IFS="$OLD_IFS"
  path="${REPO_ROOT_REAL}/${rel}"
  if [ ! -f "$path" ]; then
    bad "${LABEL} — ${rel}: file does not exist"
    IFS='
'
    continue
  fi
  if grep -q 'dev/lib/gnu_time_rss\.sh' "$path"; then
    ok "${LABEL} — ${rel}: sources the shared gnu_time_rss.sh helper"
  else
    bad "${LABEL} — ${rel}: does not source dev/lib/gnu_time_rss.sh (re-inlined copy? #2559 regression)"
  fi
  if grep -qE "tr -d '\\\\n' <\"\\\$rss_path\"" "$path"; then
    bad "${LABEL} — ${rel}: still contains the raw buggy 'tr -d' parse inline"
  fi
  IFS='
'
done
IFS="$OLD_IFS"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "OK: ${LABEL} -- all assertions passed."
