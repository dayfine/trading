#!/bin/sh
# Linter: dangling odoc-reference check (warn-level, NON-GATING).
#
# Filed by qc-behavioral on PR #2542 (finding B1, harness_gap:
# LINTER_CANDIDATE, see dev/status/cleanup.md `linter_candidate` entry).
# PR #2542 deleted `Simulator._settle_rejected_fills` and left
# `test_cancel_handler.ml:297` naming it inside a `[...]` doc-comment code
# span. Neither the build nor odoc break, because `[...]` is a code span
# (never resolved) and this repo never runs `dune build @doc` (which would
# resolve `{!...}` cross-references) -- so a doc comment can name a symbol
# that no longer exists anywhere in the tree, forever, with nothing to
# catch it.
#
# ---------------------------------------------------------------------------
# Design decision: narrow pattern, tree-scoped, non-gating (read this before
# editing the regex or trying to make this FAIL the build)
# ---------------------------------------------------------------------------
#
# The finding's own phrasing ("for each identifier removed by a diff, grep
# the surviving tree for it") is DIFF-scoped: it wants to know what a
# specific PR deleted. `dune runtest` has no notion of a diff and must be
# reproducible on any checkout, so this check is TREE-scoped instead: for
# every doc reference in the tree that looks like it names a private,
# repo-local OCaml symbol, verify that symbol still exists somewhere in the
# tree.
#
# The obvious tree-scoped formulation -- flag every `[...]` code span or
# `{!...}` odoc reference whose contents aren't found verbatim elsewhere --
# is unusable. Measured on main (2026-08-30): the tree contains ~36,695
# `[...]` code spans and ~4,926 `{!...}` references. The overwhelming
# majority hold prose, OCaml types, expressions, external names (EODHD,
# LAPACK, ...), or values that were never identifiers to begin with -- a
# broad check would either drown in false positives or need a
# non-mechanizable classifier to tell "identifier" from "prose".
#
# This check narrows to exactly the shape the finding's own regression
# instance has: a CAPITALIZED module name, a dot, and an UNDERSCORE-PREFIXED
# identifier -- `[Module._identifier]` or `{!Module._identifier}`. That
# shape is specific to this repo's convention (private helpers are named
# with a leading underscore, per .claude/rules/ocaml-patterns.md) and reads,
# unambiguously, as "this doc comment is naming a private symbol in another
# module" -- prose never has this shape, and neither does a type or a
# quantity. Measured false-positive rate against this narrower pattern: 0
# (every match below either resolves to a real binding or is a genuine,
# independently-confirmed dangling reference -- see the cleanup.md
# `linter_candidate` completion note for the audit trail).
#
# Measured selection: the narrow pattern selects 150 raw occurrences / 96
# distinct bare identifiers out of the ~41,621 total `[...]`/`{!...}` spans
# above -- i.e. it is deliberately a small, high-precision slice of the
# corpus, not an attempt to cover it.
#
# Existence check: bare-identifier, NOT module-scoped. For a candidate
# `[Module._foo]`, this asks "does `_foo` exist ANYWHERE in the tree as a
# `let` / `let rec` / `and` / `val` / `type` / `exception` / `module`
# binding (optionally under a ppx attribute, e.g. `let[@inline never]
# _foo`)?" -- not "does `_foo` exist specifically inside `Module`". This is
# a deliberate precision/recall trade: module-scoped resolution would need
# to map `Module` to its defining file (nontrivial for wrapped/aliased
# modules) and would raise the false-positive rate on a check that ships
# non-gating specifically because false positives are worse than the
# residual false negatives here (a renamed helper that happens to share its
# old name with an unrelated symbol in a different module would slip through
# undetected -- rare, and strictly safer than crying wolf on real code).
#
# NON-GATING BY DEFAULT: this check exits 0 unconditionally unless
# ODOC_DANGLING_REF_CHECK_STRICT=1 is set (see the exit path at the bottom).
# A dry run against current main (2026-08-30) scanned 150 candidate
# occurrences (96 distinct identifiers) and found 16 dangling occurrences /
# 11 distinct, independently-confirmed dangling identifiers (renamed/moved
# helpers whose doc comments were never updated -- e.g.
# `[Screener._passes_score_floor]`, now `Screener_admission
# .passes_score_floor`; `[Simulator._compute_portfolio_value]`, deleted
# outright). Eleven pre-existing violations is well past the "single-digit,
# each one a real fix" bar for a dated linter_exceptions.conf carve-out
# (.claude/rules/code-health-discipline.md), so this ships as a WARN-only
# gate -- like the cyclomatic-complexity linter (T1-Q) -- rather than a
# FAIL. The 11 findings are filed as their own dev/status/cleanup.md backlog
# item for code-health to work through; once that backlog is clear, a
# follow-up can flip this rule's dune wiring to run with
# ODOC_DANGLING_REF_CHECK_STRICT=1 to make it FAIL, the same promotion path
# any warn-level linter takes once its residual debt reaches zero.
#
# What this does NOT catch:
#   - Bare module references (`{!Module}`, `[Module]`) -- no leaf identifier
#     to resolve.
#   - Public (non-underscore) identifiers (`{!Module.public_fn}`) -- the
#     narrowing is deliberately underscore-only; a dangling PUBLIC reference
#     is a real gap but the underscore-only slice was the only one measured
#     at 0 false positives during this check's construction. Widening it is
#     future work, not blocked by anything here.
#   - Nested field-path references (`{!Module.type.field}`) -- module-scoped
#     dotted paths deeper than one level are excluded by the pattern.
#   - A reference whose IDENTIFIER happens to still exist somewhere in the
#     tree under a DIFFERENT, unrelated module than the one named -- see
#     "bare-identifier, not module-scoped" above.
#   - Diff-scoping: this never looks at git history; it is a static property
#     of the current tree, checked on every `dune runtest`.
#
# Output:
#   OK:   0 dangling references found (of N candidates scanned).
#   WARN: >=1 dangling references found -- listed, but the check still
#         exits 0 (non-gating; see rationale above).
# Both messages report the SCANNED count explicitly, not just the dangling
# count, precisely so a broken detector (core pattern accidentally narrowed
# to match nothing) is distinguishable from a genuinely clean tree: "0
# scanned" can never mean "clean", only "broken" or "no source files found".
# odoc_dangling_ref_check_test.sh pins this distinction directly.

