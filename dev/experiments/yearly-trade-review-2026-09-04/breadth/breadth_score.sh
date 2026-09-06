#!/bin/sh
# breadth_score.sh — weekly breadth series + gate-rule scoring against the record and the 14% arm.
# Inputs: breadth_all_daily.csv (date,n,above150,NH,NL,adv,dec), macro.txt (date trend), trades.csv files.
W=/tmp/yr-run; cd /Users/difan/Projects/trading-1
REC=dev/experiments/record-rebase-2026-09-03/results/rec26y-new-s0-trades.csv
ARM=.sweep-output/sw0905/sw26y-w14-D-s0-trades.csv
# 1. daily state file: date, pct_above, nl_pct, nh, ad_cum, idx_4wk, idx_vs_ma150
awk -F, 'NR==FNR { if(FNR==1){for(i=1;i<=NF;i++){if($i=="adjusted_close")ac=i;if($i=="date")d=i}; next}; n++; c[n]=$ac; dt[n]=$d; s+=$ac; if(n>150) s-=c[n-150]; if(n>=150){ r4[$d]=100*(c[n]/c[n-20]-1); vma[$d]=100*(c[n]/(s/150)-1) }; next }
  { ad+=$6-$7; if($2>=500) printf "%s,%.1f,%.2f,%d,%d,%.1f,%.1f\n", $1, 100*$3/$2, 100*$5/$2, $4, ad, r4[$1], vma[$1] }' data/G/X/GSPC.INDX/data.csv $W/breadth_all_daily.csv > $W/state_daily.csv
wc -l < $W/state_daily.csv
