# One symbol's daily store -> qualifying weekly episodes (TSV).
# vars: sym, first, last. Adjusted OHLC, stored volume; ADV uses adjusted close.
# Forward return uses weekly closes through last; a >=50% adjusted daily jump
# invalidates paths crossing it (conservative splice guard).
BEGIN { FS = "," }
function week(d,   t,n) {
  # Gregorian day number, then Monday key: year boundaries stay in one week.
  split(d,t,"-"); n=t[1]+0; m=t[2]+0; day=t[3]+0
  if (m<3) { n--; m+=12 }
  return int((365*n+int(n/4)-int(n/100)+int(n/400)+int((153*(m-3)+2)/5)+day-1+2)/7)
}
function flush() {
  if (!wd) return
  nw++; dates[nw]=wd; closes[nw]=wc; highs[nw]=wh; vols[nw]=wv
  adv[nw]=sumdv/(nd<20?nd:20); segment[nw]=seg
}
FNR>1 && $1<=last && $5+0>0 && $6+0>0 {
  d=$1; c=$6+0; v=$7+0; h=$3*c/$5; k=week(d)
  if (wd && k!=wk) { flush(); wv=0; wh=0 }
  if (prev>0 && (c/prev>=1.5 || c/prev<=0.5)) seg++
  prev=c; nd++; slot=(nd-1)%20; sumdv-=dv[slot]; dv[slot]=c*v; sumdv+=dv[slot]
  wd=d; wk=k; wc=c; wv+=v; if(h>wh) wh=h
}
END {
  flush(); peak=0; oldseg=-1
  for(i=nw;i>=1;i--) {
    if(segment[i]!=oldseg) { peak=0; pd=""; oldseg=segment[i] }
    future[i]=peak; peakdate[i]=pd; if(closes[i]>peak) { peak=closes[i]; pd=dates[i] }
  }
  for(i=31;i<=nw;i++) {
    if(dates[i]<first || dates[i]>last || segment[i]!=segment[i-30]) continue
    high=0; volume=0; ma=0; oldma=0
    for(j=i-26;j<i;j++) if(highs[j]>high) high=highs[j]
    for(j=i-4;j<i;j++) volume+=vols[j]/4
    for(j=0;j<30;j++) { ma+=(30-j)*closes[i-j]/465; oldma+=(30-j)*closes[i-j-1]/465 }
    run=100*(future[i]/closes[i]-1)
    if(closes[i]>high && volume>0 && vols[i]>=2*volume && closes[i]>ma && ma>oldma && adv[i]>=1000000 && run>=100)
      printf "%s\t%s\t%.6f\t%.6f\t%s\n",sym,dates[i],run,vols[i]/volume,peakdate[i]
  }
}
