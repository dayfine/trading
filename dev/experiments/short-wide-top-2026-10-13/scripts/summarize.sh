#!/bin/sh
# Split the event table by breakdown year into results/events/ and write the two summaries. Usage: summarize.sh <events.csv>
set -e
E=dev/experiments/short-wide-top-2026-10-13
rm -rf $E/results/events; mkdir -p $E/results/events
awk -F, -v d=$E/results/events 'NR==1{h=$0; next} {f=d"/"substr($2,1,4)".csv"; if(!(f in s)){print h > f; s[f]=1} print >> f}' "$1"
for f in 5 17; do
  cat $E/results/events/*.csv | awk 'NR==1 || !/^sym,/' | awk -F, -v floor=$f -f $E/scripts/analyze.awk > $E/results/summary-floor$f.txt
done
