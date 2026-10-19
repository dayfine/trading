#!/bin/sh
DS=/Users/difan/Projects/trading-1/data
R=/Users/difan/Projects/trading-1/.claude/worktrees/agent-ad5a719c1e2abb7df/dev/experiments/fresh-eyes-dated-2026-10-18/results/run
echo "date sym trigger reader_stop r_dist | nearest8 n8_vs_trig | nearest7 | ma30 ma_vs_trig | reader stop vs nearest8 / ma30"
for p in "2003-05-23 ASL" "2005-01-07 GIS" "2005-01-07 WKC" "2007-02-23 CMI" "2013-08-30 KALU" "2013-08-30 AKRX" "2016-11-11 MTB" "2016-11-11 EXPO" "2016-11-11 BK" "2016-11-11 SLF" "2017-07-14 AMGN" "2018-09-07 DCI" "2023-01-20 WPC"; do
  set -- $p; d=$1; s=$2
  f=$DS/$(printf %s "$s" | cut -c1)/$(printf %s "$s" | rev | cut -c1)/$s/data.csv
  tr=$(awk -F, -v s=$s 'NR>1 && $2==s {print $4}' $R/$d/orders.csv); st=$(awk -F, -v s=$s 'NR>1 && $2==s {print $6}' $R/$d/orders.csv)
  n8=$(awk -F, -v want=$d -v lb=90 -v mc=0.08 -f nearest_raw.awk $f); n7=$(awk -F, -v want=$d -v lb=90 -v mc=0.07 -f nearest_raw.awk $f)
  ma=$(awk -F, -v want=$d -f ma30f.awk $f | cut -d, -f1)
  echo "$d $s $tr $st $n8 $n7 $ma" | awk '{ t=$3; r=$4; n8=$5; n7=$6; m=$7; printf "%s %-5s %8.2f %8.2f %5.1f%% | %8s %6s | %8s | %8.2f %5.1f%% | %s / %s\n", $1, $2, t, r, 100*(t-r)/t, (n8==""?"none":sprintf("%.2f",n8)), (n8==""?"":sprintf("%.1f%%",100*(t-n8)/t)), (n7==""?"none":sprintf("%.2f",n7)), m, 100*(t-m)/t, (n8==""?"-":(r<n8?"below":"above")), (r<m?"below":"above") }'
done
