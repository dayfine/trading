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
# Assertions 7 and 8 close a gap in assertion 6 ITSELF (NEEDS_REWORK review
# on PR #2580, CP2/CP4): assertion 6 only ever runs against the live repo,
# which is clean, so a pass proves nothing about whether the detector still
# works -- a regex re-scoped to a specific variable name, or reduced to a
# no-op, both left the repo sweep green. The sweep body is extracted into
# `_sweep_dir_for_tr_d_bug()` (takes a directory argument) so it can also be
# run against a disposable fixture directory: assertion 7 plants an
# arbitrary-name bug (must be caught) and a `tail -n 1`-reduced safe file
# (must not be), and assertion 8 plants the documented co-occurrence false
# negative so that residual is a measured suite result, not just prose.
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
#   - Same-LINE match only, and it fails SAFE, not permissive: a genuine
#     multi-line/intermediate-variable BUG (no `tail`/`head -n 1` reduction
#     anywhere near it) is still caught, because there is nothing on that
#     line to match the "already reduced" exemption. What the same-line
#     restriction actually produces is the opposite of a missed bug: SAFE
#     code that splits its `tail -n 1` reduction onto a separate line/an
#     intermediate variable is flagged as a false POSITIVE (working code
#     reported as buggy). This is over-cautious, not a hole.
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

# ---------------------------------------------------------------------------
# _sweep_dir_for_tr_d_bug <dir> <out_file> [exclude_path ...]
#
# Shared sweep body for assertions 6 and 7, extracted so the SAME shape
# detector can be run against both the real repo (assertion 6: must find
# nothing) and a disposable fixture directory (assertion 7: must find a
# planted bug and must NOT find a planted safe file). Before this
# extraction assertion 6 ran ONLY against the live repo, which is clean --
# so its passing state proved nothing about whether the detector still
# worked. Re-scoping the grep below to a specific variable name (the
# #2576 blind spot) or reducing it to a no-op regex both stayed green
# against the repo alone (NEEDS_REWORK review on PR #2580, CP2/CP4).
#
# Writes one "path:lineno:content" line per hit to <out_file> (truncated
# first). Caller decides pass/fail.
# ---------------------------------------------------------------------------
_sweep_dir_for_tr_d_bug() {
  sweep_dir="$1"
  out_file="$2"
  shift 2
  : >"$out_file"
  sweep_matches_file="${WORK}/_sweep_matches_tmp.txt"

  sweep_files="$(find "$sweep_dir" \
    \( -name '.git' -o -name '_build' -o -name 'node_modules' \
       -o -name 'vendor' -o -name '.devcontainer' -o -name 'worktrees' \) -prune -o \
    -name '*.sh' -type f -print 2>/dev/null || true)"

  sweep_old_ifs="$IFS"
  IFS='
'
  for sweep_f in $sweep_files; do
    IFS="$sweep_old_ifs"
    sweep_skip=0
    for sweep_ex in "$@"; do
      if [ "$sweep_f" = "$sweep_ex" ]; then
        sweep_skip=1
        break
      fi
    done
    if [ "$sweep_skip" -eq 1 ]; then
      IFS='
'
      continue
    fi

    : >"$sweep_matches_file"
    grep -nE "tr -d '\\\\n'" "$sweep_f" 2>/dev/null >"$sweep_matches_file" || true
    if [ -s "$sweep_matches_file" ]; then
      while IFS= read -r sweep_hitline; do
        sweep_lineno="${sweep_hitline%%:*}"
        sweep_content="${sweep_hitline#*:}"
        # Skip comment lines.
        if printf '%s\n' "$sweep_content" | grep -qE '^[[:space:]]*#'; then
          continue
        fi
        # Skip the safe shape: already reduced to one line on the same line.
        case "$sweep_content" in
        *'tail -n 1'* | *'tail -n1'* | *'head -n 1'* | *'head -n1'*) continue ;;
        esac
        printf '%s:%s:%s\n' "$sweep_f" "$sweep_lineno" "$sweep_content" >>"$out_file"
      done <"$sweep_matches_file"
    fi
    IFS='
'
  done
  IFS="$sweep_old_ifs"
}

SWEEP_HITS_FILE="${WORK}/sweep_hits.txt"
_sweep_dir_for_tr_d_bug "$REPO_ROOT_REAL" "$SWEEP_HITS_FILE" "$EXCLUDE_HELPER" "$EXCLUDE_SELF"

