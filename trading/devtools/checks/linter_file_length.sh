#!/bin/sh
# Linter: file length check for .ml files (repo-wide) AND lib .mli files in
# the trading codebase.
#
# Two-tier limit (same numeric thresholds for both populations):
#
#   Normal files:         fail if > 300 (lines for .ml; signature lines for .mli).
#   Declared-large files: a file may opt in by including the marker
#                           (* @large-module: <reason> *)
#                         on any line. These are allowed up to 500, but
#                         declared-large files must stay <= 11% of all
#                         checked files IN THEIR OWN POPULATION (.ml and
#                         .mli are tracked and capped separately -- see
#                         "Why .ml and .mli populations are tracked
#                         separately" below).
#
# This lets genuinely large modules exist without gaming the 300-line norm.
# If too many files declare themselves large the check fails, preventing
# mass opt-out from the soft limit.
#
# ---------------------------------------------------------------------------
# .ml: RAW line count. .mli: SIGNATURE line count. Why the metric differs.
# ---------------------------------------------------------------------------
#
# H-MLI-FILE-LENGTH-BLIND-SPOT (P0.1, filed dev/notes/next-session-priorities
# -2026-08-14.md): this check historically scanned only `*/lib/*.ml`, so
# `.mli` files were never scanned at all -- a real gap, since interface
# files can grow unboundedly with no linter signal.
#
# Measured before picking a metric (2026-08-13, 439 `*/lib/*.mli` files):
# 14 exceed 300 RAW lines, worst case 1587 (weinstein_strategy_config.mli).
# But .mli files are DOCSTRING-DOMINATED -- they are the primary contract
# surface (qc-behavioral-authority.md), so long doc comments are a feature,
# not a defect. Stripping `(* ... *)` comment blocks and blank lines from
# every one of those 14 violators drops the SAME file from 1587 raw lines
# down to 97 signature lines; the worst SIGNATURE-line violator across all
# 439 files is 217 lines. Using raw `wc -l` for `.mli` (the naive fix) would
# have redenned main on 14 files with zero interface-complexity problem, and
# the only way to turn that green would have been either (a) 14
# `@large-module` markers slapped on for the sole purpose of appeasing the
# linter, or (b) an ad-hoc `.mli`-only line-limit bump chosen to fit the
# current tree -- both explicitly forbidden by
# `.claude/rules/code-health-discipline.md` ("What NOT to do": don't add
# markers just to satisfy a linter, don't bump limits without a real
# refactor plan). So `.mli` files are checked against SIGNATURE lines (raw
# minus comment-block content minus blank lines), using the SAME 300/500
# thresholds as `.ml` -- this is the metric that actually tracks interface
# *complexity* instead of documentation *volume*, and the current tree
# passes cleanly under it (max 217), with no markers or limit changes
# needed. See `_mli_signature_line_count()` below for the nested-comment-
# aware implementation.
#
# ---------------------------------------------------------------------------
# Why .ml and .mli populations are tracked separately
# ---------------------------------------------------------------------------
#
# The MAX_LARGE_PCT cap (11%) exists to stop mass opt-out from the soft
# limit (see the two-tier-limit comment above). Pooling .ml and .mli into
# one TOTAL/LARGE_COUNT would let a burst of `@large-module` .mli markers
# eat headroom that should be reserved for genuinely-large .ml
# implementation files (and vice versa) -- the two populations answer
# different questions (implementation size vs. interface complexity) and a
# shared cap would let either one silently subsidize the other's opt-out
# budget. Kept as two independent TOTAL/LARGE_COUNT pairs, each checked
# against the same MAX_LARGE_PCT, instead.
#
# ---------------------------------------------------------------------------
# Sibling gap, deliberately OUT OF SCOPE here: test files
# ---------------------------------------------------------------------------
#
# This check's `find` still prunes everything under `*/test/*` for both .ml
# and .mli. That is a known, separately-tracked gap -- see
# `dev/status/cleanup.md` entry `linter_coverage` for measured numbers. Not
# fixed here: it's a policy question (what limit should apply to test
# files, which are allowed to be more repetitive than lib code), not a
# linter-mechanics bug like the .mli blind spot was.
#
# ---------------------------------------------------------------------------
# H-FILE-LENGTH-LIB-SCOPE-BLIND-SPOT (issue #2876, 2026-09-25 fix)
# ---------------------------------------------------------------------------
#
# The `.ml` loop historically scanned only `-path "*/lib/*.ml"`, so any `.ml`
# file whose containing directory was not literally named `lib` -- `bin/`,
# `scripts/`, `devtools/<tool>/`, or a bare feature directory like
# `release_report/` or `scenarios/` -- was invisible to the 300-soft /
# 500-hard limits, same shape as the `.mli` blind spot above (a scope gap,
# not a metric gap). Nine files were measured over the hard limit with zero
# linter signal at the time the issue was filed, two of them over TWICE the
# hard limit (`release_report.ml` 1005, `trade_audit_ratings.ml` 1001).
#
# The obvious "widen to `*/bin/*.ml` and `*/scripts/*/*.ml`" fix (the
# issue's own suggested patch) does NOT actually close the gap: of the nine
# measured violators, only three live under a `bin/` or `scripts/<tool>/`
# directory (`build_runner.ml`, `shiller_weinstein_decades.ml`,
# `backtest_runner.ml`). The other six live in directories with arbitrary
# feature names (`release_report/`, `trade_audit_report/`, `scenarios/`,
# `differential/`) that no small allowlist of directory names would ever
# enumerate completely -- the actual invariant this codebase uses is "one
# `dune` stanza directory per module", not "modules live under `lib/`".
#
# So the `.ml` loop is now an EXCLUSION-based full-tree scan (every `.ml`
# under `$TRADING_DIR` except `_build/`, `.formatted/`, and `*/test/*`),
# matching the pattern `fmt_check.sh` already uses for its repo-wide `.ml`/
# `.mli` scan -- not an allowlist of directory names. The `.mli` loop is
# UNCHANGED (`*/lib/*.mli` only): the issue and its measurement are `.ml`-
# only, and widening `.mli` scope is a separate, unmeasured change.
#
# Newly-visible violators at the time of the fix were each given a
# deliberate disposition (extraction, an `@large-module` marker, or a dated
# `linter_exceptions.conf` file_length entry + `dev/status/cleanup.md`
# backlog entry) per `.claude/rules/code-health-discipline.md` -- see the
# `file_length` section of `linter_exceptions.conf` for the exempted set.

