#!/bin/sh
# Daily breadth aggregates over the per-year PIT universes, 1999-06..2026-08:
# date, n, n_above150, NH52, NL52, advances, declines
W=/tmp/yr-run; cd /Users/difan/Projects/trading-1
ls $(cut -d, -f2 $W/members.csv | sort -u | awk '{ printf "data/%s/%s/%s/data.csv\n", substr($1,1,1), substr($1,length($1),1), $1 }') 2>/dev/null > $W/files_all.txt
awk -F, '
  FILENAME==ARGV[1] { mem[$1","$2]=1; next }
  FNR==1 { for(i=1;i<=NF;i++){ if($i=="adjusted_close") ac=i; if($i=="date") d=i }; n=0; sum=0; split(FILENAME,p,"/"); s=p[4]; next }
  { n++; c[n]=$ac; dt[n]=$d; sum+=$ac; if(n>150) sum-=c[n-150]
    if (n>=150) { y=substr($d,1,4); if (!mem[y","s]) next
      ma=sum/150; hi=c[n]; lo=c[n]; for(k=n-251;k<n;k++){ if(k<1) continue; if(c[k]>hi) hi=c[k]; if(c[k]<lo) lo=c[k] }
      tot[$d]++; if(c[n]>ma) ab[$d]++; if(c[n]>=hi) nh[$d]++; if(c[n]<=lo) nl[$d]++; if(c[n]>c[n-1]) adv[$d]++; else if(c[n]<c[n-1]) dec[$d]++ } }
  END { for(d in tot) printf "%s,%d,%d,%d,%d,%d,%d\n", d, tot[d], ab[d], nh[d], nl[d], adv[d], dec[d] }' $W/members.csv $(cat $W/files_all.txt) | sort > $W/breadth_all_daily.csv
echo "BREADTH DONE $(wc -l < $W/breadth_all_daily.csv)" > $W/breadth_all.done
