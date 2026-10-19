#!/bin/sh
# For each of the 24 decision dates, every name on salt-0's decision list for that week: floor scan class vs record outcome.
DS=/Users/difan/Projects/trading-1/data
R=/Users/difan/Projects/trading-1/.claude/worktrees/agent-ad5a719c1e2abb7df/dev/experiments/fresh-eyes-dated-2026-10-18/results/run
echo "date,week,rank,symbol,outcome,aoff,anchor_date,anchor,counter,depth,close,class,close_vs_floor"
for D in $R/[12][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]; do
  d=$(basename $D)
  [ -f $D/ours/top.csv ] || continue
  wk=$(awk -F, 'NR==2{print $2}' $D/ours/week.csv)
  awk -F, 'NR>1 && $1==0 {print $2","$3","$5}' $D/ours/top.csv | while IFS=, read -r rk s o; do
    f=$DS/$(printf %s "$s" | cut -c1)/$(printf %s "$s" | rev | cut -c1)/$s/data.csv
    if [ -f "$f" ]; then r=$(awk -F, -v want="$wk" -v lb=90 -v mc=0.08 -f floor.awk "$f"); else r="nofile"; fi
    echo "$d,$wk,$rk,$s,$o,$r"
  done
done
