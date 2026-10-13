#!/bin/sh
# One symbol: event_one.sh <SYM> <OUT dir>. Called by run_events.sh.
s=$1; OUT=$2
E=dev/experiments/short-setup-map-2026-10-12
SPYW=dev/experiments/index-hedge-screen-2026-10-12/results/spy-weekly-stage.csv
ST=.sweep-output/short-setup-map/stages
[ -f "$ST/$s.csv" ] || exit 0
a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1); p=data/$a/$b/$s
[ -f "$p/data.csv" ] || exit 0
dv=$p/dividends.csv; [ -f "$dv" ] || dv=/dev/null
m=$(grep "^$s " $E/results/membership.txt | cut -d" " -f2-)
awk -F, -v sym="$s" -v mem="$m" -f $E/scripts/events.awk "$SPYW" data/S/Y/SPY/data.csv "$ST/$s.csv" "$p/data.csv" "$dv" > "$OUT/$s.csv"
