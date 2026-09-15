#!/bin/sh
# Fixture-driven test for dev/scripts/dispatch_disk_guard.sh
# (H-AGENT-WORKTREE-DISK-16GB-EACH, dev/status/harness.md).
#
# Drives the guard via its two injectable seams (DISPATCH_DISK_GUARD_DF_TEXT,
# DISPATCH_DISK_GUARD_FLOOR_GB) -- never over the live runner's real `df`
# alone. A test that only read live disk would pass vacuously on a roomy
# runner (this one currently has tens of GB free) and would stop testing
# anything the moment the runner's free space happened to exceed whatever
# floor a future edit computes. Each scenario below pins an exact,
# reproducible free-space reading instead.
#
# The df-text seam feeds literal `df -Pk`-shaped text through the SAME
# parsing path the guard uses for a real `df` call (header line + one data
# line, Available in field 4 of line 2) -- so the malformed/empty scenarios
# here exercise the guard's parsing defensiveness, not just a bypass of it.

set -e

GUARD="$(dirname "$0")/dispatch_disk_guard.sh"
if [ ! -f "$GUARD" ]; then
  echo "FAIL: dispatch_disk_guard_test -- guard not found at $GUARD" >&2
  exit 1
fi

# 68 GB is the exact required floor for 3 agents under the guard's own
# defaults (3 * PER_AGENT_WORKTREE_GB=16 + SAFETY_MARGIN_GB=20 = 68). If
# those constants ever change in the guard, this test's boundary scenario
# must be updated alongside them -- that coupling is intentional: the
# boundary test is only meaningful when it pins the guard's ACTUAL formula,
# not an independently-chosen number.
REQUIRED_GB_FOR_3_AGENTS=68
KB_PER_GB=1048576 # 1024 * 1024, i.e. df -Pk's 1K-block unit to GB

_df_text() {
  # $1 = Available KB value to embed in a well-formed df -Pk fixture.
  printf 'Filesystem     1024-blocks      Used Available Capacity Mounted on\noverlay          153617296  13000000 %s 50%% /\n' "$1"
}

_run_guard() {
  # $1 = agent count, $2 = DISPATCH_DISK_GUARD_DF_TEXT value to inject.
  ACTUAL_OUTPUT="$(DISPATCH_DISK_GUARD_DF_TEXT="$2" sh "$GUARD" "$1" . 2>&1)" && ACTUAL_EXIT=0 || ACTUAL_EXIT=$?
}

_assert_exit() {
  # $1 = expected exit, $2 = scenario name.
  if [ "$ACTUAL_EXIT" -ne "$1" ]; then
    echo "FAIL: dispatch_disk_guard_test -- $2: expected exit $1, got $ACTUAL_EXIT"
    echo "  output: $ACTUAL_OUTPUT"
    exit 1
  fi
}

_assert_contains() {
  # $1 = expected substring, $2 = scenario name.
  if ! printf '%s' "$ACTUAL_OUTPUT" | grep -q "$1"; then
    echo "FAIL: dispatch_disk_guard_test -- $2: output did not contain '$1'"
    echo "  output: $ACTUAL_OUTPUT"
    exit 1
  fi
}

# ---- Scenario 1: comfortably above floor -- must PASS ----

_run_guard 3 "$(_df_text $((100 * KB_PER_GB)))"
_assert_exit 0 "comfortably-above-floor"
_assert_contains "OK:" "comfortably-above-floor"

# ---- Scenario 2: comfortably below floor -- must REFUSE ----

_run_guard 3 "$(_df_text $((10 * KB_PER_GB)))"
_assert_exit 1 "comfortably-below-floor"
_assert_contains "REFUSE:" "comfortably-below-floor"

# ---- Scenario 3: exactly at the boundary -- PASSES (floor is inclusive) ----
# The guard's header documents this choice explicitly: "the minimum free
# space that is acceptable", not "...that is still too little". Free space
# exactly equal to the computed floor must exit 0.

_run_guard 3 "$(_df_text $((REQUIRED_GB_FOR_3_AGENTS * KB_PER_GB)))"
_assert_exit 0 "exact-boundary"
_assert_contains "OK:" "exact-boundary"

# ---- Scenario 3b: one KB below the boundary -- must REFUSE ----
# Pins the boundary from the other side: the floor is not fuzzy, one KB
# under it is already a refusal.

_run_guard 3 "$(_df_text $((REQUIRED_GB_FOR_3_AGENTS * KB_PER_GB - 1)))"
_assert_exit 1 "one-kb-below-boundary"
_assert_contains "REFUSE:" "one-kb-below-boundary"

# ---- Scenario 4: malformed df reading (garbage text) -- must REFUSE, never
# silently pass ----

_run_guard 3 "not a df reading at all"
_assert_exit 1 "malformed-df-reading"
_assert_contains "REFUSE:" "malformed-df-reading"
_assert_contains "default-closed" "malformed-df-reading"

# ---- Scenario 5: empty df reading -- must REFUSE, never silently pass ----
# This is the scenario that caught a real seam bug while building the guard:
# an early version used `[ -n "${VAR:-}" ]` to detect the injection, which
# treats an empty-string injection as "not set" and falls through to a live
# `df` call -- silently skipping this exact case. The fixed guard uses
# `${VAR+set}` so an explicitly-empty injection is honoured and refused.

_run_guard 3 ""
_assert_exit 1 "empty-df-reading"
_assert_contains "REFUSE:" "empty-df-reading"
_assert_contains "default-closed" "empty-df-reading"

