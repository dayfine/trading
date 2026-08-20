#!/bin/sh
# Unit tests for pr_gate_status.sh's _gate verdict reader. Offline: the fixtures
# are review bodies, so no `gh` call is made.
#
# The regression that motivated this file: on PR #2417 the *structural* review
# carried a "### Notes for Behavioral QC" section. The matcher looked for the
# gate word anywhere in a heading, so that review's APPROVED was read as the
# behavioral verdict as well, and the PR printed `pass / ok / ok  MERGE` while
# qc-behavioral had never been dispatched. On an autonomous merge path that is a
# PR merged with one gate silently unrun.
set -eu

HERE=$(dirname "$0")
PR_GATE_STATUS_LIB=1
export PR_GATE_STATUS_LIB
# shellcheck source=/dev/null
. "$HERE/pr_gate_status.sh"

TIP=7dc57cc06aa1b2c3d4e5f60718293a4b5c6d7e8f
fails=0

check() {
  _name=$1; _want=$2; _got=$3
  if [ "$_got" = "$_want" ]; then
    printf 'ok   %s\n' "$_name"
  else
    printf 'FAIL %s: want %s, got %s\n' "$_name" "$_want" "$_got"
    fails=$((fails + 1))
  fi
}

# One review body per fixture, wrapped as the [{body}] shape _gate expects.
reviews() { jq -nc --arg b "$1" '[{body: $b}]'; }

STRUCT_WITH_BEHAV_SECTION="Reviewed SHA: 7dc57cc06

## Structural QC — base-broken-2026-08-19

### File Scope
Nothing leaked.

### Notes for Behavioral QC
Recompute the cohort totals from joined.tsv.

## Verdict

APPROVED"

REAL_BEHAVIORAL="Reviewed SHA: 7dc57cc06

## Behavioral QC — base-broken (PR #2417)

qc-structural already returned APPROVED at this tip.

## Verdict

APPROVED"

QC_PREFIXED_HEADING="Reviewed SHA: 7dc57cc06

## qc-behavioral verdict

## Verdict

NEEDS_REWORK"

STALE_BEHAVIORAL="Reviewed SHA: deadbeef

## Behavioral QC — an earlier tip

## Verdict

APPROVED"

# 1. THE REGRESSION. A structural review that merely *mentions* the other gate in
#    a section heading must not supply that gate's verdict.
check "notes-for-behavioral does not satisfy the behavioral gate" \
  none "$(_gate "$(reviews "$STRUCT_WITH_BEHAV_SECTION")" behavioral "$TIP")"

# 2. ...while still counting as the structural verdict it actually is.
check "same review still satisfies the structural gate" \
  ok "$(_gate "$(reviews "$STRUCT_WITH_BEHAV_SECTION")" structural "$TIP")"

# 3. A real behavioral review is matched on its own heading, even though its body
#    quotes the structural gate's approval.
check "real behavioral review is matched" \
  ok "$(_gate "$(reviews "$REAL_BEHAVIORAL")" behavioral "$TIP")"

# 4. ...and does not leak into the structural gate.
check "real behavioral review does not satisfy structural" \
  none "$(_gate "$(reviews "$REAL_BEHAVIORAL")" structural "$TIP")"

# 5. The "qc-<kind>" heading spelling is accepted, and NEEDS_REWORK reads through.
check "qc-prefixed heading, rework verdict" \
  rework "$(_gate "$(reviews "$QC_PREFIXED_HEADING")" behavioral "$TIP")"

# 6. A verdict pinned to an older SHA is stale, never ok.
check "verdict at a superseded sha is stale" \
  "stale(deadbeef)" "$(_gate "$(reviews "$STALE_BEHAVIORAL")" behavioral "$TIP")"

# 7. No reviews at all.
check "no reviews" none "$(_gate '[]' behavioral "$TIP")"

if [ "$fails" -gt 0 ]; then
  printf 'FAIL: pr_gate_status linter -- %d test(s) failed.\n' "$fails"
  exit 1
fi
printf 'OK: pr_gate_status -- %d tests clean.\n' 7
