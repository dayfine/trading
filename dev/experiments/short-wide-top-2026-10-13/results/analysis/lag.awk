function jdn(s,   y, m, d, a, y2, m2) { y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return d + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045 }
FNR == 1 { f++; next }
f == 1 { k = $1; ns[k]++; sd[k, ns[k]] = jdn($2); next }
f == 2 { k = $1; j = jdn($2); lag = -1; for (q = 1; q <= ns[k]; q++) { d = j - sd[k, q]; if (d >= 0 && d <= 364 && (lag < 0 || d < lag)) lag = d }
  if (lag < 0) print "none"; else print int(lag / 7) }
