# Distribution of trade returns by a key column of trade_rows.awk output (tab-separated).
# -v K=<column number> (0 = one group, "all"); -v LABEL=<text>
# Prints per group: n, win rate, mean win, mean loss (price-only, %), mean / median / p10 / p25 / p75 / p90 of the
# price-only return, mean and median of the total return (dividends, borrow and commissions taken out), and the
# summed price-only and total-return P&L in dollars. Quantile = sorted v[int(q * (n - 1)) + 1] (as Phase A).
function q(arr, n, p){ return arr[int(p*(n-1))+1] }
function srt(arr, n,   i, j, t){ for (i=2; i<=n; i++) { t=arr[i]; j=i-1; while (j>0 && arr[j]>t) { arr[j+1]=arr[j]; j-- } arr[j+1]=t } }
BEGIN{ FS="\t" }
{ g=(K+0==0 ? "all" : $K); n[g]++; r=$7+0; v[g, n[g]]=r; w[g, n[g]]=$8+0; s[g]+=r; st[g]+=$8; P[g]+=$9; T[g]+=$10
  if (r>0) { nw[g]++; sw[g]+=r } else { nl[g]++; sl[g]+=r } }
END{
  for (g in n) {
    m=n[g]; for (i=1; i<=m; i++) { a[i]=v[g, i]; b[i]=w[g, i] }
    srt(a, m); srt(b, m)
    printf "%s\t%s\tn=%d\twin=%.1f%%\tmeanwin=%s\tmeanloss=%s\tmean=%+.2f\tmed=%+.2f\tp10=%+.2f\tp25=%+.2f\tp75=%+.2f\tp90=%+.2f\tTRmean=%+.2f\tTRmed=%+.2f\tpnl=%.0f\tTRpnl=%.0f\n",
      LABEL, g, m, 100*nw[g]/m, (nw[g]>0 ? sprintf("%+.2f", sw[g]/nw[g]) : "-"), (nl[g]>0 ? sprintf("%+.2f", sl[g]/nl[g]) : "-"),
      s[g]/m, q(a, m, 0.5), q(a, m, 0.1), q(a, m, 0.25), q(a, m, 0.75), q(a, m, 0.9), st[g]/m, q(b, m, 0.5), P[g], T[g]
    delete a; delete b
  }
}
