#!/bin/sh
# market_pages.sh <pages dir> [<from> <to>] [<jobs>]: pre-render the shared market pack for every Friday in a range
# (default 2000-01-07..2026-06-26, 4 parallel jobs) into <pages dir>/market, skipping cuts already rendered. The
# market pages depend only on the cut, so one render serves all 100 symbols (step.sh reads the same directory).
# Run from the repo root. Worker: market_one.sh.
set -e
P=$1; from=${2:-2000-01-07}; to=${3:-2026-06-26}; jobs=${4:-4}
S=dev/experiments/fresh-eyes-2026-10-13/scripts; mkdir -p "$P/market"
awk -v from="$from" -v to="$to" -f $S/days.awk -f $S/fridays.awk | while read -r c; do
  [ -s "$P/market/MARKET-$c-full.png" ] && [ -s "$P/market/MARKET-$c-5y.png" ] || echo "$c"
done | xargs -P "$jobs" -n 1 sh $S/market_one.sh "$P/market"
