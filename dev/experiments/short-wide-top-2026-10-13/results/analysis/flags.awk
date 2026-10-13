function jdn(s,   y, m, d, a, y2, m2) { y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return d + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045 }
function fri(s,   j) { j = jdn(s); return j + ((4 - j % 7) + 7) % 7 }
function qs(A,lo,hi,  i,last,t,p){ if(lo>=hi) return; p=int((lo+hi)/2); t=A[lo];A[lo]=A[p];A[p]=t; last=lo; for(i=lo+1;i<=hi;i++) if(A[i]<A[lo]){last++;t=A[last];A[last]=A[i];A[i]=t}; t=A[lo];A[lo]=A[last];A[last]=t; qs(A,lo,last-1); qs(A,last+1,hi) }
BEGIN { J0 = jdn("2000-01-07") }
FNR == 1 { f++ }
f == 1 { b = (fri($2) - J0) / 28; nn[b]++; v[b, nn[b]] = $4 + 0; next }
f == 2 { ne++; b = int((jdn($24) - J0 + 14) / 28); eb[ne] = b; e60[ne] = $11 + 0; wk[ne] = $24; ph[ne] = $6; next }
END { for (b in nn) { delete A; for (k = 1; k <= nn[b]; k++) A[k] = v[b, k]; qs(A, 1, nn[b]); md[b] = A[int(0.5 * (nn[b] - 1)) + 1] }
  for (i = 1; i <= ne; i++) { b = eb[i]; if (!(b in nn)) continue; print ph[i] "," wk[i] "," (e60[i] > md[b]) } }
