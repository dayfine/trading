# Short wide-top screen: one symbol's price-defined wide-top breakdown events and their outcomes.
# Pre-registration: dev/plans/short-wide-top-screen-2026-10-13.md.
#
# Usage (one symbol; file order matters):
#   awk -F, -v sym=X -v mem="1999 2000 ..." -f events.awk spy-weekly-stage.csv spy-daily.csv <X/data.csv>
# Prints event rows without a header (see header.txt).
#
# Weekly bars are built here from the daily bars (weeks end Friday), and the 30-week MA is the simple mean of the
# last 30 weekly adjusted closes. Our stage classifier is not used for the events; the SPY weekly stage CSV only
# labels the market phase. Adjusted prices for levels, stops and returns; raw close only for the $5 floor.
# Entry is the adjusted open of the next daily bar; the SPY leg starts at SPY's adjusted open of the same day.

function dn(s,   y, m, d) {  # days since a fixed epoch, proleptic Gregorian
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + d
}
function list_year(s,   y) { y = substr(s, 1, 4) + 0; return (substr(s, 6, 5) >= "05-31") ? y : y - 1 }
function is_member(s) { return ((" " mem " ") ~ (" " list_year(s) " ")) }
function fmt(x) { return sprintf("%.5f", x) }
function friday(s,   x) { x = dn(s); return x + (FRI - x % 7 + 7) % 7 }   # the Friday ending the date's week

BEGIN { FRI = dn("2000-01-07") % 7; FIRST = dn("2000-01-07"); LAST = dn("2025-12-26") }
FNR == 1 { fi++; next }
fi == 1 { nsw++; swd[nsw] = $2; sws[nsw] = $5; next }                     # SPY weekly stage (phase label only)
fi == 2 { if ($5 + 0 <= 0) next
          nsd++; sdd[nsd] = $1; sda[nsd] = $6; sdo[nsd] = $2 * $6 / $5; next }   # SPY daily
fi == 3 { if ($5 + 0 <= 0) next
          nd++; dd[nd] = $1; f = $6 / $5; dop[nd] = $2 * f; dhi[nd] = $3 * f; dcl[nd] = $5; dad[nd] = $6; next }

END {
  if (nd < 400) exit
  # SPY adjusted close / open on each stock day (carry the last SPY bar at or before the day; open only on a match).
  k = 1
  for (j = 1; j <= nd; j++) {
    while (k < nsd && sdd[k + 1] <= dd[j]) k++
    spa[j] = (sdd[k] <= dd[j]) ? sda[k] : ""; spo[j] = (sdd[k] == dd[j]) ? sdo[k] : spa[j]
  }
  for (t = 1; t <= nsw; t++) srun[t] = (t > 1 && sws[t] == sws[t - 1]) ? srun[t - 1] + 1 : 1
  # Weekly bars: first/last daily index, close (last adjusted close), high (max adjusted high), week-end Friday.
  nw = 0; prev = -1
  for (j = 1; j <= nd; j++) {
    fr = friday(dd[j])
    if (fr != prev) { nw++; wf[nw] = j; wh[nw] = 0; wfr[nw] = fr; prev = fr }
    wl[nw] = j; wc[nw] = dad[j]; if (dhi[j] > wh[nw]) wh[nw] = dhi[j]
  }
  s = 0
  for (w = 1; w <= nw; w++) { s += wc[w]; if (w > 30) s -= wc[w - 30]; ma[w] = (w >= 30) ? s / 30 : "" }
  # Each breakdown week -> the first top week H that produces it.
  for (h = 52; h <= nw; h++) {
    if (wc[h] < ma[h]) continue
    top = 1; for (t = h - 51; t < h; t++) if (wh[t] > wh[h]) { top = 0; break }
    if (!top) continue
    lo = wc[h - 8]; for (t = h - 7; t < h + 8 && t <= nw; t++) if (wc[t] < lo) lo = wc[t]   # min close [H-8, H+7]
    for (i = h + 8; i <= h + 52 && i <= nw; i++) {
      if (wc[i] < lo && wc[i] < ma[i] && ma[i] <= ma[i - 4]) { if (!(i in topof)) topof[i] = h; break }
      if (wc[i] < lo) lo = wc[i]
    }
  }
  last_kept = -100000
  for (i = 1; i <= nw; i++) {
    if (!(i in topof)) continue
    if (wfr[i] < FIRST || wfr[i] > LAST) continue
    if (wl[i] >= nd) continue
    if (dcl[wl[i]] < 5 || !is_member(dd[wl[i]])) continue
    if (wfr[i] - last_kept < 182) continue
    last_kept = wfr[i]
    emit(i, topof[i])
  }
}

function emit(i, h,   t, hi, ph, k) {
  hi = 0; for (t = wf[h + 1]; t <= wl[i - 1]; t++) if (dhi[t] > hi) hi = dhi[t]   # right shoulder, weeks [H+1, i-1]
  if (hi <= 0) return
  k = 0; for (t = 1; t <= nsw; t++) { if (swd[t] > dd[wl[i]]) break; k = t }
  if (k == 0) ph = "na"
  else if (sws[k] == "Stage4") ph = (srun[k] <= 8) ? "s4_early" : "s4_late"
  else if (sws[k] == "Stage3") ph = "s3"
  else ph = "s12"
  print sym "," dd[wl[i]] "," fmt(dcl[wl[i]]) "," dd[wl[h]] "," (i - h) "," ph "," fmt(hi * 1.01) "," outcome(wl[i] + 1, hi * 1.01)
}

# Ten fields: date, entry, O1 excess +20/+60/+120, O2 stock short ret, O2 excess, O2 bars, O2 stopped, stop room.
# Same rules as short-setup-map-2026-10-12/scripts/events.awk, but entering at the open.
function outcome(e, stop,   p, sp, k, o1, t, end, fill, stopped, j, n, ks) {
  p = dop[e]; sp = spo[e]
  o1 = ""
  n = split("20 60 120", ks, " ")
  for (k = 1; k <= n; k++) { j = e + ks[k]; if (j > nd) j = nd
    o1 = o1 "," ((sp > 0 && spa[j] > 0) ? fmt((1 - dad[j] / p) - (1 - spa[j] / sp)) : "") }
  end = (e + 120 <= nd) ? e + 120 : nd; fill = dad[end]; stopped = 0; t = end
  if (p >= stop) { t = (e + 1 <= nd) ? e + 1 : e; fill = dop[t]; stopped = 1 }
  else for (j = e + 1; j <= end; j++) if (dhi[j] >= stop) { fill = (dop[j] >= stop) ? dop[j] : stop; t = j; stopped = 1; break }
  return dd[e] "," fmt(p) o1 "," fmt(1 - fill / p) "," ((sp > 0 && spa[t] > 0) ? fmt((1 - fill / p) - (1 - spa[t] / sp)) : "") "," (t - e) "," stopped "," fmt(stop / p - 1)
}
