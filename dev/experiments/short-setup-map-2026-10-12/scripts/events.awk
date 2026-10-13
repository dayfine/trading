# Short setup map: one symbol's Stage 3 -> Stage 4 breakdown events and their outcomes.
# Pre-registration: dev/plans/short-setup-map-2026-10-12.md (incl. amendment 1).
#
# Usage (one symbol; file order matters):
#   awk -F, -v sym=X -v mem="1999 2000 ..." -f events.awk \
#     spy-weekly-stage.csv spy-daily.csv <stages/X.csv> <X/data.csv> <X/dividends.csv or /dev/null>
# Prints event rows without a header (see header.txt).
#
# Prices: adjusted (total return) for stages, stops and returns; raw close only for the $5/$17 floor and the
# dividend yield. Daily bars of a week are those with date in (previous week date, week date].

function dn(s,   y, m, d) {  # days since a fixed epoch, proleptic Gregorian
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + d
}
function list_year(s,   y) { y = substr(s, 1, 4) + 0; return (substr(s, 6, 5) >= "05-31") ? y : y - 1 }
function is_member(s,   y) { y = list_year(s); return ((" " mem " ") ~ (" " y " ")) }
function fmt(x) { return sprintf("%.5f", x) }

FNR == 1 { fi++; next }
fi == 1 { nsw++; swd[nsw] = $2; swc[nsw] = $3; sws[nsw] = $5; next }        # SPY weekly stage
fi == 2 { nsd++; sdd[nsd] = $1; sda[nsd] = $6; next }                     # SPY daily
fi == 3 { nw++; wd[nw] = $2; wc[nw] = $3; wst[nw] = $5; next }            # symbol weekly stage
fi == 4 { if ($5 + 0 <= 0) next
          nd++; dd[nd] = $1; f = $6 / $5; dop[nd] = $2 * f; dhi[nd] = $3 * f; dcl[nd] = $5; dad[nd] = $6; next }
fi == 5 { nv++; vdt[nv] = $1; vam[nv] = $2 + 0; next }                   # dividends

END {
  if (nw < 60 || nd < 200) exit
  # SPY adjusted close on each stock day (carry the last SPY close at or before the day).
  k = 1
  for (j = 1; j <= nd; j++) { while (k < nsd && sdd[k + 1] <= dd[j]) k++; spa[j] = (sdd[k] <= dd[j]) ? sda[k] : "" }
  # SPY weekly row at or before each stock week, and the length of SPY's current stage run.
  k = 1; run = 0
  for (i = 1; i <= nsw; i++) { srun[i] = (i > 1 && sws[i] == sws[i - 1]) ? srun[i - 1] + 1 : 1 }
  for (i = 1; i <= nw; i++) {
    while (k < nsw && swd[k + 1] <= wd[i]) k++
    if (swd[k] <= wd[i]) { sc[i] = swc[k]; ss[i] = sws[k]; sr[i] = srun[k] } else { sc[i] = ""; ss[i] = "" }
  }
  # Last daily bar of each week and the week's adjusted high.
  j = 1
  for (i = 1; i <= nw; i++) {
    wh[i] = 0; wl[i] = 0
    while (j <= nd && dd[j] <= wd[i]) { if (dhi[j] > wh[i]) wh[i] = dhi[j]; wl[i] = j; j++ }
    if (wl[i] > 0) wc[i] = dad[wl[i]]   # full-precision adjusted close (the stage CSV rounds to 2 decimals)
  }
  # Mansfield RS (52-week) of the weekly close vs SPY.
  for (i = 1; i <= nw; i++) {
    r[i] = (sc[i] > 0) ? wc[i] / sc[i] : 0; mr[i] = ""
    if (i >= 52) { s = 0; ok = 1
      for (t = i - 51; t <= i; t++) { if (r[t] <= 0) ok = 0; s += r[t] }
      if (ok && r[i] > 0) mr[i] = r[i] / (s / 52) - 1 }
  }
  last_kept = -100000
  for (i = 2; i <= nw; i++) {
    if (wst[i] != "Stage4" || wst[i - 1] != "Stage3") continue
    if (wd[i] < "2000-01-07" || wd[i] > "2025-12-26") continue
    if (wl[i] == 0 || wl[i] >= nd) continue
    raw = dcl[wl[i]]
    if (raw < 5 || !is_member(wd[i])) continue
    if (dn(wd[i]) - last_kept < 182) continue
    last_kept = dn(wd[i])
    emit(i)
  }
}

