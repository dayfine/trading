# Perturbation of the regime reading: SPY TR arithmetic mean return (x252, %/yr) by regime, where the regime of each
# day is read from the PRIOR week's close (lagged) under three MA definitions, plus the same-week reading (look-ahead,
# reference only). Weekly closes and the classifier's 30-week WMA come from the stage csv (2-decimal closes).
# Inputs: stage csv, SPY daily csv.
BEGIN { FS = "," }
FILENAME == ARGV[1] { if (FNR > 1) { nw++; WD[nw] = $2; C[nw] = $3; M[nw] = $4 } next }
FILENAME == ARGV[2] { if (FNR > 1) { ns++; SD[ns] = $1; TR[$1] = $6 + 0 } next }
function lab(c, m, m4) { return (c > m && m > m4) ? "UP" : ((c < m && m < m4) ? "DOWN" : "MIXED") }
END { for (i = 30; i <= nw; i++) { s = 0; for (q = i - 29; q <= i; q++) s += C[q]; SMA[i] = s / 30 }
  for (i = 1; i <= nw; i++) { R1[i] = (i >= 34) ? lab(C[i], SMA[i], SMA[i-4]) : ""; R2[i] = (i >= 38) ? lab(C[i], SMA[i], SMA[i-8]) : ""; R3[i] = (i > 4 && M[i-4] > 0) ? lab(C[i], M[i], M[i-4]) : "" }
  w = 0; prev = ""
  for (j = 1; j <= ns; j++) { d = SD[j]; if (d < "2000-01-04" || d > "2026-06-25") { prev = d; continue } if (prev == "") { prev = d; continue }
    r = TR[d] / TR[prev] - 1; prev = d; while (w < nw && WD[w+1] < d) w++
    if (R1[w] != "") { n1[R1[w]]++; s1[R1[w]] += r } if (R2[w] != "") { n2[R2[w]]++; s2[R2[w]] += r } if (R3[w] != "") { n3[R3[w]]++; s3[R3[w]] += r }
    if (w + 1 <= nw && R1[w+1] != "") { n4[R1[w+1]]++; s4[R1[w+1]] += r } }
  split("UP MIXED DOWN", K, " ")
  printf "%-40s", "lagged SMA30, 4-week slope (pack rule):"; for (k = 1; k <= 3; k++) printf "  %s n %4d %+6.1f%%/yr", K[k], n1[K[k]], 25200 * s1[K[k]] / n1[K[k]]; print ""
  printf "%-40s", "lagged SMA30, 8-week slope:"; for (k = 1; k <= 3; k++) printf "  %s n %4d %+6.1f%%/yr", K[k], n2[K[k]], 25200 * s2[K[k]] / n2[K[k]]; print ""
  printf "%-40s", "lagged WMA30 (classifier), 4-week slope:"; for (k = 1; k <= 3; k++) printf "  %s n %4d %+6.1f%%/yr", K[k], n3[K[k]], 25200 * s3[K[k]] / n3[K[k]]; print ""
  printf "%-40s", "same-week SMA30/4 (look-ahead, reference):"; for (k = 1; k <= 3; k++) printf "  %s n %4d %+6.1f%%/yr", K[k], n4[K[k]], 25200 * s4[K[k]] / n4[K[k]]; print "" }
