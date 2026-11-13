# conv.awk -- direction (b): a No_structural_stop skip the book floor would convert into a ticket. POSIX awk.
# usage: awk -F'\t' -f conv.awk events_for_symbol.tsv data.csv
#   events rows: seed date sym nav kind  (kind "skip" = a skip event; "null" = an actual trade for calibration:
#                then cols 6-8 = fill_date fill_raw installed_stop_raw)
# skip: E = the code's breakout scan (max weekly high over offsets 8..51) x 1.005; F1 floor (N=13, M=4) x 0.96;
#       gate 15 % from E; stop-limit E (limit E x 1.02) for 40 trading days; hold with the book stop until hit or
#       130 trading days (26 weeks), exit at the close. Sizing: min(1 % NAV / stop distance, 14 % NAV).
# null: the actual fill and installed stop under the same 26-week hold (calibrates the proxy against real trades).
# out: seed date sym kind status pnl_nav_pct [stop_dist]   status: F filled, N no fill, D gate drop, U no breakout
function week_of(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  return int((365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd + 1) / 7)
}
function day_le(d,   lo, hi, mid) { lo = 1; hi = nd; if (nd == 0 || D[1] > d) return 0
  while (lo < hi) { mid = int((lo + hi + 1) / 2); if (D[mid] <= d) lo = mid; else hi = mid - 1 }; return lo }
function hiN(j, N,   k, m) { m = 0; for (k = j - N; k <= j - 1; k++) if (k >= 1 && WH[k] > m) m = WH[k]; return m }
function breakout_week(js, N,   j) { for (j = js; j >= js - 25 && j > N + 1; j--) if (WC[j] > hiN(j, N) && !(WC[j - 1] > hiN(j - 1, N))) return j; return 0 }
function hold26(f, s,   i, b) { b = f + 130; if (b > nd) b = nd; for (i = f + 1; i <= b; i++) if (L[i] <= s) return (O[i] < s) ? O[i] : s; return C[b] }
function sizev(trig, stop,   sd, v) { sd = (trig - stop) / trig; if (sd <= 0) return 0; v = 0.01 / sd; return (v > 0.14) ? 0.14 : v }
FILENAME == ARGV[1] { ns++; for (c = 1; c <= NF; c++) SP[ns, c] = $c; next }
FNR == 1 { split($0, h, ","); for (c in h) col[h[c]] = c; next }
{ n0 = split($0, r, ","); cl = r[col["close"]] + 0; ad = r[col["adjusted_close"]] + 0; if (cl <= 0 || ad <= 0 || r[col["high"]] + 0 <= 0) next
  f = ad / cl; nd++; D[nd] = r[col["date"]]; FA[nd] = f; O[nd] = r[col["open"]] * f; H[nd] = r[col["high"]] * f; L[nd] = r[col["low"]] * f; C[nd] = ad
  RL[nd] = r[col["low"]] + 0; RH[nd] = r[col["high"]] + 0
  w = week_of(D[nd]); if (w != lw) { nw++; WH[nw] = H[nd]; WL[nw] = L[nd]; lw = w }
  if (H[nd] > WH[nw]) WH[nw] = H[nd]; if (L[nd] < WL[nw]) WL[nw] = L[nd]; WC[nw] = C[nd]; DW[nd] = nw }
END { for (t = 1; t <= ns; t++) {
    k = SP[t, 1]; d = SP[t, 2]; sym = SP[t, 3]; nav = SP[t, 4]; kind = SP[t, 5]
    if (kind == "null") { ifl = day_le(SP[t, 6]); if (!ifl || D[ifl] != SP[t, 6]) continue; fr = SP[t, 7] + 0
      if (!(fr >= RL[ifl] * 0.995 && fr <= RH[ifl] * 1.005)) continue
      P = fr * FA[ifl]; s = SP[t, 8] * FA[ifl]; if (s >= P) continue
      x = hold26(ifl, s); print k "\t" d "\t" sym "\tnull\tF\t" 100 * sizev(P, s) * (x - P) / P; continue }
    is = day_le(d); if (!is) continue; js = DW[is]
    e = 0; for (j = js - 51; j <= js - 8; j++) if (j >= 1 && WH[j] > e) e = WH[j]; if (e <= 0) continue; E = e * 1.005
    b = breakout_week(js, 13); if (!b) { print k "\t" d "\t" sym "\tskip\tU\t0"; continue }
    fl = 1e18; for (j = b - 4; j <= b - 1; j++) if (j >= 1 && WL[j] < fl) fl = WL[j]; bs = fl * 0.96; sdist = (E - bs) / E
    if (bs <= 0 || sdist > 0.15 || sdist <= 0) { print k "\t" d "\t" sym "\tskip\tD\t0\t" sdist; continue }
    lim = E * 1.02; fi = 0
    for (i = is + 1; i <= is + 40 && i <= nd; i++) if (H[i] >= E && L[i] <= lim) { fi = i; P = (O[i] >= E) ? (O[i] <= lim ? O[i] : lim) : E; break }
    if (!fi || P <= bs) { print k "\t" d "\t" sym "\tskip\tN\t0\t" sdist; continue }
    x = hold26(fi, bs); print k "\t" d "\t" sym "\tskip\tF\t" 100 * sizev(E, bs) * (x - P) / E "\t" sdist } }
