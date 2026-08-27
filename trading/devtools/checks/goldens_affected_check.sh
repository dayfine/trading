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
#   Config-default surface (Step 1) — everywhere a strategy-config
#   default can change today (issue #2531 closed the file-list gap that
#   let #2530's two flips through green):
#     trading/trading/weinstein/**/lib/*.ml{,i}   — strategy config + the
#         nested config records embedded in it (Weinstein_stops.config,
#         Portfolio_risk.config, Extension_stop.config, ...)
#     trading/analysis/weinstein/**/lib/*.ml{,i}  — the analysis-side
#         embedded configs (Stage, Macro, Screener, Stage3_force_exit,
#         Laggard_rotation, ...)
#     dev/weekly-picks/live-config-overrides.sexp
#   test/ and bin/ directories are deliberately outside the surface
#   (fixture [@sexp.default lines in tests are not defaults anyone
#   inherits). A surface directory that doesn't exist at the current
#   revision is skipped, not a FAIL (keeps this script forward-compatible
#   with a future rename/move of the config tree).
#
#   Knob extraction (Step 2) — only ADDED/REMOVED diff lines count (a
#   context line is not a change):
#     .ml / .mli  — a changed line containing "[@sexp.default" carries the
#                   field name as the identifier immediately before ":".
#     .ml default-record literals (Step 2b) — a REQUIRED field has no
#                   [@sexp.default]; its default lives only in the
#                   module's default value binding (e.g.
#                   `initial_stop_buffer = 1.0;` inside `let
#                   default_config`, weinstein_strategy_config.ml —
#                   the exact #2530/#2531 blind spot). For every changed
#                   surface .ml, the region under any top-level
#                   `let default*` / `let _default*` binding is
#                   extracted at BOTH revisions as `field = value;`
#                   lines, and a field whose line differs (added,
#                   removed, or value changed) counts as a changed knob.
#                   Known residuals: a field whose value spans multiple
#                   lines (no `;` at end-of-line) and a default routed
#                   through a renamed top-level constant
#                   (`let default_foo = 5` feeding field `bar`) are
#                   still invisible — the manual rule remains the
#                   backstop.
#     nested-config embedding (Step 2c) — when a changed knob comes from
#                   a file that defines a config record EMBEDDED in the
#                   strategy config (stops, portfolio_risk, stage, macro,
#                   screener, ...), the OUTER strategy-config field name
#                   (`stops_config`, `portfolio_config`, ...) is also
#                   emitted as a related knob, because a golden's
#                   config_overrides keys on the outer name and inherits
#                   the inner default silently — the historical #2530
#                   shape (armed-stoplimit armed `stops_config` while
#                   `reset_anchor_on_stalled_cycle` flipped underneath).
#                   The file→field map is maintained by hand in
#                   `_embedding_field`.
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
#   Inheritance widening for VALUE CHANGES (Step 4b, issues #2558/#2570) —
#   Step 4's name-matching answers "does any golden mention this knob",
#   which is backwards for a knob whose default VALUE changed (as opposed
#   to a brand-new field, which no golden could have referenced before):
#     - zero goldens mention it -> Step 4 says OK, but that is the MAXIMAL
#       radius, not the minimal one: every golden silently inherits the
#       new value (#2558 — a `lookback_bars` 52->56 default flip produced
#       12 grep hits, all for the unrelated `resistance_lookback_bars`,
#       and zero for the changed knob itself).
#     - a golden overrides the knob AT THE NEW VALUE already (it ran that
#       way before the flip too, so it does not actually change) -> Step 4
#       flags exactly that golden and says nothing about the goldens that
#       never mention the knob, which are the ones whose behaviour DOES
#       change (#2570 — a StopLimit-pair default flip was reported against
#       the one golden that already armed the new value, missing ~15 that
#       silently inherit it).
#   For every knob Step 2/2b determined has a REAL old-AND-new default
#   (never for a newly-added field, whose "old value" is simply "the
#   field did not exist" — nothing can inherit FROM that), Step 4b scans
#   every golden spec under the Step-3-discovered subdirs and treats it as
#   AFFECTED unless it contains the literal substring
#   "(<knob> <new_value>)" — i.e. affected = does not override the knob,
#   OR overrides it at the old value (or any value other than the new
#   one). Zero of the affected set's specs override the knob at all ->
#   "AFFECTS-ALL" wording; some do (just not all, or not at the new
#   value) -> "default-flip" wording. Both feed the same FAIL/MATCH_COUNT
#   path as Step 4, so either shape turns an otherwise-OK verdict into a
#   FAIL.
#
# DECISION
#
#   Zero (knob, golden-spec) matches from Step 4, AND zero AFFECTS-ALL /
#   default-flip findings from Step 4b -> OK, exit 0. This is the expected
#   result for the overwhelming majority of PRs (26 of 27 goldens were
#   structurally unaffected by #2384 — this script exists for the 27th).
#   Any match -> FAIL, exit 1, listing every match and pointing at the
#   manual paired-run requirement -- UNLESS GOLDENS_AFFECTED_ACK=1 is set
#   in the environment, in which case the same match list is printed as
#   an "OK (acknowledged)" pass-with-notice instead. goldens-affected.yml
#   sets that var from the PR's `paired-run-done` label, which a human
#   applies after eyeballing the pasted paired-run table
#   (`.claude/rules/config-default-blast-radius.md`) -- this script never
#   verifies the table itself, only that the label is present.
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

