#!/bin/bash
# stdin: symbol,date,tag ; out: symbol,date,tag,fwd20,fwd60,ext  (one CSV pass per symbol)
DATA=/workspaces/trading-1/data
IN=$(cat); echo "symbol,date,tag,fwd20,fwd60,ext"
printf '%s\n' "$IN" | sort -t, -k1,1 | awk -F, '{print $1}' | uniq | while read -r sym; do
  [ -z "$sym" ] && continue
  f="${sym:0:1}"; l="${sym: -1}"; csv="$DATA/$f/$l/$sym/data.csv"
  reqs=$(printf '%s\n' "$IN" | awk -F, -v s="$sym" '$1==s{print $2","$3}')
  if [ ! -f "$csv" ]; then printf '%s\n' "$reqs" | awk -F, -v s="$sym" '{print s","$1","$2",NA,NA,NA"}'; continue; fi
  awk -F, -v sym="$sym" -v reqs="$reqs" '
  BEGIN{ nr=split(reqs,rr,"\n"); for(j=1;j<=nr;j++){split(rr[j],a,","); rq_d[j]=a[1]; rq_t[j]=a[2]} }
  NR>1 && $1!="" { n++; d[n]=$1; c[n]=$6+0; s150+=c[n]; if(n>150)s150-=c[n-150]; sma[n]=(n>=150)?s150/150:0 }
  END{
    for(j=1;j<=nr;j++){
      dt=rq_d[j]; si=0; ge=dt; gsub(/-/,"",ge)
      for(i=1;i<=n;i++){gd=d[i];gsub(/-/,"",gd); if(gd+0>=ge+0){si=i;break}}
      if(si==0){print sym","dt","rq_t[j]",NA,NA,NA"; continue}
      f20=(si+20<=n && c[si]>0)? c[si+20]/c[si]-1 : "NA"
      f60=(si+60<=n && c[si]>0)? c[si+60]/c[si]-1 : "NA"
      ext=(sma[si]>0)? c[si]/sma[si]-1 : "NA"
      print sym","dt","rq_t[j]","f20","f60","ext
    }
  }' "$csv"
done
