# Fresh-eyes study: one symbol's daily bars -> weekly bars keyed by the week's Friday.
# Usage: awk -F, -f days.awk -f weekly.awk <SPY data.csv> <SYM data.csv> <SYM splits.csv or /dev/null>
# Output (header + one row per week):
#   week,open,high,low,close,vol_base,ma30,rs,raw_close,split_index
# - open/high/low/close: on the vendor's adjusted basis (raw x adjusted_close/close per day). That basis is
#   back-adjusted from the data end, so its LEVEL encodes future splits and dividends; chart.awk rescales every
#   series so the cut week's close equals its raw close, which leaves only actions up to the cut in the picture.
# - vol_base: the week's volume in "base" shares. The vendor volume is already split-adjusted to the data end
#   (AAPL 2014-06-06: 349.9M, about 7x the raw count), so base = vendor volume / product of all split factors;
#   x split_index at the cut gives the share count a reader saw then, without knowing later splits.
# - ma30: 30-week simple MA of close (empty until 30 weeks). rs: Mansfield RS vs SPY in percent,
#   100 x (ratio / 52-week mean ratio - 1), ratio = close / SPY close (empty until 52 weeks with SPY).
# Every value is a trailing function of bars up to its week, so truncating the input at a Friday changes no row
# up to that Friday.
FNR == 1 { fi++; next }
fi == 1 { if ($6 + 0 <= 0) next; k = friday(days($1)); spy[k] = $6; next }
fi == 2 { if ($5 + 0 <= 0 || $6 + 0 <= 0) next
          nd++; dd[nd] = $1; f = $6 / $5; o[nd] = $2 * f; h[nd] = $3 * f; l[nd] = $4 * f; c[nd] = $6
          rc[nd] = $5; v[nd] = $7 + 0; next }
fi == 3 { ns++; sd[ns] = $1; sf[ns] = $2 + 0; next }
END {
  print "week,open,high,low,close,vol_base,ma30,rs,raw_close,split_index"
  stot = 1; for (j = 1; j <= ns; j++) if (sf[j] > 0) stot *= sf[j]
  si = 1; j = 1; nw = 0
  for (i = 1; i <= nd; i++) {
    while (j <= ns && sd[j] <= dd[i]) { if (sf[j] > 0) si *= sf[j]; j++ }
    k = friday(days(dd[i]))
    if (nw == 0 || k != wk[nw]) { nw++; wk[nw] = k; wo[nw] = o[i]; wh[nw] = h[i]; wl[nw] = l[i]; wv[nw] = 0 }
    if (h[i] > wh[nw]) wh[nw] = h[i]
    if (l[i] < wl[nw]) wl[nw] = l[i]
    wc[nw] = c[i]; wr[nw] = rc[i]; wv[nw] += v[i] / stot; ws[nw] = si
  }
  for (i = 1; i <= nw; i++) {
    sum += wc[i]; if (i > 30) sum -= wc[i - 30]
    ma = (i >= 30) ? sprintf("%.6g", sum / 30) : ""
    r[i] = (wk[i] in spy) ? wc[i] / spy[wk[i]] : 0
    rs = ""
    if (i >= 52) { ok = 1; s = 0; for (t = i - 51; t <= i; t++) { if (r[t] <= 0) ok = 0; s += r[t] }
                   if (ok) rs = sprintf("%.4f", 100 * (r[i] / (s / 52) - 1)) }
    printf "%s,%.6g,%.6g,%.6g,%.6g,%.6g,%s,%s,%.6g,%.6g\n", civil(wk[i]), wo[i], wh[i], wl[i], wc[i], wv[i], ma, rs, wr[i], ws[i]
  }
}
