function sortv(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } }
function q(a, n, p,   x) { if (n == 0) return 0; x = 1 + (n - 1) * p; return a[int(x)] + (x - int(x)) * (a[int(x) + 1 < n ? int(x) + 1 : n] - a[int(x)]) }
NR == 1 { next }
$5 != "long" || $14 == "" { next }
{ g = $1 ($1 == "reader" ? "-" $3 : ""); if (g ~ /reader-r[12]/) g2 = "reader-rep"; else g2 = ""
  h = (1 + $14) / (1 + $15) - 1; mg = (1 + $9) / (1 + $10) - 1; va = log(1 + mg) - log(1 + h)
  add(g, h, mg, va, $8); if (g2 != "") add(g2, h, mg, va, $8) }
function add(g, h, mg, va, how) { n[g]++; i = n[g]; H[g, i] = h; M[g, i] = mg; VA[g, i] = va; if (va > 0) p[g]++; if (how == "cap104") c[g]++; sh[g] += log(1 + h); sm[g] += log(1 + mg) }
END {
  split("reader-r0 reader-rep ours-s0 ours-s1 ours-s2", G, " ")
  for (k = 1; k <= 5; k++) { g = G[k]; m = n[g]; if (!m) continue
    delete a; delete b; delete v
    for (i = 1; i <= m; i++) { a[i] = H[g, i]; b[i] = M[g, i]; v[i] = VA[g, i] }
    sortv(a, m); sortv(b, m); sortv(v, m)
    printf "%-10s n %2d | HOLD-104w excess med %+6.1f%% p25 %+6.1f p75 %+6.1f p90 %+6.1f geo-mean %+6.1f%% | MANAGED (SPY-parked) med %+6.1f%% geo %+6.1f%% | value-add (log) med %+.3f p25 %+.3f p75 %+.3f, positive %d/%d, cap104 %d\n", \
      g, m, 100*q(a,m,.5), 100*q(a,m,.25), 100*q(a,m,.75), 100*q(a,m,.9), 100*(exp(sh[g]/m)-1), 100*q(b,m,.5), 100*(exp(sm[g]/m)-1), q(v,m,.5), q(v,m,.25), q(v,m,.75), p[g], m, c[g] }
}