set -e

. "$(dirname "$0")/_check_lib.sh"

TRADING_DIR="$(trading_dir)"
EXCEPTIONS_CONF="$(dirname "$0")/linter_exceptions.conf"
SOFT_LIMIT=300
HARD_LIMIT=500
MAX_LARGE_PCT=11

# Build the file_length exclusion pattern from linter_exceptions.conf, same
# convention as linter_mli_coverage.sh: a file is excluded if its path
# CONTAINS the exception's path substring (not anchored). Excluded files are
# skipped before TOTAL/LARGE_COUNT accounting, so an exception neither counts
# against nor subsidizes the MAX_LARGE_PCT cap.
FILE_LENGTH_EXCLUDE_PATTERN=""
if [ -f "$EXCEPTIONS_CONF" ]; then
  while IFS= read -r line; do
    case "$line" in
      '#'* | '') continue ;;
    esac
    linter=$(printf '%s' "$line" | awk '{print $1}')
    path=$(printf '%s' "$line" | awk '{print $2}')
    if [ "$linter" = "file_length" ] && [ -n "$path" ]; then
      if [ -n "$FILE_LENGTH_EXCLUDE_PATTERN" ]; then
        FILE_LENGTH_EXCLUDE_PATTERN="${FILE_LENGTH_EXCLUDE_PATTERN}|${path}"
      else
        FILE_LENGTH_EXCLUDE_PATTERN="${path}"
      fi
    fi
  done < "$EXCEPTIONS_CONF"
fi

_is_file_length_excluded() {
  [ -z "$FILE_LENGTH_EXCLUDE_PATTERN" ] && return 1
  printf '%s' "$1" | grep -qE "$FILE_LENGTH_EXCLUDE_PATTERN"
}

# Nested-comment-aware OCaml `(* ... *)` block stripper + blank-line skip.
# Prints the count of non-blank lines OUTSIDE any comment block for the
# given file ("signature lines").
#
# Uses a DEPTH COUNTER, not a boolean in/out-of-comment flag, because OCaml
# comments NEST: `(* outer (* inner *) still outer *)` is ONE comment
# block, not two. Tokens are processed strictly in left-to-right order
# within each line (never via a line-level regex, which cannot see token
# order): "(*" increments depth, "*)" decrements depth (floor 0, so a
# spurious/unbalanced "*)" can't go negative and start counting real code
# as a comment). `depth` is a bare (unset -> 0) awk global so it persists
# across the whole file, which is what lets a comment span many lines.
#
# A naive boolean toggle (set true on "(*", false on "*)", no counting)
# would treat the FIRST "*)" -- the INNER comment's close -- as closing the
# whole block, leaking " still outer *)" (and everything after, up to the
# next real "(*"/"*)" pair) as if it were real code. See
# linter_file_length_test.sh fixture C, which pins this exact case: the
# nested-aware count is 2 signature lines; the naive-boolean count on the
# identical input is 307 -- comfortably crossing the 300-line threshold in
# the wrong direction.
#
# KNOWN LIMITATION: does not track string literals, so a line containing a
# quoted string with a literal "(*"/"*)" inside it would misparse -- same
# approximation every non-full-OCaml-lexer comment stripper in this repo
# makes (see check_universe_deps.sh's strip_comments() for the analogous
# dune-comment version). Not observed in any real `.mli` in this repo as of
# 2026-08-13: `.mli` files are signatures + doc comments, essentially never
# string literals.
_mli_signature_line_count() {
  awk '
    {
      buf = $0
      out = ""
      while (length(buf) > 0) {
        p_open = index(buf, "(*")
        p_close = index(buf, "*)")
        if (p_open == 0 && p_close == 0) {
          if (depth == 0) out = out buf
          buf = ""
        } else if (p_open > 0 && (p_close == 0 || p_open < p_close)) {
          if (depth == 0) out = out substr(buf, 1, p_open - 1)
          depth++
          buf = substr(buf, p_open + 2)
        } else {
          if (depth > 0) depth--
          buf = substr(buf, p_close + 2)
        }
      }
      gsub(/^[ \t]+|[ \t]+$/, "", out)
      if (depth == 0 && length(out) > 0) sig++
    }
    END { print sig + 0 }
  ' "$1"
}

