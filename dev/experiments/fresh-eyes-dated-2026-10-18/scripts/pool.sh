#!/bin/sh
# pool.sh <date> <date dir> <groups>: step B of the reader's day (plan §3), mechanical, no model.
# <groups>: the favoured sectors from step A, separated by '|' (names as in results/market/sector-strength.csv),
# or "all". Needs <date dir>/ours/top.csv (ours.sh) for our screener's list.
#   1. The PIT top-3000 members of the list in force on the date (list Y applies from Y-05-31; membership.txt of
#      the setup map) that still trade on it (a bar within 10 days; pool_scan.awk).
#   2. The neutral filter: close >= (1 - NEAR_HIGH) x the 52-week high (NEAR_HIGH default 0.25) and 20-day dollar
#      volume >= DV_FLOOR (default 1,000,000, the strategy's min_entry_dollar_adv).
#   3. In a favoured group. data/sectors.csv is survivor-only, so a member with no sector row is mostly a stock
#      that later died; leaving it out would tilt the pool toward survivors. POOL_UNKNOWN=1 (default) keeps such
#      members in the pool whatever the groups; 0 drops them.
#   4. Our screener's list for the week (every salt's top.csv names) is always added, unlabelled, filter or not,
#      as long as the stock trades on the date.
#   5. Capped at POOL_MAX names (default 120): our names first, the rest drawn at random (seed from the date).
# Writes <date dir>/pool.csv: pseudo,symbol,src,sector (src = ours|filter, never shown to the reader) in a random
# order, and the pseudonym store <date dir>/store/<a>/<b>/<PSEUDO> -> the real symbol's data dir (plus SPY), so the
# 2026-10-13 renderers draw every page under the pseudonym. Pseudonyms are four random capitals, unique per date.
# Run from the repo root. DATA = the daily store.
set -e
d=$1; DD=$2; G=$3
S0=dev/experiments/fresh-eyes-2026-10-13/scripts; S=dev/experiments/fresh-eyes-dated-2026-10-18/scripts
DATA=${DATA:-/Users/difan/Projects/trading-1/data}
MEM=${MEM:-dev/experiments/short-setup-map-2026-10-12/results/membership.txt}
NEAR_HIGH=${NEAR_HIGH:-0.25}; DV_FLOOR=${DV_FLOOR:-1000000}; POOL_UNKNOWN=${POOL_UNKNOWN:-1}; POOL_MAX=${POOL_MAX:-120}
[ -s "$DD/ours/top.csv" ] || { echo "pool.sh: run ours.sh first ($DD/ours/top.csv)" >&2; exit 2; }
T=$DD/pool.tmp; mkdir -p "$T"
y=$(printf %s "$d" | cut -c1-4); md=$(printf %s "$d" | cut -c6-10)
[ "$md" \< 05-31 ] && y=$((y - 1))
# Members of list y with a daily file.
awk -v y="$y" '{ for (i = 2; i <= NF; i++) if ($i == y) { print $1; break } }' "$MEM" | while read -r s; do
  f=$DATA/$(printf %s "$s" | cut -c1)/$(printf %s "$s" | rev | cut -c1)/$s/data.csv; [ -f "$f" ] && echo "$f"; done > "$T/files.txt"
awk -F, 'NR > 1 { print $3 }' "$DD/ours/top.csv" | sort -u > "$T/ours.txt"
while read -r s; do
  f=$DATA/$(printf %s "$s" | cut -c1)/$(printf %s "$s" | rev | cut -c1)/$s/data.csv; [ -f "$f" ] && echo "$f"; done < "$T/ours.txt" >> "$T/files.txt"
sort -u "$T/files.txt" | xargs awk -F, -v date="$d" -f $S0/days.awk -f $S/pool_scan.awk > "$T/scan.csv"
awk -F, -v g="$G" -v nh="$NEAR_HIGH" -v floor="$DV_FLOOR" -v unk="$POOL_UNKNOWN" -v max="$POOL_MAX" -v seed="$(printf %s "$d" | tr -d -)" \
  -f $S/pool_pick.awk "$T/ours.txt" "$DATA/sectors.csv" "$T/scan.csv" > "$T/pool.csv"
# The pseudonym store.
rm -rf "$DD/store"; mkdir -p "$DD/store/S/Y"; ln -s "$DATA/S/Y/SPY" "$DD/store/S/Y/SPY"
awk -F, 'NR > 1 { print $1, $2 }' "$T/pool.csv" | while read -r p s; do
  a=$(printf %s "$p" | cut -c1); b=$(printf %s "$p" | rev | cut -c1); mkdir -p "$DD/store/$a/$b"
  ln -s "$DATA/$(printf %s "$s" | cut -c1)/$(printf %s "$s" | rev | cut -c1)/$s" "$DD/store/$a/$b/$p"
done
mv "$T/pool.csv" "$DD/pool.csv"; rm -rf "$T"
echo "pool.sh: $d list $y groups '$G': $(awk -F, 'NR > 1 { n[$3]++ } END { printf "%d ours, %d filter", n["ours"], n["filter"] }' "$DD/pool.csv")"
