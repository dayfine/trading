# replay.awk -- per-trade entry counterfactuals over ONE symbol's daily CSV store file. POSIX awk.
#
# usage: awk -F'\t' -v CHART=chart.tsv -f replay.awk gspc_weekly.tsv specs_for_symbol.tsv data.csv
#   gspc_weekly.tsv  "week_index<TAB>adjusted close" (the RS benchmark)
#   specs rows       specs.awk output for this symbol (all seeds)
#   data.csv         date,open,high,low,close,adjusted_close,volume,...
#
# Every comparison is on the ADJUSTED basis: bar prices scaled by adjusted_close / close, the run's raw prices
# by that day's factor. Weekly bars are Monday-based calendar weeks; the MA is the code's 30-week WMA
# (Stage.default_config ma_type Wma) of weekly adjusted closes.
#
# Rules replayed (all use information available on the day they act):
#   null   the code's own E as a stop-limit (trigger E, limit E x 1.02) from the day after the screen -- must
#          reproduce the actual fill (replication check)
#   H2(N)  same ticket with E = max weekly high of the last N weeks (incl. the screen week) x 1.005;
#          the code's installed stop; exit = the actual exit unless the stop is hit first
#   H3(m)  buy-limit at the latest completed week's MA x (1 + m), live for 8 weeks after the screen; book stop =
#          0.96 x the lowest weekly low of the 8 weeks before the fill week, skipped when wider than 15 %;
#          exit = actual exit if it was not a stop-loss, else hold until the book stop or 13 weeks
#   ctl    the actual fill under H3's stop and exit rule (isolates H3's entry from its stop)
# Sizing for every modelled P&L: value = min(1 % NAV / stop distance at the trigger, 14 % NAV), as the code does.
function week_of(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  return int((365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd + 1) / 7)
}
function wma(j,   k, s) { if (j < 30) return 0; s = 0; for (k = 0; k < 30; k++) s += (30 - k) * WC[j - k]; return s / 465 }
function day_le(d,   lo, hi, mid) {   # last day index with date <= d (0 if none)
  lo = 1; hi = nd; if (nd == 0 || D[1] > d) return 0
  while (lo < hi) { mid = int((lo + hi + 1) / 2); if (D[mid] <= d) lo = mid; else hi = mid - 1 }
  return lo
}
function size_value(trig, stop, nav,   sd, v) {
  sd = (trig - stop) / trig; if (sd <= 0) return 0
  v = 0.01 * nav / sd; if (v > 0.14 * nav) v = 0.14 * nav; return v
}
# stop-limit ticket from day a+1 to day b: sets TF (fill day) / TP (price); returns 1 if filled
function stoplimit(trig, a, b,   i, lim) {
  lim = trig * 1.02; TF = 0
  for (i = a + 1; i <= b; i++) if (H[i] >= trig && L[i] <= lim) { TF = i; TP = (O[i] >= trig) ? (O[i] <= lim ? O[i] : lim) : trig; return 1 }
  return 0
}
# hold from fill day f with stop s until day b; if not stopped exit at px_b (or the close of b when px_b < 0)
function hold(f, s, b, px_b,   i) {
  for (i = f + 1; i <= b; i++) if (L[i] <= s) { XF = i; XP = (O[i] < s) ? O[i] : s; XK = "stop"; return }
  XF = b; XP = (px_b > 0) ? px_b : C[b]; XK = "end"
}
function bookstop(f,   j, k, m) {   # 0.96 x min weekly low of the 8 completed weeks before day f's week
  j = DW[f]; m = 1e18; for (k = j - 8; k <= j - 1; k++) if (k >= 1 && WL[k] < m) m = WL[k]
  return (m < 1e18) ? 0.96 * m : 0
}
BEGIN { OFS = "\t" }
FILENAME == ARGV[1] { G[$1] = $2; next }
FILENAME == ARGV[2] { ns++; for (c = 1; c <= NF; c++) SP[ns, c] = $c; next }
FNR == 1 { FS = ","; split($0, h, ","); for (c in h) col[h[c]] = c; next }
{
  n0 = split($0, r, ","); cl = r[col["close"]] + 0; ad = r[col["adjusted_close"]] + 0
  if (cl <= 0 || ad <= 0 || r[col["high"]] + 0 <= 0) next
  f = ad / cl; nd++; D[nd] = r[col["date"]]; FA[nd] = f
  O[nd] = r[col["open"]] * f; H[nd] = r[col["high"]] * f; L[nd] = r[col["low"]] * f; C[nd] = ad
  RH[nd] = r[col["high"]] + 0; RL[nd] = r[col["low"]] + 0; VOL[nd] = r[col["volume"]] / f   # shares on the adjusted basis
  w = week_of(D[nd])
  if (w != lastw) { nw++; WK[nw] = w; WO[nw] = O[nd]; WH[nw] = H[nd]; WL[nw] = L[nd]; WV[nw] = 0; lastw = w }
  if (H[nd] > WH[nw]) WH[nw] = H[nd]; if (L[nd] < WL[nw]) WL[nw] = L[nd]
  WC[nw] = C[nd]; WV[nw] += VOL[nd]; WD[nw] = D[nd]; DW[nd] = nw
}
END {
  for (t = 1; t <= ns; t++) {
    seed = SP[t, 1]; pid = SP[t, 2]; sym = SP[t, 3]; sd = SP[t, 4]; fd = SP[t, 5]; xd = SP[t, 6]
    fr = SP[t, 7] + 0; xr = SP[t, 8] + 0; pnl = SP[t, 10] + 0; trig = SP[t, 11]; Er = SP[t, 12] + 0; Sr = SP[t, 13] + 0
    nav = SP[t, 14] + 0; maA = SP[t, 15] + 0; adjdec = SP[t, 17] + 0
    is = day_le(sd); ifl = day_le(fd); ix = day_le(xd)
    if (is == 0 || ifl == 0 || ix == 0 || D[ifl] != fd || D[ix] != xd) { print seed, pid, sym, "NODATA"; continue }
    ok = (fr >= RL[ifl] * 0.995 && fr <= RH[ifl] * 1.005) ? 1 : 0          # run fill inside the store's raw bar
    js = DW[is]; ma_s = wma(js); jf = DW[ifl]; ma_f = wma(jf - 1)
    fs = FA[is]; E = Er * fs; S = Sr * fs; F = fr * FA[ifl]; X = xr * FA[ix]
    ext_aud = (maA > 0) ? adjdec / maA - 1 : ""; ext_me = (ma_s > 0) ? C[is] / ma_s - 1 : ""
    ext_fill = (ma_f > 0) ? F / ma_f - 1 : ""
    rt4 = 0; for (k = js - 3; k <= js; k++) if (k >= 1 && WH[k] > rt4) rt4 = WH[k]
    R_act = (F > S) ? (X - F) / (F - S) : ""; v_act = size_value(E, S, nav); pm_act = v_act * (X - F) / E
    # null control: the code's own E
    nf = stoplimit(E, is, ix) ? TF : 0; null_d = nf ? D[nf] : "-"; null_r = nf ? TP / F : ""; nR = ""; np = 0
    if (nf && TP > S * 1.005) { nTP = TP; hold(nf, S, ix, X); nR = (XP - nTP) / (nTP - S); np = size_value(E, S, nav) * (XP - nTP) / E }
    line = seed OFS pid OFS sym OFS sd OFS fd OFS xd OFS trig OFS pnl OFS nav OFS ok OFS ext_aud OFS ext_me OFS ext_fill \
      OFS E / F OFS rt4 / F OFS R_act OFS pm_act OFS v_act / nav OFS null_d OFS null_r OFS nR OFS np
    # H2(N)
    for (q = 1; q <= 4; q++) {
      N = (q == 1) ? 2 : (q == 2) ? 4 : (q == 3) ? 8 : 13
      rt = 0; for (k = js - N + 1; k <= js; k++) if (k >= 1 && WH[k] > rt) rt = WH[k]
      Ec = rt * 1.005; st = "N"; cd = "-"; cr = ""; cR = ""; cp = 0
      if (stoplimit(Ec, is, ix)) {
        if (TP <= S * 1.005) st = "I"
        else { st = "F"; cd = D[TF]; cr = TP / F; hold(TF, S, ix, X); cR = (XP - TP) / (TP - S); cp = size_value(Ec, S, nav) * (XP - TP) / Ec }
      }
      line = line OFS st OFS cd OFS cr OFS cR OFS cp
    }
    # control for H3: actual fill, book stop, proxy exit
    hz = (trig != "stop_loss") ? ix : ix + 65; if (hz > nd) hz = nd
    bs = bookstop(ifl); cR = ""; cp = ""; c15 = ""
    if (bs > 0 && bs < F) { c15 = ((F - bs) / F > 0.15) ? 1 : 0; hold(ifl, bs, hz, (hz == ix && trig != "stop_loss") ? X : -1)
      cR = (XP - F) / (F - bs); cp = size_value(F, bs, nav) * (XP - F) / F }
    line = line OFS cR OFS cp OFS c15
    # H3(m): MA pullback limit
    for (q = 1; q <= 2; q++) {
      mm = (q == 1) ? 0.03 : 0.08; st = "N"; cd = "-"; cr = ""; cR = ""; cp = 0; sdist = ""
      for (i = is + 1; i <= is + 40 && i <= nd; i++) {
        lim = wma(DW[i] - 1) * (1 + mm); if (lim <= 0) continue
        if (L[i] <= lim) { P = (O[i] < lim) ? O[i] : lim; b = bookstop(i)
          if (b <= 0 || b >= P) { st = "I"; break }
          sdist = (P - b) / P; if (sdist > 0.15) { st = "W"; cd = D[i]; break }
          h3 = (trig != "stop_loss" && ix > i) ? ix : ((ix > i ? ix : i) + 65); if (h3 > nd) h3 = nd
          hold(i, b, h3, (h3 == ix && trig != "stop_loss") ? X : -1)
          st = "F"; cd = D[i]; cr = P / F; cR = (XP - P) / (P - b); cp = size_value(P, b, nav) * (XP - P) / P; break }
      }
      line = line OFS st OFS cd OFS cr OFS cR OFS cp OFS sdist
    }
    print line
    if (seed == 0 && CHART != "") {   # weekly chart window, prices on the fill-day raw basis
      a = js - 60; if (a < 1) a = 1; b = DW[ix] + 13; if (b > nw) b = nw; ff = FA[ifl]
      for (j = a; j <= b; j++) {
        rs = ""; if (j >= 52 && (WK[j] in G)) { s = 0; m = 0
          for (k = j - 51; k <= j; k++) if (WK[k] in G) { s += WC[k] / G[WK[k]]; m++ }
          if (m == 52) rs = sprintf("%.4f", (WC[j] / G[WK[j]]) / (s / 52)) }
        printf "%s\t%s\t%.4f\t%.4f\t%.4f\t%.4f\t%.0f\t%.4f\t%s\n", pid, WD[j], WO[j] / ff, WH[j] / ff, WL[j] / ff, WC[j] / ff, WV[j] * ff, wma(j) / ff, rs >> CHART
      }
    }
  }
}
