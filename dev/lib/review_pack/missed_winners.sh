#!/bin/sh
# Read existing --data-dir + staged run inputs; publish episodes and audit evidence.
# Coverage is the available bar store, not a reconstructed historical universe.
set -eu
LIB=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DATA=$1; RUN=$2
first=$(sed -n 2p "$RUN/equity_curve.csv" | cut -d, -f1)
last=$(tail -1 "$RUN/equity_curve.csv" | cut -d, -f1)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' 0 HUP INT TERM
for file in "$DATA"/?/?/*/data.csv; do [ ! -f "$file" ] || printf '%s\n' "$file"; done | LC_ALL=C sort > "$tmp/files"
while IFS= read -r file; do
  sym=$(basename "$(dirname "$file")")
  awk -v sym="$sym" -v first="$first" -v last="$last" -f "$LIB/missed_winners.awk" "$file"
done < "$tmp/files" > "$tmp/episodes"
: > "$tmp/audit"
[ ! -s "$RUN/trade_audit.sexp" ] || awk -f "$LIB/missed_audit.awk" "$RUN/trade_audit.sexp" > "$tmp/audit"
jq -Rn --argjson symbols "$(wc -l < "$tmp/files")" '
  [inputs | split("\t") | {sym:.[0], d:.[1], forward:(.[2]|tonumber), vr:(.[3]|tonumber), peak:.[4]}]
  | {symbols:$symbols, episodes:.}' < "$tmp/episodes" > "$tmp/result"
jq -Rn '[inputs | split("\t")]' < "$tmp/audit" > "$tmp/evidence"
jq --slurpfile evidence "$tmp/evidence" '. + {audit:$evidence[0]}' "$tmp/result"
