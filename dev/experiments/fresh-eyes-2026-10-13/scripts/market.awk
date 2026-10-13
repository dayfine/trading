# Fresh-eyes study: the market pack as SVG for one cut date (plan §3): SPY with its 30-week MA and volume, the cumulative
# NYSE advance-decline line, and sector strength as small multiples.
# Usage: awk -F, -v cut=YYYY-MM-DD -v frame=full|5y -f days.awk -f chartlib.awk -f market.awk \
#          spy-weekly.csv ad-weekly.csv sector-strength.csv
# Same causality rules as chart.awk: rows after the cut week are never read, every range comes from rows <= cut.
BEGIN { W = 1600; H = 1260; frame_init(cut, frame) }
FNR == 1 { fi++; next }
{ z = days($1); if (z > CUTZ) next }
fi == 1 { n++; sz[n] = z; sh[n] = $3; sl[n] = $4; sc[n] = $5; sv[n] = $6; sm[n] = $7; sr[n] = $9; si[n] = $10; next }
fi == 2 { na++; az[na] = z; av[na] = $2 + 0; as[na] = $3; next }
fi == 3 { if (!($2 in seen)) { seen[$2] = 1; nsec++; sec[nsec] = $2 } rel[$2, z] = $6 + 0; cnt[$2, z] = $4; if (z > lastz) lastz = z; next }
END {
  svg_open(H)
  txt(PL, 22, "MARKET  |  weekly through " cut "  |  " (frame == "full" ? "frame 2000-2026" : "frame: last 5 years"), 18, "start", " font-weight=\"bold\"")
  txt(PL, 40, "SPY adjusted for splits and dividends up to " cut "; A-D line = cumulative NYSE advances - declines; sector strength = sector median 26-week return - SPY's.", 12, "start", " fill=\"#555\"")
  spy_panel(48, 340); spy_volume(348, 430); ad_panel(450, 640); sector_panel(690, 1250)
  print "</svg>"
}
function spy_panel(top, bot,   i, k, lo, hi, x, d, nv) {
  k = (n > 0 && sc[n] > 0) ? sr[n] / sc[n] : 1
  for (i = 1; i <= n; i++) if (inframe(sz[i])) { nv++; if (lo == 0 || sl[i] * k < lo) lo = sl[i] * k; if (sh[i] * k > hi) hi = sh[i] * k }
  year_axis(top, bot, 0)
  if (nv > 0) {
    logscale(top, bot, lo, hi)
    for (i = 1; i <= n; i++) if (inframe(sz[i])) { x = xw(sz[i]); line(x, ly(sh[i] * k), x, ly(sl[i] * k), "#1a1a1a", 1, "") }
    d = ""; for (i = 1; i <= n; i++) if (inframe(sz[i]) && sm[i] != "") d = d (d == "" ? "M" : " L") f2(xw(sz[i])) "," f2(ly(sm[i] * k))
    if (d != "") printf "<path d=\"%s\" fill=\"none\" stroke=\"#1f5fbf\" stroke-width=\"2\"/>\n", d
    txt(PL + 6, top + 16, sprintf("SPY weekly with 30-week MA (blue)  |  last close %s, MA %s", pfmt(sr[n]), (sm[n] == "" ? "n/a" : pfmt(sm[n] * k))), 12, "start", " fill=\"#222\"")
  }
  future_block(top, bot, 1); panel_box(top, bot)
}
# SPY weekly volume in the cut date's shares (as chart.awk); the max comes from in-frame rows <= the cut.
function spy_volume(top, bot,   i, vmax, sx) {
  sx = (n > 0) ? si[n] : 1
  for (i = 1; i <= n; i++) if (inframe(sz[i]) && sv[i] * sx > vmax) vmax = sv[i] * sx
  year_axis(top, bot, 0)
  if (vmax > 0) {
    linscale(top, bot, 0, vmax)
    for (i = 1; i <= n; i++) if (inframe(sz[i]) && sv[i] > 0) line(xw(sz[i]), bot, xw(sz[i]), yl(sv[i] * sx), "#7a7a7a", (BW > 2 ? BW * 0.7 : 1), "")
    txt(PR + 6, top + 10, vfmt(vmax), 11, "start", " fill=\"#444\"")
  }
  txt(PL + 6, top + 14, "SPY weekly volume", 12, "start", " fill=\"#555\"")
  future_block(top, bot, 0); panel_box(top, bot)
}
function ad_panel(top, bot,   i, lo, hi, nv, d, x, spl, syn) {
  for (i = 1; i <= na; i++) if (inframe(az[i])) { syn = (as[i] == "synthetic"); if (nv == 0 || av[i] < lo) lo = av[i]; if (nv == 0 || av[i] > hi) hi = av[i]; nv++ }
  year_axis(top, bot, 1)
  if (nv > 0) {
    linscale(top + 4, bot - 4, lo, hi)
    d = ""; for (i = 1; i <= na; i++) if (inframe(az[i])) d = d (d == "" ? "M" : " L") f2(xw(az[i])) "," f2(yl(av[i]))
    printf "<path d=\"%s\" fill=\"none\" stroke=\"#6a1b9a\" stroke-width=\"1.5\"/>\n", d
    for (i = 2; i <= na; i++) if (as[i] == "synthetic" && as[i - 1] == "nyse" && inframe(az[i])) {
      x = xw(az[i]); line(x, top, x, bot, "#6a1b9a", 1, " stroke-dasharray=\"3,3\""); spl = 1
    }
    txt(PR + 6, top + 12, sprintf("%.0f", hi), 11, "start", " fill=\"#444\""); txt(PR + 6, bot - 2, sprintf("%.0f", lo), 11, "start", " fill=\"#444\"")
  }
  txt(PL + 6, top + 16, "Advance-decline line (cumulative)" (spl ? "  |  dashed line: from 2020-02-14 the counts come from a stock universe (scaled to NYSE size), not the NYSE" : (syn ? "  |  counts from a stock universe (scaled to NYSE size), not the NYSE" : "")), 12, "start", " fill=\"#6a1b9a\"")
  future_block(top, bot, 0); panel_box(top, bot)
}
# 11 sectors in a 4 x 3 grid, alphabetical, one shared symmetric y-range; the 12th cell ranks sectors at the cut.
function sector_panel(top, bot,   s, j, z, m, cols, rows, cw, ch, cx, cy, d, x, r, nlast, order, t, a, b, gap) {
  cols = 4; rows = 3; gap = 14; cw = (PR - PL - (cols - 1) * gap) / cols; ch = (bot - top - (rows - 1) * gap) / rows
  for (s = 1; s <= nsec; s++) for (j = s + 1; j <= nsec; j++) if (sec[j] < sec[s]) { t = sec[s]; sec[s] = sec[j]; sec[j] = t }
  m = 0.2; for (s = 1; s <= nsec; s++) for (z = FZ0; z <= CUTZ; z += 7) if ((sec[s], z) in rel) { r = rel[sec[s], z]; if (r < 0) r = -r; if (r > m) m = r }
  m *= 1.05; if (m > 0.4) m = 0.4   # one outlier sector (Energy 2021) must not flatten the rest; values past +-40 % clip
  for (s = 1; s <= nsec && s <= cols * rows - 1; s++) {
    cx = PL + ((s - 1) % cols) * (cw + gap); cy = top + int((s - 1) / cols) * (ch + gap)
    printf "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"none\" stroke=\"#999\"/>\n", f2(cx), f2(cy), f2(cw), f2(ch)
    a = cy + ch / 2; line(cx, a, cx + cw, a, "#888", 1, " stroke-dasharray=\"4,3\"")
    d = ""
    for (z = FZ0; z <= CUTZ; z += 7) if ((sec[s], z) in rel) d = d (d == "" ? "M" : " L") f2(cx + (z - FZ0) / (FZ1 - FZ0) * cw) "," f2(a - clip(rel[sec[s], z] / m) * (ch / 2))
    if (d != "") printf "<path d=\"%s\" fill=\"none\" stroke=\"#c26a00\" stroke-width=\"1.3\"/>\n", d
    x = cx + (CUTZ + 7 - FZ0) / (FZ1 - FZ0) * cw
    if (x < cx + cw) printf "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"#cfcfcf\"/>\n", f2(x), f2(cy + 1), f2(cx + cw - x), f2(ch - 2)
    nlast = ((sec[s], lastz) in rel) ? sprintf("%+.1f%% vs SPY (n=%d)", 100 * rel[sec[s], lastz], cnt[sec[s], lastz]) : "n/a"
    txt(cx + 6, cy + 15, sec[s], 12, "start", " font-weight=\"bold\""); txt(cx + 6, cy + ch - 6, "now " nlast, 11, "start", " fill=\"#333\"")
  }
  cx = PL + ((cols * rows - 1) % cols) * (cw + gap); cy = top + int((cols * rows - 1) / cols) * (ch + gap)
  txt(cx + 6, cy + 15, "Sector rank at " civil(lastz) " (26w vs SPY)", 12, "start", " font-weight=\"bold\"")
  for (s = 1; s <= nsec; s++) order[s] = sec[s]
  for (s = 1; s <= nsec; s++) for (j = s + 1; j <= nsec; j++) if (rel[order[j], lastz] > rel[order[s], lastz]) { t = order[s]; order[s] = order[j]; order[j] = t }
  for (s = 1; s <= nsec; s++) txt(cx + 6, cy + 15 + s * 15, sprintf("%2d. %s  %+.1f%%", s, order[s], 100 * rel[order[s], lastz]), 11, "start", " fill=\"#333\"")
  txt(PL, top - 6, sprintf("Sector strength: median 26-week return of the sector's top-3000 members minus SPY's; shared y-range +/-%.0f%% (clipped)", 100 * m), 12, "start", " fill=\"#c26a00\"")
}
function clip(x) { return (x > 1) ? 1 : ((x < -1) ? -1 : x) }
