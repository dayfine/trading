# regime-split.awk: SPY regime (weekly adj close vs 30-week SMA and its 4-week slope, lagged one week; UP / MIXED / DOWN) x era,
# per arm: cumulative strategy and SPY return over the regime's days, mean invested % of NAV. Inputs: review-pack site/data
# spy_warmup.json + spy.json (date adj_close) and <arm>_nav.json (date nav invested_pct npos) flattened with jq to 'date value [..]' lines.
# Usage: awk -f regime-split.awk spy_all.txt nav-<arm>.txt
# Pass 1: spy_all.txt (date adjclose) -> weekly closes (last day of ISO week via date-sorted grouping on week key from day count), regime per week lagged one week.
# Pass 2: nav file (date nav invested) -> per (period, regime) cumulative strategy and SPY log return, mean invested.
function dnum(d,   y,m,dd,a) { y=substr(d,1,4)+0; m=substr(d,6,2)+0; dd=substr(d,9,2)+0; if (m<3){y--; m+=12}; return 365*y+int(y/4)-int(y/100)+int(y/400)+int((153*(m-3)+2)/5)+dd }
function period(d,  y) { y=substr(d,1,4)+0; if (y<=2008) return "2000-08"; if (y<=2011) return "2009-11"; if (y<=2015) return "2012-15"; if (y<=2019) return "2016-19"; if (y<=2022) return "2020-22"; return "2023-26" }
FNR==NR { n++; D[n]=$1; C[n]=$2; wk=int((dnum($1)+1)/7); W[n]=wk; spy[$1]=$2; next }
FNR==1 && !built {
  # build weekly series: last close of each week key
  nw=0; for (i=1;i<=n;i++) { if (i==n || W[i+1]!=W[i]) { nw++; wkey[nw]=W[i]; wc[nw]=C[i] } }
  for (j=1;j<=nw;j++) { if (j>=30) { s=0; for (q=j-29;q<=j;q++) s+=wc[q]; ma[j]=s/30 } }
  for (j=1;j<=nw;j++) { r="MIXED"; if ((j in ma) && ((j-4) in ma)) { sl=ma[j]-ma[j-4]; if (wc[j]>ma[j] && sl>0) r="UP"; else if (wc[j]<ma[j] && sl<0) r="DOWN" } ; reg_of_week[wkey[j]]=r }
  built=1; prevnav=""; prevspy=""
}
{ d=$1; nav=$2; inv=$3; wk=int((dnum(d)+1)/7); r=reg_of_week[wk-1]; if (r=="") r="MIXED"; p=period(d)
  if (prevnav!="" && (d in spy) && prevspy!="") { k=p" "r; ls[k]+=log(nav/prevnav); lq[k]+=log(spy[d]/prevspy); iv[k]+=inv; cnt[k]++ ; lsT[r]+=log(nav/prevnav); lqT[r]+=log(spy[d]/prevspy); ivT[r]+=inv; cT[r]++ }
  prevnav=nav; if (d in spy) prevspy=spy[d] }
END { for (k in cnt) printf "%s %d days strat %+.1f%% spy %+.1f%% invested %.1f%%\n", k, cnt[k], 100*(exp(ls[k])-1), 100*(exp(lq[k])-1), iv[k]/cnt[k]
      for (r in cT) printf "ALL %s %d days strat %+.1f%% spy %+.1f%% invested %.1f%%\n", r, cT[r], 100*(exp(lsT[r])-1), 100*(exp(lqT[r])-1), ivT[r]/cT[r] }
