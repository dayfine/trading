#!/bin/sh
# pilot_summary.sh <runs dir>: per-symbol calls, tokens, cost, wall, actions and trades for the pilot.
for d in "$1"/*/; do
  s=$(basename "$d")
  awk -F, -f dev/experiments/fresh-eyes-2026-10-13/scripts/pilot_summary.awk "$d/calls.csv" "$d/trades.csv" "$d/log.csv"
done
