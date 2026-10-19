function sortv(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } }
function q(a, n, p,   x) { if (n == 0) return 0; x = 1 + (n - 1) * p; return a[int(x)] + (x - int(x)) * (a[int(x) + 1 < n ? int(x) + 1 : n] - a[int(x)]) }
FILENAME ~ /reader_filled/ { filled[$1 "," $2] = 1; next }
FNR == 1 { next }
{ d = $1; for (h = 1; h <= 3; h++) x[h] = log((1 + $(7 + h)) / (1 + $(11 + h)))
  if ($3 == "filter") add("filter", d)
  if ($3 == "ours") add("ourlist", d)
  if ($3 == "entry") add("ourentries", d)
  if ($5 == 1) add("orders", d)
  if ($5 == 1 && ((d "," $2) in filled)) add("orders_filled", d)
  if ($5 == 1 && !((d "," $2) in filled)) add("orders_unfilled", d) }
function add(s, d,   h) { if (!((s, d) in c)) { nd[s]++; dl[s, nd[s]] = d }; c[s, d]++; for (h = 1; h <= 3; h++) { S[s, d, h] += x[h]; V[s, d, h, c[s, d]] = x[h] } }
function dmed(s, d, h,   i, m) { m = c[s, d]; delete u; for (i = 1; i <= m; i++) u[i] = V[s, d, h, i]; sortv(u, m); return q(u, m, .5) }
END {
  split("ourlist orders orders_filled orders_unfilled ourentries", G, " "); hn[1] = "26w"; hn[2] = "52w"; hn[3] = "104w"
  for (h = 1; h <= 3; h++) { printf "--- %s, log excess vs SPY from the decision date; per date: set minus filter\n", hn[h]
    for (k = 1; k <= 5; k++) { s = G[k]; np = 0; pa = 0; pm = 0; delete w; delete z
      for (i = 1; i <= nd[s]; i++) { d = dl[s, i]; if (!(("filter", d) in c)) continue; np++
        w[np] = S[s, d, h] / c[s, d] - S["filter", d, h] / c["filter", d]; if (w[np] > 0) pa++
        z[np] = dmed(s, d, h) - dmed("filter", d, h); if (z[np] > 0) pm++ }
      sortv(w, np); sortv(z, np)
      printf "%-16s dates %2d | per-date mean-log diff med %+.3f p25 %+.3f p75 %+.3f ahead %2d/%d | per-date median diff med %+.3f ahead %2d/%d\n", s, np, q(w,np,.5), q(w,np,.25), q(w,np,.75), pa, np, q(z,np,.5), pm, np } }
}
