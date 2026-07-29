#!/bin/sh
# Linter: magic numbers in lib .ml files across the whole trading codebase.
#
# Rule: numeric literals in implementation files must be routed through a
# config record. Bare numeric literals that are not part of a record field
# assignment (e.g., "field_name = 42") or a config access (e.g.,
# "config.field") are flagged as magic numbers.
#
# Acceptable exceptions (always allowed):
#   - 0, 0.0, 1, 1.0       (identity/zero values)
#   - 2.0, 0.5              (midpoint/half — common math constants)
#   - 100.0                 (percentage conversion — mathematical constant)
#   - Literals on a line that contains "= <num>" (record field default)
#   - Literals on a line that contains "config." (config field access)
#   - Literals in comments (* ... *)
#   - Lines with "->" (variant arms, e.g. Stage1 _ -> 1)
#   - Lines with "~f:", "~len:", "~pos:" (labeled args)
#
# Path exceptions: see linter_exceptions.conf (magic_numbers entries).
#
# Heuristic: grep-based, not AST-based. May have false negatives for
# complex expressions but avoids false positives on the current codebase.

set -e

. "$(dirname "$0")/_check_lib.sh"

TRADING_DIR="$(trading_dir)"
EXCEPTIONS_CONF="$(dirname "$0")/linter_exceptions.conf"
VIOLATIONS=""

# Build exclusion pattern from exceptions conf for this linter.
EXCLUDE_PATTERN=""
if [ -f "$EXCEPTIONS_CONF" ]; then
  while IFS= read -r line; do
    case "$line" in
      '#'* | '') continue ;;
    esac
    linter=$(printf '%s' "$line" | awk '{print $1}')
    path=$(printf '%s' "$line" | awk '{print $2}')
    if [ "$linter" = "magic_numbers" ] && [ -n "$path" ]; then
      if [ -n "$EXCLUDE_PATTERN" ]; then
        EXCLUDE_PATTERN="${EXCLUDE_PATTERN}|${path}"
      else
        EXCLUDE_PATTERN="${path}"
      fi
    fi
  done < "$EXCEPTIONS_CONF"
fi

_is_excluded() {
  [ -z "$EXCLUDE_PATTERN" ] && return 1
  printf '%s' "$1" | grep -qE "$EXCLUDE_PATTERN"
}

