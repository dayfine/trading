#!/bin/sh
# Architecture layer test: verify no analysis/ module imports from trading/trading/
# unless explicitly allowed in linter_exceptions.conf (arch_layer entries).
#
# Boundary: pure analysis modules must not depend on trading core libraries
# (trading.portfolio, trading.orders, trading.simulation, etc.).
#
# Allowed exceptions: see linter_exceptions.conf (arch_layer entries).

set -e

ANALYSIS_DIR="$(dirname "$0")/../../analysis"
EXCEPTIONS_CONF="$(dirname "$0")/linter_exceptions.conf"

# Build allowed-dir pattern from exceptions conf.
ALLOWED_PATTERN=""
if [ -f "$EXCEPTIONS_CONF" ]; then
  while IFS= read -r line; do
    case "$line" in
      '#'* | '') continue ;;
    esac
    linter=$(printf '%s' "$line" | awk '{print $1}')
    path=$(printf '%s' "$line" | awk '{print $2}')
    if [ "$linter" = "arch_layer" ] && [ -n "$path" ]; then
      if [ -n "$ALLOWED_PATTERN" ]; then
        ALLOWED_PATTERN="${ALLOWED_PATTERN}|${path}"
      else
        ALLOWED_PATTERN="${path}"
      fi
    fi
  done < "$EXCEPTIONS_CONF"
fi

_is_allowed() {
  [ -z "$ALLOWED_PATTERN" ] && return 1
  printf '%s' "$1" | grep -qE "$ALLOWED_PATTERN"
}

# Find dune files that reference trading.* (trading core libraries)
VIOLATIONS=$(
  find "$ANALYSIS_DIR" -name "dune" \
    | while read -r f; do
        _is_allowed "$f" && continue
        if grep -qE '\btrading\.(portfolio|orders|simulation|engine|strategy|base)\b' "$f"; then
          echo "$f"
        fi
      done
)

if [ -n "$VIOLATIONS" ]; then
  echo "FAIL: architecture layer violation — analysis/ module imports from trading/trading/:"
  echo "$VIOLATIONS"
  echo ""
  echo "Add an arch_layer exception to linter_exceptions.conf if this dependency is intentional."
  exit 1
fi

echo "OK: no unexpected analysis/ -> trading/trading/ imports found."
