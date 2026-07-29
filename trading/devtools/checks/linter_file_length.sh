#!/bin/sh
# Linter: file length check for all lib .ml files in the trading codebase.
#
# Two-tier limit:
#
#   Normal files:         fail if > 300 lines.
#   Declared-large files: a file may opt in by including the marker
#                           (* @large-module: <reason> *)
#                         on any line. These are allowed up to 500 lines,
#                         but declared-large files must stay <= 11% of all
#                         checked files.
#
# This lets genuinely large modules exist without gaming the 300-line norm.
# If too many files declare themselves large the check fails, preventing
# mass opt-out from the soft limit.

set -e

. "$(dirname "$0")/_check_lib.sh"

TRADING_DIR="$(trading_dir)"
SOFT_LIMIT=300
HARD_LIMIT=500
MAX_LARGE_PCT=11

VIOLATIONS=""
TOTAL=0
LARGE_COUNT=0

# Name-anchored prunes + race guard (see no_python_check.sh).
for ml_file in $(find "$TRADING_DIR" \
    \( -name '_build' -o -name '.formatted' \) -prune -o \
    -path "*/lib/*.ml" \
    -not -name "*.pp.ml" \
    -print 2>/dev/null || true); do
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

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: file length linter:"
  printf '%b' "$VIOLATIONS"
  echo ""
  echo "Normal files: <= ${SOFT_LIMIT} lines. To exceed, add to the file:"
  echo "  (* @large-module: <reason> *)"
  echo "Declared-large files: <= ${HARD_LIMIT} lines, capped at ${MAX_LARGE_PCT}% of all files."
  exit 1
fi

echo "OK: all lib/*.ml files within limits (${LARGE_COUNT} declared-large of ${TOTAL} total)."