if [ -s "$SWEEP_HITS_FILE" ]; then
  bad "${LABEL} — repo sweep: raw newline-fusing 'tr -d' shape found outside the shared helper"
  while IFS= read -r hit; do
    printf '    %s\n' "$hit" >&2
  done <"$SWEEP_HITS_FILE"
else
  ok "${LABEL} — repo sweep: no raw newline-fusing 'tr -d' shape found outside the shared helper (dev/lib/gnu_time_rss.sh)"
fi

# ---------------------------------------------------------------------------
# Assertion 7: pins that the SWEEP DETECTOR ITSELF still works, against a
# disposable fixture directory rather than only the (always-clean) live
# repo -- closing the gap NEEDS_REWORK review on PR #2580 (CP2/CP4)
# identified: a pass against the repo alone carries no information about
# whether the detector still catches the bug shape, since re-scoping the
# grep to a specific variable name or a no-op regex both left the repo
# sweep green.
#
# Fixture contains:
#   (a) a bug-shaped file using an ARBITRARY variable name (deliberately
#       containing no substring of "rss_path" or "rss" at all, so a
#       narrowing mutation that re-scopes the regex to those names would
#       miss it) -- must be DETECTED.
#   (b) a `tail -n 1`-reduced safe file, same idiom as the shared helper
#       -- must NOT be detected.
# ---------------------------------------------------------------------------
FIXTURE7="${WORK}/fixture7"
mkdir -p "$FIXTURE7"

BUG7="${FIXTURE7}/bug_arbitrary_name.sh"
cat >"$BUG7" <<'EOF'
#!/bin/sh
my_totally_unrelated_metric=$(tr -d '\n' <"$whatever_file")
EOF

SAFE7="${FIXTURE7}/safe_reduced.sh"
cat >"$SAFE7" <<'EOF'
#!/bin/sh
rss_value=$(tail -n 1 "$rss_path" | tr -d '\n')
EOF

FIXTURE7_HITS="${WORK}/fixture7_hits.txt"
_sweep_dir_for_tr_d_bug "$FIXTURE7" "$FIXTURE7_HITS"

if grep -q 'bug_arbitrary_name\.sh' "$FIXTURE7_HITS" 2>/dev/null \
  && ! grep -q 'safe_reduced\.sh' "$FIXTURE7_HITS" 2>/dev/null; then
  ok "${LABEL} — fixture sweep: arbitrary-name bug detected, tail-reduced safe file not flagged"
else
  bad "${LABEL} — fixture sweep: expected only bug_arbitrary_name.sh flagged; got: $(cat "$FIXTURE7_HITS" 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
# Assertion 8: pins the documented co-occurrence false negative (KNOWN
# RESIDUAL above) as a measured suite result instead of an unverified prose
# claim. A line where `tail -n 1` and `tr -d '\n'` both appear for UNRELATED
# reasons (two semicolon-separated statements) is waved through today --
# the "safe shape" check is co-occurrence, not causal precedence. This
# assertion does not fix that gap; it measures it, so a future fix to the
# detection logic has to update this assertion (and the residual comment
# above) rather than leaving them silently wrong.
# ---------------------------------------------------------------------------
FIXTURE8="${WORK}/fixture8"
mkdir -p "$FIXTURE8"

COOCCUR8="${FIXTURE8}/cooccurrence_false_negative.sh"
cat >"$COOCCUR8" <<'EOF'
#!/bin/sh
last_log=$(tail -n 1 /var/log/x); rss_value=$(tr -d '\n' <"$rss_path")
EOF

FIXTURE8_HITS="${WORK}/fixture8_hits.txt"
_sweep_dir_for_tr_d_bug "$FIXTURE8" "$FIXTURE8_HITS"

if [ ! -s "$FIXTURE8_HITS" ]; then
  ok "${LABEL} — fixture sweep: documented co-occurrence false negative reproduces (unrelated-statement line waved through, as KNOWN RESIDUAL above describes)"
else
  bad "${LABEL} — fixture sweep: expected the co-occurrence false negative to reproduce (waved through); got a hit instead -- KNOWN RESIDUAL comment above is now stale, update it"
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo "OK: ${LABEL} -- all assertions passed."
