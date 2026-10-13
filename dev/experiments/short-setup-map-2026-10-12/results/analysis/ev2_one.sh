#!/bin/sh
# One symbol: ev2_one.sh <SYM> <work dir>. Same inputs and event selection as scripts/event_one.sh + events.awk.
s=$1; W=$2
E=dev/experiments/short-setup-map-2026-10-12; A=${A:-$E/results/analysis}
SPYW=dev/experiments/index-hedge-screen-2026-10-12/results/spy-weekly-stage.csv
ST=.sweep-output/short-setup-map/stages
a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1); p=data/$a/$b/$s
m=$(grep "^$s " $E/results/membership.txt | cut -d" " -f2-)
awk -F, -v sym="$s" -v mem="$m" -f $A/ev2.awk "$SPYW" data/S/Y/SPY/data.csv "$ST/$s.csv" "$p/data.csv" > "$W/ev2/$s.csv"
