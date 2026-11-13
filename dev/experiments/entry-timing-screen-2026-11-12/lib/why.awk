# why.awk -- decompositions behind the screen. usage: awk -F'\t' -f why.awk pct.tsv replay.tsv
# (1) realised trades by screen extension over the 30-week MA, all seeds pooled
# (2) H2 (N=4) delta vs the null, split by where the code's E sits against the 4-week high
# (3) H3 (X = 20 %, m = 8 %): pullback fills vs the control, and what the unfilled (missed) trades carried
function q(a, n, p,   i, j, k, t) { for (i = 2; i <= n; i++) { t = a[i]; j = i - 1; while (j > 0 && a[j] > t) { a[j + 1] = a[j]; j-- }; a[j + 1] = t }
  k = int(p * (n - 1)) + 1; return a[k] }
function dist(lbl, arr, n,   s, i, c) { if (n == 0) { printf "%-34s n=0\n", lbl; return }; s = 0; for (i = 1; i <= n; i++) { c[i] = arr[i]; s += arr[i] }
  printf "%-34s n=%4d mean %+7.2f  p10 %+7.2f p25 %+7.2f med %+7.2f p75 %+7.2f p90 %+7.2f  sum %+7.1f\n", lbl, n, s / n, q(c, n, .1), q(c, n, .25), q(c, n, .5), q(c, n, .75), q(c, n, .9), s }
BEGIN { nb = split("a <10%|b 10-20%|c 20-30%|d 30-50%|e >=50%", BK, "|"); G[1] = "E below 4-wk high (code buys lower)"; G[2] = "E at/above 4-wk high (stale E)" }
FNR == NR { PCT[$1, $2] = $3; next }
$4 == "NODATA" { next }
{ k = $1; nav = $9; c = 100 * $8 / nav; pct = PCT[k, $2] + 0; e = $11 + 0
  b = (e < 0.10) ? 1 : (e < 0.20) ? 2 : (e < 0.30) ? 3 : (e < 0.50) ? 4 : 5
  bn[b]++; bc[b] += c; bw[b] += (pct > 0); if (pct >= 100) bm[b]++; bp[b, bn[b]] = pct
  if ($10 != 1 || $19 == "-" || $21 == "") next
  g = ($14 < $15 * 1.005 - 1e-9) ? 1 : 2
  d = 100 * ($32 - $22) / nav; gn[g]++; gd[g] += d; if ($28 != "F") { gnf[g]++; gnfc[g] += 100 * $22 / nav }
  if (k == 0) ga[g, ++gan[g]] = d
  if (e > 0.20) { ctl = 100 * $44 / nav
    if ($52 == "F") { hf++; hd += 100 * $56 / nav - ctl; if (k == 0) ha[++han] = 100 * $56 / nav - ctl } else { hm++; hmc += ctl; hmr += c } }
}
END {
  print "== realised trades by screen extension over the 30-week MA, 5 seeds pooled: n, NAV-%, win rate, trades >= +100 %, trade % distribution"
  for (b = 1; b <= nb; b++) { delete arr; for (i = 1; i <= bn[b]; i++) arr[i] = bp[b, i]
    printf "%-9s n=%4d NAV-%% %+7.1f (%+5.2f/trade) win %4.1f%% monsters %2d | ", BK[b], bn[b], bc[b], bc[b] / bn[b], 100 * bw[b] / bn[b], bm[b]; dist("trade %", arr, bn[b]) }
  print "\n== H2 (N=4) delta vs null, by where the code's E sits (5 seeds pooled); no-fill = the range-top ticket never fills, the null's P&L is lost"
  for (g = 1; g <= 2; g++) printf "%-38s n=%4d  delta %+7.1f NAV-%%  no-fill %3d (null P&L lost there %+6.1f)\n", G[g], gn[g], gd[g], gnf[g], -gnfc[g]
  for (g = 1; g <= 2; g++) { delete arr; for (i = 1; i <= gan[g]; i++) arr[i] = ga[g, i]; dist("k0 per-trade delta, " substr(G[g], 1, 16), arr, gan[g]) }
  printf "\n== H3 X=20%% m=8%% (5 seeds pooled): pullback filled %d (pullback - control %+.1f NAV-%%); missed %d (control NAV-%% given up %+.1f, real %+.1f)\n", hf, hd, hm, hmc, hmr
  delete arr; for (i = 1; i <= han; i++) arr[i] = ha[i]; dist("k0 filled: pullback - control", arr, han)
}
