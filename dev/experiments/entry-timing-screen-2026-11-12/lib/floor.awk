# floor.awk -- the book-literal pre-breakout floor (F1) replayed over one symbol's closed trades. POSIX awk.
#
# usage: awk -F'\t' -f floor.awk specs_x_for_symbol.tsv data.csv
#   specs_x rows: specs.awk columns 1-24, then 25 entry_stop 26 exit_stop 27 n_stop_raises (trades.csv)
#
# F1 at the screen week js (weekly bars on the adjusted basis, Monday weeks, information through js only):
#   breakout week b = the most recent week in [js-25, js] whose close exceeds the highest high of the N weeks before
#                     it while the week before did not (the first week of a breakout run)
#   floor           = the lowest low of the M weeks before b;  book stop = floor x 0.96 (the code's buffer)
#   gate            = drop when (E - book stop) / E > 0.15 (the record's Drop_over_max at 15 %)
# Kept trades are re-sized (1 % NAV risk at E, 14 % NAV cap) and held with the book stop:
#   - exit at the actual exit unless the book stop is hit first, except
#   - when the actual exit was the never-raised initial stop: hold until the book stop or 13 weeks past the exit.
# Baseline = the same sizing with the code's stop and the actual exit (replay.awk's pnl_model_actual).
# out per trade: seed pid sym screen exit_trigger nav base_pnl then per (N,M) cell: status stop_dist pnl_gate pnl_nogate
#   status: K kept, D dropped by the gate, U no breakout week in 26 weeks (trade unchanged), I book stop at/above fill
function week_of(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  return int((365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd + 1) / 7)
}
function day_le(d,   lo, hi, mid) { lo = 1; hi = nd; if (nd == 0 || D[1] > d) return 0
  while (lo < hi) { mid = int((lo + hi + 1) / 2); if (D[mid] <= d) lo = mid; else hi = mid - 1 }; return lo }
function size_value(trig, stop, nav,   sd, v) { sd = (trig - stop) / trig; if (sd <= 0) return 0
  v = 0.01 * nav / sd; if (v > 0.14 * nav) v = 0.14 * nav; return v }
function hold(f, s, b, px_b,   i) {
  for (i = f + 1; i <= b; i++) if (L[i] <= s) { XP = (O[i] < s) ? O[i] : s; return }
  XP = (px_b > 0) ? px_b : C[b] }
function hiN(j, N,   k, m) { m = 0; for (k = j - N; k <= j - 1; k++) if (k >= 1 && WH[k] > m) m = WH[k]; return m }
# most recent breakout-run start in [js-25, js]; 0 if none
function breakout_week(js, N,   j) {
  for (j = js; j >= js - 25 && j > N + 1; j--) if (WC[j] > hiN(j, N) && !(WC[j - 1] > hiN(j - 1, N))) return j
  return 0 }
function floor_before(b, M,   k, m) { m = 1e18; for (k = b - M; k <= b - 1; k++) if (k >= 1 && WL[k] < m) m = WL[k]; return (m < 1e18) ? m : 0 }
FILENAME == ARGV[1] { ns++; for (c = 1; c <= NF; c++) SP[ns, c] = $c; next }
FNR == 1 { split($0, h, ","); for (c in h) col[h[c]] = c; next }
{ n0 = split($0, r, ","); cl = r[col["close"]] + 0; ad = r[col["adjusted_close"]] + 0
  if (cl <= 0 || ad <= 0 || r[col["high"]] + 0 <= 0) next
  f = ad / cl; nd++; D[nd] = r[col["date"]]; FA[nd] = f
  O[nd] = r[col["open"]] * f; H[nd] = r[col["high"]] * f; L[nd] = r[col["low"]] * f; C[nd] = ad
  RH[nd] = r[col["high"]] + 0; RL[nd] = r[col["low"]] + 0
  w = week_of(D[nd]); if (w != lw) { nw++; WH[nw] = H[nd]; WL[nw] = L[nd]; lw = w }
  if (H[nd] > WH[nw]) WH[nw] = H[nd]; if (L[nd] < WL[nw]) WL[nw] = L[nd]; WC[nw] = C[nd]; DW[nd] = nw }
END {
  nN = split("8 13 26", NS, " "); nM = split("2 4 8", MS, " ")
  for (t = 1; t <= ns; t++) {
    seed = SP[t, 1]; pid = SP[t, 2]; sym = SP[t, 3]; sd = SP[t, 4]; fd = SP[t, 5]; xd = SP[t, 6]
    fr = SP[t, 7] + 0; xr = SP[t, 8] + 0; trig = SP[t, 11]; Er = SP[t, 12] + 0; Sr = SP[t, 13] + 0; nav = SP[t, 14] + 0
    es = SP[t, 25] + 0; xs = SP[t, 26] + 0; nr = SP[t, 27] + 0
    is = day_le(sd); ifl = day_le(fd); ix = day_le(xd)
    if (is == 0 || ifl == 0 || ix == 0 || D[ifl] != fd || D[ix] != xd) continue
    if (!(fr >= RL[ifl] * 0.995 && fr <= RH[ifl] * 1.005)) continue                 # basis mismatch: skip
    js = DW[is]; fs = FA[is]; E = Er * fs; S = Sr * fs; F = fr * FA[ifl]; X = xr * FA[ix]
    base = size_value(E, S, nav) * (X - F) / E
    init_stop_exit = (trig == "stop_loss" && nr == 0) ? 1 : 0
    line = seed "\t" pid "\t" sym "\t" sd "\t" trig "\t" nav "\t" base
    for (a = 1; a <= nN; a++) for (bm = 1; bm <= nM; bm++) {
      b = breakout_week(js, NS[a]); st = "U"; sdist = ""; pg = base; pn = base
      if (b) { fl = floor_before(b, MS[bm]); bs = fl * 0.96
        if (bs <= 0 || bs >= F * 0.995) { st = "I"; pg = 0; pn = base }
        else { sdist = (E - bs) / E
          hz = init_stop_exit ? ix + 65 : ix; if (hz > nd) hz = nd
          hold(ifl, bs, hz, (hz == ix && !init_stop_exit) ? X : -1)
          pn = size_value(E, bs, nav) * (XP - F) / E
          if (sdist > 0.15) { st = "D"; pg = 0 } else { st = "K"; pg = pn } } }
      line = line "\t" st "\t" sdist "\t" pg "\t" pn }
    print line } }
