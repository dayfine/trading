#!/bin/sh
# ra_one.sh <outdir> <SYM>: one symbol through ra_events.awk. Run from the repo root. Env: A (this folder), DATA (bar store).
O=$1; s=$2; D=${DATA:-data}
A=${A:-dev/experiments/short-wide-top-2026-10-13/results/analysis}
M=dev/experiments/short-setup-map-2026-10-12/results/membership.txt
SPYW=dev/experiments/index-hedge-screen-2026-10-12/results/spy-weekly-stage.csv
a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1); p=$D/$a/$b/$s/data.csv
[ -f "$p" ] || exit 0
m=$(grep "^$s " $M | cut -d" " -f2-)
awk -F, -v sym="$s" -v mem="$m" -f $A/ra_events.awk $SPYW $D/S/Y/SPY/data.csv "$p" > "$O/$s.out"
