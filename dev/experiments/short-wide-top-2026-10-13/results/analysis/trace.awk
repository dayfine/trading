# trace.awk: print one wide-top event step by step from raw bars.
# awk -F, -v BD=<breakdown last-bar date> -v HD=<top last-bar date> -f trace.awk SPY/data.csv SYM/data.csv
function jdn(s,   y, m, d, a, y2, m2) { y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return d + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045 }
function fri(s,   j) { j = jdn(s); return j + ((4 - j % 7) + 7) % 7 }
FNR == 1 { f++; next }
f == 1 { if ($5 + 0 <= 0) next; sc[$1] = $6 + 0; so[$1] = ($2 + 0) * ($6 + 0) / ($5 + 0); ns++; sdd[ns] = $1; next }
f == 2 { if ($5 + 0 <= 0) next; n++; D[n] = $1; r = ($6 + 0) / ($5 + 0); O[n] = $2 * r; H[n] = $3 * r; L[n] = $4 * r; C[n] = $6 + 0; RC[n] = $5 + 0; next }
function spyc(d,   k) { if (d in sc) return sc[d]; for (k = ns; k >= 1; k--) if (sdd[k] <= d) return sc[sdd[k]]; return "" }
END {
  nw = 0; cur = ""; for (d = 1; d <= n; d++) { fr = fri(D[d]); if (fr != cur) { nw++; WF[nw] = d; WH[nw] = H[d]; cur = fr }; WL[nw] = d; WC[nw] = C[d]; if (H[d] > WH[nw]) WH[nw] = H[d] }
  for (w = 30; w <= nw; w++) { s = 0; for (q = w - 29; q <= w; q++) s += WC[q]; MA[w] = s / 30 }
  for (w = 1; w <= nw; w++) { if (D[WL[w]] == HD) h = w; if (D[WL[w]] == BD) i = w }
  m51 = 0; for (q = h - 51; q < h; q++) if (WH[q] > m51) { m51 = WH[q]; m51d = D[WL[q]] }
  printf "TOP H week %s: weekly high %.3f (prior 51 weeks max %.3f on %s) close %.3f vs 30w MA %.3f\n", HD, WH[h], m51, m51d, WC[h], MA[h]
  lo = WC[h - 8]; lod = D[WL[h - 8]]; for (q = h - 7; q <= i - 1; q++) if (WC[q] < lo) { lo = WC[q]; lod = D[WL[q]] }
  printf "BREAKDOWN week %s (H+%d): close %.3f < lowest close of [H-8, i-1] %.3f (%s); MA(i) %.3f, MA(i-4) %.3f\n", BD, i - h, WC[i], lo, lod, MA[i], MA[i - 4]
  sh = 0; for (d = WF[h + 1]; d <= WL[i - 1]; d++) if (H[d] > sh) { sh = H[d]; shd = D[d] }
  stop = 1.01 * sh; e = WL[i] + 1; p = O[e]; sp = (D[e] in so) ? so[D[e]] : spyc(D[e])
  printf "RIGHT SHOULDER high %.3f on %s -> stop %.3f; ENTRY %s open %.3f (raw close at breakdown %.2f); room %.1f%%; entry vs H high %.1f%%\n", sh, shd, stop, D[e], p, RC[WL[i]], 100 * (stop / p - 1), 100 * (p / WH[h] - 1)
  for (k = 20; k <= 120; k += (k == 20 ? 40 : 60)) { j = e + k; if (j > n) j = n; st = spyc(D[j]); printf "  +%d bars %s: stock %.3f (short %+.1f%%), SPY %+.1f%% -> O1 excess %+.2f%%\n", k, D[j], C[j], 100 * (1 - C[j] / p), 100 * (st / sp - 1), 100 * ((1 - C[j] / p) - (1 - st / sp)) }
  end = (e + 120 <= n) ? e + 120 : n; t = end; fill = C[end]; why = "held to +120"
  if (p >= stop) { t = e + 1; fill = O[t]; why = "entry above stop" } else for (j = e + 1; j <= end; j++) if (H[j] >= stop) { t = j; fill = (O[j] >= stop) ? O[j] : stop; why = (O[j] >= stop) ? "gap over stop" : "stop hit"; break }
  st = spyc(D[t]); mx = 0; mn = 1e18; for (j = e; j <= end; j++) { if (H[j] > mx) { mx = H[j]; mxd = D[j] }; if (L[j] < mn) { mn = L[j]; mnd = D[j] } }
  printf "  O2: %s at bar +%d %s, fill %.3f: short %+.1f%%, SPY %+.1f%%, excess %+.2f%%\n", why, t - e, D[t], fill, 100 * (1 - fill / p), 100 * (st / sp - 1), 100 * ((1 - fill / p) - (1 - st / sp))
  printf "  path over the 120 bars: high %.3f (%s, %+.1f%% vs entry), low %.3f (%s, %+.1f%%)\n", mx, mxd, 100 * (mx / p - 1), mn, mnd, 100 * (mn / p - 1)
}
