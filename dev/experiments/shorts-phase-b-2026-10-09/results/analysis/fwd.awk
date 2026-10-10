# Selection estimand, independent of stops: each short's own 8-week forward return vs an SPY short over the same
# bars. Stock: adjusted close of the entry-date bar -> adjusted close 40 bars later (or the last bar staged), side-
# signed (+ = the stock fell). SPY: adjusted close on the same two dates (last bar on or before). Paired per trade.
# files: 1 bars.csv (sym,date,o,h,l,c,adj)  2 spy.csv (date,close,adj)  3 trades.csv (hdr)
# out (tab): cell pid sym entry f40_stock f40_spy diff bars_found
# -v CELL=<label> -v NB=40
function spyon(d,   lo, hi, mid){ lo=1; hi=ns; if (sd[1]>d) return 0
  while (lo<hi) { mid=int((lo+hi+1)/2); if (sd[mid]<=d) lo=mid; else hi=mid-1 } return lo }
BEGIN{ FS=","; OFS="\t"; if (NB=="") NB=40 }
FILENAME==ARGV[1]{ k[$1]++; bd[$1, k[$1]]=$2; ba[$1, k[$1]]=$7+0; next }
FILENAME==ARGV[2]{ ns++; sd[ns]=$1; sa[ns]=$3+0; next }
FILENAME==ARGV[3]{ if (FNR==1) next; s=$1; e=$3; i0=0
  for (i=1; i<=k[s]; i++) if (bd[s, i]<=e) i0=i; else break
  if (i0==0) { print CELL, $20, s, e, "NA", "NA", "NA", 0; next }
  i1=i0+NB; if (i1>k[s]) i1=k[s]
  r=-(ba[s, i1]/ba[s, i0]-1); j0=spyon(bd[s, i0]); j1=spyon(bd[s, i1]); q=-(sa[j1]/sa[j0]-1)
  print CELL, $20, s, e, sprintf("%.4f", r), sprintf("%.4f", q), sprintf("%.4f", r-q), i1-i0 }
