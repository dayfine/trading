#!/bin/sh
# Extract every member symbol's wide-top breakdown events (host only; no container). Run from the repo root.
# Inputs: data/ bars (DATA= overrides), the setup map's membership.txt, the index-hedge screen's SPY weekly stage.
E=dev/experiments/short-wide-top-2026-10-13
OUT=${OUT:-.sweep-output/short-wide-top/events}
mkdir -p "$OUT"
cut -d' ' -f1 dev/experiments/short-setup-map-2026-10-12/results/membership.txt |
  xargs -P 4 -n 1 sh $E/scripts/event_one.sh "$OUT"
{ cat $E/scripts/header.txt; find "$OUT" -name '*.csv' -exec cat {} +; } > "$OUT.csv"
