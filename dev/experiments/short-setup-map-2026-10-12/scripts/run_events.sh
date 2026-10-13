#!/bin/sh
# Extract every symbol's breakdown events (host only; no container). Run from the repo root.
# Inputs: .sweep-output/short-setup-map/stages/<SYM>.csv (stage_chart replay), data/ bars + dividends,
# results/membership.txt (PIT top-3000 v12 lists), the index-hedge screen's SPY weekly stage.
E=dev/experiments/short-setup-map-2026-10-12
OUT=${OUT:-.sweep-output/short-setup-map/events}
mkdir -p "$OUT"
cut -d' ' -f1 $E/results/membership.txt | xargs -P 4 -n 1 -I{} sh $E/scripts/event_one.sh {} "$OUT"
{ cat $E/scripts/header.txt; find "$OUT" -name '*.csv' -exec cat {} +; } > $E/results/events.csv
