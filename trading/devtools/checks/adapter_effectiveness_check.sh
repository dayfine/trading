#!/bin/sh
# adapter_effectiveness_check.sh — mechanical guard for the "silent-null
# config thread" defect class (issue #2567).
#
# WHY THIS EXISTS
#
#   A Weinstein_strategy.config field is threaded into a sub-config
#   (Rs.config, Volume.config, Screener.config, ...) by a line shaped
#   exactly like "field = config.field2" inside some function's record
#   construction. If that thread is severed (e.g. accidentally, or by
#   a refactor that hardcodes the sub-config's own default instead of
#   reading the strategy field), the WHOLE TEST SUITE can stay green --
#   nothing asserts that severing changes behaviour. The failure mode
#   is a SILENT NULL: an armed axis sweep then measures the baseline,
#   and the experiment ledger records a REJECT for a mechanism that
#   never ran. Per .claude/rules/experiment-flag-discipline.md Rule 4,
#   a terminal REJECT can get the "rejected" mechanism's code deleted --
#   so this defect class can delete working code on false evidence.
#
#   Three prior instances before this check existed: Volume.config
#   (#2459), the rt anchor knob (project_rt_needs_its_anchor_knob), and
#   enable_rs_positive_declining -> Rs.config.enable_positive_declining
#   (#2563, caught only because a reviewer hand-wrote a severing
#   mutation during review -- not by anything mechanical). See
#   dev/plans/silent-null-effectiveness-2026-08-28.md for the full
#   census (15 distinct fields, 17 occurrence sites, across 6 files) and
#   the decision to build a linter rather than rely on a convention.
#
# WHAT IT SCANS
#
#   Every *.ml file under the two domain roots where this defect class
#   lives (trading/trading/weinstein, trading/analysis/weinstein),
#   EXCLUDING */test/* and */bin/* (a field copy in a test fixture or a
#   one-off binary is not a production thread anyone relies on).
#
#   Deliberately NOT restricted to functions named "*_config_for" --
#   the census found the exact same shape inside a function named
#   "_run_screener" (Screener.neutral_blocks_longs = config.
#   neutral_blocks_longs, in weinstein_strategy_screening.ml). A
#   name-keyed trigger would have a false-negative gap on the CURRENT
#   tree, not just a hypothetical future one. The trigger is the SHAPE
#   of a field-copy line, not which function it lives in:
#
#     ^\s*<module-prefix>?<field>\s*=\s*config\.<field2>\s*;?\s*$
#
#   i.e. a record field (optionally "Module.field") assigned verbatim
#   from a bare "config.<identifier>" access, with nothing else on the
#   line. This intentionally does NOT catch:
#     - a DERIVED or CONDITIONAL thread (e.g. "require_breakout_volume =
#       not (Foo.bar config)", or an "if config.x then ... else ..."
#       branch);
#     - a field-copy whose "field =" and "config.field2" halves are split
#       across TWO LINES by ocamlfmt (confirmed on main: "Screener.
#       enable_slow_grind_short_gate =\n        config.
#       enable_slow_grind_short_gate;" in weinstein_strategy_screening.ml
#       -- this occurrence is invisible to the check entirely, not even
#       counted, which is why it does not appear in
#       adapter_effectiveness_exceptions.conf as an active entry either);
#     - R-3 (dev/reviews/harness-2567-2585.md, 2026-08-28, recorded
#       non-blocking): a narrowed DOMAIN_ROOTS. If DOMAIN_ROOTS below is
#       ever edited to a narrower scope than the two domain roots it
#       currently lists, fields outside the new scope silently drop out
#       of the audit -- the self-test's fixtures live under
#       trading/trading/weinstein/strategy/lib, so a narrowing to just
#       that subtree keeps the self-test green while the real tree's
#       coverage shrinks. Inherent to any allowlist-scoped linter; a
#       future hardening could assert a minimum found-field count
#       against the live tree. Not attempted here -- out of scope for
#       this PR.
#   All three are known, documented residuals (see the plan's "Risks"
#   section), same class of gap goldens_affected_check.sh's own header
#   documents for its [@sexp.default] scan.
#
# WHAT IT DEMANDS
#
#   For every unique field2 (the SOURCE field on the left-hand config)
#   found by the scan above, one of:
#
#     (a) a line "EFFECTIVENESS-PIN: <field2>" (a plain OCaml comment,
#         anywhere on the line) in some */test/*.ml file, anywhere in
#         the repo. This is the mechanical join key from "this field is
#         threaded somewhere" to "here is the test that proves the
#         thread live" -- see the plan for why a field-name key was
#         chosen over the issue's literal "#<issue>:" suggestion (an
#         issue number identifies WHY a pin was added, not WHICH field
#         it covers, and a field can accumulate pins across several
#         issues over time).
#
#     (b) an entry in adapter_effectiveness_exceptions.conf naming
#         <field2>, with a mandatory "# review_at: <value>" annotation
#         (same convention as universe_deps_exceptions.conf /
#         linter_exceptions.conf) -- the grandfather path for fields
#         this repo has not yet retrofitted a pin for.
#
#   A field satisfying neither is a FAIL, naming the field and the
#   adapter file:line it was found at.
#
#   NOTE: presence of an EFFECTIVENESS-PIN tag proves a human claimed
#   the thread is tested, not that the referenced test is actually
#   adequate -- the same trust model goldens_affected_check.sh's
#   "paired-run-done" label already uses for a different claim. QC
#   review is still the layer that judges whether a given pin's test
#   really exercises the real adapter and asserts a distinguishing
#   value.
#
# USAGE
#
#   sh adapter_effectiveness_check.sh
#
#   No arguments; always scans the current, real repo tree (via
#   repo_root()) unless REPO_ROOT is overridden (test-only plumbing,
#   see adapter_effectiveness_check_test.sh).
#
# Exit status: 0 = every found field-copy pair is pinned or excepted.
#              1 = at least one unpinned field, or a malformed
#                  exceptions entry.

