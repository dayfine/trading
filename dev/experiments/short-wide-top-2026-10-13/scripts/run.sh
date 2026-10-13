#!/bin/sh
# Regenerate every result from the repo root (host only, no container, ~10 min). DATA= points at the bar store
# (default data/). The full event table is committed split by breakdown year (results/events/<year>.csv, one header
# each) because jj refuses files over 1 MB.
set -e
E=dev/experiments/short-wide-top-2026-10-13; W=${OUT:-.sweep-output/short-wide-top/events}
OUT=$W sh $E/scripts/run_events.sh          # -> $W.csv
sh $E/scripts/summarize.sh $W.csv           # -> results/events/<year>.csv, results/summary-floor{5,17}.txt
