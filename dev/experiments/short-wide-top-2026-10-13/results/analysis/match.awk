# calendar-matched null. file1 = ra_null.csv (sym,date,raw,o60,o120); file2 = ra_ev.csv (EV columns, col24 = breakdown Friday)
function jdn(s,   y, m, d, a, y2, m2) { y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return d + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045 }
function fri(s,   j) { j = jdn(s); return j + ((4 - j % 7) + 7) % 7 }
function qs(A,lo,hi,  i,last,t,p){ if(lo>=hi) return; p=int((lo+hi)/2); t=A[lo];A[lo]=A[p];A[p]=t; last=lo; for(i=lo+1;i<=hi;i++) if(A[i]<A[lo]){last++;t=A[last];A[last]=A[i];A[i]=t}; t=A[lo];A[lo]=A[last];A[last]=t; qs(A,lo,last-1); qs(A,last+1,hi) }
BEGIN { J0 = jdn("2000-01-07") }
FNR == 1 { f++ }
f == 1 { b = (fri($2) - J0) / 28; nn[b]++; v60[b, nn[b]] = $4 + 0; v120[b, nn[b]] = $5 + 0; if ($4 + 0 > 0) p60[b]++; if ($5 + 0 > 0) p120[b]++; next }
f == 2 { ne++; F = jdn($24); b = int((F - J0 + 14) / 28); eb[ne] = b; e60[ne] = $11 + 0; e120[ne] = $12 + 0; eo2[ne] = $14 + 0; ey[ne] = substr($2, 1, 4) + 0; eph[ne] = $6; next }
END {
  for (b in nn) { delete A; for (k = 1; k <= nn[b]; k++) A[k] = v60[b, k]; qs(A, 1, nn[b]); m60[b] = A[int(0.5 * (nn[b] - 1)) + 1]
                  delete A; for (k = 1; k <= nn[b]; k++) A[k] = v120[b, k]; qs(A, 1, nn[b]); m120[b] = A[int(0.5 * (nn[b] - 1)) + 1] }
  for (i = 1; i <= ne; i++) { b = eb[i]; if (!(b in nn)) { miss++; continue }
    g[1] = "ALL"; g[2] = (ey[i] <= 2012) ? "h1" : "h2"; g[3] = "phase " eph[i]
    for (q = 1; q <= 3; q++) { k = g[q]; N[k]++; NB60[k] += p60[b] / nn[b]; NB120[k] += p120[b] / nn[b]
      EB60[k] += (e60[i] > 0); EB120[k] += (e120[i] > 0); EO2[k] += (eo2[i] > 0)
      AB60[k] += (e60[i] > m60[b]); AB120[k] += (e120[i] > m120[b]); AO2[k] += (eo2[i] > m120[b]) }
  }
  printf "events without a null bucket: %d\n", miss + 0
  printf "%-16s %6s | %-27s | %-27s | %-22s | %s\n", "group", "n", "O1+60 beat: event / null", "O1+120 beat: event / null", "O2 beat event / null120", "share of events worse-for-the-stock than the date's null median: O1+60, O1+120, O2"
  for (k in N) printf "%-16s %6d | %5.1f%% / %5.1f%%            | %5.1f%% / %5.1f%%            | %5.1f%% / %5.1f%%       | %5.1f%%  %5.1f%%  %5.1f%%\n", k, N[k], 100*EB60[k]/N[k], 100*NB60[k]/N[k], 100*EB120[k]/N[k], 100*NB120[k]/N[k], 100*EO2[k]/N[k], 100*NB120[k]/N[k], 100*AB60[k]/N[k], 100*AB120[k]/N[k], 100*AO2[k]/N[k]
}
