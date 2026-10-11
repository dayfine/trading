# Book Ch. 7 "How to do it right" / "The individual chart pattern": a short candidate should have had a substantial
# advance over the past year before its Stage 3 top. Measured per closed short, at the decision date of its ticket:
#   top   = highest adjusted close in the 365 days up to the decision; low = lowest adjusted close in the 365 days
#           before the top; prior_adv = top / low - 1; off_top = decision-day adjusted close / top - 1.
# Appends prior_adv, off_top and a bucket to each trade_rows.awk row (joined on position_id).
# files: 1 bars.csv (sym,date,o,h,l,c,adj; sorted by sym,date)  2 <cell>.audit.tsv  3 trade rows (tab)
function jdn(s,   y,m,d,a){ y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0
  a=int((14-m)/12); y=y+4800-a; m=m+12*a-3
  return d+int((153*m+2)/5)+365*y+int(y/4)-int(y/100)+int(y/400)-32045 }
BEGIN{ OFS="\t" }
FILENAME==ARGV[1]{ split($0, f, ","); k[f[1]]++; bj[f[1], k[f[1]]]=jdn(f[2]); ba[f[1], k[f[1]]]=f[7]+0; next }
FILENAME==ARGV[2]{ split($0, f, "\t"); if (f[1]=="T") dec[f[2]]=f[4]; next }
{ split($0, f, "\t"); pid=f[2]; s=f[3]; dj=jdn(dec[pid]); top=0; tj=0; cur=0
  for (i=1; i<=k[s]; i++) { j=bj[s, i]; if (j>dj) break; cur=ba[s, i]; if (j>=dj-365 && ba[s, i]>top) { top=ba[s, i]; tj=j } }
  lo=0; for (i=1; i<=k[s]; i++) { j=bj[s, i]; if (j>tj) break; if (j>=tj-365 && (lo==0 || ba[s, i]<lo)) lo=ba[s, i] }
  if (top>0 && lo>0) { pa=top/lo-1; ot=cur/top-1; b=(pa<0.3 ? "a adv<30%" : pa<0.6 ? "b adv 30-60%" : pa<1.0 ? "c adv 60-100%" : "d adv>=100%") }
  else { pa=-1; ot=0; b="?" }
  print $0, sprintf("%.4f", pa), sprintf("%.4f", ot), b }