# --- Step 1: config-default surface present at this revision ---

# The whole weinstein config tree, not a hand-picked file pair — issue
# #2531: initial_stop_buffer (default_config record literal) and
# reset_anchor_on_stalled_cycle (stops/lib/stop_types.ml, outside the old
# two-file list) both changed defaults invisibly to the old scan.
SURFACE_DIRS="trading/trading/weinstein trading/analysis/weinstein"
# Step 2.5 (docstring cross-references) still reads the top-level strategy
# config .mli only — that is where the [bracket]-citation convention lives.
SURFACE_MLI="trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli"
SURFACE_OVERRIDES="dev/weekly-picks/live-config-overrides.sexp"

SURFACE_DIR_PRESENT=0
for d in $SURFACE_DIRS; do
  [ -d "$d" ] && SURFACE_DIR_PRESENT=1
done
OVERRIDES_FILE=""
[ -f "$SURFACE_OVERRIDES" ] && OVERRIDES_FILE="$SURFACE_OVERRIDES"

if [ "$SURFACE_DIR_PRESENT" -eq 0 ] && [ -z "$OVERRIDES_FILE" ]; then
  echo "OK: goldens_affected_check -- no known config-default surface file exists at this revision (nothing to scan)."
  exit 0
fi

# --- Step 2: extract changed knob names ---

DIRECT_KNOBS_FILE="$(mktemp)"
RELATED_KNOBS_FILE="$(mktemp)"
KNOBS_FILE="$(mktemp)"
MLI_HEAD_CONTENT="$(mktemp)"
VALUECHANGE_KNOBS_FILE="$(mktemp)"
trap 'rm -f "$DIRECT_KNOBS_FILE" "$RELATED_KNOBS_FILE" "$KNOBS_FILE" "$MLI_HEAD_CONTENT" "$VALUECHANGE_KNOBS_FILE"' EXIT

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