VIOLATIONS=""
TOTAL=0
LARGE_COUNT=0

# Name-anchored prunes + race guard (see no_python_check.sh). Repo-wide scan
# (issue #2876) -- see the H-FILE-LENGTH-LIB-SCOPE-BLIND-SPOT header comment
# above for why this is an exclusion (prune _build/.formatted/test) rather
# than an allowlist of directory names (lib/bin/scripts/...).
for ml_file in $(find "$TRADING_DIR" \
    \( -name '_build' -o -name '.formatted' \) -prune -o \
    -path "*/test/*" -prune -o \
    -name "*.ml" \
    -not -name "*.pp.ml" \
    -print 2>/dev/null || true); do
  if _is_file_length_excluded "$ml_file"; then
    continue
  fi
  TOTAL=$((TOTAL + 1))
  # `wc -l < "$ml_file"` is a bare command-substitution assignment under
  # `set -e`: if $ml_file vanishes between `find` printing it and this read
  # (the same sandbox-cleanup race documented in no_python_check.sh, e.g. a
  # concurrent dune sandbox teardown), the redirect fails, the assignment's
  # own exit status trips `set -e`, and the WHOLE script dies silently --
  # zero output, no FAIL: line (H-CHECK-SETE-DIAGNOSTICS).
  #
  # Two DISTINCT failure shapes must not be collapsed into one blanket
  # `|| continue` (2026-07-29 qc-behavioral rework, FINDING-1): (a) the file
  # vanished before we got to it -- a genuine TOCTOU race, not a violation,
  # safe to skip; (b) the file still EXISTS but the read failed (permission
  # denied, a directory masquerading as a `*.ml` path, an I/O error) -- this
  # must remain a hard, diagnosed failure, because silently skipping it
  # would let a file that actually violates the length limit slip through
  # as a false green in this merge-gating linter. `[ -e ]` is checked both
  # before the attempt (fast path for the common "already gone" case) and
  # again only if the read fails (to distinguish "still there, unreadable"
  # from "vanished mid-read") -- never a bare `2>/dev/null || continue`.
  if [ ! -e "$ml_file" ]; then
    continue
  fi
  if line_count=$(wc -l < "$ml_file" 2>/dev/null); then
    : # fall through to the length checks below
  else
    if [ -e "$ml_file" ]; then
      VIOLATIONS="${VIOLATIONS}${ml_file}: could not read file to count lines (exists but the read failed -- permission, I/O, or type error; H-CHECK-SETE-DIAGNOSTICS FINDING-1)\n"
    fi
    continue
  fi

  if grep -q "@large-module" "$ml_file"; then
    LARGE_COUNT=$((LARGE_COUNT + 1))
    if [ "$line_count" -gt "$HARD_LIMIT" ]; then
      VIOLATIONS="${VIOLATIONS}${ml_file}: ${line_count} lines (declared-large hard limit: ${HARD_LIMIT})\n"
    fi
  else
    if [ "$line_count" -gt "$SOFT_LIMIT" ]; then
      VIOLATIONS="${VIOLATIONS}${ml_file}: ${line_count} lines (limit: ${SOFT_LIMIT})\n"
    fi
  fi
done

# Fail if declared-large files exceed MAX_LARGE_PCT% of total.
# Uses integer arithmetic: LARGE * 100 > TOTAL * MAX_LARGE_PCT.
if [ "$TOTAL" -gt 0 ] && [ $((LARGE_COUNT * 100)) -gt $((TOTAL * MAX_LARGE_PCT)) ]; then
  VIOLATIONS="${VIOLATIONS}Too many declared-large files: ${LARGE_COUNT}/${TOTAL} exceeds ${MAX_LARGE_PCT}% cap.\n"
  VIOLATIONS="${VIOLATIONS}  Split modules instead of opting out of the ${SOFT_LIMIT}-line limit.\n"
