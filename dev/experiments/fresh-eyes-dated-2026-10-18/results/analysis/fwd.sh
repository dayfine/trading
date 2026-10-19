#!/bin/sh
DS=/Users/difan/Projects/trading-1/data
R=${R:-dev/experiments/fresh-eyes-dated-2026-10-18/results/run}   # run from the repo root
F=$(dirname $0)/fwd.awk
echo "date,symbol,src,in_sl,in_ord,in_top0,base,r26,r52,r104,last,spy26,spy52,spy104"
for D in $R/[12][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]; do
  d=$(basename $D); [ "$(cat $D/side.txt)" = long ] || continue; [ -f $D/pool.csv ] || continue
  spy=$(awk -F, -v want=$d -f $F $DS/S/Y/SPY/data.csv | cut -d, -f2-4)
  awk -F, 'FNR==1{f++} f==1&&FNR>1{print $1","$2","$3} ' $D/pool.csv | while IFS=, read -r ps s src; do
    sl=0; grep -qx "$ps" $D/shortlist.txt && sl=1
    od=0; awk -F, -v s=$s 'NR>1 && $2==s {f=1} END {exit !f}' $D/orders.csv && od=1
    t0=0; awk -F, -v s=$s '$1==0 && $3==s {f=1} END {exit !f}' $D/ours/top.csv && t0=1
    f=$DS/$(printf %s "$s" | cut -c1)/$(printf %s "$s" | rev | cut -c1)/$s/data.csv
    if [ -f "$f" ]; then r=$(awk -F, -v want=$d -f $F "$f"); else r=",,,,"; fi
    echo "$d,$s,$src,$sl,$od,$t0,$r,$spy"
  done
done
