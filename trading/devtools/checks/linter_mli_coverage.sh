#!/bin/sh
# Linter: .mli coverage for all lib modules across the trading codebase.
#
# Rule: every .ml file in */lib/ must have a corresponding .mli file.
# This enforces explicit interface design and prevents accidental exposure
# of internal implementation details.
#
# Path exceptions: see linter_exceptions.conf (mli_coverage entries).

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
    if [ "$linter" = "mli_coverage" ] && [ -n "$path" ]; then
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

for ml_file in $(find "$TRADING_DIR" -path "*/lib/*.ml" \
    -not -name "*.mli" \
    -not -path "*/_build/*" \
    -not -path "*/.formatted/*" \
    -not -name "*.pp.ml"); do
  _is_excluded "$ml_file" && continue
  mli_file="${ml_file%.ml}.mli"
  if [ ! -f "$mli_file" ]; then
    VIOLATIONS="${VIOLATIONS}${ml_file}\n"
  fi
done

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: .mli coverage linter — .ml files without a corresponding .mli:"
  printf '%b' "$VIOLATIONS"
  echo ""
  echo "Add a .mli file, or add a path exception to linter_exceptions.conf."
  exit 1
fi

echo "OK: all lib/*.ml files have a corresponding .mli."
