#!/bin/sh
# One symbol: event_one.sh <OUT dir> <SYM>. Called by run_events.sh. DATA (default data) is the bar store.
OUT=$1; s=$2; D=${DATA:-data}
E=dev/experiments/short-wide-top-2026-10-13
M=dev/experiments/short-setup-map-2026-10-12/results/membership.txt
SPYW=dev/experiments/index-hedge-screen-2026-10-12/results/spy-weekly-stage.csv
a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1); p=$D/$a/$b/$s
[ -f "$p/data.csv" ] || exit 0
m=$(grep "^$s " $M | cut -d" " -f2-)
awk -F, -v sym="$s" -v mem="$m" -f $E/scripts/events.awk "$SPYW" $D/S/Y/SPY/data.csv "$p/data.csv" > "$OUT/$s.csv"
