# Date-clustered bootstrap of the 104-week hold, ratio form h = (1 + r104) / (1 + spy104) - 1, reader long r0 vs ours-s0.
# Stats: median of h, and the geometric mean exp(mean log(1 + h)) - 1. Usage: awk -F, -v seed=N -f boot_hold2.awk trades.csv
function sortv(a, n,   i, j, t) { for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t } }
function q(a, n, p,   x) { if (n == 0) return 0; x = 1 + (n - 1) * p; return a[int(x)] + (x - int(x)) * (a[int(x) + 1 < n ? int(x) + 1 : n] - a[int(x)]) }
NR == 1 || $3 != "r0" || $14 == "" { next }
($1 == "reader" && $5 == "long") || $1 == "ours-s0" {
  s = ($1 == "reader") ? "R" : "O"; if (!($2 in seen)) { seen[$2] = 1; nd++; dl[nd] = $2 }
  k = ++cnt[s, $2]; H[s, $2, k] = (1 + $14) / (1 + $15) - 1 }
function stat(side, kind,   i, k, d, m, lg) { m = 0; lg = 0; delete V
  for (i = 1; i <= nd; i++) { d = pick[i]; for (k = 1; k <= cnt[side, d]; k++) { m++; V[m] = H[side, d, k]; lg += log(1 + V[m]) } }
  if (m == 0) return "NA"; if (kind == "geo") return exp(lg / m) - 1; sortv(V, m); return q(V, m, 0.5) }
END { srand(seed); B = 10000; for (i = 1; i <= nd; i++) pick[i] = dl[i]
  split("median geo", K, " "); for (kk = 1; kk <= 2; kk++) { o[kk] = stat("R", K[kk]); w[kk] = stat("O", K[kk]) }
  for (b = 1; b <= B; b++) { for (i = 1; i <= nd; i++) pick[i] = dl[1 + int(rand() * nd)]
    for (kk = 1; kk <= 2; kk++) { r = stat("R", K[kk]); s = stat("O", K[kk]); if (r == "NA" || s == "NA") continue; nb[kk]++; D[kk, nb[kk]] = r - s; if (r - s > 0) pos[kk]++ } }
  for (kk = 1; kk <= 2; kk++) { m = nb[kk]; delete W; for (i = 1; i <= m; i++) W[i] = D[kk, i]; sortv(W, m)
    printf "hold-104w %-6s reader %+5.1f %% ours %+5.1f %% diff %+5.1f pp  95%% CI [%+6.1f, %+6.1f]  P(diff>0) %.2f\n", K[kk], 100*o[kk], 100*w[kk], 100*(o[kk]-w[kk]), 100*q(W,m,.025), 100*q(W,m,.975), pos[kk]/m } }
