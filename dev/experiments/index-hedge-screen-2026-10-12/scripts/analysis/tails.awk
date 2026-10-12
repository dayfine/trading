# Tail access from a days.awk table: of SPY's 50 largest up days and 50 largest down days over the window (SPY
# sessions only), how many fell on gate-on days; and the 10 largest each way (* = G1 on).
BEGIN { FS = "," }
$5 { n++; d[n] = $1; r[n] = $3; for (g = 1; g <= 3; g++) { G[g, n] = $(5 + g); on[g] += $(5 + g) }; mean += $3 }
END { for (k = 1; k <= 50; k++) { bu = -1e9; iu = 0; bd = 1e9; id = 0
    for (i = 1; i <= n; i++) { if (!(i in U) && r[i] > bu) { bu = r[i]; iu = i } if (!(i in Dn) && r[i] < bd) { bd = r[i]; id = i } }
    U[iu] = 1; Dn[id] = 1; for (g = 1; g <= 3; g++) { cu[g] += G[g, iu]; cd[g] += G[g, id] }
    if (k <= 10) { tu = tu sprintf(" %s %+.1f%s", d[iu], 100 * r[iu], (G[1, iu] ? "*" : "")); td = td sprintf(" %s %+.1f%s", d[id], 100 * r[id], (G[1, id] ? "*" : "")) } }
  printf "SPY sessions %d; share on: G1 %.1f%% G2 %.1f%% G3 %.1f%%\n", n, 100 * on[1] / n, 100 * on[2] / n, 100 * on[3] / n
  printf "top-50 up days on the short:   G1 %d  G2 %d  G3 %d\n", cu[1], cu[2], cu[3]
  printf "top-50 down days on the short: G1 %d  G2 %d  G3 %d\n", cd[1], cd[2], cd[3]
  print "top-10 up (* G1 on):" tu; print "top-10 down (* G1 on):" td }
