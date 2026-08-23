#!/bin/sh
# goldens_affected_check.sh — PR-time detector for a config-default change
# that only a postsubmit golden would notice (issue #2393).
#
# WHY THIS EXISTS
#
#   PR #2384 flipped `entry_order_max_rest_weeks` 0 -> 26 with green CI.
#   The one golden that change actually moved
#   (sp500-2019-2023-armed-stoplimit.sexp, -38.42pp) lives under
#   goldens-sp500/, which is exercised only by the postsubmit workflow
#   `.github/workflows/golden-runs-sp500-5y.yml`
#   (`on: push: branches: [main]`) — never on the PR itself, and that
#   workflow runs with `continue-on-error: true` during soak. A regression
#   that size could merge on fully green PR checks. See issue #2393 and
#   `dev/experiments/clock26-golden-ab-2026-08-19/`.
#
#   This script closes the detection gap mechanically: it finds config-
#   default changes in the PR diff, extracts the knob names, and checks
#   whether any golden spec that a `golden-runs-*.yml` postsubmit workflow
#   actually runs arms that knob (i.e. sets it away from its old-behaviour
#   value via `config_overrides`). If none do, the change is provably
#   invisible to every golden in the suite and the check is free. If one
#   does, this is exactly the blast-DEPTH gap #2384 fell into, and the
#   check FAILs with a pointer to the manual paired-run requirement in
#   `.claude/rules/config-default-blast-radius.md` — that rule's step (b)
#   is what actually re-derives the missing signal; this script's job is
#   only to say WHEN that step is required, not to run it.
#
#   Deliberately NOT auto-running the golden here: the 5y sp500 goldens
#   take tens of minutes each (see golden-runs-sp500-5y.yml's own runtime
#   comments) — too slow for a PR gate. A fast, deterministic FAIL-with-list
#   turns a silent gap into a blocking signal without that cost; see the
#   header comment in goldens-affected.yml for the option-3-vs-2 tradeoff.
#
# WHAT IT SCANS
#
#   Config-default surface (Step 1) — the files a config default can
#   change in today:
#     trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml
#     trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli
#     dev/weekly-picks/live-config-overrides.sexp
#   A file in this list that doesn't exist at the current revision is
#   skipped, not a FAIL (keeps this script forward-compatible with a
#   future rename/move of the config module).
#
#   Knob extraction (Step 2) — only ADDED/REMOVED diff lines count (a
#   context line is not a change):
#     .ml / .mli  — a changed line containing "[@sexp.default" carries the
#                   field name as the identifier immediately before ":".
#     live-config-overrides.sexp — a changed line shaped "((<knob> ...)"
#                   carries the field name as the identifier immediately
#                   after "((". Nested config records (e.g.
#                   "((portfolio_config ((max_position_pct_long 0.14))))")
#                   are only matched at the OUTER identifier
#                   (`portfolio_config`) — a change to only the nested
#                   field wouldn't touch the outer line's text and so
#                   would be a false negative for the nested name itself;
#                   accepted as a known gap, not a defect, because the
#                   outer name is exactly what a golden's
#                   `config_overrides` entry keys on (see the fixture
#                   sexp above: `((portfolio_config (...)))` is one
#                   overrides entry).
#
#   Docstring cross-reference (Step 2.5, best-effort) — a straight
#   "does the golden's config_overrides literally mention the changed
#   identifier" check is structurally blind to the ACTUAL #2384 shape: a
#   golden that changes behaviour by inheriting the new DEFAULT never
#   overrides the knob at all, so its text never contains the name (see
#   sp500-2019-2023-armed-stoplimit.sexp — verified 2026-08-22 against
#   the real 5c278bb78 diff: it names `enable_sim_entry_stoplimit`, never
#   `entry_order_max_rest_weeks`, and a literal-name-only version of this
#   check reports OK against that exact regression). The codebase's own
#   .mli docstring convention closes most of that gap for free: a field's
#   doc comment cross-references related fields via `[bracket_citation]`
#   syntax pervasively (`weinstein_strategy_config.mli` uses this
#   hundreds of times), and `entry_order_max_rest_weeks`'s own docstring
#   literally says "[enable_sim_entry_stoplimit] (the only place a clock
#   can bite ...)". So for every DIRECTLY changed knob found in Step 2,
#   this step also extracts every `[identifier]` citation inside that
#   knob's docstring block (from its field-declaration line up to the
#   next field declaration, read from the .mli at HEAD_REF) and treats
#   each cited identifier as a RELATED knob — searched in Step 4 exactly
#   like a direct one, just labeled "related-via:<original knob>" in the
#   FAIL output. This is a heuristic, not a proof: citations exist for
#   reasons other than "this knob gates my effect" (mutual-exclusion
#   notes, "see also" pointers), so it can over-match. That is the
#   correct bias for a gate whose failure mode on a MISS is a silent
#   regression (#2384) and whose failure mode on a false positive is one
#   extra manual paired run — cheap and mechanical, not a re-review.
#
#   Golden discovery (Step 3) — every `.github/workflows/golden-runs-*.yml`
#   file's `GOLDEN_SP500_SUBDIRS:` value names the
#   trading/test_data/backtest_scenarios/<subdir>/ directories that
#   workflow's postsubmit run scans (falls back to
#   "goldens-sp500 goldens-sp500-historical" — dev/scripts/
#   golden_sp500_postsubmit.sh's own default — for a workflow file with no
#   explicit override). Every *.sexp file under each discovered subdir is
#   grepped (whole-word) for each knob name from Steps 2 + 2.5.
#
# DECISION
#
#   Zero (knob, golden-spec) matches -> OK, exit 0. This is the expected
#   result for the overwhelming majority of PRs (26 of 27 goldens were
#   structurally unaffected by #2384 — this script exists for the 27th).
#   Any match -> FAIL, exit 1, listing every match and pointing at the
#   manual paired-run requirement.
#
# KNOWN LIMITATION
#
#   Step 2.5 relies on the changed knob's docstring actually citing its
#   gating knob(s) in `[bracket]` form. A knob whose coupling to another
#   knob is undocumented, or documented in prose without the bracket
#   convention, is still a false negative here — the mechanical signal
#   is only as good as the docstring. `.claude/rules/
#   config-default-blast-radius.md`'s manual step is the backstop for
#   exactly that residual: it asks the PR author to read the knob's own
#   docstring and reason about gating relationships, not just grep for
#   the name.
#
# USAGE
#
#   sh goldens_affected_check.sh <base-ref> <head-ref>
#
#   <base-ref> / <head-ref> are anything `git diff` accepts (SHAs, branch
#   names). <base-ref> should be the PR's MERGE-BASE with main, not main's
#   moving tip — resolving that is the caller's job (see
#   goldens-affected.yml, which computes it via `git merge-base`).
#
# Exit status: 0 = no signal / not applicable. 1 = at least one affected
# golden found, OR usage/environment error (missing git, not a git repo,
# unresolvable refs).

