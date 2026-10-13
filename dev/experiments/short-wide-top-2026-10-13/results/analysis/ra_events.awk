# Results-analyst independent re-derivation of the short wide-top screen, written from the pre-registration text
# (dev/plans/short-wide-top-screen-2026-10-13.md @ 6a0177107), NOT copied from scripts/events.awk.
# Usage: awk -F, -v sym=X -v mem="1999 2000 ..." -f ra_events.awk spy-weekly-stage.csv SPY/data.csv X/data.csv
# Prints:
#   EV,<sym>,<last-bar date>,<raw close>,<H last-bar date>,<i-h>,<phase>,<stop>,<entry date>,<entry adj open>,
#      <o1_20>,<o1_60>,<o1_120>,<o2 ret>,<o2 exc>,<o2 bars>,<o2 stopped>,<room>,
#      <H weekly high>,<entry/Hhigh-1>,<o1_60 close-entry>,<o1_120 close-entry>,<o2 exc close-entry>,<o2 exc with entry-bar stop check>,
#      <week Friday>,<phase by Friday date>
#   NU,<sym>,<sample last-bar date>,<raw close>,<o1_60>,<o1_120>,<entry/trailing-52w-high - 1>,<close below 30w MA>,<MA falling over 4 wk>
#      (null: every 4th Friday from 2000-01-07, member, raw close >= 5; same entry and outcome conventions as the events)

function jdn(s,   y, m, d, a, y2, m2) {
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return d + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045
}
function fri_of(s,   j) { j = jdn(s); return j + ((4 - j % 7) + 7) % 7 }   # JDN%7: 0=Mon .. 4=Fri
function lyear(s,   y) { y = substr(s, 1, 4) + 0; return (substr(s, 6, 5) < "05-31") ? y - 1 : y }
function member(s,   ly) { ly = lyear(s); return (ly in MEM) }
function f5(x) { return sprintf("%.5f", x) }
function jdate(J,   l, n4, i, j, d, m, y) {   # JDN -> YYYY-MM-DD (Fliegel-Van Flandern)
  l = J + 68569; n4 = int(4 * l / 146097); l = l - int((146097 * n4 + 3) / 4); i = int(4000 * (l + 1) / 1461001)
  l = l - int(1461 * i / 4) + 31; j = int(80 * l / 2447); d = l - int(2447 * j / 80); l = int(j / 11); m = j + 2 - 12 * l
  y = 100 * (n4 - 49) + i + l; return sprintf("%04d-%02d-%02d", y, m, d)
}

BEGIN {
  nm = split(mem, ML, " "); for (q = 1; q <= nm; q++) MEM[ML[q] + 0] = 1
  J0 = jdn("2000-01-07"); J1 = jdn("2025-12-26")
}
FNR == 1 { file++; next }
file == 1 { ns++; s_date[ns] = $2; s_stage[ns] = $5; next }
file == 2 { if ($5 + 0 <= 0) next; spy_c[$1] = $6 + 0; spy_o[$1] = ($2 + 0) * ($6 + 0) / ($5 + 0); nsp++; spy_d[nsp] = $1; next }
file == 3 { if ($5 + 0 <= 0) next
  n++; D[n] = $1; R = ($6 + 0) / ($5 + 0); O[n] = ($2 + 0) * R; Hh[n] = ($3 + 0) * R; C[n] = $6 + 0; RC[n] = $5 + 0; next }

function spy_close_at(d,   lo, hi, mid) {   # SPY adj close at the last SPY date <= d
  if (d in spy_c) return spy_c[d]
  lo = 1; hi = nsp; if (spy_d[1] > d) return ""
  while (lo < hi) { mid = int((lo + hi + 1) / 2); if (spy_d[mid] <= d) lo = mid; else hi = mid - 1 }
  return spy_c[spy_d[lo]]
}
function phase_at(d,   t, k, run) {
  k = 0; for (t = 1; t <= ns; t++) { if (s_date[t] > d) break; k = t }
  if (k == 0) return "na"
  run = 1; for (t = k - 1; t >= 1 && s_stage[t] == s_stage[k]; t--) run++
  if (s_stage[k] == "Stage4") return (run <= 8) ? "s4_early" : "s4_late"
  if (s_stage[k] == "Stage3") return "s3"
  return "s12"
}
function o1(e, k, p, sp, close_entry,   j, st) {   # short minus SPY short, entry bar e, horizon k bars
  j = e + k; if (j > n) j = n
  st = spy_close_at(D[j]); if (st == "" || sp <= 0) return ""
  return (1 - C[j] / p) - (1 - st / sp)
}
function o2(e, p, sp, stop, first_check,   end, j, fill, t, st, s) {   # returns "ret,exc,bars,stopped"
  end = (e + 120 <= n) ? e + 120 : n; fill = C[end]; t = end; s = 0
  if (p >= stop) { t = (e + 1 <= n) ? e + 1 : e; fill = O[t]; s = 1 }
  else for (j = e + first_check; j <= end; j++) if (Hh[j] >= stop) { fill = (O[j] >= stop) ? O[j] : stop; t = j; s = 1; break }
  st = spy_close_at(D[t])
  return f5(1 - fill / p) "," ((st != "" && sp > 0) ? f5((1 - fill / p) - (1 - st / sp)) : "") "," (t - e) "," s
}

