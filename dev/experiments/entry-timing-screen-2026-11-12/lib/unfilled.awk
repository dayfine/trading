# unfilled.awk -- tickets the code placed but never filled: would the stale-E cap (E' = min(E, 4-week high x 1.005))
# fill them, and what would a 26-week hold with the installed stop have made? Proxy exit; the code's result is 0.
# usage: awk -F'\t' -f unfilled.awk unfilled_specs_for_symbol.tsv data.csv
# out: seed pid sym screen stale(0/1) filled(0/1) fill_date R pnl_NAV%
function week_of(d,   y, m, dd) {
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; dd = substr(d, 9, 2) + 0; if (m < 3) { y--; m += 12 }
  return int((365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + dd + 1) / 7)
}
FILENAME == ARGV[1] { ns++; for (c = 1; c <= NF; c++) SP[ns, c] = $c; next }
FNR == 1 { split($0, h, ","); for (c in h) col[h[c]] = c; next }
{ n0 = split($0, r, ","); cl = r[col["close"]] + 0; ad = r[col["adjusted_close"]] + 0; if (cl <= 0 || ad <= 0) next
  f = ad / cl; nd++; D[nd] = r[col["date"]]; FA[nd] = f; O[nd] = r[col["open"]] * f; H[nd] = r[col["high"]] * f; L[nd] = r[col["low"]] * f; C[nd] = ad
  w = week_of(D[nd]); if (w != lw) { nw++; WH[nw] = H[nd]; lw = w }; if (H[nd] > WH[nw]) WH[nw] = H[nd]; DW[nd] = nw }
END { for (t = 1; t <= ns; t++) {
    k = SP[t, 1]; pid = SP[t, 2]; sd = SP[t, 4]; nav = SP[t, 7]
    is = 0; for (i = nd; i >= 1; i--) if (D[i] <= sd) { is = i; break }; if (is == 0) continue
    E = SP[t, 5] * FA[is]; S = SP[t, 6] * FA[is]; js = DW[is]; rt = 0; for (j = js - 3; j <= js; j++) if (j >= 1 && WH[j] > rt) rt = WH[j]
    Ec = rt * 1.005; stale = (E > Ec) ? 1 : 0; if (!stale) { print k, pid, SP[t, 3], sd, 0, 0, "-", "", 0; continue }
    lim = Ec * 1.02; fi = 0
    for (i = is + 1; i <= is + 260 && i <= nd; i++) if (H[i] >= Ec && L[i] <= lim) { fi = i; P = (O[i] >= Ec) ? (O[i] <= lim ? O[i] : lim) : Ec; break }
    if (!fi || P <= S * 1.005) { print k, pid, SP[t, 3], sd, 1, 0, "-", "", 0; continue }
    xp = 0; for (i = fi + 1; i <= fi + 130 && i <= nd; i++) if (L[i] <= S) { xp = (O[i] < S) ? O[i] : S; break }
    if (!xp) { i = (fi + 130 <= nd) ? fi + 130 : nd; xp = C[i] }
    sdv = (Ec - S) / Ec; v = 0.01 * nav / sdv; if (v > 0.14 * nav) v = 0.14 * nav
    print k, pid, SP[t, 3], sd, 1, 1, D[fi], (xp - P) / (P - S), 100 * v * (xp - P) / Ec / nav } }