# _sexp_default_value_in_file <ref> <file> <field>
# Prints the VALUE inside a "<field> : ...; [@sexp.default VALUE]"
# annotation for <field>, read from the WHOLE file content of <file> at
# <ref> (a plain `git show`, not a diff) -- Step 4b needs the field's
# value at a specific revision regardless of whether the changed line and
# the value-bearing line are the same line in the diff. Empty if the
# field, its default, or the file itself doesn't exist at that revision --
# e.g. a brand-new field has no value at BASE_REF, which is exactly how
# Step 4b tells "added" (skip inheritance widening) apart from "value
# changed" (apply it).
_sexp_default_value_in_file() {
  ref="$1"
  file="$2"
  field="$3"
  git show "${ref}:${file}" 2>/dev/null | sed -n \
    "s/^[[:space:]]*${field}[[:space:]]*:.*\[@sexp\.default[[:space:]]*\([^]]*\)\].*\$/\1/p" \
    | head -1 \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Changed config files: every changed lib .ml/.mli under the surface
# dirs. The /lib/ filter keeps test fixtures and bin mains out of the
# surface (a [@sexp.default in a test file is not a default anyone
# inherits).
CHANGED_CONFIG_FILES=""
if [ "$SURFACE_DIR_PRESENT" -eq 1 ]; then
  # shellcheck disable=SC2086 -- SURFACE_DIRS is a space-separated path list
  CHANGED_CONFIG_FILES="$(git diff --name-only "$BASE_REF" "$HEAD_REF" -- $SURFACE_DIRS 2>/dev/null \
    | grep -E '/lib/[^/]+\.mli?$' || true)"
fi

# --- Step 2b helpers: default-record-literal extraction + embedding map ---
# A required field's default lives only in the module's default value
# binding (`let default_config = { ...; initial_stop_buffer = 1.0; ... }`).
# Extract every `field = value;` line under any top-level `let default*` /
# `let _default*` binding at BOTH revisions; a field whose line differs is
# a changed knob. See the header's Step 2b notes for the known residuals.

# _default_literal_pairs <ref> <file>
# Prints "<field>\t<field = value;>" for each single-line record field
# inside a top-level default binding of <file> at <ref>. Missing file at
# that ref -> empty (added/removed files are handled by the set diff).
_default_literal_pairs() {
  git show "$1:$2" 2>/dev/null | awk '
    /^let / { in_def = ($0 ~ /^let _?default/) }
    in_def && $0 ~ /^[ \t]+[a-z_][a-z0-9_]* = .*;[ \t]*$/ {
      line = $0
      sub(/^[ \t]+/, "", line)
      name = line
      sub(/[ \t]*=.*/, "", name)
      print name "\t" line
    }
  ' || true
}

# _embedding_field <file>
# The strategy-config field name that EMBEDS the nested config record
# defined in <file> ("" for the top-level strategy config itself, and for
# files that define no embedded config). A golden's config_overrides keys
# on this OUTER name (`((stops_config ((...))))`), so a default change
# inside the nested record affects every golden that arms the outer field
# even though the golden never names the inner knob — the exact
# historical #2530 shape (armed-stoplimit armed `stops_config` while
# `reset_anchor_on_stalled_cycle` flipped underneath it). This map is
# maintained by hand against weinstein_strategy_config.ml's default_config
# literal (each `<field> = <Module>.default_config;` line); a new embedded
# config needs a row here, which the paired test assertion pins for the
# known ones.
_embedding_field() {
  case "$1" in
    trading/trading/weinstein/stops/lib/extension_stop.*) echo "extension_stop_config" ;;
    trading/trading/weinstein/stops/lib/*) echo "stops_config" ;;
    trading/trading/weinstein/portfolio_risk/lib/*) echo "portfolio_config" ;;
    trading/trading/weinstein/strategy/lib/liquidity_config.*) echo "liquidity_config" ;;
    trading/analysis/weinstein/stage/lib/*) echo "stage_config" ;;
    trading/analysis/weinstein/macro/lib/*) echo "macro_config" ;;
    trading/analysis/weinstein/screener/lib/*) echo "screening_config" ;;
    trading/analysis/weinstein/stage3_force_exit/lib/*) echo "stage3_force_exit_config" ;;
    trading/analysis/weinstein/laggard_rotation/lib/*) echo "laggard_rotation_config" ;;
    *) echo "" ;;
  esac
}

LIT_BASE="$(mktemp)"
LIT_HEAD="$(mktemp)"
FILE_KNOBS="$(mktemp)"
LIT_CHANGED_FIELDS="$(mktemp)"
trap 'rm -f "$DIRECT_KNOBS_FILE" "$RELATED_KNOBS_FILE" "$KNOBS_FILE" "$MLI_HEAD_CONTENT" "$VALUECHANGE_KNOBS_FILE" "$LIT_BASE" "$LIT_HEAD" "$FILE_KNOBS" "$LIT_CHANGED_FIELDS"' EXIT

# --- Steps 2 + 2b + 2c, per changed surface file ---
# 2  : field names changed via [@sexp.default lines.
# 2b : field names whose default-record-literal line changed (.ml only).
# 2c : if the file contributed any changed knob AND defines an EMBEDDED
#      config, also emit the embedding strategy-config field as a related
#      knob — goldens key on the outer name, not the inner one.
# Both 2 and 2b also populate VALUECHANGE_KNOBS_FILE ("<knob><TAB><old
# value><TAB><new value>") for Step 4b, but ONLY when a REAL old value
# exists and differs from the new one -- a newly-added field (no old
# value at BASE_REF) is deliberately excluded, since nothing can inherit
# FROM a field that did not exist (see _sexp_default_value_in_file).
for f in $CHANGED_CONFIG_FILES; do
  : > "$FILE_KNOBS"

  SEXP_DEFAULT_FIELDS="$(mktemp)"
  _changed_body_lines "$BASE_REF" "$HEAD_REF" "$f" \
    | grep -F '[@sexp.default' \
    | sed -n 's/^[[:space:]]*\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*:.*$/\1/p' \
    | sort -u > "$SEXP_DEFAULT_FIELDS" || true
  cat "$SEXP_DEFAULT_FIELDS" >> "$FILE_KNOBS"

  while IFS= read -r field; do
    [ -n "$field" ] || continue
    old_val="$(_sexp_default_value_in_file "$BASE_REF" "$f" "$field")"
    new_val="$(_sexp_default_value_in_file "$HEAD_REF" "$f" "$field")"
    if [ -n "$old_val" ] && [ -n "$new_val" ] && [ "$old_val" != "$new_val" ]; then
      printf '%s\t%s\t%s\n' "$field" "$old_val" "$new_val" >> "$VALUECHANGE_KNOBS_FILE"
    fi
  done < "$SEXP_DEFAULT_FIELDS"
  rm -f "$SEXP_DEFAULT_FIELDS"

  case "$f" in
    *.mli) ;;  # default literals live in .ml implementations only
    *)
      _default_literal_pairs "$BASE_REF" "$f" | sort -u > "$LIT_BASE"
      _default_literal_pairs "$HEAD_REF" "$f" | sort -u > "$LIT_HEAD"
      # Symmetric difference: any field line present at only one rev names
      # a changed knob (comm prefixes column 2 with a tab; strip, field 1).
      comm -3 "$LIT_BASE" "$LIT_HEAD" \
        | sed 's/^[[:space:]]*//' \
        | cut -f1 \
        | sort -u > "$LIT_CHANGED_FIELDS"
      cat "$LIT_CHANGED_FIELDS" >> "$FILE_KNOBS"

      # Same add-vs-value-change classification as above, but reading the
      # already-extracted LIT_BASE/LIT_HEAD field=value lines directly
      # (the literal region is multi-line record syntax, not a single
      # annotated declaration, so a fresh per-field git-show lookup
      # doesn't apply here).
      while IFS= read -r field; do
        [ -n "$field" ] || continue
        old_line="$(awk -F'\t' -v f="$field" '$1==f {print $2}' "$LIT_BASE")"
        new_line="$(awk -F'\t' -v f="$field" '$1==f {print $2}' "$LIT_HEAD")"
        if [ -n "$old_line" ] && [ -n "$new_line" ] && [ "$old_line" != "$new_line" ]; then
          old_val="$(printf '%s\n' "$old_line" | sed -e 's/^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*//' -e 's/;[[:space:]]*$//')"
          new_val="$(printf '%s\n' "$new_line" | sed -e 's/^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*//' -e 's/;[[:space:]]*$//')"
          printf '%s\t%s\t%s\n' "$field" "$old_val" "$new_val" >> "$VALUECHANGE_KNOBS_FILE"
        fi
      done < "$LIT_CHANGED_FIELDS"
      ;;
  esac

  if [ -s "$FILE_KNOBS" ]; then
    cat "$FILE_KNOBS" >> "$DIRECT_KNOBS_FILE"
    outer="$(_embedding_field "$f")"
    if [ -n "$outer" ]; then
      printf '%s\tembeds:%s\n' "$outer" "$(basename "$f")" >> "$RELATED_KNOBS_FILE"
    fi
  fi
done

if [ -n "$OVERRIDES_FILE" ]; then
  _changed_body_lines "$BASE_REF" "$HEAD_REF" "$OVERRIDES_FILE" \
    | sed -n 's/^[[:space:]]*((\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]].*$/\1/p' \
    >> "$DIRECT_KNOBS_FILE" || true
fi

sort -u "$DIRECT_KNOBS_FILE" -o "$DIRECT_KNOBS_FILE"

if [ ! -s "$DIRECT_KNOBS_FILE" ]; then
  echo "OK: goldens_affected_check -- no [@sexp.default value, default-record-literal value, or override knob was added or removed in any config-default surface file ($BASE_REF..$HEAD_REF)."
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
trap 'rm -f "$DIRECT_KNOBS_FILE" "$RELATED_KNOBS_FILE" "$KNOBS_FILE" "$MLI_HEAD_CONTENT" "$VALUECHANGE_KNOBS_FILE" "$LIT_BASE" "$LIT_HEAD" "$LIT_CHANGED_FIELDS" "$SUBDIRS_FILE"' EXIT

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
          embeds:*)
            MATCHES="${MATCHES}  knob '${knob}' is armed by ${rel} (${reason} -- embedding field of a nested config whose default changed)\n"
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

