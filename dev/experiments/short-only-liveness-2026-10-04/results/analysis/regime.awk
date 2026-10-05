# usage: awk -f regime.awk SPY.csv equity_curve.csv mv.tsv
# SPY regime per day (review-pack definition): weekly close vs 30-week SMA and the SMA's
# 4-week slope, known at the prior week's close, applied to the following week's days.
# Uses full SPY history (no in-window warm-up). Prints per (period, regime): days,
# strategy compounded return, SPY compounded return, mean short exposure (% of NAV).
function jdn(s,   y, m, d, a) { y = substr(s,1,4)+0; m = substr(s,6,2)+0; d = substr(s,9,2)+0
  a = int((14 - m) / 12); y = y + 4800 - a; m = m + 12 * a - 3
  return d + int((153 * m + 2) / 5) + 365 * y + int(y / 4) - int(y / 100) + int(y / 400) - 32045 }
function ma(n,   i, s) { s = 0; for (i = n - 30; i < n; i++) s += cl[i]; return s / 30 }
function per(d) { return d <= "2008-12-31" ? "P1 2007-06..2008-12" : d <= "2010-12-31" ? "P2 2009..2010" : "P3 2011..2012-06" }
FILENAME == ARGV[1] && FNR > 1 {
  split($0, b, ","); d = b[1]; v = b[6] + 0; k = int(jdn(d) / 7)
  if (k != wk && last != "") { cl[nc++] = last
    if (nc >= 34) { m = ma(nc); m4 = ma(nc - 4); c = cl[nc - 1]; cur = (c > m && m > m4) ? "UP" : (c < m && m < m4) ? "DOWN" : "MIXED" } }
  wk = k; last = v; reg[d] = cur; spy[d] = v; next }
FILENAME == ARGV[2] && FNR > 1 { split($0, b, ","); nav[b[1]] = b[2] + 0; dates[++nd] = b[1]; next }
FILENAME == ARGV[3] { split($0, b, "\t"); mv[b[1]] = b[2] + 0; next }
END {
  lastok = dates[1]; for (i = 2; i <= nd; i++) {
    d = dates[i]; if (!(d in spy)) { hol++; continue }; p = lastok; lastok = d; if (p == "") continue; r = reg[d]; if (r == "") r = "NA"
    if (!(d in spy) || !(p in spy)) { miss++; continue }
    sr = nav[d] / nav[p]; mr = spy[d] / spy[p]
    for (j = 0; j < 2; j++) { key = (j == 0 ? per(d) : "ALL 2007-06..2012-06") SUBSEP r
      n[key]++; ls[key] += log(sr); lm[key] += log(mr); ex[key] += 100 * mv[p] / nav[p] }
  }
  for (key in n) { split(key, kk, SUBSEP)
    printf "%-22s %-6s days=%4d strat=%7.2f%%  SPY=%7.2f%%  short_expo=%5.1f%%\n", kk[1], kk[2], n[key], 100 * (exp(ls[key]) - 1), 100 * (exp(lm[key]) - 1), ex[key] / n[key] }
  printf "equity rows on exchange holidays (skipped): %d\n", hol
}
