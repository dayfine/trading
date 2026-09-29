# Period (year or quarter) table -> JSON array on stdout.
# usage: awk -v gran=Y|Q -f periods.awk SPY.csv equity_curve.csv expo.tsv trades.csv macro.tsv
# Files are told apart by FILENAME order (ARGIND not in BSD awk -> use a counter).
function key(d,   y, m) { y = substr(d, 1, 4); if (gran == "Y") return y; m = substr(d, 6, 2) + 0; return y "Q" int((m - 1) / 3) + 1 }
FNR == 1 { fi++ }
fi == 1 { if (FNR == 1) { FS = ","; next } split($0, a, ","); spy[a[1]] = a[6]; next }
fi == 2 { if (FNR == 1) next; split($0, a, ","); nd++; nds[nd] = a[1]; nav[a[1]] = a[2]; next }
fi == 3 { split($0, a, "\t"); ex[a[1]] += a[2]; np[a[1]]++; next }
fi == 4 { if (FNR == 1) next; split($0, a, ",")
          k = key(a[3]); opened[k]++
          k = key(a[4]); closed[k]++; pnl[k] += a[9]; if (a[9] > 0) wins[k]++
          next }
fi == 5 { split($0, a, "\t"); k = key(a[1]); mw[k]++; mt[k, a[2]]++; next }
END {
  # SPY: carry last known adj close onto every NAV date
  peak_all = 0; nk = 0; last_spy = 0
  for (i = 1; i <= nd; i++) {
    d = nds[i]; v = nav[d] + 0; if (d in spy) last_spy = spy[d] + 0
    k = key(d)
    if (!(k in seen)) { seen[k] = 1; nk++; ks[nk] = k
      s_nav[k] = (i > 1) ? prev_v : v; s_spy[k] = (i > 1) ? prev_spy : last_spy
      pk[k] = s_nav[k]; mdd[k] = 0; dda[k] = 0 }
    e_nav[k] = v; e_spy[k] = last_spy; e_date[k] = d; if (!(k in s_date)) s_date[k] = d
    if (v > pk[k]) pk[k] = v; dd = (pk[k] > 0) ? 1 - v / pk[k] : 0; if (dd > mdd[k]) mdd[k] = dd
    if (v > peak_all) peak_all = v; dd = 1 - v / peak_all; if (dd > dda[k]) dda[k] = dd
    ndays[k]++; expo[k] += (v > 0) ? ex[d] / v : 0; pos[k] += np[d]
    prev_v = v; prev_spy = last_spy
  }
  printf "["
  for (j = 1; j <= nk; j++) {
    k = ks[j]
    r = (s_nav[k] > 0) ? (e_nav[k] / s_nav[k] - 1) * 100 : 0
    sr = (s_spy[k] > 0) ? (e_spy[k] / s_spy[k] - 1) * 100 : 0
    printf "%s{\"p\":\"%s\",\"from\":\"%s\",\"to\":\"%s\",\"nav0\":%.0f,\"nav1\":%.0f,\"ret\":%.2f,\"spy\":%.2f,\"mdd\":%.2f,\"dd_peak\":%.2f,\"expo\":%.1f,\"pos\":%.1f,\"opened\":%d,\"closed\":%d,\"wins\":%d,\"pnl\":%.0f,\"wk\":%d,\"bull\":%d,\"neut\":%d,\"bear\":%d}", \
      (j > 1 ? ",\n" : ""), k, s_date[k], e_date[k], s_nav[k], e_nav[k], r, sr, mdd[k] * 100, dda[k] * 100, \
      100 * expo[k] / ndays[k], pos[k] / ndays[k], opened[k], closed[k], wins[k], pnl[k], mw[k], mt[k, "Bullish"], mt[k, "Neutral"], mt[k, "Bearish"]
  }
  print "]"
}
