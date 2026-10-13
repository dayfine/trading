#!/bin/sh
# Sector strength at every event date, joined onto events.csv as group_rel (sector median 26w return - SPY's).
E=dev/experiments/short-setup-map-2026-10-12
cut -d, -f2 $E/results/events.csv | tail -n +2 | sort -u > $E/results/event_dates.txt
{ echo data/S/Y/SPY/data.csv
  cut -d' ' -f1 $E/results/membership.txt | while read s; do
    a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1); f=data/$a/$b/$s/data.csv
    [ -f "$f" ] && echo "$f"; done; } > /tmp/ssm-files.txt
xargs awk -f $E/scripts/sector.awk $E/results/event_dates.txt $E/results/membership.txt data/sectors.csv < /tmp/ssm-files.txt \
  > .sweep-output/short-setup-map/sector-returns.csv
# Median per (date, sector); SPY's own return per date.
sort -t, -k1,1 -k2,2 -k3,3g .sweep-output/short-setup-map/sector-returns.csv | awk -F, '
  { k = $1 "," $2; if (k != p && p != "") out(); if (k != p) { n = 0; p = k }; v[++n] = $3 }
  END { out() }
  function out() { print p "," v[int((n + 1) / 2)] "," n }' > $E/results/sector-median.csv
awk -F, 'NR == FNR { if ($2 == "SPY") spy[$1] = $3; else m[$1, $2] = $3; next }
  FNR == 1 { next }
  { print }' $E/results/sector-median.csv /dev/null