# Name-anchored prunes + race guard (see no_python_check.sh).
for f in $(find "$TRADING_DIR" \
    \( -name '_build' -o -name '.formatted' \) -prune -o \
    -path "*/lib/*.ml" \
    -not -name "*.pp.ml" \
    -print 2>/dev/null || true); do
  _is_excluded "$f" && continue

  # `done < "$f"` below opens $f for the loop's stdin. If $f vanishes
  # between `find` printing it and this open (the sandbox-cleanup race
  # documented in no_python_check.sh), the redirect fails and -- since this
  # is a bare compound command under `set -e` -- the WHOLE script would die
  # silently: zero output, no FAIL: line (H-CHECK-SETE-DIAGNOSTICS).
  #
  # Two DISTINCT failure shapes must not be collapsed into one blanket
  # `|| continue` (2026-07-29 qc-behavioral rework, FINDING-1): (a) the file
  # vanished before we got to it -- a genuine TOCTOU race, safe to skip;
  # (b) the file still EXISTS but can't be read (permission denied, a
  # directory masquerading as a `*.ml` path, an I/O error) -- this must
  # remain a hard, diagnosed failure, because silently skipping it would
  # let a file that actually contains a magic number slip through as a
  # false green in this merge-gating linter. Probe readability with `cat`
  # up front (a `while ... done < file` compound's own exit status is not a
  # reliable signal -- it reflects the LAST command run in the loop body on
  # a normal pass, not just the redirection) so vanished-vs-unreadable is
  # decided BEFORE the real scanning loop runs, not conflated with it.
  if [ ! -e "$f" ]; then
    continue
  fi
  if ! cat "$f" >/dev/null 2>/dev/null; then
    if [ -e "$f" ]; then
      VIOLATIONS="${VIOLATIONS}${f}: could not read file to scan for magic numbers (exists but the read failed -- permission, I/O, or type error; H-CHECK-SETE-DIAGNOSTICS FINDING-1)\n"
    fi
    continue
  fi

  # Track multi-line comment depth across lines. Lines inside an open comment
  # block were previously flagged as violations on numerics. Now count opens
  # and closes per line and skip lines whose start-of-line depth is positive.
  comment_depth=0
  while IFS= read -r line; do
    line_open_count=$(printf '%s' "$line" | grep -o '(\*' | wc -l | tr -d ' ')
    line_close_count=$(printf '%s' "$line" | grep -o '\*)' | wc -l | tr -d ' ')
    skip_this_line=0
    if [ "$comment_depth" -gt 0 ]; then
      skip_this_line=1
    fi
    comment_depth=$(( comment_depth + line_open_count - line_close_count ))
    [ "$comment_depth" -lt 0 ] && comment_depth=0
    [ "$skip_this_line" -eq 1 ] && continue

    # Skip lines that open or close a comment on this line itself.
    case "$line" in
      *'(*'* | *'*)'* | *'e.g.'*) continue ;;
    esac

    # Skip OCaml multi-line string continuation lines (end with backslash).
    # These lines are always inside a string literal started on a prior line.
    case "$line" in
      *'\') continue ;;
    esac

    # Skip lines whose numeric sits inside an open string from a prior line.
    # An odd count of double-quotes means this line is a continuation of a
    # string opened on an earlier line — all content is string literal, so
    # any numeric is not a magic number in code.
    quote_count=$(printf '%s' "$line" | tr -cd '"' | wc -c | tr -d ' ')
    if [ $(( quote_count % 2 )) -ne 0 ]; then
      continue
    fi

    # Skip record field assignments and named constant definitions (= <num>)
    # e.g. "field = 42", "let max_size = 100", "let pi = 3.14"
    case "$line" in
      *'= '[0-9]* | *'= -'[0-9]*) continue ;;
    esac

    # Skip named constant bindings: lines with "let <identifier> ="
    case "$line" in
      *'let '*' = '* | *'let '*'='[0-9]*) continue ;;
    esac

    # Skip config-routed values
    case "$line" in
      *'config.'*) continue ;;
    esac

    # Skip variant arms (e.g. Stage1 _ -> 1)
    case "$line" in
      *'->'*) continue ;;
    esac

    # Skip labeled args (~f:, ~len:, ~pos:)
    case "$line" in
      *'~f:'* | *'~len:'* | *'~pos:'*) continue ;;
    esac

    candidates=$(printf '%s\n' "$line" \
      | grep -oP '(?<![a-zA-Z0-9_.])([0-9]+\.[0-9]+|[0-9]{2,})(?![a-zA-Z0-9_.])' \
      || true)

    for num in $candidates; do
      case "$num" in
        0 | 1 | 0.0 | 1.0) continue ;;
        2.0 | 0.5 | 100.0) continue ;;
        *)
          # Skip numerics that appear only inside double-quoted strings on
          # this line. Strip all "..." segments; if the number no longer
          # appears in the remainder, it was inside a string literal and is
          # not a magic number in code.
          stripped=$(printf '%s' "$line" | sed 's/"[^"]*"//g')
          case "$stripped" in
            *"$num"*) VIOLATIONS="${VIOLATIONS}${f}: ${num} in: ${line}\n" ;;
          esac
          ;;
      esac
    done
  # The `cat` probe above already distinguished vanished (skip) from
  # unreadable-but-present (FAIL); `|| continue` here is only a last-resort
  # guard for the sub-millisecond TOCTOU window between that probe and this
  # redirection -- by that point the file has already been proven readable
  # once, so a failure here is overwhelmingly the same vanish-mid-scan race,
  # not a masked violation.
  done < "$f" || continue
done

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: magic number linter — bare numeric literals in lib/ files."
  echo "Route values through a config record, or add a path exception to linter_exceptions.conf."
  echo ""
  printf '%b' "$VIOLATIONS"
  exit 1
fi

echo "OK: no magic numbers found in lib/ files."