set -eu

. "$(dirname "$0")/_check_lib.sh"

REPO_ROOT="$(repo_root)"
cd "$REPO_ROOT"

CHECKS_DIR="trading/devtools/checks"
EXCEPTIONS_FILE="${CHECKS_DIR}/adapter_effectiveness_exceptions.conf"

DOMAIN_ROOTS="trading/trading/weinstein trading/analysis/weinstein"

# --- Step 1: scan the domain roots for field-copy lines ---
#
# shellcheck disable=SC2086 -- DOMAIN_ROOTS is a space-separated path list
# H-EXCLUDE-SUFFIX-NOT-SUBSTRING: exclude by directory PATH COMPONENT
# ("/test/" or "/bin/"), not by filename substring -- a file legitimately
# named e.g. "resistance_bin_search.ml" must still be scanned.
CANDIDATE_FILES=$(find $DOMAIN_ROOTS -name '*.ml' -type f 2>/dev/null \
  | grep -v '/test/' | grep -v '/bin/' || true)

MATCHES_FILE="$(mktemp)"
trap 'rm -f "$MATCHES_FILE"' EXIT
: > "$MATCHES_FILE"

for f in $CANDIDATE_FILES; do
  grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_.]*[[:space:]]*=[[:space:]]*config\.[a-z][A-Za-z0-9_]*[[:space:]]*;?[[:space:]]*$' \
    "$f" 2>/dev/null | while IFS=: read -r lineno rest; do
    field2="$(printf '%s\n' "$rest" | sed -n 's/.*=[[:space:]]*config\.\([a-z][A-Za-z0-9_]*\)[[:space:]]*;\{0,1\}[[:space:]]*$/\1/p')"
    [ -n "$field2" ] || continue
    printf '%s\t%s\t%s\n' "$field2" "$f" "$lineno" >> "$MATCHES_FILE"
  done
done

if [ ! -s "$MATCHES_FILE" ]; then
  echo "OK: adapter_effectiveness_check -- no field-copy-into-sub-config lines found under $DOMAIN_ROOTS."
  exit 0
fi

# --- Step 2: load the exceptions file (field name -> review_at) ---

EXC_FIELDS_FILE="$(mktemp)"
trap 'rm -f "$MATCHES_FILE" "$EXC_FIELDS_FILE"' EXIT
: > "$EXC_FIELDS_FILE"

BAD_REVIEW_AT=""
if [ -f "$EXCEPTIONS_FILE" ]; then
  while IFS= read -r eline || [ -n "$eline" ]; do
    trimmed="$(printf '%s' "$eline" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$trimmed" in
      "" | "#"*) continue ;;
    esac
    review_at=""
    case "$trimmed" in
      *"# review_at:"*)
        review_at="$(printf '%s\n' "$trimmed" | sed -n 's/.*# review_at:[[:space:]]*//p')"
        ;;
    esac
    field_name="$(printf '%s\n' "$trimmed" | sed 's/[[:space:]]*#.*//' | sed -e 's/[[:space:]]*$//')"
    [ -n "$field_name" ] || continue

    valid=0
    case "$review_at" in
      never*) valid=1 ;;
      M[1-7]*) valid=1 ;;
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*) valid=1 ;;
    esac
    if [ "$valid" -ne 1 ]; then
      BAD_REVIEW_AT="${BAD_REVIEW_AT}  ${field_name}\n"
      continue
    fi
    printf '%s\n' "$field_name" >> "$EXC_FIELDS_FILE"
  done < "$EXCEPTIONS_FILE"
fi

if [ -n "$BAD_REVIEW_AT" ]; then
  echo "FAIL: adapter_effectiveness_check -- exceptions entries with no parseable \"# review_at: <value>\" annotation:"
  printf '%b' "$BAD_REVIEW_AT"
  echo "An exception with no review_at silently disables this guard for that field forever; see .claude/rules/code-health-discipline.md."
  exit 1
