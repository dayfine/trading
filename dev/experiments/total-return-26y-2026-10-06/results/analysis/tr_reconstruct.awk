# Inputs: DTB3, divs.csv(sym,ex,amt), splits.csv(sym,date,factor), trades, open, equity
function jdn(s,   y,m,d,a,yy,mm){ y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0;
  a=int((14-m)/12); yy=y+4800-a; mm=m+12*a-3;
  return d+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045 }
function comm(q){ c=0.01*q; return (c<1?1:c) }
BEGIN{FS=","}
FNR==1 && f!=1 && f!=2{ }
FNR==1{f++; if(f==1||f==4||f==5||f==6) next}
f==1{ if($2!="" && $2!=".") rate[jdn($1)]=$2+0; next }
f==2{ if($3=="") next; nd[$1]++; dd[$1,nd[$1]]=jdn($2); da[$1,nd[$1]]=$3+0; next }
f==3{ ns[$1]++; sd[$1,ns[$1]]=jdn($2); sf[$1,ns[$1]]=$3+0; next }
f==4{ q=$8+0; e=jdn($3); x=jdn($4); flow[e]-= q*$6 + comm(q); flow[x]+= q*$6 + $9 - comm(q); np++; ps[np]=$1; pe[np]=e; px[np]=x; pq[np]=q; next }
f==5{ q=$5+0; e=jdn($3); flow[e]-= q*$4 + comm(q); np++; ps[np]=$1; pe[np]=e; px[np]=99999999; pq[np]=q; next }
f==6{ n++; rd[n]=jdn($1); rv[n]=$2+0; next }
END{
  # dividends per day
  for(p=1;p<=np;p++){ s=ps[p];
    for(j=1;j<=nd[s];j++){ d=dd[s,j]; if(d>pe[p] && d<=px[p] && d<=rd[n]){
        fac=1; for(k=1;k<=ns[s];k++){ if(sd[s,k]>d && sd[s,k]<=px[p]) fac*=sf[s,k] }
        dv[d]+= pq[p]/fac*da[s,j] } } }
  d0=jdn("2000-01-01"); cash=1000000; r=0;
  for(k=d0-30;k<d0;k++) if(k in rate) r=rate[k];
  i=1; ai=0; ad=0; Li=0; Ld=0; Lb=0; ti=0; td=0;
  for(d=d0; d<=rd[n]; d++){
    if(d in rate) r=rate[d];
    net=r-0.10; if(net<0) net=0;
    it=(cash>0?cash:0)*net/100/360;
    di=(d in dv)?dv[d]:0;
    ti+=it; td+=di; ai+=it; ad+=di; cash+=it+di;
    if(d in flow) cash+=flow[d];
    if(i<=n && rd[i]==d){ V=rv[i]; Li+=log(V/(V-ai)); Ld+=log(V/(V-ad)); Lb+=log(V/(V-ai-ad)); ai=0; ad=0; i++ }
  }
  printf "interest=%.0f dividends=%.0f L_int=%.4f L_div=%.4f L_both=%.4f terminal_cash=%.0f\n", ti, td, Li, Ld, Lb, cash
}
