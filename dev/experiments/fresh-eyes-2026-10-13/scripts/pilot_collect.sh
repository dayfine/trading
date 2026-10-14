#!/bin/sh
# pilot_collect.sh <runs dir> <out dir>: copy each symbol's calls.csv, trades.csv, log.csv and its raw answers
# (joined into decisions.csv) from the pilot's run root into the committed results dir. Run from the repo root.
S=dev/experiments/fresh-eyes-2026-10-13/scripts
for d in "$1"/*/; do
  s=$(basename "$d"); o=$2/$s; mkdir -p "$o"
  cp "$d/calls.csv" "$d/trades.csv" "$d/log.csv" "$o/"
  awk -f $S/raw_join.awk "$d"/raw/*.txt > "$o/decisions.csv"
done
