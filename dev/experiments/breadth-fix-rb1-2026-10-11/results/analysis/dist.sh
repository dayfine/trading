# usage: sh dist.sh <file of numbers> <label>
sort -g "$1" | awk -v L="$2" '{v[NR]=$1; s+=$1} END{n=NR; if(n==0){print L, "n=0"; exit} 
 p10=v[int(0.10*(n-1))+1]; p25=v[int(0.25*(n-1))+1]; p50=v[int(0.50*(n-1))+1]; p75=v[int(0.75*(n-1))+1]; p90=v[int(0.90*(n-1))+1];
 w=0; for(i=1;i<=n;i++) if(v[i]>0) w++;
 t1=s-v[n]; t3=s-v[n]-(n>1?v[n-1]:0)-(n>2?v[n-2]:0);
 printf "%-16s n=%3d sum=%9.0f mean=%8.0f med=%7.0f p10=%8.0f p25=%7.0f p75=%7.0f p90=%8.0f win%%=%4.1f | sum ex-top1=%8.0f ex-top3=%8.0f\n", L, n, s, s/n, p50, p10, p25, p75, p90, 100*w/n, t1, t3}'
