#!/bin/sh
# For each symbol: adj close at the last bar <= each date key. Output symbol,datekey,close,bardate
W=/tmp/yr-run; : > $W/px.csv
while read s; do
  f=data/$(echo $s | cut -c1)/$(echo $s | rev | cut -c1)/$s/data.csv
  [ -f "$f" ] || continue
  awk -F, -v s="$s" 'NR==FNR { k[++nk]=$1; next }
    FNR==1 { for(i=1;i<=NF;i++){ if($i=="adjusted_close") ac=i; if($i=="date") d=i }; next }
    { dt=$d; p=$ac; for(i=1;i<=nk;i++) if (dt<=k[i]) { last[i]=p; lastd[i]=dt } }
    END { for(i=1;i<=nk;i++) if (i in last) printf "%s,%s,%s,%s\n", s, k[i], last[i], lastd[i] }' $W/datekeys.txt "$f" >> $W/px.csv
done < $W/symbols.txt
echo "PX DONE $(wc -l < $W/px.csv)" >> $W/px.csv.done
