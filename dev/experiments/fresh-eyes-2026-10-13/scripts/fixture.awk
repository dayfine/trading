# stepper_check fixtures: a daily CSV, flat at -v base on every weekday from -v from to -v to, with some days
# overridden by -v over="YYYY-MM-DD:open/high/low/close;...". raw = adjusted (factor 1).
# Usage: awk -v from=... -v to=... -v base=10 -v over=... -f days.awk -f fixture.awk
BEGIN {
  n = split(over, O, ";")
  for (i = 1; i <= n; i++) { p = index(O[i], ":"); if (p) ov[substr(O[i], 1, p - 1)] = substr(O[i], p + 1) }
  print "date,open,high,low,close,adjusted_close,volume"
  for (z = days(from); z <= days(to); z++) {
    if ((z + 4 + 700000) % 7 == 0 || (z + 4 + 700000) % 7 == 6) continue   # Sunday = 0, Saturday = 6
    d = civil(z)
    if (d in ov) { split(ov[d], v, "/"); printf "%s,%s,%s,%s,%s,%s,1000\n", d, v[1], v[2], v[3], v[4], v[4] }
    else printf "%s,%s,%s,%s,%s,%s,1000\n", d, base, base, base, base, base
  }
}
