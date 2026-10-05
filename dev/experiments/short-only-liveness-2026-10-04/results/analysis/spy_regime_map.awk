# usage: awk -F, -f spy_regime_map.awk SPY/data.csv  ->  "date<TAB>UP|MIXED|DOWN" per bar
# Review-pack definition: weekly close vs its 30-week SMA and the SMA's 4-week slope, known at
# the prior week's close and applied to the following week's days. Full SPY history (no warm-up gap).
function jdn(s,   y, m, d, a) { y = substr(s,1,4)+0; m = substr(s,6,2)+0; d = substr(s,9,2)+0
  a = int((14 - m) / 12); y = y + 4800 - a; m = m + 12 * a - 3
  return d + int((153 * m + 2) / 5) + 365 * y + int(y / 4) - int(y / 100) + int(y / 400) - 32045 }
function ma(n,   i, s) { s = 0; for (i = n - 30; i < n; i++) s += cl[i]; return s / 30 }
NR > 1 { d = $1; v = $6 + 0; k = int(jdn(d) / 7)
  if (k != wk && last != "") { cl[nc++] = last
    if (nc >= 34) { m = ma(nc); m4 = ma(nc - 4); c = cl[nc - 1]; cur = (c > m && m > m4) ? "UP" : (c < m && m < m4) ? "DOWN" : "MIXED" } }
  wk = k; last = v; print d "\t" cur }
