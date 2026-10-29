# Generalised from dev/experiments/path-stability-2026-10-23/results/read/regime.awk: PERIODS passed with -v.
function days(d,  y,m,dd,a,yy,mm){ y=substr(d,1,4)+0; m=substr(d,6,2)+0; dd=substr(d,9,2)+0; a=int((14-m)/12); yy=y+4800-a; mm=m+12*a-3; return dd+int((153*mm+2)/5)+365*yy+int(yy/4)-int(yy/100)+int(yy/400)-32045 }
function wkey(d,  n){ n=days(d); return n-((n+0)%7) }
function ma(n,  s,i){ s=0; for(i=n-30;i<n;i++) s+=C[i]; return s/30 }
FNR==1{ fi++ }
fi==1{ split($0,f,","); W[++nw]=f[1]; WV[nw]=f[2]; next }
fi==2{ split($0,f,","); S[++ns]=f[1]; SV[ns]=f[2]; next }
fi>=3{ split($0,f,","); arm=ARGV[fi]; sub(/.*nav_/,"",arm); sub(/\.csv/,"",arm); N[arm,++NN[arm]]=f[1]; NV[arm,NN[arm]]=f[2]; NE[arm,NN[arm]]=f[3]; if(!(arm in seen)){seen[arm]=1; arms[++na]=arm} }
END{
  first=S[1]; nc=0; wk=""; last="";
  for(i=1;i<=nw;i++) if(W[i]<first){ ser_d[++L]=W[i]; ser_v[L]=WV[i] }
  for(i=1;i<=ns;i++){ ser_d[++L]=S[i]; ser_v[L]=SV[i] }
  cur="";
  for(i=1;i<=L;i++){ k=wkey(ser_d[i]); if(k!=wk && last!=""){ C[nc++]=last; if(nc>=34){ m=ma(nc); m4=ma(nc-4); c=C[nc-1]; cur=(c>m && m>m4)?"UP":((c<m && m<m4)?"DOWN":"MIXED") } } wk=k; last=ser_v[i]+0; R[ser_d[i]]=cur }
  np=split(PERIODS,PER," ");
  for(a=1;a<=na;a++){ arm=arms[a];
    for(i=2;i<=NN[arm];i++){ d=N[arm,i]; y=substr(d,1,4)+0; r=R[d]; if(r=="") continue; if(S[i]!=d){print "DATE MISMATCH",arm,d,S[i]; exit 1}
      ls=log(NV[arm,i]/NV[arm,i-1]); lm=log(SV[i]/SV[i-1]);
      for(p=1;p<=np;p++){ split(PER[p],yr,"-"); if(y<yr[1]+0||y>yr[2]+0) continue; key=arm SUBSEP PER[p] SUBSEP r; D[key]++; E[key]+=NE[arm,i]; LS[key]+=ls; LM[key]+=lm;
        key2=arm SUBSEP PER[p] SUBSEP "ALL"; D[key2]++; E[key2]+=NE[arm,i]; LS[key2]+=ls; LM[key2]+=lm } } }
  printf "%-4s %-10s %-6s %5s %7s %9s %9s %8s\n","arm","period","regime","days","invest","strat%","spy%","ln(s/spy)";
  for(p=1;p<=np;p++) for(a=1;a<=na;a++){ arm=arms[a]; split("UP MIXED DOWN ALL",RG," "); for(g=1;g<=4;g++){ key=arm SUBSEP PER[p] SUBSEP RG[g]; if(D[key]) printf "%-4s %-10s %-6s %5d %6.1f%% %+8.1f%% %+8.1f%% %+8.3f\n",arm,PER[p],RG[g],D[key],E[key]/D[key],100*(exp(LS[key])-1),100*(exp(LM[key])-1),LS[key]-LM[key] } }
}
