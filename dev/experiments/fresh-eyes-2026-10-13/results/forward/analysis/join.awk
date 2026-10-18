# join.awk: per symbol, join the chart's weekly series, our classifier's stage CSV and the reader's decisions.
# Usage: awk -F, -v sym=SYM -f days.awk -f join.awk weekly/SYM.csv stages/SYM.csv decisions_SYM.csv
# Output: one row per reader decision with features (see header in END).
FNR == 1 { fi++; next }
fi == 1 { n++; wk[n] = $1; o[n] = $2; h[n] = $3; l[n] = $4; c[n] = $5; v[n] = $6; sma[n] = $7; rs[n] = $8
          idx[$1] = n; next }
fi == 2 { k = civil(friday(days($2))); ost[k] = substr($5, 6, 1); owk[k] = $6; olate[k] = $7; oma[k] = $4; next }
fi == 3 { nd++; dl[nd] = $0; next }
END {
  # recompute WMA30 on the chart's adjusted close
  for (i = 30; i <= n; i++) { s = 0; w = 0; for (j = 1; j <= 30; j++) { s += j * c[i - 30 + j]; w += j }; wma[i] = s / w }
  print "sym,cut,rd_stage,action,our_stage,our_wks,our_late,close,sma,wma,our_ma_csv,wma_slope4,above6,sma_slope4,sma_slope5,sma_slope6,hi26,hi52,lo26,lo52,c_hi26,c_hi52,c_lo26,c_lo52,rs,rs13,fwd13,fwd26,brk_hi52_26,brk_lo26_26,reason"
  for (d = 1; d <= nd; d++) {
    split(dl[d], f, ",")
    cut = f[2]; i = idx[cut]
    if (!i) { printf "%s,%s,NOWEEK\n", sym, cut > "/dev/stderr"; continue }
    rd = f[3]; act = f[4]
    # reason = everything after the 8th comma
    r = dl[d]; for (q = 1; q <= 8; q++) r = substr(r, index(r, ",") + 1); gsub(/,/, ";", r)
    os = (cut in ost) ? ost[cut] : "NA"; ow = (cut in owk) ? owk[cut] : ""; ol = (cut in olate) ? olate[cut] : ""
    om = (cut in oma) ? oma[cut] : ""
    ws4 = (i > 34 && wma[i - 4] > 0) ? (wma[i] - wma[i - 4]) / wma[i - 4] : ""
    ab = 0; for (k = 0; k < 6; k++) if (i - k >= 30 && c[i - k] > wma[i - k]) ab++
    ss4 = (sma[i - 4] > 0) ? (sma[i] - sma[i - 4]) / sma[i - 4] : ""
    ss5 = (sma[i - 5] > 0) ? (sma[i] - sma[i - 5]) / sma[i - 5] : ""
    ss6 = (sma[i - 6] > 0) ? (sma[i] - sma[i - 6]) / sma[i - 6] : ""
    hi26 = 0; lo26 = 1e18; for (k = 1; k <= 26 && i - k >= 1; k++) { if (h[i - k] > hi26) hi26 = h[i - k]; if (l[i - k] < lo26) lo26 = l[i - k] }
    hi52 = 0; lo52 = 1e18; for (k = 1; k <= 52 && i - k >= 1; k++) { if (h[i - k] > hi52) hi52 = h[i - k]; if (l[i - k] < lo52) lo52 = l[i - k] }
    f13 = (i + 13 <= n) ? c[i + 13] / c[i] - 1 : ""
    f26 = (i + 26 <= n) ? c[i + 26] / c[i] - 1 : ""
    bh = 0; bl = 0; for (k = 1; k <= 26 && i + k <= n; k++) { if (h[i + k] > hi52 && !bh) bh = k; if (l[i + k] < lo26 && !bl) bl = k }
    rs13 = (i > 13) ? rs[i - 13] : ""
    printf "%s,%s,%s,%s,%s,%s,%s,%.6g,%.6g,%.6g,%s,%s,%d,%s,%s,%s,%.6g,%.6g,%.6g,%.6g,%.4f,%.4f,%.4f,%.4f,%s,%s,%s,%s,%d,%d,%s\n", \
      sym, cut, rd, act, os, ow, ol, c[i], sma[i], wma[i], om, ws4, ab, ss4, ss5, ss6, hi26, hi52, lo26, lo52, \
      c[i] / hi26 - 1, c[i] / hi52 - 1, c[i] / lo26 - 1, c[i] / lo52 - 1, rs[i], rs13, f13, f26, bh, bl, r
  }
}
