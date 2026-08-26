#!/bin/sh
# golden_sp500_postsubmit_rss_smoke.sh -- fixture-driven regression test for
# dev/scripts/golden_sp500_postsubmit.sh's _parse_gnu_time_rss() (issue #2553).
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
# This test dot-sources the real script (dev/scripts/golden_sp500_postsubmit.sh,
# outside the dune workspace root, resolved via repo_root() -- same pattern as
# docker_dune_smoke.sh) with POSTSUBMIT_RSS_PARSE_TEST=1, which makes the
# script define _parse_gnu_time_rss() and then `return` before running its
# scenario-discovery / scenario_runner logic. That lets this test call
# _parse_gnu_time_rss directly against small fixture files instead of driving
# a full postsubmit run.
#
# Assertions:
#   1. Failing-cell shape (status line + value) -> value only, no fused digit.
#   2. Passing-cell shape (bare value, no status line) -> value unchanged.
#   3. UNAVAILABLE sentinel (no GNU time available) -> passes through unchanged.
#   4. Killed-by-signal shape (status line names a signal, not an exit code)
#      -> value only, same as assertion 1.
#
# Run:
#   sh trading/devtools/checks/golden_sp500_postsubmit_rss_smoke.sh

set -eu

. "$(dirname "$0")/_check_lib.sh"

LABEL="golden_sp500_postsubmit_rss_smoke"
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
TARGET="${REPO_ROOT_REAL}/dev/scripts/golden_sp500_postsubmit.sh"
[ -f "$TARGET" ] || die "${LABEL}: $TARGET does not exist"

# Source the real script in test mode: defines _parse_gnu_time_rss() and
# returns before running any discovery / scenario_runner logic.
POSTSUBMIT_RSS_PARSE_TEST=1
export POSTSUBMIT_RSS_PARSE_TEST
. "$TARGET"

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

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "OK: ${LABEL} -- all assertions passed."
