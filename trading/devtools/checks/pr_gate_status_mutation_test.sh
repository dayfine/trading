#!/bin/sh
# pr_gate_status_mutation_test.sh -- mutation-coverage harness for
# dev/scripts/pr_gate_status.sh, the merge-gate reader (.claude/rules/
# pr-gate-loop.md). H-GATEPARSER-NO-MUTATION-COVERAGE, dev/status/harness.md.
#
# WHY THIS EXISTS
#   pr_gate_status.sh decides whether a PR's CI + qc-structural +
#   qc-behavioral verdicts are all green AT THE CURRENT TIP -- the thing
#   that gates every merge in this repo. Its own regression suite
#   (pr_gate_status_test.sh) has only ever been verified by hand, and that
#   hand-verification has been WRONG TWICE IN THE SAME DIRECTION:
#     - PR #2622's sweep said "8 of 11 killed, 3 survivors"; its own table
#       showed 5 GREEN rows.
#     - PR #2625 corrected it to "5 survivors, every one live" -- ALSO
#       wrong. qc-behavioral on PR #2635 swept degrees of freedom nobody
#       had listed ((?m), the heading regex's own ^/$, the .* capture, the
#       LOWER bound of #{1,4}, (?i), the (qc[- ])? group) and found four
#       MORE live survivors.
#   The honest statement was never a survivor count -- it was that nobody
#   had exhaustively enumerated this regex, and every attempt undercounted.
#   This harness makes the enumeration mechanical: it does not rely on a
#   human remembering which mutations were checked.
#
# HOW IT WORKS
#   For each pinned mutation below: copy the real pr_gate_status.sh to a
#   scratch dir, apply a sed edit, confirm the edit actually changed the
#   file (see NON-VACUITY), then run the EXISTING, unmodified
#   pr_gate_status_test.sh (which sources the mutated copy offline via its
#   PR_GATE_STATUS_LIB=1 seam -- no network, no invented sourcing
#   mechanism) against it.
#     suite exits non-zero (goes red) -> KILLED  (a real regression here
#                                                   would be caught)
#     suite exits 0        (stays green) -> SURVIVOR (a known gap)
#   Compare the observed outcome to this file's own pinned expectation.
#
# GATING POLICY -- option (b) of the H-GATEPARSER-NO-MUTATION-COVERAGE
# item: gate on a PINNED expected-outcome list, not a blanket
# WARN-or-FAIL. Known-live survivors exist today (4 of the 16 below --
# s1-s4; s5 is a verified equivalent mutant, not a live defect -- see its
# own entry below); a harness that hard-fails on any survivor would turn
# main red on merge, and .claude/rules/code-health-discipline.md forbids
# dodging that with a limit bump or an escape-hatch marker. Instead, this
# check fails ONLY when a mutation's OBSERVED outcome differs from its
# PINNED expectation,
# in either direction:
#   a pinned KILLED mutation now SURVIVES -> a live regression: something
#     the suite used to catch, it no longer does. Hard stop.
#   a pinned SURVIVOR mutation now gets KILLED -> good news, but this
#     file's own pin is now stale -- flip it to `killed` here in the same
#     PR that fixed the underlying gap, so the record stays honest.
#   This is stronger than a plain WARN: it catches regressions immediately
#   while tolerating the documented backlog by name, not by blanket
#   exception.
#
# NON-VACUITY
#   A mutation whose sed found nothing to change is a HARNESS bug, not a
#   result, and must never read as a clean KILLED or SURVIVOR -- the exact
#   failure mode the 2026-09-03 orchestrator run hit first-hand elsewhere
#   (a str.replace silently matched nothing; the suite ran unmutated and
#   reported clean, indistinguishable from "the guard is unpinned").
#   run_mutation() below hard-fails with a message
#   ("MUTATION DID NOT APPLY") that cannot be confused with either real
#   outcome the moment cmp finds the mutated copy identical to the
#   original. Proven end to end by
#   pr_gate_status_mutation_test_selftest.sh, which injects a
#   deliberately-unmatchable sed and asserts this exact message fires.
#
# RESTORE / ISOLATION
#   Every mutation is applied to a throwaway copy under a mktemp -d
#   scratch dir -- the real, tracked dev/scripts/pr_gate_status.sh is
#   NEVER written to. This is a stronger guarantee than "mutate in place,
#   then restore via a trap": there is no window, however small, in which
#   the tracked file on disk is broken, and nothing depends on a trap
#   actually firing (e.g. under SIGKILL) to avoid leaving the repo dirty.
#   The trap below still cleans up the scratch dir, and the final cmp
#   check below asserts, as a tripwire, that the tracked file was never
#   touched -- so a future edit that accidentally switches to in-place
#   mutation cannot silently drop this guarantee. cmp is used rather than
#   `git diff --quiet` deliberately: git operations in this container can
#   fail under GHA's safe.directory setup (see _check_lib.sh's repo_root()
#   comment) in a way unrelated to this check's own correctness.

