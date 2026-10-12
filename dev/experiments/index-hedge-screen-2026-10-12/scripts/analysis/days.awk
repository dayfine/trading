# Per-day table for the index-short overlay reading (analyst, 2026-10-12). One row per equity-curve day after the
# first: date,rb,rs_tr,rs_px,session,g1,g2,g3,regime,gate_week
#   rb      base daily return (equity curve)
#   rs_tr   SPY total-return daily change (adjusted_close), carried across holiday rows (0 on the holiday itself)
#   rs_px   the same on the price-only close (dividends = rs_tr - rs_px)
#   session 1 when SPY has a bar that day (borrow accrues per session)
#   g1..g3  gates as overlay.awk: the reading of the last week-end strictly before the day, minus -v lag weeks
#   regime  the review pack's SPY regime (dev/lib/review_pack/index.html spyRegimeByDay): weekly close vs its 30-week
#           SMA and that SMA 4 weeks earlier, from the prior ISO week's close (no look-ahead)
# Inputs: stage csv, macro csv, SPY daily csv, base equity curve.  -v lag=0
BEGIN { FS = "," }
FILENAME == ARGV[1] { if (FNR > 1) { nw++; WD[nw] = $2; ST[nw] = $5 } next }
FILENAME == ARGV[2] { nm++; MD[nm] = $1; MT[nm] = $2; next }
FILENAME == ARGV[3] { if (FNR > 1) { ns++; SD[ns] = $1; TR[$1] = $6 + 0; PX[$1] = $5 + 0 } next }
FILENAME == ARGV[4] { if (FNR > 1) { n++; D[n] = $1; V[n] = $2 + 0 } next }
# Monday-based week index: Julian day number / 7 changes on Mondays (JDN 2451547 = 2000-01-03, a Monday, = 7 * 350221)
function wk(d,   y, m, dd, a, y2, m2) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return int((dd + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045) / 7) }
END {
  j = 0
  for (i = 1; i <= nw; i++) { while (j < nm && MD[j+1] <= WD[i]) j++
    bear = (j > 0 && MT[j] == "Bearish"); s4 = (ST[i] == "Stage4"); A1[i] = s4; A2[i] = s4 && bear; A3[i] = bear }
  nc = 0; cw = ""; last = ""; cur = "MIXED"
  for (i = 1; i <= ns; i++) { d = SD[i]; k = wk(d)
    if (k != cw && last != "") { nc++; C[nc] = last
      if (nc >= 34) { m = 0; m4 = 0; for (q = nc - 29; q <= nc; q++) m += C[q]; for (q = nc - 33; q <= nc - 4; q++) m4 += C[q]
        m /= 30; m4 /= 30; cur = (C[nc] > m && m > m4) ? "UP" : ((C[nc] < m && m < m4) ? "DOWN" : "MIXED") } }
    cw = k; last = TR[d]; REG[d] = cur }
  w = 0; lastreg = "MIXED"
  for (t = 1; t <= n; t++) {
    while (w < nw && WD[w+1] < D[t]) w++
    if (D[t] in TR) { ctr = TR[D[t]]; cpx = PX[D[t]]; lastreg = REG[D[t]] }
    if (t == 1) { ptr = ctr; ppx = cpx; continue }
    rs = ctr / ptr - 1; rp = cpx / ppx - 1; ptr = ctr; ppx = cpx
    wi = w - lag; g1 = (wi >= 1) ? A1[wi] : 0; g2 = (wi >= 1) ? A2[wi] : 0; g3 = (wi >= 1) ? A3[wi] : 0
    printf "%s,%.10f,%.10f,%.10f,%d,%d,%d,%d,%s,%s\n", D[t], V[t] / V[t-1] - 1, rs, rp, (D[t] in TR), g1, g2, g3, lastreg, (wi >= 1 ? WD[wi] : "") }
}
