#!/bin/sh
# trace.sh SYM BREAKDOWN_WEEK: independent re-derivation of one event from raw bars (trace.awk), then the committed row.
s=$1; bd=$2; E=dev/experiments/short-setup-map-2026-10-12; A=${A:-$E/results/analysis}
a=$(printf %s "$s" | cut -c1); b=$(printf %s "$s" | rev | cut -c1)
echo "=== $s breakdown week $bd"
cat $E/results/events/${bd%%-*}.csv | awk -F, -v s="$s" -v bd="$bd" 'NR==1{for(k=1;k<=NF;k++)h[k]=$k;next} $1==s && $2==bd {printf "committed:"; for(k=1;k<=NF;k++) printf " %s=%s", h[k], $k; print ""}'
awk -F, -v bd="$bd" -f $A/trace.awk .sweep-output/short-setup-map/stages/$s.csv data/$a/$b/$s/data.csv data/S/Y/SPY/data.csv
