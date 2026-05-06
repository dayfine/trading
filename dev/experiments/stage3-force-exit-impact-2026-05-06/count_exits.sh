#!/usr/bin/env bash
# count_exits.sh — print exit_trigger counts from a trades.csv
# Usage: count_exits.sh <trades.csv>
set -eu

f="${1:?usage: count_exits.sh <trades.csv>}"
if [ ! -f "$f" ]; then
  echo "trades.csv not found: $f" >&2
  exit 1
fi

# trades.csv header column 13 is exit_trigger (0-indexed: column 12)
# Skip header line, extract column, count.
awk -F',' 'NR>1 { print $13 }' "$f" \
  | sort \
  | uniq -c \
  | sort -rn