function emit(i,   a, b, t, hi, lo, lvl, sw, nsw2, head, hidx, ls, rs, hs, rsc, ph, e1, e2, w, e2w, ylds, cut, big, lim, out) {
  a = i - 1; while (a > 1 && wst[a - 1] == "Stage3") a--
  b = i - 1
  hi = 0; for (t = a; t <= b; t++) if (wh[t] > hi) hi = wh[t]
  lo = wc[i]; for (t = (i > 104 ? i - 104 : 1); t <= i; t++) if (wc[t] < lo) lo = wc[t]
  lvl = wc[i - 1]; for (t = (i > 10 ? i - 10 : 1); t <= i - 1; t++) if (wc[t] < lvl) lvl = wc[t]
  # Head-and-shoulders proxy on weekly highs inside the Stage-3 range.
  nsw2 = 0; head = 0; hidx = 0
  for (t = a; t <= b; t++) {
    sw = 1
    for (u = t - 2; u <= t + 2; u++) if (u >= 1 && u <= nw && u != t && wh[u] > wh[t]) sw = 0
    if (sw && wh[t] > 0) { nsw2++; swi[nsw2] = t; if (wh[t] > head) { head = wh[t]; hidx = t } }
  }
  ls = 0; rs = 0
  for (u = 1; u <= nsw2; u++) { t = swi[u]; if (t < hidx && wh[t] > ls) ls = wh[t]; if (t > hidx && wh[t] > rs) rs = wh[t] }
  hs = (ls > 0 && rs > 0 && head >= 1.03 * (ls > rs ? ls : rs) && (ls > rs ? ls / rs : rs / ls) - 1 <= 0.05) ? 1 : 0
  # RS class: falling = below its value 4 weeks earlier.
  if (mr[i] == "" || i < 5 || mr[i - 4] == "") rsc = "na"
  else if (mr[i] >= mr[i - 4]) rsc = "rising"
  else rsc = (mr[i] < 0) ? "neg_falling" : "pos_falling"
  # SPY market phase.
  if (ss[i] == "Stage4") ph = (sr[i] <= 8) ? "s4_early" : "s4_late"
  else if (ss[i] == "Stage3") ph = "s3"
  else ph = "s12"
  # Dividend yield: trailing 365 days of raw amounts over the breakdown week's raw close.
  ylds = 0; cut = dn(wd[i]) - 365
  for (t = 1; t <= nv; t++) if (vdt[t] <= wd[i] && dn(vdt[t]) > cut) ylds += vam[t]
  ylds = ylds / dcl[wl[i]]
  # Large dividend (>= 3 % of prior raw close) inside the E1 hold.
  e1 = wl[i] + 1; lim = (e1 + 120 <= nd) ? e1 + 120 : nd; big = 0
  for (t = 1; t <= nv; t++) {
    if (vdt[t] <= dd[e1] || vdt[t] > dd[lim]) continue
    for (u = e1; u <= lim && dd[u] < vdt[t]; u++) ;
    if (u - 1 >= 1 && vam[t] >= 0.03 * dcl[u - 1]) big = 1
  }
  # E2: first weekly close in weeks +1..+8 at or above the broken support.
  e2 = 0; e2w = 0
  for (w = i + 1; w <= i + 8 && w <= nw; w++) if (wc[w] >= lvl && wl[w] > 0 && wl[w] < nd) { e2 = wl[w]; e2w = w - i; break }
  out = sym "," wd[i] "," fmt(dcl[wl[i]]) "," (b - a + 1) "," (lo > 0 ? fmt(hi / lo - 1) : "") "," hs "," (mr[i] == "" ? "" : fmt(mr[i])) "," rsc "," ph "," fmt(ylds) "," big "," fmt(hi * 1.01)
  out = out "," outcome(e1, hi * 1.01)
  out = out "," e2w "," (e2 ? outcome(e2, hi * 1.01) : ",,,,,,,,,")
  print out
}

# Ten fields: date, entry, O1 excess +20/+60/+120, O2 stock short ret, O2 excess, O2 bars, O2 stopped, stop room.
# A field past the end of the symbol's data carries its last bar (the "trunc" note is the O2 bars < 120 & !stopped).
function outcome(e, stop,   p, sp, k, o1, t, end, fill, stopped, j, n) {
  p = dad[e]; sp = spa[e]
  o1 = ""
  n = split("20 60 120", ks, " ")
  for (k = 1; k <= n; k++) { j = e + ks[k]; if (j > nd) j = nd
    o1 = o1 "," ((sp > 0 && spa[j] > 0) ? fmt((1 - dad[j] / p) - (1 - spa[j] / sp)) : "") }
  end = (e + 120 <= nd) ? e + 120 : nd; fill = dad[end]; stopped = 0; t = end
  if (p >= stop) { t = (e + 1 <= nd) ? e + 1 : e; fill = dop[t]; stopped = 1 }
  else for (j = e + 1; j <= end; j++) if (dhi[j] >= stop) { fill = (dop[j] >= stop) ? dop[j] : stop; t = j; stopped = 1; break }
  return dd[e] "," fmt(p) o1 "," fmt(1 - fill / p) "," ((sp > 0 && spa[t] > 0) ? fmt((1 - fill / p) - (1 - spa[t] / sp)) : "") "," (t - e) "," stopped "," fmt(stop / p - 1)
}
