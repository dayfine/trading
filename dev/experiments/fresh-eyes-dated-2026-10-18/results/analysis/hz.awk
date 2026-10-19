function sortv(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } }
function q(a, n, p,   x) { if (n == 0) return 0; x = 1 + (n - 1) * p; return a[int(x)] + (x - int(x)) * (a[int(x) + 1 < n ? int(x) + 1 : n] - a[int(x)]) }
{ d = $1; for (h = 1; h <= 6; h++) { r = $(5 + h); s = $(11 + h); xa[h] = r - s; xl[h] = log((1 + r) / (1 + s)) }
  if ($3 == "filter") add("filter", d); if ($3 == "ours") add("ourlist", d); if ($3 == "entry") add("ourentries", d)
  if ($4 == 1) add("orders", d); if ($5 == 1) add("filled", d) }
function add(s, d,   h) { c[s, d]++; seen[s, d] = 1; ds[d] = 1; for (h = 1; h <= 6; h++) { A[s, d, h] += xa[h]; L[s, d, h] += xl[h] } }
function cmp(a, b, form,   h, d, np, pos, w) { line = sprintf("%-10s - %-8s %-4s", a, b, form)
  for (h = 1; h <= 6; h++) { np = 0; pos = 0; delete w
    for (d in ds) { if (!((a, d) in seen) || !((b, d) in seen)) continue; np++
      w[np] = (form == "arit" ? A[a, d, h] / c[a, d] - A[b, d, h] / c[b, d] : L[a, d, h] / c[a, d] - L[b, d, h] / c[b, d]); if (w[np] > 0) pos++ }
    sortv(w, np); line = line sprintf(" | %2d/%2d %+.3f", pos, np, q(w, np, .5)) }
  print line }
END { print "horizon weeks:                  |   13w         |   26w         |   39w         |   52w         |   78w         |  104w"
  split("arit log", F, " ")
  for (f = 1; f <= 2; f++) { cmp("orders", "filter", F[f]); cmp("filled", "filter", F[f]); cmp("ourlist", "filter", F[f]); cmp("ourentries", "filter", F[f]); cmp("orders", "ourlist", F[f]); cmp("filled", "ourentries", F[f]) } }
