#!/bin/bash
O=/tmp/p0_out
echo "===== (B) PER-EVENT rotation difference: diff = C_fwd - P_mostext_fwd (realizable test) ====="
awk -F, '
FILENAME~/skip_fwd/ && FNR>1 && $4!="NA"{ v=$4+0; if(v<=5&&v>=-0.95) sc[$2]=v }
FILENAME~/held_fwd/ && FNR>1 && $4!="NA" && $6!="NA"{ v=$4+0; if(v<=5&&v>=-0.95){ d=$2; if(!(d in mx)||$6+0>mx[d]){mx[d]=$6+0; pf[d]=v} } }
FILENAME~/skips_top/{ d=$1; if(d in sc && d in pf) print sc[d]-pf[d] }
' $O/skip_fwd.csv $O/held_fwd.csv $O/skips_top.csv | sort -g | awk '
{v[NR]=$1; s+=$1; if($1>0)pos++}
END{n=NR; if(n==0){print "n=0"; exit}
 printf "n=%d  mean=%+.4f  median=%+.4f  %%C>P=%.1f%%\n",n,s/n,v[int(n*0.5)],100*pos/n
 printf "deciles diff: p10=%+.4f p25=%+.4f p50=%+.4f p75=%+.4f p90=%+.4f  (min %+.3f max %+.3f)\n",v[int(n*0.1)],v[int(n*0.25)],v[int(n*0.5)],v[int(n*0.75)],v[int(n*0.9)],v[1],v[n]}'

echo; echo "===== (A) distribution: fresh-early vs mature-extended fwd20 (annualized x13) ====="
for grp in early mature; do
awk -F, -v g="$grp" 'NR>1 && $5!="NA"{v=$5+0; if(v>5||v<-0.95)next; w=$3+0;e=$4+0;k=$7;
  if(g=="early" && w<=4 && k=="early")print v;
  if(g=="mature" && w>=27 && e>0.2)print v}' $O/fwd_a.csv | sort -g | awk -v g="$grp" '
  {v[NR]=$1;s+=$1}
  END{n=NR; if(n==0){print g" n=0";exit}
   med=v[int(n*0.5)]; mean=s/n;
   printf "%-7s n=%-4d mean=%+.4f(%+.1f%%/yr) median=%+.4f  p10=%+.4f p25=%+.4f p75=%+.4f p90=%+.4f\n",g,n,mean,mean*13*100,med,v[int(n*0.1)],v[int(n*0.25)],v[int(n*0.75)],v[int(n*0.9)]}'
done
