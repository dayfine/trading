# pool_scan.awk: per symbol, the numbers the step-B filter needs on the decision date (plan §3 step B).
# Usage: awk -F, -v date=YYYY-MM-DD -f days.awk -f pool_scan.awk <.../SYM/data.csv ...>   (symbol = parent dir)
# Daily rows are date,open,high,low,close,adjusted_close,volume. On the adjusted basis (x adjusted_close / close):
# close = the last bar at or before the date, kept only when it is within 10 days of it (the stock still trades);
# hi52 / lo52 = the highest adjusted high / lowest adjusted low over the 365 days to that bar; dv20 = the mean of adjusted_close x volume over
# the last 20 bars (the vendor's volume is split-adjusted to the data end like its adjusted close, so the product
# is close to the dollar volume traded then; dividends make it read slightly low).
# Prints: symbol,last_date,close,hi52,dv20,lo52
BEGIN { dz = days(date) }
FNR == 1 { flush(); np = split(FILENAME, pp, "/"); sym = pp[np - 1]; n = 0; next }
$1 <= date && $5 + 0 > 0 && $6 + 0 > 0 { n++; d[n] = $1; f = $6 / $5; h[n] = $3 * f; l[n] = $4 * f; c[n] = $6 + 0; dv[n] = $6 * $7 }
END { flush() }
function flush(   i, z0, hi, lo, s, k) {
  if (sym == "" || n == 0 || dz - days(d[n]) > 10) return
  z0 = days(d[n]) - 365; hi = 0; lo = -1
  for (i = n; i >= 1 && days(d[i]) > z0; i--) { if (h[i] > hi) hi = h[i]; if (lo < 0 || l[i] < lo) lo = l[i] }
  s = 0; k = 0; for (i = n; i >= 1 && k < 20; i--) { s += dv[i]; k++ }
  printf "%s,%s,%.6g,%.6g,%.6g,%.6g\n", sym, d[n], c[n], hi, s / k, lo
}
