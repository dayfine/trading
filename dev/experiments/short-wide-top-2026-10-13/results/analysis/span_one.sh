#!/bin/sh
# span_one.sh <scratch dir> <SYM>: calendar span and largest bar gap of each committed event's +120-bar window.
W=$1; s=$2; D=${DATA:-data}; A=${A:-dev/experiments/short-wide-top-2026-10-13/results/analysis}
a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1)
grep "^$s," $W/ev_entries.csv > $W/span/$s.in
awk -F, -v SYM="$s" -f $A/span.awk $W/span/$s.in $D/$a/$b/$s/data.csv
