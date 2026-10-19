# thumb.awk: one stock's 5-year contact-sheet thumbnail as SVG (600 x 400), as a reader would have seen it on the
# cut date (plan §3 step C). The small sibling of the 2026-10-13 chart.awk, on the same helpers and the same rules.
# Usage: awk -F, -v cut=YYYY-MM-DD -v sym=PSEUDO -f days.awk -f chartlib.awk -f thumb.awk <weekly.csv from weekly.sh>
# Panels: weekly bars on a log scale with the 30-week MA; volume; Mansfield RS vs SPY. Frame: the 260 weeks to the
# cut plus 26 grey weeks of hidden future.
# Causality: only rows dated <= the cut week are read into the picture and every axis range comes from them; the
# price level is rescaled so the cut week's close is its raw close, volume is in the cut date's shares (as chart.awk).
# The calendar axis shows years, as on the composite (plan §3 blinding note).
BEGIN { W = 600; H = 400; frame_init(cut, "5y") }
NR == 1 { next }
{ z = days($1); if (z > CUTZ) next
  n++; wz[n] = z; wo[n] = $2; wh[n] = $3; wl[n] = $4; wc[n] = $5; wv[n] = $6; wm[n] = $7; wr[n] = $8
  rawc[n] = $9; sidx[n] = $10 }
END {
  PL = 8; PR = W - 52; BW = (PR - PL) / ((FZ1 - FZ0) / 7 + 1)
  T0 = 30; P1 = 270; V0 = 276; V1 = 316; R0 = 322; R1 = 380
  svg_open(H)
  k = (n > 0 && wc[n] > 0) ? rawc[n] / wc[n] : 1; sx = (n > 0) ? sidx[n] : 1
  lo = 0; hi = 0; vmax = 0; rmax = 10; nv = 0
  for (i = 1; i <= n; i++) if (inframe(wz[i])) {
    nv++; if (lo == 0 || wl[i] * k < lo) lo = wl[i] * k; if (wh[i] * k > hi) hi = wh[i] * k
    if (wm[i] != "" && wm[i] * k < lo) lo = wm[i] * k
    if (wm[i] != "" && wm[i] * k > hi) hi = wm[i] * k
    if (wv[i] * sx > vmax) vmax = wv[i] * sx
    if (wr[i] != "" && (wr[i] < 0 ? -wr[i] : wr[i]) > rmax) rmax = (wr[i] < 0 ? -wr[i] : wr[i])
  }
  txt(PL, 20, sym, 18, "start", " font-weight=\"bold\"")
  if (n > 0) txt(PR, 20, sprintf("close %s  MA %s  RS %s", pfmt(rawc[n]), (wm[n] == "" ? "n/a" : pfmt(wm[n] * k)), (wr[n] == "" ? "n/a" : sprintf("%+.0f", wr[n]))), 14, "end", " fill=\"#222\"")
  year_axis(T0, P1, 0); year_axis(V0, V1, 0); year_axis(R0, R1, 1)
  if (nv == 0) txt((PL + PR) / 2, (T0 + P1) / 2, "no bars up to the cut", 14, "middle", " fill=\"#777\"")
  else {
    logscale(T0, P1, lo, hi)
    for (i = 1; i <= n; i++) if (inframe(wz[i])) {
      x = xw(wz[i]); col = (wc[i] >= wo[i]) ? "#1a1a1a" : "#b03030"
      line(x, ly(wh[i] * k), x, ly(wl[i] * k), col, 1, "")
    }
    p = ""
    for (i = 1; i <= n; i++) if (inframe(wz[i])) {
      if (wm[i] == "") { if (p != "") tpath(p, "#1f5fbf", 2); p = ""; continue }
      p = p (p == "" ? "M" : " L") f2(xw(wz[i])) "," f2(ly(wm[i] * k))
    }
    if (p != "") tpath(p, "#1f5fbf", 2)
    linscale(V0, V1, 0, (vmax > 0 ? vmax : 1))
    for (i = 1; i <= n; i++) if (inframe(wz[i]) && wv[i] > 0) line(xw(wz[i]), V1, xw(wz[i]), yl(wv[i] * sx), "#7a7a7a", 1, "")
    linscale(R0, R1, -rmax * 1.05, rmax * 1.05)
    line(PL, yl(0), PR, yl(0), "#888", 1, " stroke-dasharray=\"4,3\"")
    p = ""
    for (i = 1; i <= n; i++) if (inframe(wz[i])) {
      if (wr[i] == "") { if (p != "") tpath(p, "#2e7d32", 1.5); p = ""; continue }
      p = p (p == "" ? "M" : " L") f2(xw(wz[i])) "," f2(yl(wr[i]))
    }
    if (p != "") tpath(p, "#2e7d32", 1.5)
    txt(PL + 4, R0 + 11, "RS", 11, "start", " fill=\"#2e7d32\"")
  }
  future_block(T0, P1, 0); future_block(V0, V1, 0); future_block(R0, R1, 0)
  panel_box(T0, P1); panel_box(V0, V1); panel_box(R0, R1)
  print "</svg>"
}
function tpath(d, stroke, wd) { printf "<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\"/>\n", d, stroke, wd }
