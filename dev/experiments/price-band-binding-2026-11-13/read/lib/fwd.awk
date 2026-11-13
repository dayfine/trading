# fwd.awk -- for one symbol and a list of screen dates: the decision-date raw close (its #3587 price band) and the
# population screen's ex-post outcomes (../../../price-band-tiebreak-2026-11-13/screen/PREREG.md). POSIX awk.
#
# usage: awk -F, -v SYM=X -v STORE_END=YYYY-MM-DD -f dates.awk -f fwd.awk dates.txt <bar store>/<A>/<B>/X/data.csv
# dates.txt: ascending screen dates, one per line. Output (WORK only, never committed: it carries a raw close):
#   symbol  date  raw_close  band  monster  fwd_max  ride  cov
#
# The weekly series is built exactly as the screen's lib/mscan.awk builds it: adjusted weekly closes (WC, last bar of
# each Monday week), the 30-week WMA (weights 30..1, /465), rows with a non-positive close, adjusted close or high
# skipped. For a screen date d, the base is the adjusted close of the last bar on or before d (the Friday close).
#   monster = max weekly close over the next 52 weeks >= 2x the base   (PREREG: "max weekly close in the next 52 weeks")
#   ride    = return from the base to the first weekly close below the WMA, at most 104 weeks; else to the last close
#   cov     F: 52 forward weeks exist.   D: the series ends earlier and before STORE_END - 14 days (delisted), so the
#           outcome is read over the weeks that exist (a delisted name that never doubled is not a monster).
#           T: STORE_END truncates the window: monster and ride are NA.   X: no bar within 10 days on or before d.
# The screen's own events (mscan) need 52 forward weeks, so they drop D names; cov lets the read show both conventions.
FILENAME == ARGV[1] { if ($1 != "") { nq++; Q[nq] = $1 } next }
FNR == 1 { for (c = 1; c <= NF; c++) col[$c] = c; next }
{
  cl = $col["close"] + 0; ad = $col["adjusted_close"] + 0
  if (cl <= 0 || ad <= 0 || $col["high"] + 0 <= 0) next
  d = $col["date"]; w = week_of(d)
  if (w != lw) { nw++; lw = w }
  WC[nw] = ad
  nd++; DD[nd] = d; DR[nd] = cl; DA[nd] = ad; DW[nd] = nw
}
END {
  for (j = 30; j <= nw; j++) { s = 0; for (k = 0; k < 30; k++) s += (30 - k) * WC[j - k]; MA[j] = s / 465 }
  delisted = (nd > 0 && days(DD[nd]) < days(STORE_END) - 14)
  i = 0
  for (q = 1; q <= nq; q++) {
    while (i < nd && DD[i + 1] <= Q[q]) i++
    if (i == 0 || days(Q[q]) - days(DD[i]) > 10) { print SYM "\t" Q[q] "\tNA\tNA\tNA\tNA\tNA\tX"; continue }
    j = DW[i]; base = DA[i]; band = (DR[i] >= 8) + (DR[i] >= 14) + (DR[i] >= 33)
    if (j + 52 <= nw) cov = "F"; else if (delisted) cov = "D"; else cov = "T"
    if (cov == "T") { print SYM "\t" Q[q] "\t" DR[i] "\t" band "\tNA\tNA\tNA\tT"; continue }
    e = (j + 52 < nw) ? j + 52 : nw; fm = 0
    for (k = j + 1; k <= e; k++) if (WC[k] > fm) fm = WC[k]
    fwd = (fm > 0) ? fm / base - 1 : DA[nd] / base - 1
    e = (j + 104 < nw) ? j + 104 : nw; ride = ""
    for (k = j + 1; k <= e; k++) if (k >= 30 && WC[k] < MA[k]) { ride = WC[k] / base - 1; break }
    if (ride == "") ride = WC[e] / base - 1
    printf "%s\t%s\t%s\t%d\t%d\t%.4f\t%.4f\t%s\n", SYM, Q[q], DR[i], band, (fwd >= 1), fwd, ride, cov
  }
}