set -eu

. "$(dirname "$0")/_check_lib.sh"

TRADING_DIR="$(trading_dir)"

# Candidate shape: a capitalized module name, a dot, an underscore-prefixed
# identifier, inside either a `[...]` code span or a `{!...}` odoc
# cross-reference (the latter may carry an optional leading `?` for an
# optional-argument reference, e.g. `{!?foo}` -- not seen in this repo today
# but part of odoc's own grammar, so tolerated rather than silently missed).
CANDIDATE_RE='\[[A-Z][A-Za-z0-9_]*\._[A-Za-z0-9_]+\]|\{!\??[A-Z][A-Za-z0-9_]*\._[A-Za-z0-9_]+\}'

# Name-anchored prunes (see no_python_check.sh / linter_mli_coverage.sh):
# match at any depth so a nested _build (dune sandbox artifacts) is always
# excluded regardless of how deep TRADING_DIR itself is nested.
FILELIST="$(mktemp)"
RESOLVED_CACHE="$(mktemp)"
DANGLING_CACHE="$(mktemp)"
trap 'rm -f "$FILELIST" "$RESOLVED_CACHE" "$DANGLING_CACHE"' EXIT INT TERM

find "$TRADING_DIR" \
  \( -name '_build' -o -name '.formatted' \) -prune -o \
  \( -name '*.ml' -o -name '*.mli' \) -print 2>/dev/null \
  > "$FILELIST" || true

FILE_COUNT=$(wc -l < "$FILELIST" | tr -d ' ')
if [ "$FILE_COUNT" -eq 0 ]; then
  echo "OK: odoc_dangling_ref_check -- 0 .ml/.mli files found under ${TRADING_DIR}; nothing to scan."
  exit 0
fi

# Single grep invocation over the whole file list (not a per-file loop or
# xargs) -- 1591 files today, comfortably under any realistic ARG_MAX, and
# a single process avoids both the per-file fork cost (see
# magic_numbers_linter's own header for why that mattered at this repo's
# scale) and xargs's batching ambiguity (a match in an early xargs batch
# does not make a later empty batch's failure disappear from xargs's own
# exit code -- so xargs is not safe here for "did ANY batch match").
#
# -H forces the filename prefix even if only one file happens to match;
# -n line number; -o only the matched span; -E extended regex.
CANDIDATES=$(grep -HnoE "$CANDIDATE_RE" $(cat "$FILELIST") 2>/dev/null || true)

