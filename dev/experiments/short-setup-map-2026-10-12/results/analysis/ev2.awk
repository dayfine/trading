# Analyst diagnostics for the short setup map (results-analyst, 2026-10-12; read-only re-derivation, not the rule).
# Same event selection as events.awk (copied verbatim for the selection), extra per-event fields:
#   bclose, lvl (broken support), ma (stage csv), below_sup (breakdown weekly close < lvl), dd52 (breakdown close vs the
#   52-week max weekly close), hi26/hi52 stops (1 % above the max weekly high of the 26 / 52 weeks before the break),
#   nbars_after (daily bars after E1 entry), and an E1 stop-width surface: O2-style excess vs the SPY short with the
#   buy-stop at entry x (1+k), k = 5,10,15,20,30,50,100 %, and with the hi26 / hi52 stops. Hold to stop or +120 bars.
function dn(s,   y, m, d) {
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + d
}
function list_year(s,   y) { y = substr(s, 1, 4) + 0; return (substr(s, 6, 5) >= "05-31") ? y : y - 1 }
function is_member(s,   y) { y = list_year(s); return ((" " mem " ") ~ (" " y " ")) }
function fmt(x) { return sprintf("%.5f", x) }
FNR == 1 { fi++; next }
fi == 1 { nsw++; swd[nsw] = $2; swc[nsw] = $3; sws[nsw] = $5; next }
fi == 2 { nsd++; sdd[nsd] = $1; sda[nsd] = $6; next }
fi == 3 { nw++; wd[nw] = $2; wc[nw] = $3; wst[nw] = $5; wma[nw] = $4; next }
fi == 4 { if ($5 + 0 <= 0) next
          nd++; dd[nd] = $1; f = $6 / $5; dop[nd] = $2 * f; dhi[nd] = $3 * f; dcl[nd] = $5; dad[nd] = $6; next }
END {
  if (nw < 60 || nd < 200) exit
  k = 1
  for (j = 1; j <= nd; j++) { while (k < nsd && sdd[k + 1] <= dd[j]) k++; spa[j] = (sdd[k] <= dd[j]) ? sda[k] : "" }
  j = 1
  for (i = 1; i <= nw; i++) {
    wh[i] = 0; wl[i] = 0
    while (j <= nd && dd[j] <= wd[i]) { if (dhi[j] > wh[i]) wh[i] = dhi[j]; wl[i] = j; j++ }
    if (wl[i] > 0) wc[i] = dad[wl[i]]
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
function emit(i,   t, lvl, h26, h52, c52, e1, p, out, kk, ks, n) {
  lvl = wc[i - 1]; for (t = (i > 10 ? i - 10 : 1); t <= i - 1; t++) if (wc[t] < lvl) lvl = wc[t]
  h26 = 0; for (t = (i > 26 ? i - 26 : 1); t <= i - 1; t++) if (wh[t] > h26) h26 = wh[t]
  h52 = 0; c52 = 0; for (t = (i > 52 ? i - 52 : 1); t <= i - 1; t++) { if (wh[t] > h52) h52 = wh[t]; if (wc[t] > c52) c52 = wc[t] }
  e1 = wl[i] + 1; p = dad[e1]
  out = sym "," wd[i] "," fmt(wc[i]) "," fmt(lvl) "," wma[i] "," (wc[i] < lvl ? 1 : 0) "," (c52 > 0 ? fmt(wc[i] / c52 - 1) : "") "," fmt(h26 * 1.01 / p - 1) "," fmt(h52 * 1.01 / p - 1) "," (nd - e1)
  n = split("0.05 0.10 0.15 0.20 0.30 0.50 1.00", ks, " ")
  for (kk = 1; kk <= n; kk++) out = out "," o2(e1, p * (1 + ks[kk]))
  out = out "," o2(e1, h26 * 1.01) "," o2(e1, h52 * 1.01)
  print out
}
# excess (short - SPY short) and stopped flag, hold to stop or +120 bars; entry close above the stop = cover next open
function o2(e, stop,   p, sp, end, fill, t, j, st) {
  p = dad[e]; sp = spa[e]; end = (e + 120 <= nd) ? e + 120 : nd; fill = dad[end]; t = end; st = 0
  if (p >= stop) { t = (e + 1 <= nd) ? e + 1 : e; fill = dop[t]; st = 1 }
  else for (j = e + 1; j <= end; j++) if (dhi[j] >= stop) { fill = (dop[j] >= stop) ? dop[j] : stop; t = j; st = 1; break }
  return ((sp > 0 && spa[t] > 0) ? fmt((1 - fill / p) - (1 - spa[t] / sp)) : "") ";" st
}