set -eu
. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT_REAL="$(repo_root)"
SCRIPT="${REPO_ROOT_REAL}/dev/scripts/pr_gate_status.sh"
SUITE="${REPO_ROOT_REAL}/dev/scripts/pr_gate_status_test.sh"
[ -f "$SCRIPT" ] || die "pr_gate_status_mutation_test: missing $SCRIPT"
[ -f "$SUITE" ] || die "pr_gate_status_mutation_test: missing $SUITE"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$SCRIPT" "$WORK/pr_gate_status.sh.orig"
cp "$SUITE" "$WORK/pr_gate_status_test.sh"

fails=0
total=0
killed_count=0
live_survivor_count=0
equivalent_count=0

# run_mutation <id> <killed|survivor> <sed-expr> <description> [equivalent]
# <sed-expr> is applied (GNU sed -i, BRE) to a fresh copy of the pristine
# script on every call -- mutations never compound across calls. The
# optional 5th arg, literally "equivalent", marks a `survivor`-pinned
# mutation as a VERIFIED EQUIVALENT MUTANT rather than a live defect (no
# test can ever distinguish it from the unmutated script -- see s5 below
# for the one case that uses it). This is the mechanical source of the
# killed/live-survivor/equivalent-mutant split printed in the final
# summary line -- read the split from that line, not from prose restating
# it, so the two can never drift out of sync again (dev/status/harness.md
# H-GATEPARSER-NO-MUTATION-COVERAGE's own "Out of scope" note got this
# split wrong once already).
run_mutation() {
  id=$1; expected=$2; sedexpr=$3; desc=$4; equivalent=${5:-}
  total=$((total + 1))
  cp "$WORK/pr_gate_status.sh.orig" "$WORK/pr_gate_status.sh"
  sed -i "$sedexpr" "$WORK/pr_gate_status.sh"
  if cmp -s "$WORK/pr_gate_status.sh.orig" "$WORK/pr_gate_status.sh"; then
    printf 'FAIL %s: MUTATION DID NOT APPLY (sed found nothing to change) -- %s\n' \
      "$id" "$desc" >&2
    fails=$((fails + 1))
    return
  fi
  if sh "$WORK/pr_gate_status_test.sh" >"$WORK/out.log" 2>&1; then
    got=survivor
  else
    got=killed
  fi
  if [ "$got" = "$expected" ]; then
    if [ "$got" = "killed" ]; then
      killed_count=$((killed_count + 1))
    elif [ "$equivalent" = "equivalent" ]; then
      equivalent_count=$((equivalent_count + 1))
    else
      live_survivor_count=$((live_survivor_count + 1))
    fi
    printf 'ok   %s (%s, as pinned): %s\n' "$id" "$got" "$desc"
  else
    printf 'FAIL %s: pinned %s, observed %s -- %s\n' \
      "$id" "$expected" "$got" "$desc" >&2
    fails=$((fails + 1))
  fi
}

# --- Self-test hook (opt-in only, never set by the dune rule) --------------
# Proves the NON-VACUITY guard above actually fires end to end. See
# pr_gate_status_mutation_test_selftest.sh, which sets both vars. Setting
# _ONLY skips the 16 real mutations below (redundant in that mode -- the
# selftest cares only about the injected no-op) so the selftest stays fast.
if [ "${PR_GATE_STATUS_MUTATION_SELFTEST_NOOP:-0}" = "1" ]; then
  run_mutation selftest-noop killed \
    's/ZZZZ_NONEXISTENT_TOKEN_FOR_SELFTEST_ZZZZ/nope/' \
    'self-test fixture: this sed can never match a real file (proves the non-vacuity guard fires)'
fi

if [ "${PR_GATE_STATUS_MUTATION_SELFTEST_ONLY:-0}" != "1" ]; then

# --- Pinned mutation table --------------------------------------------------
# Seeded from the FULL list recorded in dev/status/harness.md
# (H-GATEPARSER-NO-MUTATION-COVERAGE) -- both the "Killed" table (d, j, k,
# f, g, m) and the "LIVE and unpinned" table found by #2635's sweep -- plus
# further degrees of freedom this harness's own construction swept across
# the same three regexes (first_heading_text's heading match, review_result's
# sha capture, and the kind test): x1-x5 and s5 below are not named in the
# status entry. s5 in particular is a verified EQUIVALENT MUTANT (see its
# own note) rather than a live defect -- recorded rather than silently
# dropped, per this repo's own standard for classifying a survivor
# (odoc_dangling_ref_check.sh's header makes the same distinction). Of the
# 5 pinned `survivor` outcomes below (s1-s5), 4 (s1-s4) are live defects
# and 1 (s5) is this equivalent mutant -- see "Out of scope" in the status
# entry, which scopes follow-up to the 4.

run_mutation d1 killed \
  's/^      strip_fences$/      ./' \
  '(d) drop the strip_fences call inside first_heading_text (leaves review_results own copy untouched)'

