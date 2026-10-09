# Extended copy of total-return-26y results/analysis/tr_reconstruct.awk.
# Inputs: 1 DTB3 (hdr), 2 divs (sym,ex,unadj,adj; no hdr), 3 splits (sym,date,factor; no hdr),
#         4 trades (hdr), 5 open (hdr), 6 equity (hdr), 7 event prices (sym,date,amt,prev_close,open,close; no hdr)
# -v CREDIT=1 adds dividends to cash (rb1); 0 = counterfactual only (rb0). -v CUT=0.05 special cut. -v EV=file event dump.
function jdn(s,   y,m,d,a,yy,mm){ y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0;
  a=int((14-m)/12); yy=y+4800-a; mm=m+12*a-3;
  return d+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045 }
function comm(q){ c=0.01*q; return (c<1?1:c) }
BEGIN{FS=","; if(CUT=="") CUT=0.05}
FNR==1{f++; if(f==1||f==4||f==5||f==6) next}
f==1{ if($2!="" && $2!=".") rate[jdn($1)]=$2+0; next }
f==2{ if($3=="") next; nd[$1]++; dd[$1,nd[$1]]=jdn($2); ds[$1,nd[$1]]=$2; da[$1,nd[$1]]=$3+0; next }
f==3{ ns[$1]++; sd[$1,ns[$1]]=jdn($2); sf[$1,ns[$1]]=$3+0; next }
f==4{ q=$8+0; e=jdn($3); x=jdn($4); flow[e]-= q*$6 + comm(q); flow[x]+= q*$6 + $9 - comm(q); np++; ps[np]=$1; pe[np]=e; px[np]=x; pq[np]=q; pid[np]=$20; next }
f==5{ q=$5+0; e=jdn($3); flow[e]-= q*$4 + comm(q); np++; ps[np]=$1; pe[np]=e; px[np]=99999999; pq[np]=q; pid[np]="open:"$1; next }
f==6{ n++; rd[n]=jdn($1); rs[n]=$1; rv[n]=$2+0; next }
f==7{ pc[$1","$2]=$4+0; next }
END{
  for(p=1;p<=np;p++){ s=ps[p];
    for(j=1;j<=nd[s];j++){ d=dd[s,j]; if(d>pe[p] && d<=px[p] && d<=rd[n]){
        fac=1; for(k=1;k<=ns[s];k++){ if(sd[s,k]>d && sd[s,k]<=px[p]) fac*=sf[s,k] }
        sh=pq[p]/fac; amt=da[s,j]; usd=sh*amt; k2=s","ds[s,j]; P=pc[k2];
        y=(P>0?amt/P:-1); cls=(y>=CUT?"S":"O"); if(P<=0) nomiss++;
        dv[d]+=usd; if(cls=="S") dvs[d]+=usd; else dvo[d]+=usd;
        if(EV!="") printf "%s,%s,%.6f,%.4f,%.6f,%.2f,%.2f,%s,%s\n", s, ds[s,j], amt, P, y, sh, usd, cls, pid[p] > EV } } }
  d0=jdn("2000-01-01"); cash=1000000; r=0;
  for(k=d0-30;k<d0;k++) if(k in rate) r=rate[k];
  i=1; ai=0; ad=0; ao=0; as=0; Li=0; Ld=0; Lb=0; Lo=0; Ls=0; ti=0; td=0; tdo=0; tds=0;
  for(d=d0; d<=rd[n]; d++){
    if(d in rate) r=rate[d];
    net=r-0.10; if(net<0) net=0;
    it=(cash>0?cash:0)*net/100/360;
    di=(d in dv)?dv[d]:0; dio=(d in dvo)?dvo[d]:0; dis=(d in dvs)?dvs[d]:0;
    ti+=it; td+=di; tdo+=dio; tds+=dis; ai+=it; ad+=di; ao+=dio; as+=dis; cash+=it+(CREDIT?di:0);
    if(d in flow) cash+=flow[d];
    if(i<=n && rd[i]==d){ V=rv[i]; Li+=log(V/(V-ai)); Ld+=log(V/(V-ad)); Lb+=log(V/(V-ai-ad)); Lo+=log(V/(V-ao)); Ls+=log(V/(V-as));
      if(DAY!="") printf "%s,%.2f,%.2f,%.2f,%.2f,%.2f\n", rs[i], V, cash, ai, ao, as > DAY;
      ai=0; ad=0; ao=0; as=0; i++ }
  }
  printf "interest=%.0f dividends=%.0f ord=%.0f spec=%.0f L_int=%.4f L_div=%.4f L_ord=%.4f L_spec=%.4f L_both=%.4f terminal_cash=%.0f nopx=%d\n", ti, td, tdo, tds, Li, Ld, Lo, Ls, Lb, cash, nomiss
}
