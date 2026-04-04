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

TRADING_DIR="$(dirname "$0")/../.."
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

for f in $(find "$TRADING_DIR" -path "*/lib/*.ml" \
    -not -path "*/_build/*" \
    -not -path "*/.formatted/*" \
    -not -name "*.pp.ml"); do
  _is_excluded "$f" && continue

  while IFS= read -r line; do
    # Skip comment lines (single-line and multi-line comment content).
    case "$line" in
      *'(*'* | *'*)'* | *'e.g.'*) continue ;;
    esac

    # Skip record field assignments (= <num>) — these are defaults
    case "$line" in
      *'= '[0-9]* | *'= -'[0-9]*) continue ;;
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
        *) VIOLATIONS="${VIOLATIONS}${f}: ${num} in: ${line}\n" ;;
      esac
    done
  done < "$f"
done

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: magic number linter — bare numeric literals in lib/ files."
  echo "Route values through a config record, or add a path exception to linter_exceptions.conf."
  echo ""
  printf '%b' "$VIOLATIONS"
  exit 1
fi

echo "OK: no magic numbers found in lib/ files."
