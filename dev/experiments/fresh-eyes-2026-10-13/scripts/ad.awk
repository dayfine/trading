# Fresh-eyes study: the cumulative advance-decline line, weekly (value at the week's last trading day).
# Usage: awk -f days.awk -f ad.awk nyse_advn.csv nyse_decln.csv synthetic_advn.csv synthetic_decln.csv
# Rows are "YYYYMMDD, count". NYSE counts are used through SPLICE (2020-02-14; the last real NYSE day is
# 2020-02-10, and 02-11..14 are zero placeholders), the universe-computed synthetic counts after it. A day with
# advances + declines = 0 is a placeholder and is skipped. The line starts at 0 on 1999-01-01.
# Output: week,ad_cum,source   (source nyse | synthetic; the first synthetic week marks the splice; ad_cum rounded).
BEGIN { FS = ","; SPLICE = "20200214"; START = "19990101" }
FNR == 1 { fi++ }
{ d = $1; gsub(/ /, "", d); x = $2 + 0 }
fi == 1 { na[d] = x; next }
fi == 2 { nd[d] = x; next }
fi == 3 { sa[d] = x; next }
fi == 4 { sd[d] = x; next }
END {
  for (d in na) if (d >= START && d <= SPLICE && (d in nd) && na[d] + nd[d] > 0) { day[++n] = d; net[d] = na[d] - nd[d]; src[d] = "nyse" }
  # The synthetic universe counts far fewer issues than the NYSE (mean |daily net| about 4x smaller), which would
  # flatten the line after the splice. Scale the synthetic daily net by the ratio of mean |net| over the overlap
  # START..SPLICE, a constant fixed from data before every post-splice date, so it stays causal.
  for (d in na) if (d >= START && d <= SPLICE && (d in nd) && (d in sa) && (d in sd) && na[d] + nd[d] > 0 && sa[d] + sd[d] > 0) {
    u = na[d] - nd[d]; v = sa[d] - sd[d]; su += (u < 0 ? -u : u); sv += (v < 0 ? -v : v) }
  SCALE = (sv > 0) ? su / sv : 1
  printf "ad.awk: synthetic net scaled by %.4f (mean |net| NYSE / synthetic over %s..%s)\n", SCALE, START, SPLICE > "/dev/stderr"
  for (d in sa) if (d > SPLICE && (d in sd) && sa[d] + sd[d] > 0) { day[++n] = d; net[d] = SCALE * (sa[d] - sd[d]); src[d] = "synthetic" }
  for (i = 1; i <= n; i++) key[i] = day[i]
  qs(key, 1, n)
  print "week,ad_cum,source"
  cum = 0; pw = ""
  for (i = 1; i <= n; i++) {
    d = key[i]; cum += net[d]
    w = civil(friday(days(substr(d, 1, 4) "-" substr(d, 5, 2) "-" substr(d, 7, 2))))
    if (w != pw && pw != "") printf "%s,%.0f,%s\n", pw, lastcum, lastsrc
    pw = w; lastcum = cum; lastsrc = src[d]
  }
  if (pw != "") printf "%s,%.0f,%s\n", pw, lastcum, lastsrc
}
function qs(A, lo, hi,   i, last, t) {
  if (lo >= hi) return
  t = A[lo]; A[lo] = A[int((lo + hi) / 2)]; A[int((lo + hi) / 2)] = t
  last = lo
  for (i = lo + 1; i <= hi; i++) if (A[i] < A[lo]) { last++; t = A[last]; A[last] = A[i]; A[i] = t }
  t = A[lo]; A[lo] = A[last]; A[last] = t
  qs(A, lo, last - 1); qs(A, last + 1, hi)
}