fi

TOTAL_MLI=0
LARGE_COUNT_MLI=0

# The `*.pp.mli` exclusion mirrors the `*.pp.ml` one in the .ml loop above and
# is load-bearing, not cosmetic: dune's PPX output lands at
# `_build/.sandbox/<hash>/default/**/foo.pp.mli`, and because the check runs
# FROM INSIDE that sandbox with a relative TRADING_DIR (`./../..`), the
# `-name '_build' -prune` above never matches on the way down. Preprocessed
# interfaces are macro-expanded and routinely exceed 300 signature lines, so
# without this the check FAILS on generated files that have no source form
# (measured: `trade_audit.pp.mli` 396, `barbell_floor_sweep.pp.mli` 316,
# `validator_types.pp.mli` 306 -- none of which is a real violation).
# Running the script directly against the source tree cannot surface this:
# there are zero `*.pp.mli` outside `_build`. Only `dune runtest` reproduces it.
for mli_file in $(find "$TRADING_DIR" \
    \( -name '_build' -o -name '.formatted' \) -prune -o \
    -path "*/lib/*.mli" \
    -not -name "*.pp.mli" \
    -print 2>/dev/null || true); do
  TOTAL_MLI=$((TOTAL_MLI + 1))
  # Same TOCTOU vanished-vs-unreadable discrimination as the .ml loop above
  # (H-CHECK-SETE-DIAGNOSTICS FINDING-1) -- see that loop's comment for the
  # full rationale. Not duplicated here verbatim to keep this loop short.
  if [ ! -e "$mli_file" ]; then
    continue
  fi
  if line_count=$(_mli_signature_line_count "$mli_file" 2>/dev/null); then
    :
  else
    if [ -e "$mli_file" ]; then
      VIOLATIONS="${VIOLATIONS}${mli_file}: could not read file to count signature lines (exists but the read failed -- permission, I/O, or type error; H-CHECK-SETE-DIAGNOSTICS FINDING-1)\n"
    fi
    continue
  fi

  if grep -q "@large-module" "$mli_file"; then
    LARGE_COUNT_MLI=$((LARGE_COUNT_MLI + 1))
    if [ "$line_count" -gt "$HARD_LIMIT" ]; then
      VIOLATIONS="${VIOLATIONS}${mli_file}: ${line_count} signature lines (declared-large hard limit: ${HARD_LIMIT})\n"
    fi
  else
    if [ "$line_count" -gt "$SOFT_LIMIT" ]; then
      VIOLATIONS="${VIOLATIONS}${mli_file}: ${line_count} signature lines (limit: ${SOFT_LIMIT})\n"
    fi
  fi
done

# Same MAX_LARGE_PCT cap, applied to the .mli population independently of
# the .ml population -- see "Why .ml and .mli populations are tracked
# separately" above.
if [ "$TOTAL_MLI" -gt 0 ] && [ $((LARGE_COUNT_MLI * 100)) -gt $((TOTAL_MLI * MAX_LARGE_PCT)) ]; then
  VIOLATIONS="${VIOLATIONS}Too many declared-large .mli files: ${LARGE_COUNT_MLI}/${TOTAL_MLI} exceeds ${MAX_LARGE_PCT}% cap.\n"
  VIOLATIONS="${VIOLATIONS}  Split modules instead of opting out of the ${SOFT_LIMIT}-signature-line limit.\n"
fi

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: file length linter:"
  printf '%b' "$VIOLATIONS"
  echo ""
  echo "Normal .ml files: <= ${SOFT_LIMIT} lines. Normal .mli files: <= ${SOFT_LIMIT}"
  echo "signature lines (raw lines minus (* ... *) comment blocks minus blank"
  echo "lines). To exceed, add to the file:"
  echo "  (* @large-module: <reason> *)"
  echo "Declared-large files: <= ${HARD_LIMIT} (lines / signature lines), capped at"
  echo "${MAX_LARGE_PCT}% of all files IN THEIR OWN POPULATION (.ml, .mli tracked separately)."
  echo "For a .ml file over ${HARD_LIMIT} lines, add a dated 'file_length' entry to"
  echo "linter_exceptions.conf instead (see its header for the format)."
  exit 1
fi

echo "OK: all *.ml files within limits (${LARGE_COUNT} declared-large of ${TOTAL} total); all lib/*.mli signatures within limits (${LARGE_COUNT_MLI} declared-large of ${TOTAL_MLI} total)."
