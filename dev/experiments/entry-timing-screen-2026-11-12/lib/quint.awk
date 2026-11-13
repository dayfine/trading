# quint.awk -- per decision-time feature: quintiles of unique trades with win rate, median trade, +50 % trades, NAV-%;
# AUC for "+50 % or better" and for "loser" (probability a positive scores above a negative on the feature).
function auc(c, tgt,   i, j, pos, neg, s, nn, r, rk, v, idx, m, t) {   # rank-based Mann-Whitney on rows with a value
  m = 0; for (i = 1; i <= n; i++) if (X[i, c] != "") { m++; v[m] = X[i, c] + 0; idx[m] = i }
  for (i = 2; i <= m; i++) { t = v[i]; ti = idx[i]; j = i - 1; while (j > 0 && v[j] > t) { v[j + 1] = v[j]; idx[j + 1] = idx[j]; j-- }; v[j + 1] = t; idx[j + 1] = ti }
  i = 1; while (i <= m) { j = i; while (j < m && v[j + 1] == v[i]) j++; r = (i + j) / 2; for (q = i; q <= j; q++) rk[q] = r; i = j + 1 }
  pos = 0; neg = 0; s = 0
  for (i = 1; i <= m; i++) { y = (tgt == "tail") ? (PC[idx[i]] >= 50) : (PC[idx[i]] < 0); if (y) { pos++; s += rk[i] } else neg++ }
  return (pos && neg) ? (s - pos * (pos + 1) / 2) / (pos * neg) : 0.5 }
{ n++; PC[n] = $3 + 0; NV[n] = $4 + 0; for (c = 5; c <= 16; c++) X[n, c] = $c }
END { split("ext_screen ext_fill E/fill rt4/fill code_stop_dist book_floor_dist vol_ratio rs weeks_adv score ma_slope ticket_age", NM, " ")
  for (c = 5; c <= 16; c++) { m = 0; delete v; delete idx
    for (i = 1; i <= n; i++) if (X[i, c] != "") { m++; v[m] = X[i, c] + 0; idx[m] = i }
    for (i = 2; i <= m; i++) { t = v[i]; ti = idx[i]; j = i - 1; while (j > 0 && v[j] > t) { v[j + 1] = v[j]; idx[j + 1] = idx[j]; j-- }; v[j + 1] = t; idx[j + 1] = ti }
    printf "\n%-15s n=%d  AUC(+50%%)=%.2f  AUC(loser)=%.2f\n", NM[c - 4], m, auc(c, "tail"), auc(c, "loss")
    for (qq = 1; qq <= 5; qq++) { a = int((qq - 1) * m / 5) + 1; b = int(qq * m / 5); cnt = 0; w = 0; t5 = 0; nav = 0; delete pp
      for (i = a; i <= b; i++) { r = idx[i]; cnt++; w += (PC[r] > 0); t5 += (PC[r] >= 50); nav += NV[r]; pp[cnt] = PC[r] }
      for (i = 2; i <= cnt; i++) { t = pp[i]; j = i - 1; while (j > 0 && pp[j] > t) { pp[j + 1] = pp[j]; j-- }; pp[j + 1] = t }
      printf "  Q%d [%8.3f .. %8.3f] n=%3d win %4.1f%%  median %+6.1f%%  +50%% trades %2d  NAV-%% %+6.1f (%+.2f/trade)\n", qq, v[a], v[b], cnt, 100 * w / cnt, pp[int((cnt + 1) / 2)], t5, nav, nav / cnt } } }
