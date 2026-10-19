function sortv(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } }
function q(a, n, p,   x) { if (n == 0) return 0; x = 1 + (n - 1) * p; return a[int(x)] + (x - int(x)) * (a[int(x) + 1 < n ? int(x) + 1 : n] - a[int(x)]) }
# input: who,date,rep,symbol,side,entry,exit,how,ret,spy,excess,days,ann,r104,spy104
NR == 1 { next }
$3 != "r0" { next }
{
  g = $1; if ($1 == "reader") g = "reader-" $5
  add(g); if ($1 == "reader") add("reader-all")
}
function add(g) { n[g]++; i = n[g]; ex[g, i] = $11; dy[g, i] = $12; an[g, i] = $13
  lr[g] += log((1 + $9) / (1 + $10)); yr[g] += ($12 < 7 ? 7 : $12) / 365; if ($11 > 0) w[g]++ }
END {
  split("reader-long reader-short reader-all ours-s0 ours-s1 ours-s2", G, " ")
  for (k = 1; k <= 6; k++) { g = G[k]; m = n[g]; if (!m) continue
    delete v; delete d; delete a; s = 0
    for (i = 1; i <= m; i++) { v[i] = ex[g, i] + 0; d[i] = dy[g, i] + 0; a[i] = an[g, i] + 0; s += v[i] }
    sortv(v, m); sortv(d, m); sortv(a, m)
    printf "%-12s n %2d  excess mean %+6.1f%% med %+6.1f%% p10 %+6.1f p25 %+6.1f p75 %+6.1f p90 %+6.1f  beat-SPY %2d/%d | days med %3d p25 %3d p75 %3d | ann med %+6.1f%% | time-normalised %+6.1f%%/yr over %.1f trade-yrs\n", \
      g, m, 100*s/m, 100*q(v,m,.5), 100*q(v,m,.1), 100*q(v,m,.25), 100*q(v,m,.75), 100*q(v,m,.9), w[g], m, q(d,m,.5), q(d,m,.25), q(d,m,.75), 100*q(a,m,.5), 100*(exp(lr[g]/yr[g])-1), yr[g]
  }
}
