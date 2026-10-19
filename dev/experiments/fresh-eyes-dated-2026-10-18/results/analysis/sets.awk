function sortv(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } }
function q(a, n, p,   x) { if (n == 0) return 0; x = 1 + (n - 1) * p; return a[int(x)] + (x - int(x)) * (a[int(x) + 1 < n ? int(x) + 1 : n] - a[int(x)]) }
FNR == 1 { next }
{ d = $1; for (h = 1; h <= 3; h++) { x[h] = $(7 + h) - $(11 + h) }
  if ($3 == "filter") add("filter", d)
  if ($3 == "ours") add("ourlist", d)
  if ($3 == "entry") add("ourentries", d)
  if ($4 == 1) add("shortlist", d)
  if ($5 == 1) add("orders", d)
  if ($5 == 1 && $3 == "ours") add("orders_ours", d)
  if ($5 == 1 && $3 != "ours") add("orders_filter", d)
  if ($3 != "entry") add("pool", d)
  if ($4 == 1 && $5 == 0) add("sl_not_ordered", d) }
function add(s, d,   h) { if (!((s, d) in c)) { nd[s]++; dl[s, nd[s]] = d }; c[s, d]++; for (h = 1; h <= 3; h++) S[s, d, h] += x[h]; all[s]++; for (h = 1; h <= 3; h++) { A[s, h, all[s]] = x[h] } }
END {
  split("pool filter ourlist shortlist orders orders_ours orders_filter sl_not_ordered ourentries", G, " ")
  hn[1] = "26w"; hn[2] = "52w"; hn[3] = "104w"
  for (h = 1; h <= 3; h++) {
    printf "--- horizon %s, excess vs SPY from the decision date (difference form)\n", hn[h]
    for (k = 1; k <= 9; k++) { s = G[k]; m = all[s]; delete v; for (i = 1; i <= m; i++) v[i] = A[s, h, i]; sortv(v, m)
      # per-date mean minus filter per-date mean
      np = 0; pos = 0; delete w
      for (i = 1; i <= nd[s]; i++) { d = dl[s, i]; if (!(("filter", d) in c)) continue; np++; w[np] = S[s, d, h] / c[s, d] - S["filter", d, h] / c["filter", d]; if (w[np] > 0) pos++ }
      sortv(w, np)
      printf "%-15s names %4d dates %2d | pooled mean %+6.1f%% med %+6.1f%% p10 %+6.1f p90 %+6.1f | per-date set minus filter: med %+6.1f pp, set ahead %2d/%d\n", s, m, nd[s], 100*mean(v,m), 100*q(v,m,.5), 100*q(v,m,.1), 100*q(v,m,.9), 100*q(w,np,.5), pos, np }
  }
}
function mean(v, m,   i, t) { t = 0; for (i = 1; i <= m; i++) t += v[i]; return m ? t / m : 0 }
