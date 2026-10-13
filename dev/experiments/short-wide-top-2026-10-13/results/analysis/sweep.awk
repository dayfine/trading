function jdn(s,   y, m, d, a, y2, m2) { y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return d + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045 }
function fri(s,   j) { j = jdn(s); return j + ((4 - j % 7) + 7) % 7 }
BEGIN { J0 = jdn("2000-01-07") }
FNR == 1 { f++ }
f == 1 { b = (fri($2) - J0) / 28; nn[b]++; if ($5 + 0 > 0) pp[b]++; next }
f == 2 { ne++; b = int((jdn($24) - J0 + 14) / 28); eb[ne] = b; eo2[ne] = ($14 + 0 > 0); y[ne] = substr($2, 1, 4) + 0; next }
END { print "cut   late-half n   event O2 beat   matched null (O1+120)   event - null"
  for (c = 2004; c <= 2020; c += 2) { n = 0; e = 0; nb = 0; for (i = 1; i <= ne; i++) { if (y[i] < c || !(eb[i] in nn)) continue; n++; e += eo2[i]; nb += pp[eb[i]] / nn[eb[i]] }
    printf "%d+  %6d        %5.1f%%          %5.1f%%                 %+5.1f pp\n", c, n, 100*e/n, 100*nb/n, 100*(e-nb)/n } }
