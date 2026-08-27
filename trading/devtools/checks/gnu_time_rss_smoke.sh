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
# Assertion 5 below additionally pins that every one of the seven known call
# sites sources the shared library (not a re-inlined copy) -- this is what
# actually prevents the duplication #2559 fixed from recurring at those
# specific paths.
#
# Assertion 6 closes a STRUCTURAL gap that #2559/#2572 left open and that
# issue #2576 tripped over: assertion 5's list is hardcoded, so it can only
# ever answer "are these N known files still broken?", never "has an (N+1)th
# copy appeared?". #2576 found exactly that -- a 7th copy in
# dev/experiments/capital-recycling-combined-2026-05-07/run_with_perf.sh,
# using `$rss` instead of `$rss_path`, which evaded both #2559's original
# discovery grep and assertion 5's name-and-path-scoped check. Assertion 6
# sweeps every *.sh file in the repo for the BUG'S SHAPE (a `tr -d '\n'`
# whose input was not first reduced to one line) rather than a list of
# locations, and does not reference any variable name at all -- see its own
# header comment below for exactly what it does and does not catch.
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
dev/scripts/run_tier4_release_gate.sh
dev/experiments/capital-recycling-combined-2026-05-07/run_with_perf.sh"

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
  # Anchored to the actual `. "${REPO_ROOT}/dev/lib/gnu_time_rss.sh"` source
  # statement, not to any mention of the path -- a bare grep for the path
  # string also matches the doc comment naming it, which stays present even
  # after the source line is deleted and the parser re-inlined (the #2559
  # regression this assertion exists to catch). See NEEDS_REWORK review on
  # PR #2572, CP4.
  if grep -qE '^[[:space:]]*\.[[:space:]]+"\$\{REPO_ROOT\}/dev/lib/gnu_time_rss\.sh"' "$path"; then
    ok "${LABEL} — ${rel}: sources the shared gnu_time_rss.sh helper"
  else
    bad "${LABEL} — ${rel}: does not source dev/lib/gnu_time_rss.sh (re-inlined copy? #2559 regression)"
  fi
  # Widened from the `$rss_path`-specific form: a re-inlined copy of the bug
  # is a *function* taking `$1` (`_parse_gnu_time_rss() { tr -d '\n' <"$1"; }`,
  # exactly how #2553's original private helper was written), which the
  # narrower `<"$rss_path"` grep would miss entirely.
  if grep -qE "tr -d '\\\\n'[[:space:]]*<" "$path"; then
    bad "${LABEL} — ${rel}: still contains the raw buggy 'tr -d' parse inline"
  fi
  IFS='
'
done
IFS="$OLD_IFS"

