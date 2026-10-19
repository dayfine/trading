#!/bin/sh
R=${R:-dev/experiments/fresh-eyes-dated-2026-10-18/results/run}   # run from the repo root
echo "dir,side,N,K,sl_n,sl_k,ord_n,ord_k,filled"
for D in $R/[12]*; do
  b=$(basename $D); [ -f $D/pool.csv ] || { echo "$b,$(cat $D/side.txt),0,0,0,0,0,0,0"; continue; }
  awk -F, -v b=$b -v side=$(cat $D/side.txt) '
    FNR==1 { f++ }
    f==1 && FNR>1 { N++; src[$1]=$3; s2[$2]=$3; if ($3=="ours") K++ }
    f==2 && $1!="" { sn++; if (src[$1]=="ours") sk++ }
    f==3 && FNR>1 { on++; if (s2[$2]=="ours") ok++ }
    f==4 && FNR>1 && $4!="" { nf++ }
    END { printf "%s,%s,%d,%d,%d,%d,%d,%d,%d\n", b, side, N, K, sn, sk, on, ok, nf }' $D/pool.csv $D/shortlist.txt $D/orders.csv $D/reader-trades.csv
done
