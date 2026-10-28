#!/bin/sh
# CancelEntry construction-site census (dev/status/trade-audit.md, R5).
#
# The closed list of cancel reasons (test_cancel_reason_closed_list.exe) only
# sees producers it drives; a new producer in a third module would leave it
# green. This check fails when the set of production `CancelEntry { ... }`
# construction sites differs from KNOWN below, naming each new or missing one.
#
# Counted: lines matching `CancelEntry {` under trading/trading, excluding
# `.mli`, test dirs / test_*.ml, and match arms (line starts with `|`).
# Site identity is "path:count" (count of construction lines in that file).
#
# Adding a producer on purpose: add its "path:count" line to KNOWN here and
# update the closed-list docstrings/test in the same PR.
#
# Usage: cancelentry_census_check.sh [ROOT]   (default: git repo root)
# Test override: CANCELENTRY_KNOWN (newline-separated, replaces KNOWN).
# Scans the real tree at RUN TIME; the dune rule needs (universe).
. "$(dirname "$0")/_check_lib.sh"

ROOT="${1:-$(repo_root)}"
KNOWN="${CANCELENTRY_KNOWN-trading/trading/simulation/lib/cancel_handler.ml:1
trading/trading/simulation/lib/delisted_ticket_cancel.ml:1
trading/trading/weinstein/strategy/lib/entry_ticket_suspend.ml:1
trading/trading/weinstein/strategy/lib/entry_ticket_ttl.ml:1
trading/trading/weinstein/strategy/lib/short_ticket_policy.ml:1
trading/trading/weinstein/strategy/lib/split_ticket_cancel.ml:1}"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
printf '%s\n' "$KNOWN" | sed '/^$/d' | sort > "$tmp/known"

cd "$ROOT" || exit 2
find trading/trading -name '*.ml' ! -path '*/_build/*' ! -path '*/test/*' \
    ! -name 'test_*' 2>/dev/null |
  while read -r f; do
    n=$(grep -E 'CancelEntry *\{' "$f" | grep -cvE '^[[:space:]]*\|')
    [ "$n" -gt 0 ] && echo "$f:$n"
  done | sort > "$tmp/found"

new=$(comm -13 "$tmp/known" "$tmp/found")
gone=$(comm -23 "$tmp/known" "$tmp/found")
if [ -n "$new" ] || [ -n "$gone" ]; then
  echo "FAIL: cancelentry census: production CancelEntry construction sites changed"
  [ -z "$new" ] || printf '%s\n' "$new" | sed 's/^/  NEW (or count changed): /'
  [ -z "$gone" ] || printf '%s\n' "$gone" | sed 's/^/  MISSING (or count changed): /'
  echo "  update KNOWN in cancelentry_census_check.sh and the closed-list docs/test"
  exit 1
fi
echo "OK: cancelentry census: $(wc -l < "$tmp/known" | tr -d ' ') sites"