# ---- Scenario 5b: well-formed df line with a NON-NUMERIC Available field --
# must REFUSE via the default-closed path, not crash ----
# Distinct from scenario 4 (single-line garbage, no second line at all) and
# scenario 5 (empty injection): this is a properly-shaped two-line df -Pk
# fixture (header + one data line, five fields) where field 4 itself is not
# a number. Without this scenario the `*[!0-9]*` arm of the case statement
# guarding FREE_KB is never exercised -- both scenarios 4 and 5 reach the
# empty-string `''` arm instead (awk prints nothing when there's no second
# line to match NR==2), so deleting the `*[!0-9]*` arm survives undetected.

_run_guard 3 "$(printf 'Filesystem     1024-blocks      Used Available Capacity Mounted on\noverlay          153617296  13000000 notanumber 50%% /\n')"
_assert_exit 1 "non-numeric-available-field"
_assert_contains "REFUSE:" "non-numeric-available-field"
_assert_contains "default-closed" "non-numeric-available-field"

# ---- Scenario 6: missing agent-count argument -- must REFUSE ----

ACTUAL_OUTPUT="$(sh "$GUARD" 2>&1)" && ACTUAL_EXIT=0 || ACTUAL_EXIT=$?
_assert_exit 1 "missing-agent-count"
_assert_contains "REFUSE:" "missing-agent-count"

# ---- Scenario 7: non-numeric agent-count argument -- must REFUSE ----

ACTUAL_OUTPUT="$(sh "$GUARD" three 2>&1)" && ACTUAL_EXIT=0 || ACTUAL_EXIT=$?
_assert_exit 1 "non-numeric-agent-count"
_assert_contains "REFUSE:" "non-numeric-agent-count"

# ---- Scenario 8: zero agents still enforces the safety margin -- must
# REFUSE when free space is below SAFETY_MARGIN_GB alone ----
# Guards against the per-agent constant being effectively "dropped" for the
# zero-agent case: 0 agents is not the same as "no floor at all".

_run_guard 0 "$(_df_text $((5 * KB_PER_GB)))"
_assert_exit 1 "zero-agents-below-safety-margin"
_assert_contains "REFUSE:" "zero-agents-below-safety-margin"

# ---- Scenario 9: DISPATCH_DISK_GUARD_FLOOR_GB override bypasses the
# agent-count formula entirely ----

ACTUAL_OUTPUT="$(DISPATCH_DISK_GUARD_FLOOR_GB=1 DISPATCH_DISK_GUARD_DF_TEXT="$(_df_text $((2 * KB_PER_GB)))" sh "$GUARD" 99 . 2>&1)" && ACTUAL_EXIT=0 || ACTUAL_EXIT=$?
_assert_exit 0 "floor-override-pass"
_assert_contains "required-floor=1GB" "floor-override-pass"

# ---- Scenario 10: the floor actually SCALES with <agent-count> -- same free
# space (50GB), 1 agent PASSES and 3 agents REFUSES ----
# Every other non-override scenario above fixes the agent count at 3, so none
# of them can tell apart "the formula multiplies by agent-count" from "the
# formula is a constant that happens to equal 68 when count=3" -- a rewrite
# that hardcodes REQUIRED_GB=$((3 * PER_AGENT_WORKTREE_GB + SAFETY_MARGIN_GB))
# (ignoring $1 entirely) stays green against every scenario above. This pair
# pins agent-count as a real multiplicand: at 50GB free, 1 agent's floor (36)
# passes and 3 agents' floor (68) refuses -- the same free-space reading,
# different verdicts, only explained by AGENT_COUNT actually scaling the sum.

_run_guard 1 "$(_df_text $((50 * KB_PER_GB)))"
_assert_exit 0 "one-agent-50gb-passes"
_assert_contains "OK:" "one-agent-50gb-passes"

_run_guard 3 "$(_df_text $((50 * KB_PER_GB)))"
_assert_exit 1 "three-agents-50gb-refuses"
_assert_contains "REFUSE:" "three-agents-50gb-refuses"

# ---- Scenario 11: an invalid DISPATCH_DISK_GUARD_FLOOR_GB override value --
# must REFUSE rather than silently ignore the override and fall back to the
# agent-count formula ----

ACTUAL_OUTPUT="$(DISPATCH_DISK_GUARD_FLOOR_GB=abc DISPATCH_DISK_GUARD_DF_TEXT="$(_df_text $((100 * KB_PER_GB)))" sh "$GUARD" 3 . 2>&1)" && ACTUAL_EXIT=0 || ACTUAL_EXIT=$?
_assert_exit 1 "invalid-floor-override"
_assert_contains "REFUSE:" "invalid-floor-override"

# ---- Scenario 12: the optional [target-path] argument is threaded through
# into the printed decision line, not silently dropped ----

ACTUAL_OUTPUT="$(DISPATCH_DISK_GUARD_DF_TEXT="$(_df_text $((100 * KB_PER_GB)))" sh "$GUARD" 3 /custom/target/path 2>&1)" && ACTUAL_EXIT=0 || ACTUAL_EXIT=$?
_assert_exit 0 "custom-target-path"
_assert_contains "target='/custom/target/path'" "custom-target-path"

echo "OK: dispatch_disk_guard_test -- all 15 scenarios passed (pass/refuse/boundary x2/malformed/empty/non-numeric-field/missing-arg/bad-arg/zero-agent-floor/floor-override/agent-count-scaling x2/invalid-floor-override/target-path)."
