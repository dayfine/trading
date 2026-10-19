function sortv(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } }
function q(a, n, p,   x) { if (n == 0) return 0; x = 1 + (n - 1) * p; return a[int(x)] + (x - int(x)) * (a[int(x) + 1 < n ? int(x) + 1 : n] - a[int(x)]) }
function agg(side, d, kind,   k, m, v, s) { m = c[side, d]; if (!m) return "NA"; delete v; s = 0
  for (k = 1; k <= m; k++) { v[k] = X[side, d, k]; s += v[k] }
  if (kind == "mean") return s / m; sortv(v, m); return q(v, m, .5) }
FNR == 1 && FILENAME ~ /dates/ { }
FILENAME ~ /dates/ { nd++; dl[nd] = $1; next }
FNR == 1 { next }
$3 != "r0" { next }
{ side = ""; if ($1 == "reader") side = "R"; else if ($1 == who) side = "O"; if (side == "") next
  if (field == "hold") { if ($14 == "") next; val = $14 - $15 } else val = $11
  c[side, $2]++; X[side, $2, c[side, $2]] = val }
END {
  np = 0; pos = 0; delete D
  for (i = 1; i <= nd; i++) { d = dl[i]; r = agg("R", d, kind); o = agg("O", d, kind)
    if (abst == 1) { if (r == "NA" && o == "NA") continue; if (r == "NA") r = 0; if (o == "NA") o = 0 }
    else if (r == "NA" || o == "NA") continue
    np++; D[np] = r - o; if (r - o > 0) pos++ }
  sortv(D, np)
  printf "%-8s %-6s %-6s abst=%d: paired dates %2d, reader ahead %2d (%3.0f%%), median %+6.1f%%, p25 %+6.1f, p75 %+6.1f, min %+6.1f, max %+6.1f\n", who, field, kind, abst, np, pos, 100*pos/np, 100*q(D,np,.5), 100*q(D,np,.25), 100*q(D,np,.75), 100*D[1], 100*D[np]
}
