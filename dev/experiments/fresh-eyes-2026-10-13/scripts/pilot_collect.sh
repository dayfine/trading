#!/bin/sh
# pilot_collect.sh <runs dir> <out dir>: copy each symbol's calls.csv, trades.csv, log.csv, pauses.csv and shadow.csv
# (when present) and its raw answers (joined into decisions.csv, shadow-decisions.csv) from a pilot's run root into
# the committed results dir, plus summary.txt (pilot_summary.sh) and agreement.txt (agreement.sh, when a shadow ran).
# Run from the repo root.
S=dev/experiments/fresh-eyes-2026-10-13/scripts
for d in "$1"/*/; do
  s=$(basename "$d"); o=$2/$s; mkdir -p "$o"
  for f in calls.csv trades.csv log.csv pauses.csv shadow.csv; do [ -f "$d/$f" ] && cp "$d/$f" "$o/"; done
  awk -f $S/raw_join.awk "$d"/raw/*.txt > "$o/decisions.csv"
  ls "$d"/shadow-raw/*.txt > /dev/null 2>&1 && awk -f $S/raw_join.awk "$d"/shadow-raw/*.txt > "$o/shadow-decisions.csv"
done
sh $S/pilot_summary.sh "$1" > "$2/summary.txt"
ls "$1"/*/shadow.csv > /dev/null 2>&1 && sh $S/agreement.sh "$1" > "$2/agreement.txt"
