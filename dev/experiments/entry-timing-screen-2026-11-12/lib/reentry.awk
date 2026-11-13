# reentry.awk -- post-stop re-entry (R1) over one symbol's closed trades. POSIX awk.
# usage: awk -F'\t' -v GATE=0.15 -f reentry.awk specs_x_for_symbol.tsv data.csv   (GATE=0: no stop-width gate)
# For every stop_loss exit (basis-checked):
#   trigger T = highest high while held (fill .. exit) x 1.005; stop-limit T (limit T x 1.02), live W trading days
#   after the exit (W = 40 / 65 / 130, i.e. 8 / 13 / 26 weeks)
#   stop = 0.96 x the shakeout low (lowest low from the exit day to the day before the re-entry fill)
#   gate: (T - stop) / T > GATE -> no re-entry ("D"), GATE = 0 disables it; sizing min(1 % NAV / stop distance, 14 % NAV), NAV at the
#   original screen; exit = stop hit or 130 trading days (26 weeks), at the close.
#   dup = the same seed's run re-bought this symbol itself between the exit and the re-entry fill (not incremental)
# out: seed pid sym exit_date initial_stop_exit(0/1) then per W: status fill_date ret_pct nav_pct stop_dist dup
#   status F filled, N no trigger, D gate drop
function day_le(d,   lo, hi, mid) { lo = 1; hi = nd; if (nd == 0 || D[1] > d) return 0
  while (lo < hi) { mid = int((lo + hi + 1) / 2); if (D[mid] <= d) lo = mid; else hi = mid - 1 }; return lo }
FILENAME == ARGV[1] { ns++; for (c = 1; c <= NF; c++) SP[ns, c] = $c; FILLS[$1] = FILLS[$1] " " $5; next }
FNR == 1 { split($0, h, ","); for (c in h) col[h[c]] = c; next }
{ n0 = split($0, r, ","); cl = r[col["close"]] + 0; ad = r[col["adjusted_close"]] + 0; if (cl <= 0 || ad <= 0 || r[col["high"]] + 0 <= 0) next
  f = ad / cl; nd++; D[nd] = r[col["date"]]; FA[nd] = f; O[nd] = r[col["open"]] * f; H[nd] = r[col["high"]] * f; L[nd] = r[col["low"]] * f; C[nd] = ad
  RL[nd] = r[col["low"]] + 0; RH[nd] = r[col["high"]] + 0 }
END { for (t = 1; t <= ns; t++) {
    if (SP[t, 11] != "stop_loss") continue
    k = SP[t, 1]; pid = SP[t, 2]; sym = SP[t, 3]; fd = SP[t, 5]; xd = SP[t, 6]; fr = SP[t, 7] + 0; nav = SP[t, 14] + 0
    ifl = day_le(fd); ix = day_le(xd); if (!ifl || !ix || D[ifl] != fd || D[ix] != xd) continue
    if (!(fr >= RL[ifl] * 0.995 && fr <= RH[ifl] * 1.005)) continue
    pk = 0; for (i = ifl; i <= ix; i++) if (H[i] > pk) pk = H[i]; T = pk * 1.005; lim = T * 1.02
    line = k "\t" pid "\t" sym "\t" xd "\t" ((SP[t, 27] + 0 == 0) ? 1 : 0)
    nW = split("40 65 130", WS, " ")
    for (q = 1; q <= nW; q++) { st = "N"; cd = "-"; ret = ""; nv = 0; sdist = ""; dup = 0; lo = 1e18; fi = 0
      for (i = ix; i <= ix + WS[q] && i <= nd; i++) {
        if (i > ix && H[i] >= T && L[i] <= lim) { fi = i; break }
        if (L[i] < lo) lo = L[i] }
      if (fi) { P = (O[fi] >= T) ? (O[fi] <= lim ? O[fi] : lim) : T; bs = lo * 0.96; sdist = (T - bs) / T; cd = D[fi]
        n1 = split(FILLS[k], fl, " "); for (j = 1; j <= n1; j++) if (fl[j] > xd && fl[j] <= cd) dup = 1
        if ((GATE > 0 && sdist > GATE) || bs >= P) st = "D"
        else { st = "F"; xp = 0; e = fi + 130; if (e > nd) e = nd
          for (i = fi + 1; i <= e; i++) if (L[i] <= bs) { xp = (O[i] < bs) ? O[i] : bs; break }
          if (!xp) xp = C[e]
          v = 0.01 / sdist; if (v > 0.14) v = 0.14; ret = 100 * (xp - P) / P; nv = 100 * v * (xp - P) / P } }
      line = line "\t" st "\t" cd "\t" ret "\t" nv "\t" sdist "\t" dup }
    print line } }