if [ -z "$CANDIDATES" ]; then
  echo "OK: odoc_dangling_ref_check -- 0 candidate doc-identifier reference(s) scanned (${FILE_COUNT} files checked); nothing to check."
  exit 0
fi

SCANNED=$(printf '%s\n' "$CANDIDATES" | grep -c .)

# Resolved-identifier caches (POSIX sh has no associative arrays): one line
# per identifier already checked, so a repeated reference to the same
# symbol (`_on_market_close` is cited 7x in the real tree) is resolved once.
# (Both files are created above, before the file list is even known to be
# non-empty, so the single EXIT/INT/TERM trap above already covers them.)

# $1 = bare identifier (leading underscore included). Returns 0 (found) or
# 1 (dangling), consulting/populating the caches above.
_ident_exists() {
  ident="$1"
  if grep -qxF "$ident" "$RESOLVED_CACHE"; then
    return 0
  fi
  if grep -qxF "$ident" "$DANGLING_CACHE"; then
    return 1
  fi
  # A binding site: let / let rec / and / val / type / exception / module,
  # optionally carrying a ppx attribute either directly after the keyword
  # (`let[@inline never] _foo`, no space) or after `rec`. Boundaries use
  # explicit non-word character classes rather than \b (not universally
  # supported by non-GNU grep; every other check in this directory uses the
  # same convention -- see tracked_artifact_linter.sh's ALLOW_PATTERN).
  pattern="(^|[^A-Za-z0-9_])(let|and|val|type|exception|module)(\[@[^]]*\])?([[:space:]]+rec)?[[:space:]]+(\[@[^]]*\])?${ident}([^A-Za-z0-9_]|\$)"
  if grep -qE "$pattern" $(cat "$FILELIST") 2>/dev/null; then
    echo "$ident" >> "$RESOLVED_CACHE"
    return 0
  else
    echo "$ident" >> "$DANGLING_CACHE"
    return 1
  fi
}

VIOLATIONS=""
DANGLING_COUNT=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  file="${line%%:*}"
  rest="${line#*:}"
  lnum="${rest%%:*}"
  match="${rest#*:}"
  # Strip the delimiters to get "Module._ident", then split on the first
  # dot -- Module never contains a dot (the pattern forbids it), so this is
  # unambiguous.
  inner=$(printf '%s' "$match" | sed -E 's/^\{!\??//; s/^\[//; s/\}$//; s/\]$//')
  ident="${inner#*.}"
  if ! _ident_exists "$ident"; then
    DANGLING_COUNT=$((DANGLING_COUNT + 1))
    VIOLATIONS="${VIOLATIONS}  ${file}:${lnum}: ${match}\n"
  fi
done <<EOF
$CANDIDATES
EOF

if [ "$DANGLING_COUNT" -gt 0 ]; then
  echo "WARN: odoc_dangling_ref_check -- ${SCANNED} candidate doc-identifier reference(s) scanned; ${DANGLING_COUNT} dangling reference(s) found (non-gating -- see script header):"
  printf '%b' "$VIOLATIONS"
  echo ""
  echo "  Each path above names a private, underscore-prefixed identifier that no"
  echo "  longer exists anywhere in the tree under that name -- it was likely"
  echo "  renamed, moved to a different module, or deleted. Fix: update the doc"
  echo "  comment to name the symbol's current home, or delete the stale reference"
  echo "  if the described behavior no longer exists."
  # STRICT mode (opt-in via env var, not yet wired into the dune rule) is
  # the promotion path once the pre-existing backlog above is cleared: flip
  # this on for a fixture / a manual run to confirm zero remaining findings
  # before wiring ODOC_DANGLING_REF_CHECK_STRICT=1 into the dune action.
  if [ "${ODOC_DANGLING_REF_CHECK_STRICT:-0}" = "1" ]; then
    exit 1
  fi
  exit 0
fi

echo "OK: odoc_dangling_ref_check -- ${SCANNED} candidate doc-identifier reference(s) scanned; 0 dangling."