set -eu

. "$(dirname "$0")/_check_lib.sh"

if [ $# -ne 2 ]; then
  echo "Usage: goldens_affected_check.sh <base-ref> <head-ref>" >&2
  exit 1
fi

BASE_REF="$1"
HEAD_REF="$2"

REPO_ROOT="$(repo_root)"
cd "$REPO_ROOT"

if ! command -v git >/dev/null 2>&1; then
  echo "FAIL: goldens_affected_check: git not found on PATH" >&2
  exit 1
fi

# --- Step 1: config-default surface files present at this revision ---

SURFACE_ML="trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml"
SURFACE_MLI="trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli"
SURFACE_OVERRIDES="dev/weekly-picks/live-config-overrides.sexp"

SEXP_DEFAULT_FILES=""
for f in "$SURFACE_ML" "$SURFACE_MLI"; do
  [ -f "$f" ] && SEXP_DEFAULT_FILES="$SEXP_DEFAULT_FILES $f"
done
OVERRIDES_FILE=""
[ -f "$SURFACE_OVERRIDES" ] && OVERRIDES_FILE="$SURFACE_OVERRIDES"

if [ -z "$SEXP_DEFAULT_FILES" ] && [ -z "$OVERRIDES_FILE" ]; then
  echo "OK: goldens_affected_check -- no known config-default surface file exists at this revision (nothing to scan)."
  exit 0
fi

# --- Step 2: extract changed knob names ---

DIRECT_KNOBS_FILE="$(mktemp)"
RELATED_KNOBS_FILE="$(mktemp)"
KNOBS_FILE="$(mktemp)"
MLI_HEAD_CONTENT="$(mktemp)"
trap 'rm -f "$DIRECT_KNOBS_FILE" "$RELATED_KNOBS_FILE" "$KNOBS_FILE" "$MLI_HEAD_CONTENT"' EXIT

# _changed_body_lines <ref> <ref> <files...>
# Prints the text (post "+"/"-" marker stripped) of every ADDED/REMOVED
# line in `git diff -U0`, excluding the "+++"/"---" file-header lines.
_changed_body_lines() {
  base="$1"
  head="$2"
  shift 2
  # shellcheck disable=SC2068 -- $@ (the remaining file paths) must word-split
  git diff -U0 --no-color "$base" "$head" -- $@ 2>/dev/null \
    | grep -E '^[+-][^+-]' | cut -c2- || true
}

# DIRECT_KNOBS_FILE: field names changed via [@sexp.default (Step 1's
# SEXP_DEFAULT_FILES). Kept separate from the overrides-file extraction
# below because ONLY these have a docstring for Step 2.5 to read.
if [ -n "$SEXP_DEFAULT_FILES" ]; then
  # shellcheck disable=SC2086 -- SEXP_DEFAULT_FILES is a space-separated path list
  _changed_body_lines "$BASE_REF" "$HEAD_REF" $SEXP_DEFAULT_FILES \
    | grep -F '[@sexp.default' \
    | sed -n 's/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*:.*$/\1/p' \
    >> "$DIRECT_KNOBS_FILE" || true
fi

if [ -n "$OVERRIDES_FILE" ]; then
  _changed_body_lines "$BASE_REF" "$HEAD_REF" "$OVERRIDES_FILE" \
    | sed -n 's/^[[:space:]]*((\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]].*$/\1/p' \
    >> "$DIRECT_KNOBS_FILE" || true
fi

sort -u "$DIRECT_KNOBS_FILE" -o "$DIRECT_KNOBS_FILE"

if [ ! -s "$DIRECT_KNOBS_FILE" ]; then
  echo "OK: goldens_affected_check -- config-default surface file(s) changed, but no [@sexp.default value / override knob was added or removed ($BASE_REF..$HEAD_REF)."
  exit 0
fi

# --- Step 2.5: docstring cross-references for each DIRECT knob (best-effort) ---
# See the header comment "Docstring cross-reference (Step 2.5, ...)" for why
# this exists: a literal-name-only check is blind to the actual #2384 shape.
# Reads the .mli at HEAD_REF (docstrings there, not in the base revision --
# we want the CURRENT documented relationship) if that file exists there.

if [ -f "$SURFACE_MLI" ]; then
  git show "${HEAD_REF}:${SURFACE_MLI}" > "$MLI_HEAD_CONTENT" 2>/dev/null || : > "$MLI_HEAD_CONTENT"
else
  : > "$MLI_HEAD_CONTENT"
fi

# _docstring_related_knobs <target-knob>
# Prints every OTHER identifier cited as "[identifier]" inside <target-
# knob>'s docstring block in MLI_HEAD_CONTENT -- from its own field-
# declaration line up to (not including) the next field declaration.
_docstring_related_knobs() {
  target="$1"
  # NOTE: the field-declaration anchor below requires EXACTLY two leading
  # spaces ("^  ", not "^[ \t]*") -- this repo's config record fields are
  # consistently indented two spaces (verified: 78/78 real fields in
  # weinstein_strategy_config.mli), while docstring PROSE inside a "(**
  # ... *)" comment is indented four spaces or deeper. Prose routinely
  # contains "Word: text" shapes (e.g. "Motivation: in a fast V-crash
  # ...", "bug: a ticket placed on review week N ...") that satisfy a
  # looser "identifier followed by colon" pattern and would falsely end
  # the block mid-docstring -- confirmed against the real
  # entry_order_max_rest_weeks docstring, which is long enough (~90
  # lines) to contain several such false decls before its genuine
  # [enable_sim_entry_stoplimit] citation.
  awk -v target="$target" '
    {
      line = $0
      is_decl = (line ~ /^  [A-Za-z_][A-Za-z0-9_]*[ \t]*:[ \t]*[A-Za-z(]/)
      if (is_decl) {
        fname = line
        sub(/^[ \t]*/, "", fname)
        sub(/[ \t]*:.*/, "", fname)
        in_block = (fname == target) ? 1 : 0
      }
      if (in_block) print line
    }
  ' "$MLI_HEAD_CONTENT" \
    | grep -oE '\[[a-z][a-z0-9]*(_[a-z0-9]+)+\]' \
    | tr -d '[]' \
    | grep -v -x -- "$target" || true
}

if [ -s "$MLI_HEAD_CONTENT" ]; then
  while IFS= read -r knob; do
    [ -n "$knob" ] || continue
    _docstring_related_knobs "$knob" | while IFS= read -r related; do
      [ -n "$related" ] || continue
      printf '%s\trelated-via:%s\n' "$related" "$knob" >> "$RELATED_KNOBS_FILE"
    done
  done < "$DIRECT_KNOBS_FILE"
fi

# --- Merge: KNOBS_FILE is "<knob><TAB><reason>", deduped ---

while IFS= read -r knob; do
  [ -n "$knob" ] || continue
  printf '%s\tdirect\n' "$knob" >> "$KNOBS_FILE"
done < "$DIRECT_KNOBS_FILE"
cat "$RELATED_KNOBS_FILE" >> "$KNOBS_FILE"
sort -u "$KNOBS_FILE" -o "$KNOBS_FILE"

# --- Step 3: discover golden spec directories from golden-runs-*.yml ---

WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"
SUBDIRS_FILE="$(mktemp)"
trap 'rm -f "$DIRECT_KNOBS_FILE" "$RELATED_KNOBS_FILE" "$KNOBS_FILE" "$MLI_HEAD_CONTENT" "$SUBDIRS_FILE"' EXIT

WORKFLOW_MATCHED=0
for wf in "$WORKFLOWS_DIR"/golden-runs-*.yml; do
  [ -f "$wf" ] || continue
  WORKFLOW_MATCHED=1
  val="$(sed -n 's/^[[:space:]]*GOLDEN_SP500_SUBDIRS:[[:space:]]*//p' "$wf" | head -1 | tr -d '"')"
  if [ -z "$val" ]; then
    # golden_sp500_postsubmit.sh's own default when a workflow doesn't
    # override the env var.
    val="goldens-sp500 goldens-sp500-historical"
  fi
  printf '%s\n' $val
done >> "$SUBDIRS_FILE"

if [ "$WORKFLOW_MATCHED" -eq 0 ]; then
  echo "OK: goldens_affected_check -- no .github/workflows/golden-runs-*.yml found; nothing to check against."
  exit 0
fi

sort -u "$SUBDIRS_FILE" -o "$SUBDIRS_FILE"

# --- Step 4: cross-reference: does any golden spec arm a changed knob? ---

SCENARIO_ROOT="${REPO_ROOT}/trading/test_data/backtest_scenarios"
MATCHES=""
MATCH_COUNT=0
TAB="$(printf '\t')"

while IFS="$TAB" read -r knob reason; do
  [ -n "$knob" ] || continue
  while IFS= read -r subdir; do
    [ -n "$subdir" ] || continue
    dir="${SCENARIO_ROOT}/${subdir}"
    [ -d "$dir" ] || continue
    for spec in "$dir"/*.sexp; do
      [ -f "$spec" ] || continue
      if grep -q -w -- "$knob" "$spec" 2>/dev/null; then
        rel="${spec#"${REPO_ROOT}"/}"
        case "$reason" in
          direct)
            MATCHES="${MATCHES}  knob '${knob}' is armed by ${rel}\n"
            ;;
          *)
            MATCHES="${MATCHES}  knob '${knob}' is armed by ${rel} (${reason} -- docstring cross-reference, best-effort)\n"
            ;;
        esac
        MATCH_COUNT=$((MATCH_COUNT + 1))
      fi
    done
  done < "$SUBDIRS_FILE"
done < "$KNOBS_FILE"

if [ "$MATCH_COUNT" -eq 0 ]; then
  echo "OK: goldens_affected_check -- $(wc -l < "$KNOBS_FILE" | tr -d ' ') changed/related knob(s), zero postsubmit golden specs arm any of them."
  exit 0
fi

echo "FAIL: goldens_affected_check -- this PR changes a config default that a POSTSUBMIT-ONLY golden arms."
echo ""
printf '%b' "$MATCHES"
echo ""
echo "These goldens run only on push to main (golden-runs-*.yml), not on this PR,"
echo "so CI green here gives no signal about them. Per"
echo ".claude/rules/config-default-blast-radius.md, run each affected golden by"
echo "hand, PAIRED (base vs this PR, one-line spec diff), and paste the paired"
echo "table in the PR body before merging. See issue #2393 / PR #2384"
echo "(-38.42pp merged on green CI) for why this is a hard requirement, not"
echo "a suggestion."
exit 1
