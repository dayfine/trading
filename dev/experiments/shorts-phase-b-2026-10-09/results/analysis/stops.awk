# #3145 after-merge evidence (README §After-merge verification items): per cell, from stop_decisions
# (audit_flat.awk S rows) and the bars:
#   - positions whose stop reached the Tightened state, how many had their stop lowered at least once (anywhere
#     in the trade), and how many were lowered while Tightened (Tightened_ratchet);
#   - the ADSK-shaped freeze: a short whose stop level stays unchanged for >= 26 distinct weeks of decisions while
#     a raw close falls >= 30 % below that stop, inside that run.
# files: 1 bars.csv (sorted)  2 <cell>.audit.tsv  3 trades.csv (hdr)    -v CELL=<label>
function jdn(s,   y,m,d,a){ y=substr(s,1,4)+0; m=substr(s,6,2)+0; d=substr(s,9,2)+0
  a=int((14-m)/12); y=y+4800-a; m=m+12*a-3
  return d+int((153*m+2)/5)+365*y+int(y/4)-int(y/100)+int(y/400)-32045 }
BEGIN{ FS="," }
FILENAME==ARGV[1]{ k[$1]++; bd[$1, k[$1]]=$2; bc[$1, k[$1]]=$6+0; next }
FILENAME==ARGV[2]{ split($0, f, "\t"); if (f[1]!="S") next; p=f[2]; n[p]++; sd[p, n[p]]=f[3]; sa[p, n[p]]=f[7]+0
  if (f[5]=="Tightened") tg[p]=1; if (f[7]+0 < f[6]-1e-9) lw[p]=1; if (f[8]=="Tightened_ratchet") tr[p]++; next }
FILENAME==ARGV[3]{ if (FNR==1) next; pid=$20; sym[pid]=$1; npos++; next }
END{
  for (p in sym) {
    if (p in tg) { nt++; if (p in lw) ntl++; if (p in tr) ntr++ }
    # freeze runs: consecutive decisions at one level
    i=1; while (i<=n[p]) { lv=sa[p, i]; j=i; while (j+1<=n[p] && sa[p, j+1]==lv) j++
      delete wk; nw=0; for (m=i; m<=j; m++) { w=int((jdn(sd[p, m])+1)/7); if (!(w in wk)) { wk[w]=1; nw++ } }
      if (nw>=26) { s=sym[p]; lo=0; for (b=1; b<=k[s]; b++) { if (bd[s, b]<sd[p, i]) continue; if (bd[s, b]>sd[p, j]) break; if (lo==0 || bc[s, b]<lo) lo=bc[s, b] }
        if (lo>0 && lo<=0.7*lv) { nf++; printf "%s\tFREEZE\t%s %s: stop %.2f held %d weeks (%s .. %s), lowest close %.2f (%.0f%% below)\n", CELL, p, s, lv, nw, sd[p, i], sd[p, j], lo, 100*(1-lo/lv) }
        else { nl++; printf "%s\tLONGHOLD\t%s %s: stop %.2f held %d weeks (%s .. %s), lowest close %.2f\n", CELL, p, s, lv, nw, sd[p, i], sd[p, j], lo } }
      i=j+1 } }
  printf "%s\tSUMMARY\tpositions %d; reached Tightened %d, of them stop lowered at least once %d, lowered while Tightened (Tightened_ratchet) %d; ADSK-shaped freezes (>= 26 weeks at one stop, close >= 30%% below it) %d; other >= 26-week single-level runs %d\n",
    CELL, npos, nt+0, ntl+0, ntr+0, nf+0, nl+0
}
