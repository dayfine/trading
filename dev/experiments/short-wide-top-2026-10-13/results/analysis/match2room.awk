# date bucket x distance bucket matched null. file1 = ra_null2.csv ; file2 = ra_ev.csv
function jdn(s,   y, m, d, a, y2, m2) { y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return d + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045 }
function fri(s,   j) { j = jdn(s); return j + ((4 - j % 7) + 7) % 7 }
function db(d) { return (d > -0.2) ? "a>-20" : (d > -0.3 ? "b-20..-30" : (d > -0.4 ? "c-30..-40" : (d > -0.5 ? "d-40..-50" : "e<-50"))) }
function qs(A,lo,hi,  i,last,t,p){ if(lo>=hi) return; p=int((lo+hi)/2); t=A[lo];A[lo]=A[p];A[p]=t; last=lo; for(i=lo+1;i<=hi;i++) if(A[i]<A[lo]){last++;t=A[last];A[last]=A[i];A[i]=t}; t=A[lo];A[lo]=A[last];A[last]=t; qs(A,lo,last-1); qs(A,last+1,hi) }
BEGIN { J0 = jdn("2000-01-07") }
FNR == 1 { f++ }
f == 1 { if ($6 == "") next; c = ((fri($2) - J0) / 28) SUBSEP db($6 + 0); if (MODE == "fall" && !($7 == 1 && $8 == 1)) next
         nn[c]++; v[c, nn[c]] = $5 + 0; if ($5 + 0 > 0) pp[c]++; next }
f == 2 { ne++; F = jdn($24); b = int((F - J0 + 14) / 28); ec[ne] = b SUBSEP db($19 + 0); r = $17 + 0; eg[ne] = (r <= 0.15) ? "room<=15" : (r <= 0.30 ? "room15-30" : (r <= 0.60 ? "room30-60" : (r <= 1.0 ? "room60-100" : "room>100"))); e120[ne] = $12 + 0; ey[ne] = substr($2,1,4)+0; next }
END {
  for (c in nn) { delete A; for (k = 1; k <= nn[c]; k++) A[k] = v[c, k]; qs(A, 1, nn[c]); md[c] = A[int(0.5 * (nn[c] - 1)) + 1] }
  for (i = 1; i <= ne; i++) { c = ec[i]; if (!(c in nn) || nn[c] < 20) { miss++; continue }
    for (q = 1; q <= 3; q++) { k = (q == 1) ? eg[i] : (q == 2 ? "ALL" : ((ey[i] <= 2012) ? "h1 " : "h2 ") eg[i])
      N[k]++; EB[k] += (e120[i] > 0); NB[k] += pp[c] / nn[c]; AB[k] += (e120[i] > md[c]); ED[k] += e120[i] - md[c] } }
  printf "mode=%s; events skipped (no null cell with >= 20 rows): %d\n", MODE, miss + 0
  for (k in N) printf "%-16s n=%5d  O1+120 beat event %5.1f%% vs matched null %5.1f%% | share above the cell null median %5.1f%% | mean (event - null median) %+6.2f pp\n", k, N[k], 100*EB[k]/N[k], 100*NB[k]/N[k], 100*AB[k]/N[k], 100*ED[k]/N[k]
}
