#!/bin/sh
# Regenerate every result from the repo root (host only, ~15 min). The stage replay that feeds it is
# scripts/replay.sh (container, stage_chart.exe, ~1.5 h) writing .sweep-output/short-setup-map/stages/.
# The full event table is committed split by breakdown year (results/events/<year>.csv, one header each).
set -e
E=dev/experiments/short-setup-map-2026-10-12; W=.sweep-output/short-setup-map
sh $E/scripts/membership.sh
OUT=$W/events sh $E/scripts/run_events.sh          # -> $E/results/events.csv (temporary)
sh $E/scripts/run_sector.sh                          # -> $E/results/sector-median.csv
awk -F, -f $E/scripts/join_group.awk $E/results/sector-median.csv data/sectors.csv $E/results/events.csv > $W/events-full.csv
rm -f $E/results/events.csv; rm -rf $E/results/events; mkdir -p $E/results/events
awk -F, -v d=$E/results/events 'NR==1{h=$0; next} {f=d"/"substr($2,1,4)".csv"; if(!(f in s)){print h > f; s[f]=1} print >> f}' $W/events-full.csv
for f in 5 17; do
  cat $E/results/events/*.csv | awk 'NR==1 || !/^sym,/' | awk -F, -v floor=$f -f $E/scripts/analyze.awk > $E/results/summary-floor$f.txt
done