# ---------------------------------------------------------------------------
# Assertion 6: repo-wide, SHAPE-based sweep for the raw newline-fusing bug --
# not a list of "known" call sites (see header comment / issue #2576).
#
# Shape: a `tr -d '\n'` whose input has NOT already been reduced to a single
# line, on the SAME line, via `tail -n 1` / `head -n 1`. That reduction is
# exactly what makes the shared helper's own `tail -n 1 "$1" | tr -d '\n'`
# safe -- `tr -d '\n'` alone is not the bug, feeding it a file that can have
# more than one line (a leading GNU-time status line on failing/killed
# cells) is. The regex names NO variable -- `$rss`, `$rss_path`, `$rssfile`,
# anything -- because #2576's copy evaded the OLD assertion precisely by
# using a variable name ($rss) the discovery grep didn't happen to use.
#
# Scanned: every "*.sh" file under the repo root, pruning the same
# non-source directories as no_python_check.sh (.git, _build, node_modules,
# vendor, .devcontainer, worktrees).
#
# Excluded by path (legitimately contain the raw string, not a live bug):
#   - dev/lib/gnu_time_rss.sh   -- the canonical correct implementation
#     (`tail -n 1 ... | tr -d '\n'`) plus doc-comment prose about the bug.
#   - this script                -- quotes the buggy shape in its own
#     doc-comments and history notes to describe/pin the check.
# Comment lines (first non-blank char '#') are also skipped everywhere else,
# so a future doc-comment mentioning the bug for context does not itself
# trip the sweep.
#
# KNOWN RESIDUAL -- read before trusting this as exhaustive:
#   - Same-LINE match only. A `tr -d '\n'` and its `tail -n 1` reduction (or
#     its file redirection) split across two lines/a multi-step pipeline
#     built via intermediate variables is NOT caught.
#   - Only `*.sh` files are scanned. Shell embedded inline in a GitHub
#     Actions `run:` block (YAML), a Makefile recipe, or any non-".sh"
#     script is NOT covered -- a grep of the full repo tree while writing
#     this assertion found the buggy STRING quoted only in YAML/Markdown
#     *comments/docs* referencing this bug (no live instance), but that is
#     a property of the repo TODAY, not a guarantee the sweep would catch a
#     future one there.
#   - Only the literal `tr -d '\n'` idiom is matched. A DIFFERENT
#     newline-fusing idiom (`awk 'BEGIN{RS="\0"}'`, `paste -s -d '' -`, a
#     hand-rolled `while read` line-concatenation loop) would not match this
#     regex at all. This assertion closes the SPECIFIC recurring copy-paste
#     bug shape (#2553/#2559/#2576), not every conceivable way to fuse
#     lines together.
#   - The "safe shape" check is CO-OCCURRENCE, not causal precedence: it
#     asks "does `tail -n 1` / `head -n 1` appear anywhere on this same
#     line", not "does it actually feed the `tr -d '\n'` on this line". A
#     contrived line with both substrings present for unrelated reasons
#     (e.g. two semicolon-separated statements) would be waved through as a
#     false negative. Every real call site in this repo is a simple
#     single-purpose assignment or two-stage pipe, so this has not been
#     observed in practice, but it is a real gap in the check's logic, not
#     just its scope.
# ---------------------------------------------------------------------------
EXCLUDE_HELPER="${REPO_ROOT_REAL}/dev/lib/gnu_time_rss.sh"
EXCLUDE_SELF="${REPO_ROOT_REAL}/trading/devtools/checks/gnu_time_rss_smoke.sh"
SWEEP_HITS_FILE="${WORK}/sweep_hits.txt"
SWEEP_MATCHES_FILE="${WORK}/sweep_matches.txt"
: >"$SWEEP_HITS_FILE"

SWEEP_FILES="$(find "$REPO_ROOT_REAL" \
  \( -name '.git' -o -name '_build' -o -name 'node_modules' \
     -o -name 'vendor' -o -name '.devcontainer' -o -name 'worktrees' \) -prune -o \
  -name '*.sh' -type f -print 2>/dev/null || true)"

OLD_IFS="$IFS"
IFS='
'
for f in $SWEEP_FILES; do
  IFS="$OLD_IFS"
  if [ "$f" = "$EXCLUDE_HELPER" ] || [ "$f" = "$EXCLUDE_SELF" ]; then
    IFS='
'
    continue
  fi

  : >"$SWEEP_MATCHES_FILE"
  grep -nE "tr -d '\\\\n'" "$f" 2>/dev/null >"$SWEEP_MATCHES_FILE" || true
  if [ -s "$SWEEP_MATCHES_FILE" ]; then
    while IFS= read -r hitline; do
      lineno="${hitline%%:*}"
      content="${hitline#*:}"
      # Skip comment lines.
      if printf '%s\n' "$content" | grep -qE '^[[:space:]]*#'; then
        continue
      fi
      # Skip the safe shape: already reduced to one line on the same line.
      case "$content" in
      *'tail -n 1'* | *'tail -n1'* | *'head -n 1'* | *'head -n1'*) continue ;;
      esac
      printf '%s:%s:%s\n' "$f" "$lineno" "$content" >>"$SWEEP_HITS_FILE"
    done <"$SWEEP_MATCHES_FILE"
  fi
  IFS='
'
done
IFS="$OLD_IFS"

if [ -s "$SWEEP_HITS_FILE" ]; then
  bad "${LABEL} — repo sweep: raw newline-fusing 'tr -d' shape found outside the shared helper"
  while IFS= read -r hit; do
    printf '    %s\n' "$hit" >&2
  done <"$SWEEP_HITS_FILE"
else
  ok "${LABEL} — repo sweep: no raw newline-fusing 'tr -d' shape found outside the shared helper (dev/lib/gnu_time_rss.sh)"
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "OK: ${LABEL} -- all assertions passed."
