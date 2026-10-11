# RV2 (backtest-result-review.md): the short book's return EX INTEREST and its short exposure, split by SPY regime
# and by period. Regime = review-pack definition: SPY weekly close vs its 30-week SMA and the SMA's 4-week slope,
# known at the prior week's close and applied to the following week's days; full SPY history (no warm-up gap).
# Per equity row t: r_t = ln((V_t - s*x_t) / V_{t-1}) (V_0 = 1,000,000), s = CIT / reconstructed interest;
# exposure = short market value at the prior row's close / V_{t-1}; SPY = adjusted-close log return (0 on a
# row with no SPY bar, i.e. an exchange holiday). Last column: an SPY short held at the same exposure path
# (compounded ln(1 - exposure * SPY daily return)), the index-short counterfactual for the same days.
# files: 1 spy.csv (date,close,adj)  2 DAY csv from recon.awk   -v CIT=<cashinteresttotal> -v CELL=<label>
function jdn(s,   y,m,d,a){ y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0
  a=int((14-m)/12); y=y+4800-a; m=m+12*a-3
  return d+int((153*m+2)/5)+365*y+int(y/4)-int(y/100)+int(y/400)-32045 }
function ma(k,   i, s){ s=0; for (i=k-30; i<k; i++) s+=cl[i]; return s/30 }
function per(d,  y){ y=substr(d,1,4)+0; return y<=2002 ? "2000-02" : y<=2007 ? "2003-07" : y<=2009 ? "2008-09" : y<=2019 ? "2010-19" : y<=2021 ? "2020-21" : y==2022 ? "2022" : "2023-26" }
BEGIN{ FS="," }
FILENAME==ARGV[1]{ d=$1; v=$3+0; k=int((jdn(d)+1)/7)
  if (k!=wk && last!="") { cl[nc++]=last
    if (nc>=34) { m=ma(nc); m4=ma(nc-4); c=cl[nc-1]; cur=(c>m && m>m4) ? "UP" : (c<m && m<m4) ? "DOWN" : "MIXED" } }
  wk=k; last=v; reg[d]=cur; spy[d]=v; curreg=cur; next }
FILENAME==ARGV[2]{ n++; dt[n]=$1; V[n]=$2+0; x[n]=$3+0; mv[n]=$7+0; tx+=$3; next }
END{
  s=CIT/tx; pv=1000000; pm=0; ps=""
  # regime of a holiday row = the regime of the last SPY bar before it
  for (t=1; t<=n; t++) {
    d=dt[t]; r=log((V[t]-s*x[t])/pv)
    if (d in spy) { g=reg[d]; lr=(ps!="" ? log(spy[d]/ps) : 0); ps=spy[d]; lg=g } else { g=lg; lr=0 }
    if (g=="") g="NA"
    ex=pm/pv; hs=log(1-ex*(exp(lr)-1))
    for (j=0; j<2; j++) { k=(j==0 ? per(d) : "ALL") SUBSEP g
      N[k]++; L[k]+=r; S[k]+=lr; E[k]+=ex; H[k]+=hs
      k2=(j==0 ? per(d) : "ALL") SUBSEP "ANY"; N[k2]++; L[k2]+=r; S[k2]+=lr; E[k2]+=ex; H[k2]+=hs }
    pv=V[t]; pm=mv[t]
  }
  np=split("2000-02,2003-07,2008-09,2010-19,2020-21,2022,2023-26,ALL", P, ",")
  for (i=1; i<=np; i++) for (j=1; j<=4; j++) { g=(j==1?"UP":j==2?"MIXED":j==3?"DOWN":"ANY"); k=P[i] SUBSEP g
    if (N[k]>0) printf "%s\t%s\t%s\t%d\t%+.2f\t%+.2f\t%.1f\t%+.2f\n", CELL, P[i], g, N[k], 100*(exp(L[k])-1), 100*(exp(S[k])-1), 100*E[k]/N[k], 100*(exp(H[k])-1) }
}
