# mscan.awk -- every book-style weekly breakout of one symbol while it is a PIT top-3000 member, with decision-time
# traits and ex-post outcomes (see PREREG.md). POSIX awk.
# usage: awk -F'\t' -v SYM=X -f mscan.awk gspc_weekly.tsv windows_for_symbol.tsv data.csv
# out: sym date monster fwd_max ride base_weeks depth ath_gap age price dollar_vol vol26 volx ret26 ext regime eff104
function week_of(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  return int((365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd + 1) / 7)
}
FILENAME == ARGV[1] { gn++; GW[gn] = $1; GC[gn] = $2; GI[$1] = gn; next }
FILENAME == ARGV[2] { nwin++; WS[nwin] = $2; WE[nwin] = $3; next }
FNR == 1 { split($0, h, ","); for (c in h) col[h[c]] = c; next }
{ n0 = split($0, r, ","); cl = r[col["close"]] + 0; ad = r[col["adjusted_close"]] + 0; if (cl <= 0 || ad <= 0 || r[col["high"]] + 0 <= 0) next
  f = ad / cl; d = r[col["date"]]; w = week_of(d); vol = r[col["volume"]] + 0
  if (w != lw) { nw++; WK[nw] = w; WH[nw] = r[col["high"]] * f; WL[nw] = r[col["low"]] * f; WV[nw] = 0; lw = w }
  if (r[col["high"]] * f > WH[nw]) WH[nw] = r[col["high"]] * f; if (r[col["low"]] * f < WL[nw]) WL[nw] = r[col["low"]] * f
  WC[nw] = ad; WR[nw] = cl; WD[nw] = d; WV[nw] += vol / f
  nd++; DV[nd] = cl * vol; DW[nd] = nw }
END {
  if (nw < 60) exit
  for (j = 30; j <= nw; j++) { s = 0; for (k = 0; k < 30; k++) s += (30 - k) * WC[j - k]; MA[j] = s / 465 }
  for (i = 31; i <= gn; i++) { s = 0; for (k = 0; k < 30; k++) s += (30 - k) * GC[i - k]; GM[i] = s / 465 }
  # last daily index of each week, for the 20-day dollar volume
  for (i = 1; i <= nd; i++) LD[DW[i]] = i
  amax = 0; nxt = 0
  for (j = 2; j <= nw; j++) { if (WH[j - 1] > amax) amax = WH[j - 1]; ATH[j] = amax }
  for (j = 35; j <= nw - 52; j++) {
    if (j < nxt) continue
    inwin = 0; for (q = 1; q <= nwin; q++) if (WD[j] >= WS[q] && WD[j] <= WE[q]) { inwin = 1; break }
    if (!inwin || WD[j] < "2000-01-01" || WR[j] < 5) continue
    h26 = 0; for (k = j - 26; k <= j - 1; k++) if (WH[k] > h26) h26 = WH[k]
    v4 = 0; for (k = j - 4; k <= j - 1; k++) v4 += WV[k]; v4 /= 4
    if (!(WC[j] > h26 && v4 > 0 && WV[j] >= 2 * v4 && WC[j] > MA[j] && MA[j] >= MA[j - 4])) continue
    nxt = j + 26
    # outcomes (ex post)
    fm = 0; for (k = j + 1; k <= j + 52; k++) if (WC[k] > fm) fm = WC[k]; fwd = fm / WC[j] - 1
    ride = ""; e = j + 104; if (e > nw) e = nw
    for (k = j + 1; k <= e; k++) if (WC[k] < MA[k]) { ride = WC[k] / WC[j] - 1; break }
    if (ride == "") ride = WC[e] / WC[j] - 1
    # traits (decision time, bars <= j)
    a = (j - 52 > 1) ? j - 52 : 1; hm = 0; lm = 1e18; km = j - 1
    for (k = a; k <= j - 1; k++) { if (WH[k] >= hm) { hm = WH[k]; km = k }; if (WL[k] < lm) lm = WL[k] }
    base = j - km; depth = (hm > 0) ? (hm - lm) / hm : 0; athg = WC[j] / ATH[j] - 1
    dv = 0; m = 0; for (i = LD[j]; i > LD[j] - 20 && i >= 1; i--) { dv += DV[i]; m++ }; dv = (m ? dv / m : 0)
    sx = 0; sxx = 0; nn = 0; for (k = j - 25; k <= j; k++) { x = log(WC[k] / WC[k - 1]); sx += x; sxx += x * x; nn++ }
    v26 = sqrt((sxx - sx * sx / nn) / (nn - 1))
    volx = WV[j] / v4; r26 = WC[j] / WC[j - 26] - 1; ext = WC[j] / MA[j] - 1
    reg = 0; if (WK[j] in GI) { gi = GI[WK[j]]; if (gi > 34 && GC[gi] > GM[gi] && GM[gi] >= GM[gi - 4]) reg = 1 }
    eff = ""; if (j > 105) { p = 0; for (k = j - 103; k <= j; k++) { x = WC[k] - WC[k - 1]; p += (x < 0) ? -x : x }; nt = WC[j] - WC[j - 104]; if (nt < 0) nt = -nt; eff = (p > 0) ? nt / p : 0 }
    printf "%s\t%s\t%d\t%.4f\t%.4f\t%d\t%.4f\t%.4f\t%d\t%.2f\t%.0f\t%.4f\t%.2f\t%.4f\t%.4f\t%d\t%s\n", SYM, WD[j], (fwd >= 1), fwd, ride, base, depth, athg, j, WR[j], dv, v26, volx, r26, ext, reg, eff
  } }
