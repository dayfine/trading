# Fresh-eyes study: one stock's weekly chart as SVG, as a reader would have seen it on the cut date (plan §3).
# Usage: awk -F, -v cut=YYYY-MM-DD -v frame=full|5y -v sym=X -v sector="..." \
#          -f days.awk -f chartlib.awk -f chart.awk <weekly.csv from weekly.sh>
# Panels: weekly OHLC bars on a log scale with the 30-week MA; volume; Mansfield RS vs SPY with its zero line.
# Causality: only rows dated <= the cut week are read into the picture, and every axis range comes from them.
# Price level: the vendor's back-adjusted series is rescaled so the cut week's close equals its raw close, and
# volume is expressed in the cut date's share count, so no later split or dividend shows in the numbers.
BEGIN { W = 1600; H = 1000; frame_init(cut, frame) }
NR == 1 { next }
{ z = days($1); if (z > CUTZ) next
  n++; wz[n] = z; wo[n] = $2; wh[n] = $3; wl[n] = $4; wc[n] = $5; wv[n] = $6; wm[n] = $7; wr[n] = $8
  rawc[n] = $9; sidx[n] = $10 }
END {
  T0 = 48; P1 = 600; V0 = 612; V1 = 742; R0 = 754; R1 = 944
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
  title = sym "  |  " sector "  |  weekly bars through " cut "  |  " (frame == "full" ? "frame 2000-2026" : "frame: last 5 years")
  txt(PL, 22, title, 18, "start", " font-weight=\"bold\"")
  txt(PL, 40, "Prices adjusted for splits and dividends up to " cut " (the last bar is the real close then); volume in that date's shares.", 12, "start", " fill=\"#555\"")
  if (n > 0) txt(PR, 40, sprintf("last week %s: close %s, 30w MA %s, RS %s", civil(wz[n]), pfmt(rawc[n]), (wm[n] == "" ? "n/a" : pfmt(wm[n] * k)), (wr[n] == "" ? "n/a" : sprintf("%+.1f", wr[n]))), 12, "end", " fill=\"#222\"")
  year_axis(T0, P1, 0); year_axis(V0, V1, 0); year_axis(R0, R1, 1)
  if (nv == 0) { txt((PL + PR) / 2, (T0 + P1) / 2, "no bars in this frame up to the cut", 16, "middle", " fill=\"#777\"") }
  else {
    logscale(T0, P1, lo, hi)
    for (i = 1; i <= n; i++) if (inframe(wz[i])) {
      x = xw(wz[i]); col = (wc[i] >= wo[i]) ? "#1a1a1a" : "#b03030"
      line(x, ly(wh[i] * k), x, ly(wl[i] * k), col, (BW > 3 ? 1.2 : 1), "")
      if (BW > 3) { line(x - BW * 0.4, ly(wo[i] * k), x, ly(wo[i] * k), col, 1, ""); line(x, ly(wc[i] * k), x + BW * 0.4, ly(wc[i] * k), col, 1, "") }
    }
    ma_path = ""
    for (i = 1; i <= n; i++) if (inframe(wz[i])) {
      if (wm[i] == "") { if (ma_path != "") { pathout(ma_path, "#1f5fbf", 2) } ma_path = ""; continue }
      ma_path = ma_path (ma_path == "" ? "M" : " L") f2(xw(wz[i])) "," f2(ly(wm[i] * k))
    }
    if (ma_path != "") pathout(ma_path, "#1f5fbf", 2)
    txt(PL + 6, T0 + 16, "30-week MA", 12, "start", " fill=\"#1f5fbf\"")
    # Volume.
    linscale(V0, V1, 0, (vmax > 0 ? vmax : 1))
    for (i = 1; i <= n; i++) if (inframe(wz[i]) && wv[i] > 0) line(xw(wz[i]), V1, xw(wz[i]), yl(wv[i] * sx), "#7a7a7a", (BW > 2 ? BW * 0.7 : 1), "")
    txt(PR + 6, V0 + 10, vfmt(vmax), 11, "start", " fill=\"#444\""); txt(PL + 6, V0 + 14, "weekly volume", 12, "start", " fill=\"#555\"")
    # Mansfield RS.
    linscale(R0, R1, -rmax * 1.05, rmax * 1.05)
    line(PL, yl(0), PR, yl(0), "#888", 1, " stroke-dasharray=\"4,3\"")
    rs_path = ""
    for (i = 1; i <= n; i++) if (inframe(wz[i])) {
      if (wr[i] == "") { if (rs_path != "") pathout(rs_path, "#2e7d32", 1.5); rs_path = ""; continue }
      rs_path = rs_path (rs_path == "" ? "M" : " L") f2(xw(wz[i])) "," f2(yl(wr[i]))
    }
    if (rs_path != "") pathout(rs_path, "#2e7d32", 1.5)
    txt(PR + 6, yl(0) + 4, "0", 11, "start", " fill=\"#444\""); txt(PR + 6, R0 + 10, sprintf("%+.0f", rmax * 1.05), 11, "start", " fill=\"#444\"")
    txt(PR + 6, R1, sprintf("%+.0f", -rmax * 1.05), 11, "start", " fill=\"#444\"")
    txt(PL + 6, R0 + 14, "Mansfield relative strength vs SPY (52-week), %", 12, "start", " fill=\"#2e7d32\"")
  }
  future_block(T0, P1, 1); future_block(V0, V1, 0); future_block(R0, R1, 0)
  panel_box(T0, P1); panel_box(V0, V1); panel_box(R0, R1)
  print "</svg>"
}
function pathout(d, stroke, wd) { printf "<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\"/>\n", d, stroke, wd }
