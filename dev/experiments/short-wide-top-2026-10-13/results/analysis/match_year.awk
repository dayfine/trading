function jdn(s,   y, m, d, a, y2, m2) { y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  a = int((14 - m) / 12); y2 = y + 4800 - a; m2 = m + 12 * a - 3
  return d + int((153 * m2 + 2) / 5) + 365 * y2 + int(y2 / 4) - int(y2 / 100) + int(y2 / 400) - 32045 }
function fri(s,   j) { j = jdn(s); return j + ((4 - j % 7) + 7) % 7 }
function qs(A,lo,hi,  i,last,t,p){ if(lo>=hi) return; p=int((lo+hi)/2); t=A[lo];A[lo]=A[p];A[p]=t; last=lo; for(i=lo+1;i<=hi;i++) if(A[i]<A[lo]){last++;t=A[last];A[last]=A[i];A[i]=t}; t=A[lo];A[lo]=A[last];A[last]=t; qs(A,lo,last-1); qs(A,last+1,hi) }
BEGIN { J0 = jdn("2000-01-07") }
FNR == 1 { f++ }
f == 1 { b = (fri($2) - J0) / 28; nn[b]++; v[b, nn[b]] = $5 + 0; if ($5 + 0 > 0) pp[b]++; next }
f == 2 { ne++; b = int((jdn($24) - J0 + 14) / 28); eb[ne] = b; e120[ne] = $12 + 0; eo2[ne] = $14 + 0; y[ne] = substr($2, 1, 4); next }
END { for (b in nn) { delete A; for (k = 1; k <= nn[b]; k++) A[k] = v[b, k]; qs(A, 1, nn[b]); md[b] = A[int(0.5 * (nn[b] - 1)) + 1] }
  for (i = 1; i <= ne; i++) { b = eb[i]; if (!(b in nn)) continue; k = y[i]; N[k]++; O2[k] += (eo2[i] > 0); E[k] += (e120[i] > 0); NB[k] += pp[b] / nn[b]; AB[k] += (e120[i] > md[b]) }
  print "year      n   O2 beat  O1+120 beat  matched-null O1+120 beat  event-minus-null  share above the date's null median"
  for (k = 2000; k <= 2025; k++) printf "%d  %5d   %5.1f%%    %5.1f%%        %5.1f%%                %+5.1f pp         %5.1f%%\n", k, N[k], 100*O2[k]/N[k], 100*E[k]/N[k], 100*NB[k]/N[k], 100*(E[k]-NB[k])/N[k], 100*AB[k]/N[k]
}
