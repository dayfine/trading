# span.awk: for each event (file1 rows "sym,entry_date,o2_bars") of ONE symbol, print the calendar days from entry to +120 bars and to the O2 exit
function jdn(s,   y, m, d, a, y2, m2) { y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return d + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045 }
FNR == 1 { f++; if (f == 2) next }
f == 1 { ne++; ed[ne] = $2; eb[ne] = $3; next }
f == 2 { if ($5 + 0 <= 0) next; n++; D[n] = $1; idx[$1] = n; next }
END { for (i = 1; i <= ne; i++) { e = idx[ed[i]]; j = (e + 120 <= n) ? e + 120 : n; t = e + eb[i]; if (t > n) t = n
  maxgap = 0; for (k = e + 1; k <= j; k++) { g = jdn(D[k]) - jdn(D[k - 1]); if (g > maxgap) { maxgap = g; gd = D[k - 1] } }
  printf "%s,%s,%d,%d,%d,%s\n", SYM, ed[i], jdn(D[j]) - jdn(D[e]), jdn(D[t]) - jdn(D[e]), maxgap, gd } }
