# Metrics from a (date,value) series. files: 1 DTB3 (hdr), 2 series (hdr). -v START=2000-01-01
function jdn(s,   y,m,d,a,yy,mm){ y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0;
  a=int((14-m)/12); yy=y+4800-a; mm=m+12*a-3;
  return d+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045 }
BEGIN{FS=","}
FNR==1{f++; next}
f==1{ if($2!="" && $2!=".") rate[jdn($1)]=$2+0; next }
f==2{ n++; dt[n]=$1; v[n]=$2+0; next }
END{ d0=(START!=""?jdn(START):jdn(dt[1])); r=0; for(k=d0-30;k<=d0;k++) if(k in rate) r=rate[k];
  # rf per calendar day accumulated between rows
  prevd=d0; v0=(V0!=""?V0+0:v[1]); peak=v0; mdd=0; i0=(V0!=""?1:2); pv=v0;
  for(i=i0;i<=n;i++){ dj=jdn(dt[i]); rf=0; for(k=prevd+1;k<=dj;k++){ if(k in rate) r=rate[k]; net=r-0.10; if(net<0) net=0; rf+=net/100/360 } prevd=dj;
    ret=v[i]/pv-1; pv=v[i]; m++; s1+=ret; s2+=ret*ret; e=ret-rf; e1+=e; e2+=e*e;
    if(v[i]>peak){peak=v[i]; pkd=dt[i]} dd=1-v[i]/peak; if(dd>mdd){mdd=dd; trd=dt[i]; pkk=pkd} }
  yrs=(jdn(dt[n])-d0)/365.25; tr=v[n]/v0; cagr=exp(log(tr)/yrs)-1;
  mu=s1/m; sd=sqrt(s2/m-mu*mu); emu=e1/m; esd=sqrt(e2/m-emu*emu);
  printf "TR=%.2f%% CAGR=%.2f%% maxDD=%.2f%% (peak %s trough %s) Calmar=%.3f Sharpe_raw=%.3f Sharpe_excess=%.3f yrs=%.3f last=%s\n", 100*(tr-1), 100*cagr, 100*mdd, pkk, trd, cagr/mdd, mu/sd*sqrt(252), emu/esd*sqrt(252), yrs, dt[n] }
