# rsum.awk -- R1 tables: per window W and seed: stop exits, re-entry fills (incremental = not re-bought by the run anyway),
# gate drops, NAV-% of incremental fills, per-fill mean, median trade, win rate, +50 % fills; k0 cash-binding share.
function wk(d,   y, m, dd, n) { y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  n = 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd; return n - (n + 2) % 7 + 4 }   # the week's Friday
FILENAME ~ /cashweeks/ { CW[wk($1)] = 1; next }
{ k = $1; ns[k]++; ini[k] += $5
  for (q = 1; q <= 3; q++) { o = 5 + (q - 1) * 6; st = $(o + 1); dup = $(o + 6)
    if (st == "D") gd[q, k]++
    if (st == "F") { if (dup) { du[q, k]++; continue }
      n[q, k]++; s[q, k] += $(o + 4); w[q, k] += ($(o + 3) > 0); b[q, k] += ($(o + 3) >= 50); R[q, k, n[q, k]] = $(o + 3)
      if (k == 0) { cb[q] += (wk($(o + 2)) in CW) } } } }
END { split("8 13 26", WW, " ")
  for (k = 0; k <= 4; k++) printf "k%d stop exits %d (initial-stop exits %d)\n", k, ns[k], ini[k]
  for (q = 1; q <= 3; q++) { printf "\n== re-entry window %s weeks\n", WW[q]
    for (k = 0; k <= 4; k++) { m = n[q, k]; delete v; for (i = 1; i <= m; i++) v[i] = R[q, k, i]
      for (i = 2; i <= m; i++) { x = v[i]; j = i - 1; while (j > 0 && v[j] > x) { v[j + 1] = v[j]; j-- }; v[j + 1] = x }
      printf "k%d fills %3d (+%d the run re-bought anyway, %d blocked by the 15%% rule)  NAV-%% %+6.1f  per fill %+.2f  median trade %+5.1f%%  win %4.1f%%  +50%% fills %d\n", k, m, du[q, k], gd[q, k], s[q, k], m ? s[q, k] / m : 0, m ? v[int((m + 1) / 2)] : 0, m ? 100 * w[q, k] / m : 0, b[q, k] }
    printf "k0 fills in weeks where cash was already short (an Insufficient_cash skip that week): %d of %d\n", cb[q], n[q, 0] } }
