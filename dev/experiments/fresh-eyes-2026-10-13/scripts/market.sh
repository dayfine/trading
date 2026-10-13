#!/bin/sh
# Market series for the fresh-eyes charts (plan §3). Run from the repo root; DATA = daily store (default data).
# Writes results/market/: spy-weekly.csv (weekly.sh SPY), ad-weekly.csv (ad.awk), sector-strength.csv
#   week,sector,median_26w,n,spy_26w,rel   (rel = sector median 26-week return - SPY's 26-week return)
# Sector members: symbols in that week's PIT top-3000 list (list Y applies from Y-05-31) with a sector in
# data/sectors.csv. sectors.csv is survivor-only (a known defect), so delisted members without a sector are
# missing; the n column shows how many members each median uses.
set -e
E=dev/experiments/fresh-eyes-2026-10-13; S=$E/scripts; DATA=${DATA:-data}; M=$E/results/market
B=trading/test_data/breadth; MEM=dev/experiments/short-setup-map-2026-10-12/results/membership.txt
TMP=${TMPDIR:-/tmp}/fe-market-$$; mkdir -p $M $TMP
DATA=$DATA sh $S/weekly.sh SPY > $M/spy-weekly.csv
awk -f $S/days.awk -f $S/ad.awk $B/nyse_advn.csv $B/nyse_decln.csv $B/synthetic_advn.csv $B/synthetic_decln.csv > $M/ad-weekly.csv
[ "$1" = "--no-sectors" ] && { rm -rf $TMP; wc -l $M/*.csv; exit 0; }
# Every Friday 2000-01-07..2026-06-26.
awk -v from=2000-01-07 -v to=2026-06-26 -f $S/days.awk -f $S/fridays.awk > $TMP/dates.txt
{ echo "$DATA/S/Y/SPY/data.csv"
  cut -d' ' -f1 $MEM | while read -r s; do
    a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1); f=$DATA/$a/$b/$s/data.csv
    [ -f "$f" ] && echo "$f"; done; } > $TMP/files.txt
xargs awk -f $S/sector.awk $TMP/dates.txt $MEM $DATA/sectors.csv < $TMP/files.txt > $TMP/returns.csv
sort -t, -k1,1 -k2,2 -k3,3g $TMP/returns.csv | awk -F, '
  { k = $1 "," $2; if (k != p && p != "") out(); if (k != p) { n = 0; p = k }; v[++n] = $3 }
  END { out() }
  function out() { print p "," v[int((n + 1) / 2)] "," n }' > $TMP/median.csv
awk -F, 'NR == FNR { if ($2 == "SPY") spy[$1] = $3; next }
  $2 != "SPY" && ($1 in spy) { printf "%s,%s,%s,%s,%s,%.5f\n", $1, $2, $3, $4, spy[$1], $3 - spy[$1] }' \
  $TMP/median.csv $TMP/median.csv | { echo "week,sector,median_26w,n,spy_26w,rel"; cat; } > $M/sector-strength.csv
rm -rf $TMP
wc -l $M/*.csv