fi

# --- Step 2.5: build the set of pinned field names, once ---
#
# H-ADAPTER-PIN-LINEWRAP: ocamlformat reflows odoc comments at its line-
# width limit, and it does NOT keep "EFFECTIVENESS-PIN:" and the field
# name that follows it on the same physical line (confirmed on this
# check's own first real run: "... catches. EFFECTIVENESS-PIN:\n
# virgin_crossing_readmission -- same mechanism ..." in
# test_stock_analysis_config_wiring.ml). A plain line-based `grep -E`
# would silently miss that pin. Each test file's content is joined into
# one line (newlines -> spaces) before the pin-tag search, so the tag and
# the field name are always on the same "line" from grep's point of view,
# regardless of where ocamlformat wraps the surrounding prose.
PINNED_FIELDS_FILE="$(mktemp)"
trap 'rm -f "$MATCHES_FILE" "$EXC_FIELDS_FILE" "$PINNED_FIELDS_FILE"' EXIT
: > "$PINNED_FIELDS_FILE"

# Scan under the single top-level "trading/" dune-workspace root (which
# already contains both the trading/trading/ and trading/analysis/
# subtrees -- there is no separate top-level "analysis/" directory), and
# explicitly prune trading/_build/ -- the sandbox mirror under there can
# contain non-UTF8 / stale-copy artifacts that trip `grep` binary-file
# detection and are never real source anyway.
TEST_ML_FILES=$(find trading -path '*/_build/*' -prune -o -path '*/test/*.ml' -type f -print 2>/dev/null || true)
for tf in $TEST_ML_FILES; do
  tr '\n' ' ' < "$tf" 2>/dev/null \
    | grep -a -oE 'EFFECTIVENESS-PIN:[[:space:]]*[a-z][A-Za-z0-9_]*' \
    | sed -E 's/EFFECTIVENESS-PIN:[[:space:]]*//'
done >> "$PINNED_FIELDS_FILE"
sort -u "$PINNED_FIELDS_FILE" -o "$PINNED_FIELDS_FILE"

# --- Step 3: for each unique field, require a pin or an exception ---

TAB="$(printf '\t')"
UNPINNED=""
FAIL_COUNT=0

for field2 in $(cut -f1 "$MATCHES_FILE" | sort -u); do
  if [ -s "$EXC_FIELDS_FILE" ] && grep -q -x -- "$field2" "$EXC_FIELDS_FILE"; then
    echo "SKIP (exceptions list): $field2"
    continue
  fi

  # A pin is a plain-text tag "EFFECTIVENESS-PIN: <field2>" anywhere in
  # any */test/*.ml file, repo-wide -- exact field-name match (via
  # PINNED_FIELDS_FILE, built above) so e.g.
  # "enable_rs_positive_declining" doesn't accidentally satisfy a search
  # for "positive_declining".
  PIN_FOUND=0
  if [ -s "$PINNED_FIELDS_FILE" ] && grep -q -x -- "$field2" "$PINNED_FIELDS_FILE"; then
    PIN_FOUND=1
  fi

  if [ "$PIN_FOUND" -eq 1 ]; then
    echo "OK: $field2 -- EFFECTIVENESS-PIN found in a test file"
    continue
  fi

  SITES="$(awk -F"$TAB" -v f="$field2" '$1==f {print "    " $2 ":" $3}' "$MATCHES_FILE")"
  UNPINNED="${UNPINNED}  '${field2}':\n${SITES}\n"
  FAIL_COUNT=$((FAIL_COUNT + 1))
done

if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "OK: adapter_effectiveness_check -- every field-copy-into-sub-config field is pinned or excepted."
  exit 0
fi

echo "FAIL: adapter_effectiveness_check -- ${FAIL_COUNT} field(s) copied into a sub-config with no EFFECTIVENESS-PIN test and no exceptions entry:"
echo ""
printf '%b' "$UNPINNED"
echo "Each field above is threaded from a Weinstein_strategy.config (or an"
echo "intermediate sub-config) field into another config record via a bare"
echo "'field = config.field2' copy. Per issue #2567 / dev/plans/silent-null-"
echo "effectiveness-2026-08-28.md, an untested thread like this can be silently"
echo "severed while the whole suite stays green, producing a false REJECT in the"
echo "experiment ledger for a mechanism that never ran. Either:"
echo "  (a) add a test that sets the STRATEGY-level field, routes through the"
echo "      real adapter, and asserts a distinguishing value on the built"
echo "      sub-config -- then tag it with a comment"
echo "      \"(* EFFECTIVENESS-PIN: <field2> *)\" in that test file; or"
echo "  (b) add the field to adapter_effectiveness_exceptions.conf with a"
echo "      mandatory \"# review_at: <value>\" annotation, if this is a"
echo "      pre-existing thread being grandfathered rather than retrofitted now."
exit 1