run_mutation j1 killed \
  's/"(?i)^(qc\[- \])?" + \$kind/"(?i)(qc[- ])?" + $kind/' \
  '(j) drop the ^ anchor in the kind test (line ~325)'

run_mutation k1 killed \
  's/ + \$kind + "\\\\b"))/ + $kind))/' \
  '(k) drop \b (word boundary) from the kind test'

run_mutation f1 killed \
  's/#{1,4} +(?<h>\.\*)\$/#{1,6} +(?<h>.*)$/' \
  '(f) relax #{1,4} upper bound to #{1,6} in the heading regex (line ~237)'

run_mutation g1 killed \
  's/#{1,4} +(?<h>\.\*)\$/#{1,4} *(?<h>.*)$/' \
  '(g) relax required space " +" to " *" in the heading regex'

run_mutation m1 killed \
  's/(?m)^#{1,4}/(?m)#{1,4}/' \
  '(m) drop the ^ anchor from the heading regex itself (distinct from (j), which anchors the kind test)'

run_mutation s1 survivor \
  's/#{1,4} +(?<h>\.\*)\$/#{1,3} +(?<h>.*)$/' \
  'UNPINNED: #{1,4} -> #{1,3} (the LOWER half of (f) -- nothing pins the 4 from below; false-MERGE AND false-BLOCK)'

run_mutation s2 survivor \
  's/(?<h>\.\*)\$/(?<h>.+)$/' \
  'UNPINNED: (?<h>.*) -> (?<h>.+) -- a bare "## " heading with no text masks the real heading (false-MERGE)'

run_mutation s3 survivor \
  's/#{1,4} +(?<h>\.\*)\$/#{1,4} (?<h>.*)$/' \
  'UNPINNED: required space " +" -> " " (exactly one) -- a two-space heading "##  QC" goes unrecognized (false-BLOCK)'

run_mutation s4 survivor \
  's/(qc\[- \])?/(qc[-])?/' \
  'UNPINNED: [- ] -> [-] in the kind test -- "## QC Behavioral notes" (space, not hyphen) no longer satisfies the gate (false-BLOCK)'

# --- Additional degrees of freedom swept by this harness, not named in the
# status entry's tables (new findings, not scope creep -- see this file's
# own header) ---

run_mutation x1 killed \
  's/match("(?m)^#{1,4}/match("^#{1,4}/' \
  'drop the (?m) multiline flag entirely from the heading regex (not just its ^ anchor -- distinct from (m))'

run_mutation x2 killed \
  's/test("(?i)^(qc\[- \])?/test("^(qc[- ])?/' \
  'drop the (?i) case-insensitive flag from the kind test'

run_mutation x3 killed \
  's/(qc\[- \])?/(qc[- ])/' \
  'require the qc[- ] prefix (drop the optional ?) -- rejects a bare "## Structural QC" heading'

run_mutation x4 killed \
  's/#{1,4} +(?<h>\.\*)\$/#+ +(?<h>.*)$/' \
  'relax #{1,4} to unbounded #+ in the heading regex'

run_mutation x5 killed \
  's/\[0-9a-f\]{7,40}/[0-9a-f]{8,40}/' \
  'regress the sha-capture lower bound from {7,40} back to {8,40} -- the exact #2397 short-sha bug'

run_mutation s5 survivor \
  's/(?<h>\.\*)\$")\]/(?<h>.*)")]/' \
  'UNPINNED: drop the trailing $ end-anchor from the heading regex -- a VERIFIED EQUIVALENT MUTANT, not a live defect. What bounds "." at end-of-line is the ABSENCE of dot-all ((?s)), not (?m): confirmed in this container jq-1.6/Oniguruma, `"a\nb" | test("(?m)a.b")` is false but `"a\nb" | test("(?ms)a.b")` is true, so with only (?m) set the capture is line-bounded with or without the trailing $, making it redundant here. (Also a jq-semantics tripwire: if a future jq made "." dot-all by default, s5 would stop being equivalent.) The suite pins neither reading, but no test can ever distinguish them -- this is not left-for-follow-up work.' \
  equivalent

fi

if [ "$fails" -gt 0 ]; then
  printf 'FAIL: pr_gate_status mutation harness -- %d/%d mutation(s) off-pin.\n' \
    "$fails" "$total" >&2
  exit 1
fi

# Tripwire, not a real restore: this harness never writes $SCRIPT (see the
# header). Confirms that guarantee held for this run rather than assuming it.
cmp -s "$SCRIPT" "$WORK/pr_gate_status.sh.orig" \
  || die "pr_gate_status_mutation_test: the tracked $SCRIPT was modified by this run"

# The split below is derived from the per-mutation tallies above, not
# restated by hand -- see the run_mutation doc comment for why.
printf 'OK: pr_gate_status mutation harness -- %d mutation(s) match pin (%d killed / %d live survivor / %d equivalent mutant).\n' \
  "$total" "$killed_count" "$live_survivor_count" "$equivalent_count"
