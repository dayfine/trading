#!/bin/bash
# (a) forward-return-vs-extension sampler. stdin: symbol,entry_date,exit_date,stage_kind
DATA=/workspaces/trading-1/data
echo "symbol,date,wk,ext,fwd20,fwd60,stage_kind"
while IFS=, read -r sym ed xd sk; do
  f="${sym:0:1}"; l="${sym: -1}"; csv="$DATA/$f/$l/$sym/data.csv"
  [ -f "$csv" ] || continue
  awk -F, -v sym="$sym" -v ed="$ed" -v xd="$xd" -v sk="$sk" '
  NR>1 && $1!="" {
    n++; d[n]=$1; c[n]=$6+0
    s150+=c[n]; if(n>150) s150-=c[n-150]
    sma[n]=(n>=150)? s150/150 : 0
  }
  END{
    si=0
    for(i=1;i<=n;i++){gd=d[i];gsub(/-/,"",gd); ge=ed;gsub(/-/,"",ge); if(gd+0>=ge+0){si=i;break}}
    if(si>0){
      cnt=0
      for(i=si;i<=n;i+=5){
        gd=d[i];gsub(/-/,"",gd); gx=xd;gsub(/-/,"",gx)
        if(gd+0>gx+0)break
        if(sma[i]>0){
          ext=c[i]/sma[i]-1
          f20=(i+20<=n && c[i]>0)? c[i+20]/c[i]-1 : "NA"
          f60=(i+60<=n && c[i]>0)? c[i+60]/c[i]-1 : "NA"
          print sym","d[i]","cnt","ext","f20","f60","sk
        }
        cnt++
      }
    }
  }' "$csv"
done
