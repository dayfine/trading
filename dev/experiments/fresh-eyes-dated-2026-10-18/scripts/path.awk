# path.awk: one trade's numbers on the adjusted (total-return) basis, plus its price path to 104 weeks after entry
# (plan §4 "price path after the end": what an exit left behind or avoided). Needs days.awk.
# Usage: awk -F, -v side=long|short -v ed=ENTRY -v xd=EXIT -v epx=P -v xpx=Q -v basis=raw|adj -v xo=0|1 \
#          -f days.awk -f path.awk <SPY data.csv> <SYM data.csv>
# basis=raw: epx / xpx are raw prices (the record's trades.csv) and are put on the adjusted basis with that day's
# adjusted_close / close; basis=adj: already adjusted (the stepper's trades.csv). xo=1: the exit filled at the open
# (SPY leg ends at its open, as sim.awk does).
# Prints one line: ret,spy_ret,excess,days,r104,max104,min104,spy104,end104 where r104 / max104 / min104 are the
# stock's adjusted close at entry + 728 days (or its last bar before) and the extremes of its daily closes over
# (entry, entry + 728] against the entry price, signed for the side (a short gains when the price falls), and
# spy104 the SPY leg over the same span. Empty fields when a bar is missing.
BEGIN { CONVFMT = "%.10g" }
FNR == 1 { fi++; next }
fi == 1 { if ($5 + 0 > 0 && $6 + 0 > 0) { f = $6 / $5; so[$1] = $2 * f; sc[$1] = $6 + 0; sd[++ns] = $1 }; next }
fi == 2 { if ($5 + 0 > 0 && $6 + 0 > 0) { nd++; dd[nd] = $1; ff[nd] = $6 / $5; dc[nd] = $6 + 0 }; next }
function at(d,   i, r) { r = 0; for (i = 1; i <= nd && dd[i] <= d; i++) r = i; return r }
function spyat(d, o,   z, s) { for (z = days(d); z >= days(d) - 10; z--) { s = civil(z); if (s in sc) return o ? so[s] : sc[s] }; return 0 }
function sg(r) { return (side == "short") ? -r : r }
END {
  ie = at(ed); if (ie == 0 || dd[ie] != ed) { print ",,,,,,,,"; exit }
  e = (basis == "raw") ? epx * ff[ie] : epx + 0
  ret = ""; sr = ""; ex = ""; dy = ""
  if (xd != "" && xpx != "") {
    ix = at(xd); x = (basis == "raw" && ix > 0) ? xpx * ff[ix] : xpx + 0
    ret = sg(x / e - 1); s0 = spyat(ed, 1); s1 = spyat(xd, xo + 0)
    if (s0 > 0) { sr = sg(s1 / s0 - 1); ex = ret - sr }
    dy = days(xd) - days(ed)
  }
  lim = civil(days(ed) + 728); mx = ""; mn = ""; last = 0
  for (i = ie + 1; i <= nd && dd[i] <= lim; i++) {
    r = sg(dc[i] / e - 1); last = i
    if (mx == "" || r > mx) mx = r
    if (mn == "" || r < mn) mn = r
  }
  r104 = ""; s104 = ""; end104 = ""
  if (last > 0) {
    r104 = sg(dc[last] / e - 1); end104 = dd[last]; s0 = spyat(ed, 1); s1 = spyat(dd[last], 0)
    if (s0 > 0) s104 = sg(s1 / s0 - 1)
  }
  printf "%s,%s,%s,%s,%s,%s,%s,%s,%s\n", fm(ret), fm(sr), fm(ex), dy, fm(r104), fm(mx), fm(mn), fm(s104), end104
}
function fm(v) { return (v == "") ? "" : sprintf("%.6f", v) }
