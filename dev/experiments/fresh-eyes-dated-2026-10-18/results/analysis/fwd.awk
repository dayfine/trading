# Calendar helpers shared by the fresh-eyes scripts (Hinnant's civil-day algorithms; 1970-01-01 = day 0).
function days(s,   y, m, d, era, yoe, doy, doe) {
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (m <= 2) y--
  era = int((y >= 0 ? y : y - 399) / 400); yoe = y - era * 400
  doy = int((153 * (m > 2 ? m - 3 : m + 9) + 2) / 5) + d - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return era * 146097 + doe - 719468
}
function civil(z,   era, doe, yoe, y, doy, mp, d, m) {
  z += 719468; era = int(z / 146097); doe = z - era * 146097
  yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
  y = yoe + era * 400; doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
  mp = int((5 * doy + 2) / 153); d = doy - int((153 * mp + 2) / 5) + 1; m = (mp < 10) ? mp + 3 : mp - 9
  if (m <= 2) y++
  return sprintf("%04d-%02d-%02d", y, m, d)
}
# Friday ending the week of a day (weeks run Saturday..Friday); 1970-01-01 was a Thursday.
function friday(z) { return z + (5 - (z + 4 + 700000) % 7 + 7) % 7 }
# fwd.awk: adjusted-close forward returns from the last bar <= want to the last bar <= want + 182/364/728 days.
# Usage: awk -F, -v want=D -f fwd.awk data.csv   Prints: base_date,r26,r52,r104,last_date
NR == 1 { next }
$6 + 0 > 0 { n++; d[n] = $1; c[n] = $6 + 0 }
END {
  b = 0; for (i = 1; i <= n; i++) if (d[i] <= want) b = i
  if (b == 0) { print ",,,,"; exit }
  z = days(want); out = d[b]
  for (k = 1; k <= 3; k++) { t = civil(z + (k == 1 ? 182 : (k == 2 ? 364 : 728))); j = b; for (i = b; i <= n && d[i] <= t; i++) j = i; r[k] = c[j] / c[b] - 1 }
  printf "%s,%.6f,%.6f,%.6f,%s\n", d[b], r[1], r[2], r[3], d[n]
}
