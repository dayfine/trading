# Item 6: dividends paid by shorts, per event. An open short pays q * unadjusted_amount on the ex-date when held at
# the prior close (entry < ex <= cover), as recon.awk. Class: special when the amount is >= 5 % of the prior raw
# close (rebaseline-v12 convention), else ordinary. Log cost per event = ln((V + paid) / V), V = the equity row on
# or after the ex-date (what the book would have ended at, scaled, had the dividend not been paid).
# files: 1 divs.csv  2 bars.csv (sorted)  3 trades.csv (hdr)  4 equity_curve.csv (hdr)
# out: EVENT lines (sym ex amount prior_close yield class shares paid pid) and a SUMMARY line.  -v CELL=<label>
BEGIN{ FS="," }
FILENAME==ARGV[1]{ nd[$1]++; dd[$1, nd[$1]]=$2; da[$1, nd[$1]]=$3+0; next }
FILENAME==ARGV[2]{ k[$1]++; bd[$1, k[$1]]=$2; bc[$1, k[$1]]=$6+0; next }
FILENAME==ARGV[3]{ if (FNR==1) next; np++; ps[np]=$1; pe[np]=$3; px[np]=$4; pq[np]=$8+0; pid[np]=$20; sy[$1]=1; next }
FILENAME==ARGV[4]{ if (FNR==1) next; n++; rd[n]=$1; rv[n]=$2+0; next }
END{
  for (p=1; p<=np; p++) { s=ps[p]
    for (j=1; j<=nd[s]; j++) { d=dd[s, j]; if (d>pe[p] && d<=px[p] && d<=rd[n]) {
        pc=0; for (i=1; i<=k[s]; i++) { if (bd[s, i]<d) pc=bc[s, i]; else break }
        y=(pc>0 ? da[s, j]/pc : -1); cls=(y>=0.05 ? "special" : "ordinary"); usd=pq[p]*da[s, j]
        r=0; for (i=1; i<=n; i++) if (rd[i]>=d) { r=i; break }
        L=log((rv[r]+usd)/rv[r]); tot[cls]+=usd; LL[cls]+=L; cnt[cls]++; T+=usd; LT+=L
        printf "%s\tEVENT\t%s\t%s\t%.4f\t%.4f\t%.4f\t%s\t%d\t%.2f\t%s\n", CELL, s, d, da[s, j], pc, y, cls, pq[p], usd, pid[p] } } }
  for (s in sy) { ns++; if (!(s in nd)) nodiv++ }
  printf "%s\tSUMMARY\tpaid %.2f (L_div %.4f): ordinary %d events %.2f (L %.4f), special %d events %.2f (L %.4f); distinct shorted symbols %d, with no dividend rows in the file %d\n",
    CELL, T, LT, cnt["ordinary"], tot["ordinary"], LL["ordinary"], cnt["special"]+0, tot["special"], LL["special"], ns, nodiv+0
}