sort -u "$VALUECHANGE_KNOBS_FILE" -o "$VALUECHANGE_KNOBS_FILE"

# --- Step 4b: inheritance / affects-all widening for VALUE-CHANGED knobs ---
# See the header comment "Inheritance widening for VALUE CHANGES (Step 4b,
# issues #2558/#2570)" for the full rationale. In short: Step 4 above asks
# "does any golden mention this knob", which is the wrong question for a
# knob whose default VALUE changed -- the affected set is every golden
# that does NOT pin the knob at the NEW value, because config_overrides
# always wins over the compiled-in default, so anything that doesn't pin
# the knob silently inherits whatever the new default is.
ALL_SPECS_FILE="$(mktemp)"
trap 'rm -f "$DIRECT_KNOBS_FILE" "$RELATED_KNOBS_FILE" "$KNOBS_FILE" "$MLI_HEAD_CONTENT" "$VALUECHANGE_KNOBS_FILE" "$LIT_BASE" "$LIT_HEAD" "$LIT_CHANGED_FIELDS" "$SUBDIRS_FILE" "$ALL_SPECS_FILE"' EXIT
: > "$ALL_SPECS_FILE"
while IFS= read -r subdir; do
  [ -n "$subdir" ] || continue
  dir="${SCENARIO_ROOT}/${subdir}"
  [ -d "$dir" ] || continue
  for spec in "$dir"/*.sexp; do
    [ -f "$spec" ] || continue
    printf '%s\n' "$spec" >> "$ALL_SPECS_FILE"
  done
done < "$SUBDIRS_FILE"
sort -u "$ALL_SPECS_FILE" -o "$ALL_SPECS_FILE"
TOTAL_SPECS="$(wc -l < "$ALL_SPECS_FILE" | tr -d ' ')"

while IFS="$TAB" read -r vknob old_val new_val; do
  [ -n "$vknob" ] || continue
  OVERRIDDEN_COUNT=0
  AFFECTED_SPECS=""
  AFFECTED_COUNT=0
  NEW_VALUE_PATTERN="(${vknob} ${new_val})"
  while IFS= read -r spec; do
    [ -n "$spec" ] || continue
    if grep -q -w -- "$vknob" "$spec" 2>/dev/null; then
      OVERRIDDEN_COUNT=$((OVERRIDDEN_COUNT + 1))
    fi
    if ! grep -F -q -- "$NEW_VALUE_PATTERN" "$spec" 2>/dev/null; then
      rel="${spec#"${REPO_ROOT}"/}"
      AFFECTED_SPECS="${AFFECTED_SPECS}    ${rel} (inherits new default -- does not pin ${vknob}=${new_val})\n"
      AFFECTED_COUNT=$((AFFECTED_COUNT + 1))
    fi
  done < "$ALL_SPECS_FILE"

  if [ "$AFFECTED_COUNT" -gt 0 ]; then
    if [ "$OVERRIDDEN_COUNT" -eq 0 ]; then
      MATCHES="${MATCHES}  knob '${vknob}' default changed ${old_val} -> ${new_val}: 0 of ${TOTAL_SPECS} golden(s) override this knob -- no cell overrides it, so all ${TOTAL_SPECS} inherit it (AFFECTS-ALL)\n${AFFECTED_SPECS}"
    else
      MATCHES="${MATCHES}  knob '${vknob}' default changed ${old_val} -> ${new_val} (default-flip): ${OVERRIDDEN_COUNT} golden(s) override this knob explicitly; ${AFFECTED_COUNT} golden(s) inherit the new value and were NOT previously flagged\n${AFFECTED_SPECS}"
    fi
    MATCH_COUNT=$((MATCH_COUNT + AFFECTED_COUNT))
  fi
done < "$VALUECHANGE_KNOBS_FILE"

if [ "$MATCH_COUNT" -eq 0 ]; then
  echo "OK: goldens_affected_check -- $(wc -l < "$KNOBS_FILE" | tr -d ' ') changed/related knob(s), zero postsubmit golden specs arm any of them."
  exit 0
fi

# --- Acknowledgment path (B3): a PR that legitimately trips this check has
# no way to make the diff-derived FAIL above go away on its own -- see
# goldens-affected.yml's "ACKNOWLEDGMENT PATH" comment and
# .claude/rules/config-default-blast-radius.md. A human applies the
# 'paired-run-done' label AFTER eyeballing the pasted paired-run table;
# the workflow then sets this env var. This downgrades the verdict to a
# pass-with-notice -- it does NOT verify the table's contents, only that
# the label (an explicit human act) is present.
if [ "${GOLDENS_AFFECTED_ACK:-}" = "1" ]; then
  echo "OK (acknowledged): goldens_affected_check -- this PR changes a config default that a POSTSUBMIT-ONLY golden arms, but the 'paired-run-done' label is present."
  echo ""
  printf '%b' "$MATCHES"
  echo ""
  echo "The paired golden run table required by"
  echo ".claude/rules/config-default-blast-radius.md must already be pasted in"
  echo "the PR body -- this downgrade only records that a maintainer applied the"
  echo "'paired-run-done' label after eyeballing that table; it does not verify"
  echo "the table's contents."
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
echo "a suggestion. Once the table is pasted, apply the 'paired-run-done' label"
echo "to acknowledge it and turn this check green."
exit 1
