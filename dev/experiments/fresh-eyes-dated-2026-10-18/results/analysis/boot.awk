function sortv(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } }
function q(a, n, p,   x) { if (n == 0) return 0; x = 1 + (n - 1) * p; return a[int(x)] + (x - int(x)) * (a[int(x) + 1 < n ? int(x) + 1 : n] - a[int(x)]) }
NR == 1 { next }
$3 != "r0" { next }
($1 == "reader" && $5 == "long") || $1 == "ours-s0" {
  s = ($1 == "reader") ? "R" : "O"
  if (!($2 in seen)) { seen[$2] = 1; nd++; dl[nd] = $2 }
  k = ++cnt[s, $2]; X[s, $2, k] = $11 + 0; L[s, $2, k] = log((1 + $9) / (1 + $10)); Y[s, $2, k] = ($12 < 7 ? 7 : $12) / 365
}
function stat(side, kind,   i, j, k, d, m, s, ly, yy) {
  m = 0; s = 0; ly = 0; yy = 0; delete V
  for (i = 1; i <= nd; i++) { d = pick[i]; for (k = 1; k <= cnt[side, d]; k++) { m++; V[m] = X[side, d, k]; s += V[m]; ly += L[side, d, k]; yy += Y[side, d, k] } }
  if (m == 0) return "NA"
  if (kind == "mean") return s / m
  if (kind == "tn") return exp(ly / yy) - 1
  sortv(V, m); return q(V, m, 0.5)
}
END {
  srand(seed); B = 10000
  for (i = 1; i <= nd; i++) pick[i] = dl[i]
  split("mean median tn", K, " ")
  for (kk = 1; kk <= 3; kk++) { obs[kk] = stat("R", K[kk]) - stat("O", K[kk]) }
  for (b = 1; b <= B; b++) {
    for (i = 1; i <= nd; i++) pick[i] = dl[1 + int(rand() * nd)]
    for (kk = 1; kk <= 3; kk++) { r = stat("R", K[kk]); o = stat("O", K[kk]); if (r == "NA" || o == "NA") { bad[kk]++; continue } ; nb[kk]++; D[kk, nb[kk]] = r - o; if (r - o > 0) pos[kk]++ }
  }
  printf "clusters (dates with a long trade on either side): %d\n", nd
  for (kk = 1; kk <= 3; kk++) { m = nb[kk]; delete W; for (i = 1; i <= m; i++) W[i] = D[kk, i]; sortv(W, m)
    printf "reader-long minus ours-s0 %-6s observed %+6.1f pp  95%% CI [%+6.1f, %+6.1f]  P(diff>0) %.2f\n", K[kk], 100*obs[kk], 100*q(W,m,.025), 100*q(W,m,.975), pos[kk]/m }
}