END {
  if (n < 400) exit   # same minimum-history guard as the screen's script (a run choice, not in the plan)
  # weekly bars
  nw = 0; cur = ""
  for (d = 1; d <= n; d++) {
    fr = fri_of(D[d])
    if (fr != cur) { nw++; WF[nw] = d; WH[nw] = Hh[d]; WFR[nw] = fr; cur = fr }
    WL[nw] = d; WC[nw] = C[d]; if (Hh[d] > WH[nw]) WH[nw] = Hh[d]
  }
  for (w = 30; w <= nw; w++) { s = 0; for (q = w - 29; q <= w; q++) s += WC[q]; MA[w] = s / 30 }
  # tops and their breakdowns
  for (h = 52; h <= nw; h++) {
    if (!(WC[h] >= MA[h])) continue
    istop = 1; for (q = h - 51; q <= h - 1; q++) if (WH[q] > WH[h]) { istop = 0; break }
    if (!istop) continue
    for (i = h + 8; i <= h + 52 && i <= nw; i++) {
      lo = WC[h - 8]; for (q = h - 7; q <= i - 1; q++) if (WC[q] < lo) lo = WC[q]
      if (WC[i] < lo && WC[i] < MA[i] && MA[i] <= MA[i - 4]) { if (!(i in TOP)) TOP[i] = h; break }
    }
  }
  # events
  last = -1e9
  for (i = 1; i <= nw; i++) {
    if (!(i in TOP)) continue
    if (WFR[i] < J0 || WFR[i] > J1) continue
    b = WL[i]; if (b + 1 > n) continue
    if (RC[b] < 5) continue
    if (!member(D[b])) continue
    if (WFR[i] - last < 182) continue
    last = WFR[i]
    h = TOP[i]
    hi = 0; for (d = WF[h + 1]; d <= WL[i - 1]; d++) if (Hh[d] > hi) hi = Hh[d]
    if (hi <= 0) continue
    stop = 1.01 * hi; e = b + 1; p = O[e]
    sp = (D[e] in spy_o) ? spy_o[D[e]] : spy_close_at(D[e])
    pc = C[e]; spc = spy_close_at(D[e])
    # Friday date string of week i for the phase-by-Friday variant
    a20 = o1(e, 20, p, sp); a60 = o1(e, 60, p, sp); a120 = o1(e, 120, p, sp)
    line = "EV," sym "," D[b] "," f5(RC[b]) "," D[WL[h]] "," (i - h) "," phase_at(D[b]) "," f5(stop) "," D[e] "," f5(p)
    line = line "," (a20 == "" ? "" : f5(a20)) "," (a60 == "" ? "" : f5(a60)) "," (a120 == "" ? "" : f5(a120))
    line = line "," o2(e, p, sp, stop, 1) "," f5(stop / p - 1) "," f5(WH[h]) "," f5(p / WH[h] - 1)
    line = line "," f5(o1(e, 60, pc, spc)) "," f5(o1(e, 120, pc, spc)) "," o2xc(e, pc, spc, stop) "," o2x(e, p, sp, stop)
    line = line "," jdate(WFR[i]) "," phase_at(jdate(WFR[i]))
    print line
  }
  # null sample: every 4th Friday from 2000-01-07
  for (w = 1; w <= nw; w++) {
    if (WFR[w] < J0 || WFR[w] > J1) continue
    if ((WFR[w] - J0) % 28 != 0) continue
    b = WL[w]; if (b + 1 > n) continue
    if (RC[b] < 5 || !member(D[b])) continue
    e = b + 1; p = O[e]; sp = (D[e] in spy_o) ? spy_o[D[e]] : spy_close_at(D[e])
    a60 = o1(e, 60, p, sp); a120 = o1(e, 120, p, sp)
    if (a60 == "" || a120 == "") continue
    hi52 = 0; if (w >= 52) for (q = w - 51; q <= w; q++) if (WH[q] > hi52) hi52 = WH[q]
    dist = (hi52 > 0) ? f5(p / hi52 - 1) : ""; bm = (w >= 30) ? (WC[w] < MA[w]) : ""; mf = (w >= 34) ? (MA[w] <= MA[w - 4]) : ""
    printf "NU,%s,%s,%s,%s,%s,%s,%s,%s\n", sym, D[b], f5(RC[b]), f5(a60), f5(a120), dist, bm, mf
  }
}
function o2x(e, p, sp, stop,   r) { r = o2(e, p, sp, stop, 0); split(r, Z, ","); return Z[2] }   # entry-bar stop check included
function o2xc(e, p, sp, stop,   r) { r = o2(e, p, sp, stop, 1); split(r, Z, ","); return Z[2] }  # close entry, check from e+1
